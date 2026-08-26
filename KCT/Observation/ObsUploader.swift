//
//  ObsUploader.swift
//  KCT
//
//  역할 : 아직 안 올라간 관찰 기록을 Supabase 로 밀어 올린다
//  요점 : 실패해도 아무 일이 없다. 폰에 남아 있다가 다음번에 다시 간다
//
//  ── 구성 ──────────────────────────────────────────────
//  ObsUploader                 업로더 (@MainActor)
//  ├─ modelContext             기록을 읽고, 성공 표시를 남길 저장소
//  ├─ isUploading              지금 올리는 중인가 (static — 겹쳐 부르는 것을 막는다)
//  ├─ deviceID                 이 기기의 고유 번호 (UserDefaults 에 한 번 만들어 둔다)
//  ├─ Payload                  서버로 보낼 JSON 한 줄의 모양
//  ├─ uploadPending()          안 올라간 줄을 모아 한 번에 보낸다 (입구)
//  ├─ pendingRecords()         uploadedAt 이 nil 인 줄을 꺼낸다
//  └─ send(_:)                 실제 HTTP POST. 성공하면 true
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession 이 회차를 시작할 때 / 채점을 마쳤을 때
//    → uploadPending()
//    → pendingRecords() : uploadedAt == nil 인 줄을 최대 200개
//    → Payload 로 옮겨 담아 JSON 배열 하나로 만든다
//    → send() : POST {projectURL}/rest/v1/obs_record
//    → 2xx 면 그 줄들의 uploadedAt 에 지금 시각을 찍고 save()
//    → 실패하면 아무것도 하지 않는다. 다음 회차가 다시 시도한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.start() · QuizSession.gradeAll()
//  기대는 것    : ObsRecord(무엇을 보낼지), SupabaseConfig(어디로 보낼지)
//  건드리지 않는 것 : 화면 — 성공도 실패도 어머니에게 보이지 않는다.
//                    실패를 알려 봐야 어머니가 할 수 있는 일이 없다
//
//  ⚠️ 서버 쪽은 「입력만 되고 읽기는 안 되는」 표입니다. 그래서 이 파일에
//     내려받는 코드가 없습니다. 기록을 보는 것은 Supabase 대시보드에서 합니다.
//

import Foundation
import SwiftData

/// 관찰 기록을 서버로 올리는 곳.
///
/// ## 실패를 어떻게 다루나
///
/// **아무것도 하지 않습니다.** 오류를 던지지도, 화면에 알리지도, 재시도 타이머를
/// 걸지도 않습니다. 올라가지 않은 줄은 ``ObsRecord/uploadedAt`` 이 `nil` 인 채로
/// 폰에 남고, **다음 회차가 시작될 때 자연스럽게 다시 갑니다.**
///
/// 이 단순함이 값어치입니다. 재시도 로직은 대개 재시도 로직의 버그를 낳는데,
/// 여기서는 "다음에 또 보낸다" 가 이미 전체 설계입니다.
///
/// ## 왜 `@MainActor` 인가
///
/// `ModelContext` 는 만들어진 곳에서만 안전하게 쓸 수 있습니다. 네트워크는
/// `await` 하는 동안 알아서 비켜 주므로, 메인에 묶어 두어도 화면이 멈추지 않습니다.
/// **초보 단계에서 동시성 버그를 만들지 않는 가장 싼 방법**입니다.
@MainActor
struct ObsUploader {
    
    let modelContext: ModelContext
    /// 한 번에 보낼 최대 줄 수.
    ///
    /// 처음 켰거나 오래 못 올렸을 때 수천 줄을 한 요청에 밀어 넣지 않기 위해서입니다.
    /// 남은 것은 다음번에 갑니다 — 서두를 이유가 없습니다.
    private let batchLimit = 200
    
