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

/// 채점 결과. 모델이 이 구조체 모양으로 직접 만들어 줍니다.
///
/// `@Generable` 을 붙이면 **유도 생성(guided generation)** 이 되어, 답을 문자열로 받아 파싱하지 않고 타입 안전하게 값이 들어옵니다.
@Generable
struct GradingResult {
    /// 사용자의 답이 정답과 **같은 것을 가리키면** `true`.
    ///
    /// - Important: 뜻이 통해도 다른 이름이면 오답입니다 — 2026-08-31 에 「단군신화」가 「단군왕검」의 정답으로 처리됐습니다.
    @Guide(description: "답변이 정답과 같은 것을 가리키면 true. 다른 이름이면 false. 정답이 여러 항목이면 그 항목들을 다 말했을 때만 true")
    let isCorrect: Bool

    /// 채점 이유(한국어 한 문장).
    ///
    /// 화면에는 표시하지 않고 ``ObsRecord/reason`` 에 남겨, 오채점을 찾고 지침을 고친 뒤 고쳐졌는지 확인하는 데 씁니다.
    @Guide(description: "위 규칙 1~6 중 어느 것을 적용했는지와 이유를 한국어 한 문장으로")
    let reason: String
}

/// 뜻으로 판정하는 채점기. 직접입력에만 쓰며 ``RuleGrader`` 와 짝을 이룹니다 — 규칙으로 먼저, 안 되면 뜻으로.
///
/// 어르신은 "세종대왕" 을 "세종" 이라고 쓰시므로 글자를 그대로 비교하면 다 틀리게 되는데, 뜻이 같은지는 규칙으로 쓰기 어려워 온디바이스 모델에 맡깁니다.
///
/// - Important: 판단이 서지 않으면 오답으로 둡니다 — 틀렸는데 맞다고 하면 사다리가 잘못 올라가고 아무도 모르지만, 맞았는데 틀렸다고 하면 그 문항을 곧 다시 만나 스스로 회복됩니다.
struct MeaningGrader {

    /// 문제와 사용자 답을 모델로 채점합니다.
    ///
    /// - Returns: 정답 여부와 이유가 담긴 ``GradingResult``
    /// - Throws: 모델을 쓸 수 없거나 응답 생성이 실패한 경우. ``QuizSession`` 이 조용히 오답으로 처리합니다
    func grade(question: Question, userAnswer: String) async throws -> GradingResult {
        // 지침(instructions)은 세션 전체에 걸리며 개별 프롬프트보다 우선한다.
        // 채점 "기준" 은 매번 바뀌지 않으므로 프롬프트가 아니라 여기에 둔다.
        //
        // 옛 지침은 네 줄 중 셋이 "맞다고 하라" 쪽이었고 "틀렸다고 하라" 는 줄이
        // 하나도 없었다. 그래서 「단군신화」가 「단군왕검」의 정답으로 통과했다.
        // 새 지침은 통과 조건과 탈락 조건을 같은 무게로 적고 각각 예를 붙인다 —
        // 작은 온디바이스 모델은 규칙 문장보다 예시를 훨씬 잘 따른다.
        let instructions = """
                    당신은 한국어 퀴즈 채점기입니다.
                    '정답'과 '답변'을 비교해 정답 여부만 판정합니다.
                    사용자는 어르신이고 음성이나 손으로 답합니다.
                    말버릇과 띄어쓰기는 무시하고, 무엇을 답으로 골랐는지만 보세요.

                    [정답으로 처리한다]
                    1. 답변 안에 정답이 그대로 들어 있다. 앞뒤에 군더더기가 붙어도 된다.
                       정답 "단군신화" / 답변 "음 이건... 단군신화" → 정답
                    2. 띄어쓰기만 다르다.
                       정답 "단군왕검" / 답변 "단군 왕검" → 정답
                    3. 정답이 여러 항목이면, 항목을 다 말했으면 순서는 달라도 된다.
                       항목을 나누는 기호는 무엇이든 상관없다.
                       정답 "고구려, 백제, 신라" / 답변 "신라 백제 고구려" → 정답

                    [오답으로 처리한다]
                    4. 답변이 정답과 다른 이름이다.
                       글자가 겹치거나 같은 이야기에 나와도 다른 이름이면 오답이다.
                       정답 "단군왕검" / 답변 "단군신화" → 오답
                    5. 서로 다른 답 사이에서 어느 것인지 정하지 못했다.
                       그중에 정답이 있어도 오답이다.
                       정답 "단군왕검" / 답변 "단군신화인가...? 단군왕검인가?" → 오답
                       정답 "고구려, 백제, 신라" / 답변 "고구려, 백제, 신라인가 조선인가" → 오답
                       ※ 정답이 여러 항목인 것과는 다르다. 정답 자체가 여러 개면
                          여럿을 말하는 것이 맞다 (규칙 3).
                    6. 정답이 여러 항목인데 일부만 말했다.
                       정답 "고구려, 백제, 신라" / 답변 "고구려, 백제" → 오답

                    판단이 서지 않으면 오답으로 두세요.
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
