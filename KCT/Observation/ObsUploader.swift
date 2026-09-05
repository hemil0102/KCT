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
/// 실패하면 아무것도 하지 않습니다 — 못 올라간 줄은 ``ObsRecord/uploadedAt`` 이 `nil` 인 채 폰에 남아 다음 회차가 시작될 때 다시 갑니다.
/// `@MainActor` 인 것은 `ModelContext` 를 만들어진 곳에서만 쓰기 위해서이며, 네트워크는 `await` 하는 동안 비켜 주므로 화면이 멈추지 않습니다.
@MainActor
struct ObsUploader {
    
    let modelContext: ModelContext
    /// 한 번에 보낼 최대 줄 수.
    ///
    /// 오래 못 올렸을 때 수천 줄을 한 요청에 밀어 넣지 않기 위해서이며, 남은 것은 다음번에 갑니다.
    private let batchLimit = 200
    
    /// 지금 올리는 중인가.
    ///
    /// `@MainActor` 는 두 코드가 같은 순간에 도는 것만 막고 `await` 사이에 끼어드는 **재진입**은 막지 못해, 2026-08-26 에 한 회차가 같은 줄을 두 번 올려 10줄로 들어갔습니다.
    /// ``ObsUploader`` 는 부를 때마다 새로 만들어지는 `struct` 라 인스턴스 프로퍼티로는 깃발 구실을 못 하므로 `static` 으로 둡니다.
    private static var isUploading = false

    // MARK: - 이 기기가 누구인가
    
    /// 이 기기의 고유 번호.
    ///
    /// 시뮬레이터와 어머니 폰의 기록을 가르려고 처음 한 번 만들어 `UserDefaults` 에 넣어 두고 계속 같은 값을 씁니다.
    ///
    /// - Note: 개인을 식별하는 값이 아니라 무작위 UUID 이며, 앱을 지웠다 깔면 새 번호가 됩니다.
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
    /// 보낼 모양을 따로 두어야 서버 표가 바뀌어도 앱 저장 구조가 안 흔들리며, 카멜케이스 이름은 ``send(_:)`` 의 `keyEncodingStrategy` 가 스네이크케이스로 바꿔 보냅니다.
    ///
    /// - Important: `encode(to:)` 를 손으로 쓰는 이유 — 자동 `Codable` 은 `nil` 인 키를 아예 빼는데, PostgREST 는 배열의 모든 객체가 같은 키를 가져야 해서 한 줄만 `reason` 을 가지면 회차 전체를 `400 PGRST102` 로 거부합니다 (2026-08-31).
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
        let chosen: String?
        let reason: String?
        let explanation: String?

        enum CodingKeys: String, CodingKey {
            case deviceID, sessionID, askedAt, questionID
            case secToFirstTouch, secToSubmit, isCorrect, modeRaw
            case wasFirstEver, affectsProgress, chosen, reason, explanation
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(deviceID, forKey: .deviceID)
            try container.encode(sessionID, forKey: .sessionID)
            try container.encode(askedAt, forKey: .askedAt)
            try container.encode(questionID, forKey: .questionID)
            try container.encode(secToFirstTouch, forKey: .secToFirstTouch)
            try container.encode(secToSubmit, forKey: .secToSubmit)
            try container.encode(isCorrect, forKey: .isCorrect)
            try container.encode(modeRaw, forKey: .modeRaw)
            try container.encode(wasFirstEver, forKey: .wasFirstEver)
            try container.encode(affectsProgress, forKey: .affectsProgress)
            try container.encode(chosen, forKey: .chosen)
            try container.encode(reason, forKey: .reason)
            try container.encode(explanation, forKey: .explanation)
        }
    }
    
    // MARK: - 입구
    
    /// 아직 안 올라간 줄을 모아 한 번에 보냅니다.
    ///
    /// 보낼 것이 없거나 이미 올리는 중이면 아무것도 하지 않고 물러납니다 — 물러난 줄은 사라지지 않고 다음 회차가 다시 보냅니다.
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
                affectsProgress: record.affectsProgress,
                chosen: record.chosen,
                reason: record.reason,
                explanation: record.explanation
            )
        }
        
        guard await send(payloads) else { return }
        
        let now = Date.now
        for record in records { record.uploadedAt = now }
        try? modelContext.save()
    }
    
    // MARK: - 안에서 하는 일
    
    /// ``ObsRecord/uploadedAt`` 이 `nil` 인 줄을 오래된 것부터 꺼냅니다.
    private func pendingRecords() -> [ObsRecord] {
        var descriptor = FetchDescriptor<ObsRecord>(
            predicate: #Predicate { $0.uploadedAt == nil },
            sortBy: [SortDescriptor(\.askedAt)]
        )
        descriptor.fetchLimit = batchLimit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// 실제로 HTTP 로 보냅니다. 성공하면 `true` 이며, 오류는 던지지 않습니다 — 부르는 쪽이 할 수 있는 일이 다음에 다시 보내는 것 하나뿐입니다.
    ///
    /// 업서트를 쓰지 않는 이유 — PostgREST 업서트는 UPDATE 권한까지 요구하는데 우리 표는 입력만 열려 있어 모든 요청이 `401` 로 튕겼고(2026-08-26), 중복은 볼 때 `distinct on` 으로 걸러냅니다.
    /// 날짜 형식을 직접 지정하는 이유 — 기본 `.iso8601` 은 소수점 이하를 버려, 한 회차가 5.1초 만에 끝났을 때 출제 순서를 되살릴 수 없었습니다(2026-08-26).
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
