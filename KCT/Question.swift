//
//  Question.swift
//  IdeaPlayground
//
//  귀화 시험 문제 데이터 모델과 고정 문제집.
//

import Foundation

/// 한 개의 퀴즈 문제를 표현하는 모델.
///
/// 문제 내용은 변하지 않는 "고정 데이터"이므로, 맞은/틀린 횟수 같은
/// 사용자별 진행 기록은 여기에 두지 않는다. (진행 기록은 별도 저장소로 분리)
struct Question: Identifiable, Codable, Hashable {
    /// 문제 고유 번호
    let id: Int
    /// 문제 분류 (예: "역사")
    let category: String
    /// 문제 지문
    let question: String
    /// 정답
    let answer: String
    /// 난이도 (1: 쉬움 ~ 3: 어려움). 첫 라운드 출제 순서를 정할 때 사용한다.
    let level: Int
}

extension Question {
    /// 귀화 시험 문제집 — 역사 10문제. (질문 · 정답 · 난이도)
    static let all: [Question] = [
        Question(
            id: 1,
            category: "역사",
            question: "우리나라 역사상 최초의 국가로 기원전 2333년 10월 3일에 세워진 나라의 이름은 무엇입니까?",
            answer: "고조선",
            level: 1
        ),
        Question(
            id: 2,
            category: "역사",
            question: "한국의 최초 국가 이름은 무엇입니까?",
            answer: "고조선",
            level: 1
        ),
        Question(
            id: 3,
            category: "역사",
            question: "도읍지를 아사달로 삼아 고조선을 세운 왕(시조)는 누구입니까?",
            answer: "단군왕검",
            level: 1
        ),
        Question(
            id: 4,
            category: "역사",
            question: "천제인 환인의 손자이며, 환웅의 아들로 서기전 2333년 아사달에 도읍을 정한 고조선을 세운 사람은 누구입니까?",
            answer: "단군왕검",
            level: 1
        ),
        Question(
            id: 5,
            category: "역사",
            question: "우리 나라에 최초의 국가인 고조선을 세운 사람은 누구입니까?",
            answer: "단군왕검",
            level: 1
        ),
        Question(
            id: 6,
            category: "역사",
            question: "아사달에 도읍을 정하고 우리나라에 최초의 고조선이라는 나라를 세웠으며, 우리 민족의 시조로서 천제인 환인의 손자이며 환웅의 아들인 이 사람 누구입니까?",
            answer: "단군왕검",
            level: 1
        ),
        Question(
            id: 7,
            category: "역사",
            question: "민족의 시조 단군에 관한 신화로 '삼국유사'를 통해 전해지는 신화는 무엇입니까?",
            answer: "단군신화",
            level: 2
        ),
        Question(
            id: 8,
            category: "역사",
            question: "단군의 출생과 고조선에 대한 신화로 곰이 쑥과 마늘을 먹고 사람이 되어 환웅과 결혼을 해서 아들 낳았다는 이야기의 신화는 무엇입니까?",
            answer: "단군신화",
            level: 2
        ),
        Question(
            id: 9,
            category: "역사",
            question: "삼국시대의 세 나라의 이름을 말해 보세요.",
            answer: "고구려, 백제, 신라",
            level: 1
        ),
        Question(
            id: 10,
            category: "역사",
            question: "고구려를 세운 왕(시조)이며 활을 잘 쏘았던 사람은 누구입니까?",
            answer: "주몽",
            level: 2
        ),
    ]
}
