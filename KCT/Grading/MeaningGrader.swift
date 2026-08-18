//
//  MeaningGrader.swift
//  KCT
//
//  역할 : 직접입력 답을 온디바이스 모델로 "뜻이 같은가" 판정한다
//  요점 : 어르신은 조사·띄어쓰기를 정확히 맞추지 않는다. 글자가 아니라 뜻을 봐야 한다
//
//  ── 구성 ──────────────────────────────────────────────
//  GradingResult (@Generable)   모델이 만들어 주는 채점 결과
//  ├─ isCorrect                 뜻이 일치하는가
//  └─ reason                    한국어 한 문장 설명 (지금 화면에는 쓰지 않는다)
//
//  MeaningGrader
//  └─ grade(question:userAnswer:) async throws -> GradingResult
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.judge() 가 RuleGrader 에서 nil 을 받으면
//    → grade(question:userAnswer:) 호출
//    → 지침(instructions)으로 채점 규칙을 세운 세션을 만든다
//    → 문제·정답·사용자 답변을 프롬프트로 넘긴다
//    → 유도 생성(guided generation)으로 GradingResult 를 그대로 받는다
//    → 실패하면 throw → QuizSession 이 조용히 오답 처리한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.judge()
//  기대는 것    : FoundationModels, Question(문제와 정답)
//  건드리지 않는 것 : 실패 처리 — 실패를 어떻게 보여줄지는 QuizSession 이 정한다
//                    (화면에는 "모델 오류" 를 절대 내지 않는다)
//

import Foundation
import FoundationModels

/// 채점 결과. 모델이 이 구조체 모양으로 직접 만들어 준다.
///
/// `@Generable` 을 붙이면 **유도 생성(guided generation)** 이 되어, 모델의 답을
/// 문자열로 받아 파싱할 필요가 없습니다. 타입 안전하게 값이 들어옵니다.
///
/// - Note: 규칙 채점(``RuleGrader``)의 결과를 담을 때도 이 타입을 씁니다.
///   그때는 `reason` 을 빈 문자열로 둡니다 — 이유를 설명할 것이 없기 때문입니다.
@Generable
struct GradingResult {
    /// 사용자의 답이 정답과 의미상 일치하면 `true`.
    @Guide(description: "사용자의 답이 정답과 의미상 일치하면 true, 아니면 false")
    let isCorrect: Bool

    /// 채점 이유(한국어 한 문장).
    ///
    /// 지금 화면에는 표시하지 않습니다. 4단계(연습 모드 즉시 채점)에서
    /// "이해 못 한 지점 안내" 에 쓸 자리로 남겨 둔 것입니다.
    @Guide(description: "맞거나 틀린 이유를 한국어 한 문장으로 간단히 설명")
    let reason: String
}

/// 뜻으로 판정하는 채점기. 직접입력에만 쓴다.
///
/// 어르신은 "세종대왕" 을 "세종" 이라고, "1948년" 을 "천구백사십팔년" 이라고
/// 씁니다. 글자를 그대로 비교하면 다 틀리게 되므로 **뜻이 같은지**를 봐야 합니다.
/// 그 판단은 규칙으로 쓰기 어려워서 온디바이스 모델에 맡깁니다.
///
/// ``RuleGrader`` 와 짝을 이룹니다 — 규칙으로 먼저, 안 되면 뜻으로.
///
/// - Important: 모델을 쓸 수 없는 기기가 있습니다. 이 타입은 그 경우 오류를
///   던지고, ``QuizSession`` 이 조용히 오답으로 처리합니다. 선다형·O/X 는
///   모델 없이 동작하므로 **앱 전체가 멈추지는 않습니다.**
struct MeaningGrader {

    /// 문제와 사용자 답을 모델로 채점한다.
    ///
    /// - Parameters:
    ///   - question: 채점할 문제 (지문과 정답을 함께 넘긴다)
    ///   - userAnswer: 사용자가 입력한 답
    /// - Returns: 정답 여부와 이유가 담긴 ``GradingResult``
    /// - Throws: 모델을 쓸 수 없거나 응답 생성이 실패한 경우
    func grade(question: Question, userAnswer: String) async throws -> GradingResult {
        // 지침(instructions)은 세션 전체에 걸리며 개별 프롬프트보다 우선한다.
        // 채점 "기준" 은 매번 바뀌지 않으므로 프롬프트가 아니라 여기에 둔다.
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

        let response = try await session.respond(to: prompt, generating: GradingResult.self)
        return response.content
    }
}