    /// 지금 올리는 중인가.
    ///
    /// ## 왜 필요한가
    ///
    /// ``uploadPending()`` 이 겹쳐 불리면 **같은 줄이 두 번 올라갑니다.**
    ///
    /// ```
    /// A : 안 올라간 줄 5개를 꺼낸다
    /// B : 안 올라간 줄 5개를 꺼낸다   ← A 가 아직 표시를 안 남겼다
    /// A : 5줄 POST
    /// B : 같은 5줄 POST              ← 표에 10줄
    /// ```
    ///
    /// `@MainActor` 는 두 코드가 **같은 순간에** 도는 것만 막습니다. `await` 에서
    /// 잠시 비켜 준 사이에 다른 호출이 끼어드는 것(**재진입**)은 막지 않습니다.
    /// 2026-08-26 에 실제로 한 회차가 10줄로 들어갔습니다.
    ///
    /// ## 왜 `static` 인가
    ///
    /// ``ObsUploader`` 는 부를 때마다 새로 만들어지는 `struct` 입니다. 보통
    /// 프로퍼티에 깃발을 두면 **매번 새것이라 아무 소용이 없습니다.** `static` 은
    /// 타입에 하나뿐이라 누가 어디서 부르든 같은 깃발을 봅니다.
    ///
    /// - Note: 깃발을 ``QuizSession`` 에 둘 수도 있지만, 그러면 **부르는 쪽마다**
    ///   조심해야 합니다. 지켜야 할 규칙은 "겹쳐 올리지 마라" 하나이므로,
    ///   그 규칙이 깨지는 자리에 둡니다.
    private static var isUploading = false

    // MARK: - 이 기기가 누구인가
    
