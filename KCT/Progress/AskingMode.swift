//
//  AskingMode.swift
//  KCT
//
//  역할 : [축 B] 같은 문제를 얼마나 쉽게 물을지 정하는 사다리
//  요점 : 문제가 어려운 정도가 아니다. 같은 문제를 묻는 "방식"이다
//
//  ── 구성 ──────────────────────────────────────────────
//  AskingMode (enum, rawValue = 사다리 칸 0..3)
//  ├─ binaryChoice   0   2지선다   — 가장 쉽다. 모든 문제가 여기서 시작한다
//  ├─ trueOrFalse    1   O/X
//  ├─ multipleChoice 2   4지선다
//  ├─ typing         3   직접입력  — 가장 어렵다
//  ├─ mastery            마스터로 간주하는 최고 칸 (= typing)
//  └─ <                  칸 비교 (Comparable)
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionProgress 가 문제별로 이 값을 기억한다 (modeRaw 로 저장)
//    → SessionBuilder.shapeRound() 가 그 값을 읽어 출제 방식을 정한다
//    → QuizItem.make() 가 방식에 맞는 재료(ModePayload)를 만든다
//    → 채점 후 QuestionProgress.moveLadder() 가 한 칸 올리거나 내린다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionProgress(저장), SessionBuilder(배정), QuizItem(재료 만들기)
//  기대는 것    : 없음 — Foundation 뿐
//  건드리지 않는 것 : 화면 표현 — 이 사다리는 어르신에게 보이지 않는다.
//                    문제 유형 배지는 3차 프로토타입에서 없앴다
//

import Foundation

/// 문제를 묻는 방식. rawValue 가 곧 사다리의 칸(0..3)이며, 낮을수록 쉽게 묻습니다.
///
/// 정답이면 한 칸 올라가고 오답이면 한 칸 내려가며, 최고 칸(``typing``)에서 맞히면
/// 마스터로 봅니다. 모든 문제가 같은 사다리를 타는 것은, 문제마다 사다리가 다르면
/// 진척을 비교할 수 없기 때문입니다.
///
/// - Important: 이것은 문제의 고유 난이도(축 A, ``Question/difficulty``)가 아닌 축 B이며,
///   두 축을 섞으면 설계가 무너집니다.
enum AskingMode: Int, CaseIterable, Codable, Comparable {
    /// 2지선다 — 모든 문제의 출발점
    case binaryChoice   = 0
    /// O/X — 진술문이 맞는지 판단
    case trueOrFalse    = 1
    /// 4지선다
    case multipleChoice = 2
    /// 직접입력 (음성 입력은 이 칸의 대체 입력수단)
    case typing         = 3

    /// 마스터로 간주하는 최고 칸.
    ///
    /// 이름을 따로 둔 이유는 `typing` 이 최고 칸이라는 사실이 바뀌어도 마스터 판정 코드를
    /// 뒤지지 않게 하기 위해서입니다.
    static let mastery = AskingMode.typing

    static func < (lhs: AskingMode, rhs: AskingMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
