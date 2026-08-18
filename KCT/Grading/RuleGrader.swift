//
//  RuleGrader.swift
//  KCT
//
//  역할 : 정답이 명확한 방식(선다형·O/X)을 모델 없이 즉시 판정한다
//  요점 : nil 을 돌려주는 것이 "나는 못 정한다, 뜻으로 봐 달라" 는 신호다
//
//  ── 구성 ──────────────────────────────────────────────
//  RuleGrader (enum — 상태가 없어 인스턴스를 만들 필요가 없다)
//  ├─ trueLabel     O/X 의 "맞아요" 버튼 값
//  ├─ falseLabel    O/X 의 "아니에요" 버튼 값
//  └─ grade(_:userAnswer:) -> Bool?
//      ├─ .choices   → 고른 값이 정답과 같은가
//      ├─ .trueFalse → "맞아요" 를 골랐는가 == 진술이 참인가
//      └─ .freeText  → nil (MeaningGrader 에게 넘겨라)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.judge(_:answer:)
//    → RuleGrader.grade() 를 먼저 부른다
//    → Bool 이 오면 그대로 채택 (빠르고, 기기에 모델이 없어도 된다)
//    → nil 이 오면 MeaningGrader(온디바이스 모델)로 넘긴다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.judge(), QuestionScreen(O/X 버튼 문구)
//  기대는 것    : QuizItem.payload 뿐
//  건드리지 않는 것 : 진척 기록 — 판정만 하고 저장은 QuizSession 이 한다
//

import Foundation

/// 규칙으로 판정하는 채점기. 정답이 명확한 방식만 다룬다.
///
/// 선다형과 O/X 는 정답이 딱 하나로 정해지므로 값을 비교하면 끝입니다.
/// 여기에 온디바이스 모델을 쓰면 느리고, 모델이 없는 기기에서는 아예 채점이
/// 안 되고, 같은 답에 다른 결과가 나올 수도 있습니다.
///
/// ``MeaningGrader`` 와 짝을 이룹니다 — **규칙으로 먼저, 안 되면 뜻으로.**
///
/// - Note: O/X 버튼의 문구를 여기에 둔 이유는 **판정과 표시가 어긋나지 않게**
///   하기 위해서입니다. 화면이 "맞아요" 를 보여주고 채점기가 "예" 를 기대하면
///   모든 O/X 가 틀리게 됩니다. 한곳에서 정의하면 그럴 수 없습니다.
enum RuleGrader {

    /// O/X 에서 "맞다" 에 해당하는 선택 값.
    static let trueLabel = "맞아요"

    /// O/X 에서 "아니다" 에 해당하는 선택 값.
    static let falseLabel = "아니에요"

    /// 규칙으로 판정한다.
    ///
    /// - Parameters:
    ///   - item: 출제 항목. `payload` 에 정답이 담겨 있다
    ///   - userAnswer: 사용자가 고르거나 입력한 값
    /// - Returns: 맞았는지 여부. **`nil` 이면 규칙으로 정할 수 없다는 뜻**이며,
    ///   호출한 쪽이 ``MeaningGrader`` 로 넘겨야 한다.
    static func grade(_ item: QuizItem, userAnswer: String) -> Bool? {
        switch item.payload {
        case .choices(_, let correct):
            return userAnswer == correct

        case .trueFalse(_, _, let isTrue):
            // "맞아요를 골랐다" 와 "진술이 참이다" 가 일치하면 정답이다.
            return (userAnswer == trueLabel) == isTrue

        case .freeText:
            return nil
        }
    }
}
