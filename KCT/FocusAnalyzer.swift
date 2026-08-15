//
//  FocusAnalyzer.swift
//  KCT
//
//  온디바이스 모델로 "질문이 무엇을 묻는지" 분석한다.
//  화면을 막지 않도록 백그라운드에서만 돌리고, 결과는 캐시에 저장해 다음부터 재사용한다.
//

import Foundation
import FoundationModels

/// 모델이 생성하는 분석 결과.
@Generable
struct GeneratedFocus {
    @Guide(description: "질문이 묻고 있는 대상. 반드시 질문 문장에 있는 표현을 그대로 인용할 것")
    let phrase: String

    @Guide(description: "묻는 대상의 종류. 사람, 장소, 나라, 신화, 제도, 법, 시기, 개수, 이름 중 하나")
    let category: String
}

struct FocusAnalyzer {
    /// 모델을 쓸 수 있는 상태인지.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// 질문 하나를 분석한다.
    /// - Returns: 분석 결과. 모델이 지문에 없는 표현을 지어냈으면 `nil`.
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
        // 화면에서 하이라이트하려면 지문에 실제로 있는 문자열이어야 한다.
        guard question.contains(generated.phrase) else { return nil }

        return QuestionFocus(phrase: generated.phrase, category: generated.category)
    }
}
