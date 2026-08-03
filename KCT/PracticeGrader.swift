//
//  PracticeGrader.swift
//  KCT
//
//  선다형·O/X처럼 정답이 명확한 모드는 모델 없이 즉시 비교로 채점한다.
//  직접입력(freeText)은 의미 채점이 필요하므로 nil을 돌려 모델 채점(AnswerGrader)에 넘긴다.
//

import Foundation

enum PracticeGrader {
    /// O/X에서 "맞다"에 해당하는 선택 값.
    static let trueLabel = "O"
    /// O/X에서 "아니다"에 해당하는 선택 값.
    static let falseLabel = "X"

    /// 결정적 채점 결과. `nil`이면 모델 채점(AnswerGrader)이 필요하다.
    static func grade(_ item: PracticeItem, userAnswer: String) -> Bool? {
        switch item.payload {
        case .choices(_, let correct):
            return userAnswer == correct
        case .trueFalse(_, let isTrue):
            return (userAnswer == trueLabel) == isTrue
        case .freeText:
            return nil
        }
    }
}
