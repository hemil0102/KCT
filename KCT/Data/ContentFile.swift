//
//  ContentFile.swift
//  KCT
//
//  역할 : 번들·다운로드 두 자리에서 JSON 한 벌을 읽고 쓴다
//  요점 : 「받아 둔 것 먼저, 없으면 번들」이라는 순서를 여기 한 곳에만 둔다
//
//  ── 구성 ──────────────────────────────────────────────
//  ContentFile<Payload>          내용 파일 하나 (제네릭 — 담는 것만 다르다)
//  ├─ fileName                   확장자를 뺀 파일 이름 ("questions")
//  ├─ downloadedURL              문서 폴더의 그 파일 자리
//  ├─ LoadError.notFound         번들에도 없을 때
//  ├─ loadPreferringDownloaded(isEmpty:fallback:failureMessage:)
//  │                             ← 두 카탈로그가 쓰는 입구. 세 갈래를 한 벌로
//  ├─ loadDownloaded()           받아 둔 것. 없거나 깨졌으면 nil
//  ├─ loadBundled()              앱과 함께 나온 것. 이것마저 없으면 던진다
//  └─ saveDownloaded(_:)         받은 것을 문서 폴더에 적어 둔다
//                                ⚠️ 아직 부르는 곳이 없다 (서버 갱신을 붙일 자리)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionCatalog.loaded() · MatchingSetCatalog.loaded()
//  기대는 것    : Foundation 뿐
//  건드리지 않는 것 : 서버에서 받아 오는 일 — 이 타입은 읽고 쓰기만 한다
//
//  Created by harryho on 9/9/26.
//

import Foundation

/// 앱이 읽는 내용 파일 하나.
///
/// 문제집(`questions.json`)과 연결 문제 묶음(`matchingSets.json`)이 **같은 타입을 씁니다.**
/// 둘 다 「받아 둔 것 먼저, 없으면 번들」이고 담는 내용만 다르기 때문입니다.
///
/// - Note: 서버에서 **받아 오는 일**은 여기 없습니다. 받아서 ``saveDownloaded(_:)`` 로
///   적어 두는 것까지가 6단계의 몫이고, 이 타입은 **읽고 쓰기만** 합니다.
struct ContentFile<Payload: Codable> {
    
    /// 확장자를 뺀 파일 이름.
    let fileName: String
    
    // ❓ 파일매니저의 옵션 의미, 파일이 저장된 경로가 어디인지?
    private var downloadedURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("\(fileName).json")
    }
    
    enum LoadError: Error {
        case notFound(String)
    }
    
    /// **받아 둔 것 먼저, 없으면 번들, 그것마저 없으면 빈 것.**
    ///
    /// 문제집과 연결 문제 묶음이 각자 이 세 갈래를 한 벌씩 들고 있었습니다.
    /// 「받아 둔 것이 비어 있으면 번들로 물러선다」는 판단을 한쪽만 고치면
    /// 두 카탈로그가 다르게 동작하게 되므로 여기로 모았습니다.
    ///
    /// - Parameters:
    ///   - isEmpty: 읽어 온 것이 **쓸 만한가**를 판단한다. 파일이 있어도 내용이
    ///     비었으면 번들로 물러서기 위해서다 (예: `\.questions.isEmpty`).
    ///   - fallback: 번들에서도 못 읽었을 때 쓸 빈 값. 앱이 죽는 것보다 빈 화면이 낫다.
    ///   - failureMessage: 번들에서 못 읽었을 때 개발 중에만 띄울 말.
    ///     `assertionFailure` 라 릴리스에서는 조용히 `fallback` 이 쓰인다.
    func loadPreferringDownloaded(
        isEmpty: (Payload) -> Bool,
        fallback: Payload,
        failureMessage: String
    ) -> Payload {
        if let downloaded = loadDownloaded(), !isEmpty(downloaded) {
            return downloaded
        }

        do {
            return try loadBundled()
        } catch {
            assertionFailure("\(failureMessage): \(error)")
            return fallback
        }
    }

    /// 서버에서 받아 기기에 적어 둔 것. 없거나 깨졌으면 `nil`.
    ///
    /// 깨졌을 때 오류를 던지지 않는 이유 — 앱이 안 켜지는 것보다
    /// **번들 것으로 도는 편이 낫습니다.**
    func loadDownloaded() -> Payload? {
        guard let url = downloadedURL, let data = try? Data(contentsOf: url) else { return nil }
        
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
    
    /// 앱과 함께 나온 것. 이것마저 없으면 오류입니다.
    func loadBundled() throws -> Payload {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw LoadError.notFound(fileName)
        }
        
        return try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
    }
    
    /// 서버에서 받은 것을 적어 둔다.
    ///
    /// - Note: **아직 부르는 곳이 없습니다.** 서버 갱신을 붙일 자리(씸)로 남겨 둔 것입니다.
    // ❓ 여기서 encode를 하는 이유가 뭐지? 그냥 받은 것이 json이면 다시 이렇게 할 이유가 있나?
    //    → Q&A.md 「ContentFile 은 왜 받은 JSON 을 다시 encode 하나」 참고
    func saveDownloaded(_ payload: Payload) throws {
        guard let url = downloadedURL else { return }
        try JSONEncoder().encode(payload).write(to: url, options: .atomic)
    }
}
