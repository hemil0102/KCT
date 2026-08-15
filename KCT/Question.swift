//
//  Question.swift
//  KCT
//
//  귀화 시험 문제의 데이터 모델.
//  문제 목록 자체는 `QuestionCatalog`이 들고 있다. (번들 JSON → 나중에 서버)
//

import Foundation

/// 한 개의 퀴즈 문제를 표현하는 모델.
///
/// 문제 내용은 변하지 않는 "고정 데이터"이므로, 맞은/틀린 기록 같은
/// 사용자별 진행 상태는 여기에 두지 않는다. (진행 상태는 `QuestionProgress`로 분리)
///
/// 오답 보기를 만들 때 필요한 "다른 문제들의 정답"은 인자로 받는다.
/// 문제 하나가 전체 문제집을 알고 있으면 문제집을 갈아끼울 수 없기 때문이다.
struct Question: Identifiable, Codable, Hashable {
    /// 문제 고유 번호. 진척(`QuestionProgress`)이 이 값으로 연결되므로 절대 재사용하지 않는다.
    let id: Int
    /// 상위 분류 (예: "역사")
    let category: String
    /// 단원 (예: "역사1") — 균등 출제 단위
    let unit: String
    /// 문제 지문
    let question: String
    /// 정답
    let answer: String
    /// O/X용 진술문. `{답}` 자리에 답이 들어간다.
    /// (의문문을 자동으로 진술문으로 바꾸면 어색해서 문제마다 직접 적어 둔다)
    let statementFormat: String
    /// [축 A] 문제 고유 난이도(고정). 신규 문제 "도입 순서"에만 사용한다.
    let difficulty: Int
}

// MARK: - 모드별 출제 데이터 파생

extension Question {
    /// 주어진 답을 넣은 O/X 진술문.
    func statement(with candidate: String) -> String {
        statementFormat.replacingOccurrences(of: "{답}", with: candidate)
    }

    /// 선다형 보기를 만든다. 정답 1개 + 오답 (count-1)개를 섞어서 반환.
    /// - Parameters:
    ///   - count: 총 보기 수 (2지선다=2, 4지선다=4)
    ///   - answerPool: 오답을 뽑아 올 정답 모음. (보통 문제집 전체의 정답)
    func makeChoices(count: Int, answerPool: [String]) -> (options: [String], correct: String) {
        let distractors = Array(
            Set(answerPool).subtracting([answer]).shuffled().prefix(max(0, count - 1))
        )
        return ((distractors + [answer]).shuffled(), answer)
    }

    /// O/X 문항을 만든다. 절반 확률로 정답을, 절반 확률로 오답을 넣은 진술문을 보여준다.
    /// - Returns: 보여줄 진술문, 그 안에 들어간 답, 진술이 참인지 여부.
    func makeTrueFalse(answerPool: [String]) -> (statement: String, candidate: String, isTrue: Bool) {
        let candidate: String
        if Bool.random() {
            candidate = answer
        } else {
            candidate = Set(answerPool).subtracting([answer]).randomElement() ?? answer
        }
        return (statement(with: candidate), candidate, candidate == answer)
    }
}
