//
//  MatchingSet.swift
//  KCT
//
//  역할 : 「맞는 짝을 연결해보세요」 문제 한 묶음의 모양
//  요점 : Question 은 한 사실 = 한 답이라 재활용이 안 된다. 이 묶음은 N쌍이
//         하나의 닫힌 세트로 함께 나오고 함께 채점되는, Question 과는 다른 종류의 문제다
//
//  ── 구성 ──────────────────────────────────────────────
//  MatchingPair (struct)        낱말 한 쌍 — left ↔ right
//  MatchingSet (struct)         한 세트 = 여러 쌍 + 어느 계열·단원인지
//  MatchingSetPayload (struct)  matchingSets.json 최상위 모양 {version, sets}
//
//  ── 흐름 ──────────────────────────────────────────────
//  matchingSets.json (또는 서버에서 받은 것)
//    → MatchingSetCatalog.loaded() 가 읽어 옴
//    → (아직 없음) SessionBuilder 가 회차의 정해진 자리에 한 세트를 골라 끼워 넣음
//    → MatchingQuestionScreen 이 그 세트 하나를 받아 그리고 채점까지 스스로 함
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : MatchingSetCatalog(보관), MatchingQuestionScreen(표시·채점)
//  기대는 것    : Codable 뿐
//  건드리지 않는 것 : Question·questions.json — 이 파일은 그쪽을 전혀 모른다.
//                    두 문제 체계는 나란히 있을 뿐 서로 바뀌지 않는다
//

import Foundation

/// 연결 문제 한 쌍. 왼쪽 낱말과 오른쪽 낱말은 이 쌍 안에서만 서로 정답이다.
struct MatchingPair: Codable, Hashable {
    let left: String
    let right: String
}

/// 연결 문제 한 세트.
///
/// - Important: `pairs` 는 **이 세트 하나를 위해 닫혀 있는 묶음**이다. `Question` 의
///   오답 보기처럼 다른 세트·다른 문제에서 섞어 오지 않는다 — 국경일 세트를 풀 때
///   화면에 뜨는 5쌍은 항상 이 5쌍뿐이다.
struct MatchingSet: Identifiable, Codable, Hashable {
    let id: Int
    let category: String
    let unit: String
    let pairs: [MatchingPair]
}

/// matchingSets.json 최상위 모양. `QuestionPayload`(questions.json)와 같은 자리를
/// 하는 별도 파일이다 — 하나가 바뀌어도 다른 하나는 그대로다.
struct MatchingSetPayload: Codable {
    let version: Int
    let sets: [MatchingSet]
}
