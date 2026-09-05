//
//  QuestionCatalog.swift
//  KCT
//
//  역할 : 앱이 쓰는 문제집을 들고 있는 단 하나의 창구
//  요점 : 문제집 출처(번들/서버)가 바뀌어도 다른 코드는 손대지 않는다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionCatalog             문제집 보관소 (@Observable)
//  ├─ version                  문제집 버전. 서버 것이 더 높을 때만 교체
//  ├─ questions                문제 목록
//  ├─ answerPool               오답 보기용 정답 모음 (문제집이 바뀔 때만 다시 계산)
//  ├─ answerPool(excluding:)   같은 계열을 뺀 정답 모음 — 근접 오답을 없앤다
//  ├─ bundled()                앱에 들어 있는 기본 문제집으로 만들기
//  ├─ replace(with:)           문제집 통째 교체 — 안전한 시점에만
//  └─ question(id:)            id 로 한 개 찾기
//
//  ── 흐름 ──────────────────────────────────────────────
//  KCTApp 이 시작할 때
//    → bundled() : BundledQuestionSource 가 questions.json 을 읽어 옴
//    → environment 로 아래 화면들에 내려보냄
//    → SessionBuilder 가 questions 와 answerPool 을 읽어 출제 계획을 세움
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp(생성), QuizSession·SessionBuilder(읽기)
//  기대는 것    : QuestionSource(어디서 읽을지), Question
//  건드리지 않는 것 : 진척 — 문제집은 누가 무엇을 맞혔는지 모른다
//

import Foundation
import Observation

/// 앱이 사용하는 문제집을 들고 있는 곳.
///
/// 화면과 스케줄러가 여기서만 문제를 얻으므로, 출처가 번들에서 서버로 바뀌어도
/// 고칠 곳은 이 파일과 ``QuestionSource`` 뿐입니다. 앱 전체가 같은 하나를 봐야 해서
/// 값이 아니라 `@Observable` 클래스입니다.
@Observable
final class QuestionCatalog {

    /// 문제집 버전. 서버 것이 더 높을 때만 내려받는다.
    private(set) var version: Int

    /// 문제 목록.
    private(set) var questions: [Question]

    /// 오답 보기를 뽑을 정답 모음.
    ///
    /// 매번 계산하면 문제 수만큼 훑어야 하므로 문제집이 바뀔 때만 다시 만듭니다.
    private(set) var answerPool: [String]

    init(payload: QuestionPayload) {
        self.version = payload.version
        self.questions = payload.questions
        self.answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    /// 앱에 들어 있는 기본 문제집으로 카탈로그를 만듭니다.
    ///
    /// 읽지 못하면 빈 문제집을 돌려줍니다. 앱이 죽는 것보다 빈 화면이 낫고,
    /// 개발 중에는 `assertionFailure` 가 즉시 알려 줍니다.
    static func bundled() -> QuestionCatalog {
        do {
            return QuestionCatalog(payload: try BundledQuestionSource().loadFromBundle())
        } catch {
            assertionFailure("기본 문제집을 읽지 못했습니다: \(error)")
            return QuestionCatalog(payload: QuestionPayload(version: 0, questions: []))
        }
    }

    /// 문제집을 통째로 교체합니다. 버전이 더 높고 내용이 비어 있지 않을 때만 바꿉니다.
    ///
    /// - Important: 회차 도중에 부르면 풀고 있던 문제가 사라질 수 있으니 안전한 시점에만
    ///   호출하세요.
    func replace(with payload: QuestionPayload) {
        guard payload.version > version, !payload.questions.isEmpty else { return }

        version = payload.version
        questions = payload.questions
        answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    /// id 로 문제 하나를 찾는다.
    func question(id: Int) -> Question? {
        questions.first { $0.id == id }
    }

    /// 정답 모음을 만든다. `Set` 을 거쳐 중복을 없앤다 — 같은 보기가 두 번 나오면 안 된다.
    private static func makeAnswerPool(from questions: [Question]) -> [String] {
        Array(Set(questions.map(\.answer)))
    }
    
    /// 같은 계열(``Question/category``)을 뺀 정답 모음.
    ///
    /// 오답이 ``answerPool`` 에서 무작위로 뽑히면 같은 문항의 난이도가 회차마다
    /// 달라집니다. 난이도를 낮추려는 것이 아니라 고정하려는 것입니다.
    ///
    /// - Note: 남은 보기가 `minimum` 보다 적으면 전체 모음으로 되돌아갑니다 —
    ///   문제집이 한 계열뿐일 때 보기가 비어 화면이 깨지는 것을 막습니다.
    func answerPool(excludingCategory category: String, atLeast minimum: Int = 3) -> [String] {
        let narrowed = Set(questions.filter { $0.category != category }.map(\.answer))
        return narrowed.count >= minimum ? Array(narrowed) : answerPool
    }
}
