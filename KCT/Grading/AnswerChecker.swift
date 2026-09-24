//
//  AnswerChecker.swift
//  KCT
//
//  역할 : 코드가 못 가른 답을 모델에게 묻는다
//  요점 : 모델은 판사가 아니라 마지막 구제 절차다. 확실한 것은 이미 코드가 통과시켰다
//
//  ── 구성 ──────────────────────────────────────────────
//  AnswerCheck (@Generable)   모델이 만들어 주는 판정
//  ├─ isCorrect               같은가
//  ├─ reason                  한국어 한 문장 (로그용)
//  └─ basis                   무엇을 근거로 보았나
//
//  AnswerChecker
//  ├─ timeout                 모델을 기다리는 한계 (초)
//  ├─ prepare()               회차를 시작할 때 모델을 깨워 둔다
//  ├─ check(answer:correctAnswer:shape:)  판정을 묻는다
//  └─ guide(for:)             답의 모양마다 다른 지침 한 줄
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.judge() 의 ③층
//    → check(answer:correctAnswer:shape:)
//    → 시한(timeout, 60초)을 걸고 세션에 묻는다
//    → 유도 생성으로 AnswerCheck 를 그대로 받는다
//    → 실패하거나 시한이 지나면 throw → QuizSession 이 조용히 오답 처리한다
//
//  ⚠️ 여기만 실패를 **던진다.** 다른 모델 호출(해설·낱말 예문)은 ModelCall.generate 가
//     실패를 Writing 으로 돌려주는데, 채점은 「판정이 없다」를 화면이 대신 채울 수 없어
//     호출한 쪽이 알아야 한다. 그래서 generate 를 쓰지 않고 withTimeout 만 쓴다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.judge()
//  기대는 것    : FoundationModels, CheckBasis, ModelCall.withTimeout
//  건드리지 않는 것 : 문제 지문 - 프롬프트에 넣지 않는다 (안전 필터)
//                    채점 결과 타입(GradingResult)은 AnswerTypes.swift 에 있다
//

import Foundation
import FoundationModels

/// 모델이 만들어 주는 판정.
@Generable
struct AnswerCheck {
    @Guide(description: "정답과 답변이 같으면 true, 다르면 false")
    let isCorrect: Bool

    @Guide(description: "왜 그렇게 보았는지 한국어 한 문장")
    let reason: String

    @Guide(description: "판정의 근거")
    let basis: CheckBasis
}

/// 코드가 못 가른 답만 모델에게 묻습니다. ``AnswerMatcher`` 와 짝을 이룹니다.
///
/// - Important: 판단이 서지 않으면 오답으로 둡니다 — 틀렸는데 맞다고 하면 사다리가 잘못
///   올라가고 아무도 모르지만, 맞았는데 틀렸다고 하면 그 문항을 곧 다시 만나 회복됩니다.
@MainActor
final class AnswerChecker {

    /// 모델이 답하기를 기다리는 한계. 넘으면 오답으로 두고 넘어갑니다.
    private static let timeout: Double = 60

    /// 회차를 시작할 때 부릅니다. 첫 직접입력의 기다림이 줄어듭니다.
    func prepare() {
        LanguageModelSession(instructions: "").prewarm()
    }

    func check(answer: String, correctAnswer: String, shape: AnswerShape) async throws -> AnswerCheck {
        // 채점 규칙은 매번 같지만, 답의 모양마다 한 줄이 다르다.
        let instructions = """
            당신은 한국어 귀화 시험 면접관입니다.
            '정답'과 '답변'이 같은지 확인합니다.
            
            아래 가이드를 반드시 따릅니다.
            \(guide(for: shape))
            """

        let prompt = """
            정답: \(correctAnswer)
            답변: \(answer)

            답변이 정답과 같은지 채점하세요.
            """

        // ModelCall.generate 를 쓰지 않는 이유 — 그쪽은 실패를 Writing 으로 **돌려주고**,
        // 여기는 실패를 **던져 올려야** 한다. QuizSession.judge() 가 그 throw 를 받아
        // 조용히 오답으로 두기 때문이다. 공통으로 쓰는 것은 시한 하나다.
        let session = LanguageModelSession(instructions: instructions)
        let response = try await ModelCall.withTimeout(seconds: Self.timeout) {
            try await session.respond(
                to: prompt,
                generating: AnswerCheck.self,
                options: GenerationOptions(temperature: 0.1))
        }
        return response.content
    }
    
    private func guide(for shape: AnswerShape) -> String {
        switch shape {
        case .word:
            return "정답은 하나입니다."
        case .closedList, .openList:
            // 목록은 코드가 집합으로 판정하므로 여기까지 오지 않는다.
            return ""
        case .sentence:
            return ""
        }
    }
}
