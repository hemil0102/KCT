//
//  QuestionCatalog.swift
//  KCT
//
//  앱이 사용하는 문제집을 들고 있는 곳.
//  화면·스케줄러는 여기서만 문제를 얻는다. 덕분에 문제집 출처(번들/서버)가 바뀌어도
//  다른 코드는 손대지 않는다.
//

import Foundation
import Observation

@Observable
final class QuestionCatalog {
    private(set) var version: Int
    private(set) var questions: [Question]
    /// 오답 보기를 뽑을 정답 모음. 문제집이 바뀔 때만 다시 계산한다.
    private(set) var answerPool: [String]

    init(payload: QuestionPayload) {
        self.version = payload.version
        self.questions = payload.questions
        self.answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    /// 앱에 들어 있는 기본 문제집으로 카탈로그를 만든다.
    static func bundled() -> QuestionCatalog {
        do {
            return QuestionCatalog(payload: try BundledQuestionSource().loadFromBundle())
        } catch {
            assertionFailure("기본 문제집을 읽지 못했습니다: \(error)")
            return QuestionCatalog(payload: QuestionPayload(version: 0, questions: []))
        }
    }

    /// 문제집을 통째로 교체한다.
    ///
    /// ⚠️ 세션 도중에 부르면 풀고 있던 문제가 사라질 수 있다.
    /// 앱 시작 시나 세션이 끝난 뒤처럼 안전한 시점에만 호출할 것.
    func replace(with payload: QuestionPayload) {
        guard payload.version > version, !payload.questions.isEmpty else { return }
        version = payload.version
        questions = payload.questions
        answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    func question(id: Int) -> Question? {
        questions.first { $0.id == id }
    }

    private static func makeAnswerPool(from questions: [Question]) -> [String] {
        Array(Set(questions.map(\.answer)))
    }
}
