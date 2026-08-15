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
    /// O/X: 보여줄 진술문과 그 안에 들어간 답, 진술이 참인지 여부.
    case trueFalse(statement: String, candidate: String, isTrue: Bool)
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
    /// 질문이 묻는 대상. (하이라이트와 안내 문구에 쓰인다)
    let focus: QuestionFocus?

    /// 화면에 크게 보여줄 본문.
    /// O/X는 의문문 대신 진술문을 보여줘야 "맞다/아니다"로 판단하는 흐름이 자연스럽다.
    var displayText: String {
        switch payload {
        case .trueFalse(let statement, _, _): statement
        default:                              question.question
        }
    }

    /// 본문에서 강조할 부분. (O/X는 판단 대상인 답)
    var highlightText: String? {
        switch payload {
        case .trueFalse(_, let candidate, _): candidate
        default:                              nil
        }
    }

    /// 지문에서 형광펜으로 강조할 부분. (묻는 대상)
    ///
    /// O/X는 판단 대상인 답이 이미 강조되어 있으므로 겹치지 않게 생략한다.
    var markerText: String? {
        switch payload {
        case .trueFalse: nil
        default:         focus?.phrase
        }
    }

    /// 사용자가 무엇을 해야 하는지 알려 주는 한 줄 안내.
    ///
    /// 묻는 대상(사람·나라 등)까지 알려 주면 힌트가 과해져 스스로 판단할 여지가 줄어든다.
    /// 그래서 행동만 알려 주고, 무엇을 묻는지는 지문의 형광펜으로 드러낸다.
    var actionGuide: String {
        switch payload {
        case .choices:   return "답을 골라보세요"
        case .trueFalse: return "이 말이 맞을까요?"
        case .freeText:  return "답을 입력하세요"
        }
    }
}

extension PracticeItem {
    /// 문제와 모드를 받아 페이로드를 자동 파생해 출제 항목을 만든다. (출제 시 1회 계산)
    /// - Parameter focus: 캐시·서버에서 가져온 분석 결과. 없으면 규칙 기반으로 즉시 계산한다.
    static func make(
        _ question: Question,
        mode: DifficultyMode,
        affectsProgress: Bool = true,
        focus: QuestionFocus? = nil
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
            payload = .trueFalse(statement: t.statement, candidate: t.candidate, isTrue: t.isTrue)
        case .typing:
            payload = .freeText(accepted: [question.answer])
        }
        return PracticeItem(
            id: question.id,
            question: question,
            mode: mode,
            payload: payload,
            affectsProgress: affectsProgress,
            focus: focus ?? QuestionFocusExtractor.focus(in: question.question)
        )
    }
}
