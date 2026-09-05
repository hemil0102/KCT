//
//  FocusAnalyzer.swift
//  KCT
//
//  역할 : 온디바이스 모델로 "질문이 무엇을 묻는지" 분석한다. 하이라이트 2층
//  요점 : ⚠️ 지금 꺼져 있다 (FocusStore.usesModelAnalysis == false)
//
//  ── 구성 ──────────────────────────────────────────────
//  GeneratedFocus (@Generable)   모델이 만들어 주는 분석 결과
//  ├─ phrase                     묻는 대상. 질문에 있는 표현을 그대로 인용해야 한다
//  └─ category                   묻는 대상의 종류
//
//  FocusAnalyzer
//  ├─ isAvailable                이 기기에서 모델을 쓸 수 있는가
//  └─ analyze(question:)         한 문장 분석. 지어낸 답이면 nil
//
//  ── 흐름 ──────────────────────────────────────────────
//  FocusStore.analyzeMissing()   (백그라운드, 화면을 막지 않는다)
//    → isAvailable 확인
//    → analyze(question:) : 지침 + 프롬프트 → GeneratedFocus 로 유도 생성
//    → **환각 검증** : 돌려준 phrase 가 지문에 실제로 있는지 확인
//    → 없으면 nil (조용히 버림) → 규칙 기반 결과가 계속 쓰인다
//    → 있으면 QuestionFocusRecord 로 캐시에 저장
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : FocusStore.analyzeMissing() — 단 지금은 스위치가 꺼져 호출되지 않는다
//  기대는 것    : FoundationModels
//  건드리지 않는 것 : 저장·재시도 — 캐시에 넣는 일과 언제 다시 시도할지는 FocusStore 가 정한다
//

import Foundation
import FoundationModels

/// 모델이 만들어 주는 분석 결과.
///
/// ``QuestionFocus`` 와 모양이 비슷하지만 다른 타입입니다 — 아직 검증되지 않은 "모델이 주장한 것" 입니다.
@Generable
struct GeneratedFocus {
    @Guide(description: "질문이 묻고 있는 대상. 반드시 질문 문장에 있는 표현을 그대로 인용할 것")
    let phrase: String

    @Guide(description: "묻는 대상의 종류. 사람, 장소, 나라, 신화, 제도, 법, 시기, 개수, 이름 중 하나")
    let category: String
}

/// 온디바이스 모델로 "묻는 대상" 을 분석하는 쪽. **하이라이트 2층.**
///
/// 화면을 막지 않도록 백그라운드에서만 돌리고, 결과는 캐시에 저장해 재사용합니다.
///
/// - Important: ``FocusStore/usesModelAnalysis`` 가 `false` 라 지금은 호출되지 않습니다. 모델이 질문 전체를 돌려주는 일이 잦아 지문이 통째로 형광펜 처리됐기 때문입니다.
struct FocusAnalyzer {

    /// 이 기기에서 모델을 쓸 수 있는지.
    ///
    /// `false` 인 기기와 시뮬레이터가 있으므로 모델을 쓰는 경로에는 반드시 폴백(규칙 기반 층)이 있어야 합니다.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// 질문 하나를 분석한다.
    ///
    /// 모델이 지문에 없는 표현을 지어냈으면 `nil` 을 돌려주고, 모델을 쓸 수 없거나 생성에 실패하면 오류를 던집니다.
    func analyze(question: String) async throws -> QuestionFocus? {
        let instructions = """
            당신은 한국어 퀴즈 질문을 분석하는 도우미입니다.
            질문이 무엇을 묻고 있는지 찾아내세요.
            묻는 대상은 반드시 질문 문장에 등장하는 표현을 그대로 인용해야 합니다.
            새로운 낱말을 지어내지 마세요.
            """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: "질문: \(question)\n이 질문이 묻는 대상과 그 종류를 알려주세요.",
            generating: GeneratedFocus.self
        )

        let generated = response.content

        // 환각(hallucination) 검증 — 지시했다고 지키는 것은 아니다.
        // 화면에서 이 문자열을 찾아 형광펜을 칠하므로 지문에 실제로 있어야 한다.
        guard question.contains(generated.phrase) else { return nil }

        return QuestionFocus(phrase: generated.phrase, category: generated.category)
    }
}
