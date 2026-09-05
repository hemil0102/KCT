//
//  QuizItem.swift
//  KCT
//
//  역할 : 문제 하나를 "이번엔 이렇게 묻는다" 로 완성한 출제 항목
//  요점 : 화면이 필요한 모든 것을 미리 계산해 담는다. 화면은 파생 계산을 하지 않는다
//
//  ── 구성 ──────────────────────────────────────────────
//  ModePayload (enum)          묻는 방식별 재료
//  ├─ choices(options:correct:)          선다형 — 섞인 보기 + 정답
//  ├─ trueFalse(statement:candidate:isTrue:)  O/X — 진술문 + 넣은 답 + 참 여부
//  └─ freeText(accepted:)               직접입력 — 허용 정답들
//
//  QuizItem                    출제 항목 = 문제 + 묻는 방식 + 재료
//  ├─ question / mode / payload
//  ├─ affectsProgress          격려용 슬롯이면 false — 진척에 반영하지 않는다
//  ├─ focus                    질문이 묻는 대상 (형광펜용)
//  ├─ displayText              화면에 크게 보여줄 본문
//  ├─ highlightText            본문에서 색+밑줄로 강조할 부분 (O/X 의 판단 대상)
//  ├─ markerText               형광펜으로 칠할 부분 (묻는 대상)
//  ├─ actionGuide              "답을 골라보세요" 같은 한 줄 안내
//  └─ make(...)                문제 + 방식 → 재료를 파생해 항목 완성 (출제 시 1회)
//
//  ── 흐름 ──────────────────────────────────────────────
//  SessionBuilder.shapeRound()
//    → QuizItem.make(question, mode:answerPool:affectsProgress:focus:)
//    → 방식에 맞춰 Question 에게 재료를 요청 (makeChoices / makeTrueFalse)
//    → focus 가 없으면 QuestionFocusExtractor 로 즉시 계산 (규칙 기반, 안전망)
//    → 완성된 항목이 QuizSession.items 에 담긴다
//    → QuestionScreen 이 displayText·payload·actionGuide 를 읽어 그린다
//    → RuleGrader 가 payload 를 보고 정오답을 판정한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : SessionBuilder(생성), QuestionScreen·ResultScreen(표시), RuleGrader(채점)
//  기대는 것    : Question(재료 만들기), AskingMode(방식), QuestionFocus(하이라이트)
//  건드리지 않는 것 : 정답 판정 — 정답을 담고만 있고 비교는 RuleGrader 가 한다
//

import Foundation

/// 묻는 방식별로 화면이 필요한 재료.
///
/// enum 으로 두면 방식과 재료가 어긋날 수 없습니다 — 선다형인데 보기가 없는 상태를 애초에 만들 수 없습니다.
enum ModePayload {
    /// 2지선다·4지선다: 섞인 보기와 그중 정답.
    case choices(options: [String], correct: String)

    /// O/X: 보여줄 진술문, 그 안에 들어간 답, 그 진술이 참인지.
    case trueFalse(statement: String, candidate: String, isTrue: Bool)

    /// 직접입력·음성: 허용 정답들.
    case freeText(accepted: [String])
}

/// 출제 항목 — 원본 문제에 "이번엔 이렇게 묻는다" 를 붙여 완성한 것.
///
/// 화면이 필요한 것은 모두 미리 계산해 담습니다. 화면이 보기를 섞으면 다시 그릴 때마다 순서가 바뀝니다.
struct QuizItem: Identifiable {
    /// 문제 id 를 그대로 쓴다. 한 회차에 같은 문제가 두 번 나오지 않으므로 충분하다.
    let id: Int

    let question: Question
    let mode: AskingMode
    let payload: ModePayload

    /// 이 문제의 채점 결과를 진척에 반영할지.
    ///
    /// 격려용(회차의 첫·마지막) 슬롯은 `false` 입니다. 일부러 쉽게 낸 문제로 승급하면 사다리가 망가집니다.
    let affectsProgress: Bool

    /// 질문이 묻는 대상. 형광펜 강조에 쓰인다.
    let focus: QuestionFocus?

    /// 화면에 크게 보여줄 본문.
    ///
    /// O/X 는 의문문 대신 진술문을 보여줘야 "맞다/아니다" 로 판단하는 흐름이 자연스럽습니다.
    var displayText: String {
        switch payload {
        case .trueFalse(let statement, _, _): statement
        default:                              question.question
        }
    }

    /// 본문에서 색과 굵은 밑줄로 강조할 부분. (O/X 의 판단 대상인 답)
    var highlightText: String? {
        switch payload {
        case .trueFalse(_, let candidate, _): candidate
        default:                              nil
        }
    }

    /// 지문에서 형광펜으로 칠할 부분. (질문이 묻는 대상)
    ///
    /// O/X 는 판단 대상이 이미 밑줄로 강조되어 있으므로 겹치지 않게 생략합니다.
    var markerText: String? {
        switch payload {
        case .trueFalse: nil
        default:         focus?.phrase
        }
    }

    /// 사용자가 무엇을 해야 하는지 알려 주는 한 줄 안내.
    ///
    /// 묻는 대상까지 말해 주지는 않습니다. 힌트가 과해지면 스스로 판단할 여지가 줄어듭니다.
    var actionGuide: String {
        switch payload {
        case .choices:   "답을 골라보세요"
        case .trueFalse: "이 말이 맞을까요?"
        case .freeText:  "답을 입력하세요"
        }
    }
}

// MARK: - 출제 항목 만들기

extension QuizItem {

    /// 문제와 묻는 방식을 받아 재료를 파생해 출제 항목을 만든다. **출제 시 1회만** 계산합니다.
    ///
    /// `answerPool` 에서 오답 보기를 뽑고, `focus` 가 없으면 규칙 기반으로 즉시 계산합니다.
    /// 격려용 슬롯은 `affectsProgress` 를 `false` 로 넘깁니다.
    static func make(
        _ question: Question,
        mode: AskingMode,
        answerPool: [String],
        affectsProgress: Bool = true,
        focus: QuestionFocus? = nil
    ) -> QuizItem {
        let payload: ModePayload

        switch mode {
        case .binaryChoice:
            let choices = question.makeChoices(count: 2, answerPool: answerPool)
            payload = .choices(options: choices.options, correct: choices.correct)

        case .multipleChoice:
            let choices = question.makeChoices(count: 4, answerPool: answerPool)
            payload = .choices(options: choices.options, correct: choices.correct)

        case .trueOrFalse:
            let statement = question.makeTrueFalse(answerPool: answerPool)
            payload = .trueFalse(
                statement: statement.statement,
                candidate: statement.candidate,
                isTrue: statement.isTrue
            )

        case .typing:
            payload = .freeText(accepted: [question.answer])
        }

        return QuizItem(
            id: question.id,
            question: question,
            mode: mode,
            payload: payload,
            affectsProgress: affectsProgress,
            // 캐시가 없어도 형광펜이 비지 않도록 규칙 기반으로 즉시 채운다.
            focus: focus ?? QuestionFocusExtractor.focus(in: question.question)
        )
    }
}
