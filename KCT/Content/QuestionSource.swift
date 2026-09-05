//
//  QuestionSource.swift
//  KCT
//
//  역할 : 문제집을 "어디서" 가져오는지 담당한다
//  요점 : 번들과 서버가 같은 형식·같은 디코딩 경로를 쓴다. 서버는 구현체 하나만 더 만들면 된다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionPayload             문제집 파일의 내용 (버전 + 문제 목록)
//  QuestionSource (protocol)   "문제집을 읽어 온다" 는 약속
//  └─ BundledQuestionSource    앱에 함께 넣어 둔 기본 문제집
//      ├─ fileName             찾을 파일 이름 ("questions")
//      ├─ load()               비동기 (프로토콜 요구사항)
//      └─ loadFromBundle()     동기 — 앱 시작 시 곧바로 필요해서
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionCatalog.bundled()
//    → BundledQuestionSource().loadFromBundle()
//    → Bundle 에서 questions.json 을 찾아 Data 로 읽음
//    → JSONDecoder 가 QuestionPayload 로 해독
//    → QuestionCatalog 이 그 내용을 보관
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionCatalog
//  기대는 것    : Question(Codable), 번들 안의 questions.json
//  건드리지 않는 것 : 교체 시점 판단 — 언제 갈아끼울지는 QuestionCatalog 이 정한다
//

import Foundation

/// 문제집 파일의 내용.
///
/// 배열이 아니라 객체로 감싸 두어야 나중에 필드를 추가해도 기존 디코더가 깨지지 않습니다.
struct QuestionPayload: Codable {
    /// 문제집 버전. 서버 것이 더 높을 때만 내려받는다.
    let version: Int

    let questions: [Question]
}

/// 문제집을 읽어 오는 곳이 지켜야 할 약속.
///
/// 서버를 붙일 때 이 약속을 지키는 타입을 하나 더 만들면 ``QuestionCatalog`` 은
/// 고치지 않아도 됩니다. 이것이 이음새(seam)입니다.
protocol QuestionSource {
    func load() async throws -> QuestionPayload
}

/// 앱에 함께 넣어 둔 기본 문제집.
///
/// 첫 실행과 오프라인에서도 항상 동작하게 해 주는 안전망이며, 서버를 붙인 뒤에도
/// 씨앗으로 남습니다.
///
/// - Note: 번들 리소스는 루트에 평평하게 놓이므로 소스가 `Content/` 아래에 있어도
///   이름만으로 찾습니다.
struct BundledQuestionSource: QuestionSource {
    var fileName = "questions"
    var bundle: Bundle = .main

    enum LoadError: Error {
        case fileNotFound(String)
    }

    func load() async throws -> QuestionPayload {
        try loadFromBundle()
    }

    /// 번들에서 곧바로 읽습니다.
    ///
    /// 앱 시작 시점에 문제집이 이미 있어야 첫 화면을 그릴 수 있어 동기 방식도 둡니다.
    func loadFromBundle() throws -> QuestionPayload {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw LoadError.fileNotFound(fileName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(QuestionPayload.self, from: data)
    }
}
