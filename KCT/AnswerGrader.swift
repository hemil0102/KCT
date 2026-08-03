//
//  AnswerGrader.swift
//  IdeaPlayground
//
//  온디바이스 모델을 사용해 사용자의 답을 정답과 대조해 채점한다. (C단계)
//

import Foundation
import FoundationModels

/// 모델이 생성하는 채점 결과.
///
/// `@Generable`을 붙이면 모델이 이 구조체 형태로 직접 결과를 만들어 준다.
/// 덕분에 문자열을 직접 파싱할 필요가 없고, 타입 안전하게 값을 받는다.
@Generable
struct GradingResult {
    /// 사용자의 답이 정답과 의미상 일치하면 true.
    @Guide(description: "사용자의 답이 정답과 의미상 일치하면 true, 아니면 false")
    let isCorrect: Bool

    /// 채점 이유(한국어 한 문장).
    @Guide(description: "맞거나 틀린 이유를 한국어 한 문장으로 간단히 설명")
    let reason: String
}

/// 문제 하나에 대한 사용자의 답을 채점하는 도우미.
struct AnswerGrader {
    /// 주어진 문제와 사용자 답을 모델로 채점한다.
    /// - Returns: 정답 여부와 이유가 담긴 ``GradingResult``.
    func grade(question: Question, userAnswer: String) async throws -> GradingResult {
        // 채점 규칙을 지침으로 지정한다. (프롬프트보다 우선 적용됨)
        let instructions = """
            당신은 한국어 퀴즈 채점 도우미입니다.
            제시된 '정답'과 사용자의 '답변'이 의미상 같은지 판단하세요.
            띄어쓰기, 조사, 표현이 달라도 핵심 내용이 일치하면 정답으로 처리하세요.
            정답에 여러 항목이 있으면 사용자가 핵심 항목들을 모두 말했는지 확인하세요.
            """

        let session = LanguageModelSession(instructions: instructions)

        let prompt = """
            문제: \(question.question)
            정답: \(question.answer)
            사용자 답변: \(userAnswer)

            사용자 답변이 정답과 일치하는지 채점하세요.
            """

        // 결과를 GradingResult 타입으로 직접 받는다. (guided generation)
        let response = try await session.respond(to: prompt, generating: GradingResult.self)
        return response.content
    }
}