    /// 이 기기의 고유 번호.
    ///
    /// 형님 시뮬레이터와 어머니 폰을 갈라야 기록이 섞이지 않습니다.
    /// 처음 한 번 만들어 `UserDefaults` 에 넣어 두고, 그 뒤로는 같은 값을 씁니다.
    ///
    /// - Note: 개인을 식별하는 값이 아닙니다. 그냥 무작위 UUID 이고,
    ///   앱을 지웠다 깔면 새 번호가 됩니다.
    static var deviceID: String {
        let key = "obs.deviceID"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
    // MARK: - 서버로 보낼 모양
    
    /// 서버 표의 한 줄에 대응하는 JSON.
    ///
    /// ``ObsRecord`` 를 그대로 못 보내는 이유 — `@Model` 클래스는 SwiftData 가
    /// 속을 바꿔 놓아서 `Encodable` 로 곧장 쓰기 어렵습니다. **보낼 모양을 따로
    /// 두는 편이** 서버 표가 바뀌어도 앱 저장 구조가 안 흔들립니다.
    ///
    /// - Note: 이름을 `deviceID` 처럼 카멜케이스로 쓰지만 서버에는 `device_id` 로
    ///   갑니다. ``send(_:)`` 의 `keyEncodingStrategy` 가 바꿔 줍니다.
    private struct Payload: Encodable {
        let deviceID: String
        let sessionID: UUID
        let askedAt: Date
        let questionID: Int
        let secToFirstTouch: Double?
        let secToSubmit: Double
        let isCorrect: Bool
        let modeRaw: Int
        let wasFirstEver: Bool
        let affectsProgress: Bool
    }
    
    // MARK: - 입구
    
    /// 아직 안 올라간 줄을 모아 한 번에 보낸다.
    ///
    /// 보낼 것이 없으면 네트워크를 건드리지 않고 곧장 돌아옵니다.
    /// 이미 올리는 중이면 **아무것도 하지 않고 물러납니다** — ``isUploading`` 참고.
    /// 물러난 줄은 사라지지 않습니다. 다음 회차가 다시 보냅니다.
    func uploadPending() async {
        // 겹쳐 부르면 같은 줄이 두 번 올라간다. defer 로 깃발을 반드시 내린다.
        guard !Self.isUploading else { return }
        Self.isUploading = true
        defer { Self.isUploading = false }

        let records = pendingRecords()
        print("📤 안 올라간 줄:", records.count)
        guard !records.isEmpty else { return }
        
        let payloads = records.map { record in
            Payload(
                deviceID: Self.deviceID,
                sessionID: record.sessionID,
                askedAt: record.askedAt,
                questionID: record.questionID,
                secToFirstTouch: record.secToFirstTouch,
                secToSubmit: record.secToSubmit,
                isCorrect: record.isCorrect,
                modeRaw: record.modeRaw,
                wasFirstEver: record.wasFirstEver,
                affectsProgress: record.affectsProgress
            )
        }
        
        guard await send(payloads) else { return }
        
        let now = Date.now
        for record in records { record.uploadedAt = now }
        try? modelContext.save()
    }
    
    // MARK: - 안에서 하는 일
    
    /// ``ObsRecord/uploadedAt`` 이 `nil` 인 줄을 오래된 것부터 꺼낸다.
    private func pendingRecords() -> [ObsRecord] {
        var descriptor = FetchDescriptor<ObsRecord>(
            predicate: #Predicate { $0.uploadedAt == nil },
            sortBy: [SortDescriptor(\.askedAt)]
        )
        descriptor.fetchLimit = batchLimit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// 실제로 HTTP 로 보낸다. 성공하면 `true`.
    ///
    /// 헤더 둘이면 됩니다.
    /// - `apikey` — 어느 프로젝트인지
    /// - `Authorization: Bearer` — 같은 값. PostgREST 가 권한을 정할 때 본다
    ///
    /// ## 업서트를 쓰지 않는 이유
    ///
    /// 한때 `?on_conflict=...` 와 `Prefer: resolution=ignore-duplicates` 를 붙여
    /// 중복을 서버가 무시하게 했습니다. 그런데 PostgREST 는 업서트에 **UPDATE 권한**
    /// 까지 요구하고, 우리 표는 **입력만** 열려 있어서 모든 요청이 `401` 로 튕겼습니다
    /// (2026-08-26). UPDATE 정책을 여는 것은 **기록을 고칠 수 있게 만드는 일**이라
    /// 하지 않았습니다.
    ///
    /// 대신 중복을 **볼 때** 걸러냅니다 — `select distinct on (device_id, session_id,
    /// question_id)`. 이 기록은 덮어쓰지 않고 쌓기만 하는 과거라 그래도 됩니다.
    ///
    /// ## 날짜에 소수점을 살린다
    ///
    /// `JSONEncoder` 의 기본 `.iso8601` 은 **소수점 이하를 버립니다.** 그러면
    /// `asked_at` 이 초 단위로 잘려, 한 회차의 문항 다섯 개가 같은 초에 몰리면
    /// **출제 순서를 되살릴 수 없습니다.** 실제로 시험 회차가 5.1초 만에 끝난 적이
    /// 있습니다(2026-08-26). 그래서 형식을 직접 지정합니다.
    ///
    /// 포매터를 함수 안에서 매번 만드는 것은 낭비처럼 보이지만, 이 함수는
    /// **회차당 많아야 한 번** 불립니다. 전역 상태를 하나 늘리는 값이 더 비쌉니다.
    ///
    /// - Note: 오류를 밖으로 던지지 않고 `false` 만 돌려줍니다. 부르는 쪽이
    ///   할 수 있는 일이 "다음에 다시 보낸다" 하나뿐이라, 오류의 종류가
    ///   행동을 바꾸지 않습니다.
    private func send(_ payloads: [Payload]) async -> Bool {
        let path = "/rest/v1/obs_record"
        guard let url = URL(string: SupabaseConfig.projectURL + path) else { return false }

        // 소수점 세 자리까지 살린 ISO 8601 (예: 2026-08-26T15:57:08.412Z)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso.string(from: date))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? encoder.encode(payloads)

        guard request.httpBody != nil else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
