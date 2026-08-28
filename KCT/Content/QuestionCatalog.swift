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
/// 화면과 스케줄러는 **여기서만** 문제를 얻습니다. 덕분에 문제집이 번들 JSON에서
/// 서버로 바뀌어도 고칠 곳은 이 파일과 ``QuestionSource`` 뿐입니다.
///
/// ## 왜 클래스인가
///
/// 문제집은 앱 전체가 **같은 하나**를 봐야 합니다. 값(struct)이면 복사되어
/// 교체가 전파되지 않습니다. `@Observable` 클래스라서 교체하면 화면이 따라옵니다.
@Observable
final class QuestionCatalog {

    /// 문제집 버전. 서버 것이 더 높을 때만 내려받는다.
    private(set) var version: Int

    /// 문제 목록.
    private(set) var questions: [Question]

    /// 오답 보기를 뽑을 정답 모음.
    ///
    /// 매번 계산하면 문제 수만큼 훑어야 하므로, **문제집이 바뀔 때만** 다시 만듭니다.
    private(set) var answerPool: [String]

    init(payload: QuestionPayload) {
        self.version = payload.version
        self.questions = payload.questions
        self.answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    /// 앱에 들어 있는 기본 문제집으로 카탈로그를 만든다.
    ///
    /// 읽지 못하면 빈 문제집을 돌려줍니다. 앱이 죽는 것보다는 빈 화면이 낫고,
    /// 개발 중에는 `assertionFailure` 가 즉시 알려 줍니다.
    static func bundled() -> QuestionCatalog {
        do {
            return QuestionCatalog(payload: try BundledQuestionSource().loadFromBundle())
        } catch {
            assertionFailure("기본 문제집을 읽지 못했습니다: \(error)")
            return QuestionCatalog(payload: QuestionPayload(version: 0, questions: []))
        }
    }

    /// 문제집을 통째로 교체한다. 버전이 더 높고 내용이 비어 있지 않을 때만.
    ///
    /// - Important: 회차 도중에 부르면 풀고 있던 문제가 사라질 수 있습니다.
    ///   앱 시작 시나 회차가 끝난 뒤처럼 **안전한 시점에만** 호출하세요.
    func replace(with payload: QuestionPayload) {
        guard payload.version > version, !payload.questions.isEmpty else { return }

        version = payload.version
        questions = payload.questions
        answerPool = Self.makeAnswerPool(from: payload.questions)
    }

    /// 같은 계열(``Question/category``)을 뺀 정답 모음.
    ///
    /// ## 왜 필요한가
    ///
    /// 오답 보기는 ``answerPool`` 에서 **무작위로** 뽑힙니다. 그래서 정답이
    /// "단군왕검" 인 문항은 회차마다 난이도가 달라집니다 — 보기로 "태극기" 가
    /// 뽑히면 3초에 지워지고, "단군신화" 가 뽑히면 20초가 걸립니다.
    /// 2026-08-28 관찰에서 오답 여덟 개 중 다섯이 이 계열에 몰렸습니다.
    ///
    /// **난이도를 낮추려는 것이 아니라 고정하려는 것입니다.** 매 회차 주사위를
    /// 굴리면 무엇을 고쳐서 좋아졌는지 알 수 없습니다.
    ///
    /// - Parameters:
    ///   - category: 뺄 계열. 보통 지금 내는 문항의 ``Question/category``
    ///   - minimum: 남은 보기가 이보다 적으면 **전체 모음으로 되돌아간다.**
    ///     문제집이 한 계열뿐일 때 보기가 비어 화면이 깨지는 것을 막는다
    // ⌨️ ①

    /// id 로 문제 하나를 찾는다.
    func question(id: Int) -> Question? {
        questions.first { $0.id == id }
    }

    /// 정답 모음을 만든다. `Set` 을 거쳐 중복을 없앤다 — 같은 보기가 두 번 나오면 안 된다.
    private static func makeAnswerPool(from questions: [Question]) -> [String] {
        Array(Set(questions.map(\.answer)))
    }
}
