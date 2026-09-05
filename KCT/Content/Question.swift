//
//  Question.swift
//  KCT
//
//  역할 : 문제 한 개의 내용. 그리고 그 문제를 여러 방식으로 물을 재료를 만든다
//  요점 : 문제는 자기 자신만 안다. 문제집 전체를 모르므로 문제집을 갈아끼울 수 있다
//
//  ── 구성 ──────────────────────────────────────────────
//  Question                    문제 한 개 (고정 데이터)
//  ├─ id                       영구 고정. 진척이 이 값으로 연결된다
//  ├─ category / unit          분류 / 단원 (단원은 균등 출제 단위)
//  ├─ question / answer        지문 / 정답
//  ├─ statementFormat          O/X 진술문 틀. "{답}" 자리에 답이 들어간다
//  ├─ difficulty               [축 A] 문제 고유 난이도. 고정
//  ├─ statement(with:)         진술문 만들기
//  ├─ makeChoices(count:answerPool:)   선다형 보기 만들기
//  └─ makeTrueFalse(answerPool:)       O/X 문항 만들기
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizItem.make() 가 묻는 방식을 정한 뒤
//    → makeChoices() / makeTrueFalse() 를 불러 재료를 받는다
//    → 오답 보기는 answerPool(다른 문제들의 정답)에서 뽑는다
//    → 만들어진 재료는 ModePayload 에 담겨 화면으로 간다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizItem.make(), QuestionCatalog
//  기대는 것    : 없음 — Foundation 뿐. 이 파일은 앱의 어떤 것도 모른다
//  건드리지 않는 것 : 맞은/틀린 기록 — 그것은 QuestionProgress 의 몫이다
//

import Foundation

/// 퀴즈 문제 한 개. 변하지 않는 고정 데이터입니다.
///
/// 맞은/틀린 기록은 ``QuestionProgress`` 로 분리해 두어, 문제집을 갈아끼워도
/// 학습 기록이 살아남습니다. 오답 보기용 "다른 문제들의 정답" 을 인자로 받는 것도
/// 문제 하나가 문제집 전체를 알면 교체가 불가능해지기 때문입니다.
///
/// - Important: ``id`` 를 재사용하면 학습 기록이 엉뚱한 문제에 붙습니다.
struct Question: Identifiable, Codable, Hashable {
    /// 문제 고유 번호. 절대 재사용하지 않는다.
    let id: Int

    /// 상위 분류 (예: "역사")
    let category: String

    /// 단원 (예: "역사1") — 신규 문제를 고르게 도입하는 단위
    let unit: String

    /// 문제 지문
    let question: String

    /// 정답
    let answer: String

    /// O/X 용 진술문 틀. `{답}` 자리에 답이 들어갑니다.
    ///
    /// 의문문을 코드로 진술문으로 바꾸면 어색해져서 문제마다 사람이 직접 적어 둡니다.
    let statementFormat: String

    /// 정답의 종류. 해설을 어떤 방식으로 쓸지 정한다.
    let kind: AnswerKind
    
    /// [축 A] 문제 고유 난이도. 고정이며 신규 문제의 도입 순서만 정합니다.
    ///
    /// - Important: "얼마나 마스터했나"(축 B, ``QuestionProgress/mode``)와는 다른 축이며,
    ///   두 축을 섞으면 설계가 무너집니다.
    let difficulty: Int
}

// MARK: - 묻는 방식별 재료 만들기

extension Question {

    /// 주어진 답을 넣은 O/X 진술문.
    func statement(with candidate: String) -> String {
        statementFormat.replacingOccurrences(of: "{답}", with: candidate)
    }

    /// 선다형 보기를 만듭니다. 정답 1개 + 오답 `count - 1` 개를 섞어 돌려줍니다.
    ///
    /// 오답을 다른 문제의 정답에서 뽑으므로 그럴듯하고, 문제집이 바뀌면 보기도 따라
    /// 바뀌어 문제마다 오답을 손으로 적어 둘 필요가 없습니다.
    func makeChoices(count: Int, answerPool: [String]) -> (options: [String], correct: String) {
        let distractors = Array(
            Set(answerPool).subtracting([answer]).shuffled().prefix(max(0, count - 1))
        )
        return ((distractors + [answer]).shuffled(), answer)
    }

    /// O/X 문항을 만듭니다.
    ///
    /// 절반 확률로 정답을, 절반 확률로 오답을 넣습니다. 늘 정답만 넣으면 "맞아요" 만
    /// 눌러도 다 맞게 되어 O/X 가 의미를 잃습니다.
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
