//
//  Question.swift
//  KCT
//
//  귀화 시험 문제 데이터 모델과 고정 문제집.
//

import Foundation

/// 한 개의 퀴즈 문제를 표현하는 모델.
///
/// 문제 내용은 변하지 않는 "고정 데이터"이므로, 맞은/틀린 기록 같은
/// 사용자별 진행 상태는 여기에 두지 않는다. (진행 상태는 `QuestionProgress`로 분리)
struct Question: Identifiable, Codable, Hashable {
    /// 문제 고유 번호
    let id: Int
    /// 상위 분류 (예: "역사")
    let category: String
    /// 단원 (예: "역사1") — 균등 출제 단위
    let unit: String
    /// 문제 지문
    let question: String
    /// 정답
    let answer: String
    /// [축 A] 문제 고유 난이도(고정). 신규 문제 "도입 순서"에만 사용한다.
    let difficulty: Int
}

// MARK: - 모드별 출제 데이터 파생

extension Question {
    /// 선다형 보기를 만든다. 정답 1개 + 다른 문제 정답에서 뽑은 오답 (count-1)개, 섞어서 반환.
    /// - Parameter count: 총 보기 수 (2지선다=2, 4지선다=4)
    func makeChoices(count: Int) -> (options: [String], correct: String) {
        let pool = Set(Question.all.map(\.answer)).subtracting([answer])
        let distractors = Array(pool.shuffled().prefix(max(0, count - 1)))
        return ((distractors + [answer]).shuffled(), answer)
    }

    /// O/X 문항을 만든다. 절반 확률로 정답을, 절반 확률로 오답을 "제시된 답"으로 보여준다.
    /// - Returns: 제시할 답과, 그것이 실제 정답인지 여부.
    func makeTrueFalse() -> (shownAnswer: String, isTrue: Bool) {
        let presentTrue = Bool.random()
        if presentTrue {
            return (answer, true)
        }
        let pool = Set(Question.all.map(\.answer)).subtracting([answer])
        return (pool.randomElement() ?? answer, false)
    }
}

extension Question {
    /// 귀화 시험 문제집 — 역사 10문제. (질문 · 정답 · 고유 난이도)
    static let all: [Question] = [
        Question(
            id: 1,
            category: "역사",
            unit: "역사1",
            question: "우리나라 역사상 최초의 국가로 기원전 2333년 10월 3일에 세워진 나라의 이름은 무엇입니까?",
            answer: "고조선",
            difficulty: 1
        ),
        Question(
            id: 2,
            category: "역사",
            unit: "역사1",
            question: "한국의 최초 국가 이름은 무엇입니까?",
            answer: "고조선",
            difficulty: 1
        ),
        Question(
            id: 3,
            category: "역사",
            unit: "역사1",
            question: "도읍지를 아사달로 삼아 고조선을 세운 왕(시조)는 누구입니까?",
            answer: "단군왕검",
            difficulty: 1
        ),
        Question(
            id: 4,
            category: "역사",
            unit: "역사1",
            question: "천제인 환인의 손자이며, 환웅의 아들로 서기전 2333년 아사달에 도읍을 정한 고조선을 세운 사람은 누구입니까?",
            answer: "단군왕검",
            difficulty: 1
        ),
        Question(
            id: 5,
            category: "역사",
            unit: "역사1",
            question: "우리 나라에 최초의 국가인 고조선을 세운 사람은 누구입니까?",
            answer: "단군왕검",
            difficulty: 1
        ),
        Question(
            id: 6,
            category: "역사",
            unit: "역사1",
            question: "아사달에 도읍을 정하고 우리나라에 최초의 고조선이라는 나라를 세웠으며, 우리 민족의 시조로서 천제인 환인의 손자이며 환웅의 아들인 이 사람 누구입니까?",
            answer: "단군왕검",
            difficulty: 1
        ),
        Question(
            id: 7,
            category: "역사",
            unit: "역사2",
            question: "민족의 시조 단군에 관한 신화로 '삼국유사'를 통해 전해지는 신화는 무엇입니까?",
            answer: "단군신화",
            difficulty: 2
        ),
        Question(
            id: 8,
            category: "역사",
            unit: "역사2",
            question: "단군의 출생과 고조선에 대한 신화로 곰이 쑥과 마늘을 먹고 사람이 되어 환웅과 결혼을 해서 아들 낳았다는 이야기의 신화는 무엇입니까?",
            answer: "단군신화",
            difficulty: 2
        ),
        Question(
            id: 9,
            category: "역사",
            unit: "역사2",
            question: "삼국시대의 세 나라의 이름을 말해 보세요.",
            answer: "고구려, 백제, 신라",
            difficulty: 1
        ),
        Question(
            id: 10,
            category: "역사",
            unit: "역사2",
            question: "고구려를 세운 왕(시조)이며 활을 잘 쏘았던 사람은 누구입니까?",
            answer: "주몽",
            difficulty: 2
        ),
    ]
}
