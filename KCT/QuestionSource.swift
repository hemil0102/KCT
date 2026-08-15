//
//  QuestionSource.swift
//  KCT
//
//  문제집을 "어디서" 가져오는지 담당한다.
//  번들과 서버가 같은 JSON 형식·같은 디코딩 경로를 쓰도록 해서,
//  나중에 서버를 붙일 때 새 구현체 하나만 추가하면 되게 한다.
//

import Foundation

/// 문제집 파일의 내용.
///
/// 배열이 아니라 객체로 감싸 두면, 나중에 필드를 추가해도 기존 디코더가 깨지지 않는다.
struct QuestionPayload: Codable {
    /// 문제집 버전. 서버 것이 더 높을 때만 내려받는다.
    let version: Int
    let questions: [Question]
}

protocol QuestionSource {
    func load() async throws -> QuestionPayload
}

/// 앱에 함께 넣어 둔 기본 문제집. 첫 실행과 오프라인에서 항상 동작하게 해 준다.
struct BundledQuestionSource: QuestionSource {
    var fileName = "questions"
    var bundle: Bundle = .main

    enum LoadError: Error {
        case fileNotFound(String)
    }

    func load() async throws -> QuestionPayload {
        try loadFromBundle()
    }

    /// 앱 시작 시 곧바로 필요하므로 동기 방식도 제공한다.
    func loadFromBundle() throws -> QuestionPayload {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw LoadError.fileNotFound(fileName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(QuestionPayload.self, from: data)
    }
}
