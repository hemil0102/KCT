//
//  PracticeItem.swift
//  KCT
//
//  한 문제를 특정 모드로 출제하기 위해, 렌더링에 필요한 데이터를 담은 항목.
//  (모드별 부가 데이터는 문제집 정답에서 자동 파생한다)
//

import Foundation

/// 모드별 화면 렌더링에 필요한 데이터.
enum ModePayload {
    /// 2지선다·4지선다: 섞인 보기와 정답.
    case choices(options: [String], correct: String)
    /// O/X: 제시된 답과 그것이 실제 정답인지 여부.
    case trueFalse(shownAnswer: String, isTrue: Bool)
    /// 직접입력·음성: 허용 정답들.
    case freeText(accepted: [String])
}

/// 출제 항목 = 원본 문제 + 배정된 모드 + 파생된 페이로드.
struct PracticeItem: Identifiable {
    let id: Int
    let question: Question
    let mode: DifficultyMode
    let payload: ModePayload
    /// 격려용(첫/마지막) 슬롯이면 false — 채점 결과를 진척에 반영하지 않는다.
    let affectsProgress: Bool
}

extension PracticeItem {
    /// 문제와 모드를 받아 페이로드를 자동 파생해 출제 항목을 만든다. (출제 시 1회 계산)
    static func make(
        _ question: Question,
        mode: DifficultyMode,
        affectsProgress: Bool = true
    ) -> PracticeItem {
        let payload: ModePayload
        switch mode {
        case .binaryChoice:
            let c = question.makeChoices(count: 2)
            payload = .choices(options: c.options, correct: c.correct)
        case .multipleChoice:
            let c = question.makeChoices(count: 4)
            payload = .choices(options: c.options, correct: c.correct)
        case .trueOrFalse:
            let t = question.makeTrueFalse()
            payload = .trueFalse(shownAnswer: t.shownAnswer, isTrue: t.isTrue)
        case .typing:
            payload = .freeText(accepted: [question.answer])
        }
        return PracticeItem(
            id: question.id,
            question: question,
            mode: mode,
            payload: payload,
            affectsProgress: affectsProgress
        )
    }
}
