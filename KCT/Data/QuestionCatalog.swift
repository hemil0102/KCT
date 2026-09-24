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
//  ├─ answerPool(preferringKindOf:)   같은 종류를 최대한 채우고 모자란 만큼만 다른 데서 채운 정답 모음
//  ├─ loaded()                 받아 둔 것 먼저, 없으면 번들
//  ├─ replace(with:)           문제집 통째 교체 — 안전한 시점에만
//  │                           ⚠️ 아직 부르는 곳이 없다 (서버 갱신을 붙일 자리)
//  └─ question(answering:)     그 답이 정답인 문항 찾기
//
//  ── 흐름 ──────────────────────────────────────────────
//  KCTApp 이 시작할 때
//    → loaded() : ContentFile 이 questions.json 을 읽어 옴
//    → environment 로 아래 화면들에 내려보냄
//    → SessionBuilder 가 questions 와 answerPool 을 읽어 출제 계획을 세움
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KCTApp(생성), QuizSession·SessionBuilder(읽기)
//  기대는 것    : ContentFile(어디서 읽을지), Question
//  건드리지 않는 것 : 진척 — 문제집은 누가 무엇을 맞혔는지 모른다
//

import Foundation
import Observation

/// 앱이 사용하는 문제집을 들고 있는 곳.
///
/// 화면과 스케줄러가 여기서만 문제를 얻으므로, 출처가 번들에서 서버로 바뀌어도
/// 고칠 곳은 이 파일과 ``ContentFile`` 뿐입니다. 앱 전체가 같은 하나를 봐야 해서
/// 값이 아니라 `@Observable` 클래스입니다.
@Observable
final class QuestionCatalog {

    // ❓버전은 서버 것이 더 높을 때만 내려 받는다는데, 그런 알고리즘이 지금 있나?
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

    /// 앱이 쓸 문제집을 읽어 온다. **받아 둔 것 먼저, 없으면 번들.**
    ///
    /// 둘 다 실패하면 빈 문제집을 돌려줍니다. 앱이 죽는 것보다 빈 화면이 낫고,
    /// 개발 중에는 `assertionFailure` 가 즉시 알려 줍니다.
    static func loaded() -> QuestionCatalog {
        QuestionCatalog(
            payload: ContentFile<QuestionPayload>(fileName: "questions")
                .loadPreferringDownloaded(
                    isEmpty: { $0.questions.isEmpty },
                    fallback: QuestionPayload(version: 0, questions: []),
                    failureMessage: "기본 문제집을 읽지 못했습니다"))
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

    /// **그 답이 정답인 문항**을 찾는다. 없으면 `nil`.
    ///
    /// 어머니가 고른 오답이 다른 문항의 정답일 때가 많습니다 — 추석 문제에 「개천절」.
    /// 그때 그 문항의 ``Question/facts`` 를 가져와 **고른 답이 무엇인지도 알려 줍니다.**
    ///
    /// - Note: 못 찾으면 설명하지 않습니다. 「고죠선」 같은 오타나 O/X 의 「맞아요」는
    ///   어느 문항의 정답도 아니므로 **지어낼 재료가 없습니다.**
    func question(answering answer: String) -> Question? {
        let wanted = answer.filter { $0.isLetter || $0.isNumber }
        return questions.first { $0.displayAnswer.filter { $0.isLetter || $0.isNumber } == wanted }
    }

    /// 정답 모음을 만든다. `Set` 을 거쳐 중복을 없앤다 — 같은 보기가 두 번 나오면 안 된다.
    /// ❓answerPool이 뭐하는거지?
    ///    → **선다형의 「오답 보기」를 뽑아 오는 통.** 문항마다 오답을 손으로 적어 두는
    ///      대신 「다른 문제들의 정답」을 모아 두고 거기서 뽑는다. 그래서 오답이 그럴듯하고,
    ///      문제집을 갈아끼우면 보기도 저절로 따라 바뀐다. (Q&A.md 참고)
    private static func makeAnswerPool(from questions: [Question]) -> [String] {
        Array(Set(questions.map(\.displayAnswer)))
    }
    
    /// 같은 계열(``Question/category``)을 뺀 정답 모음.
    ///
    /// 오답이 ``answerPool`` 에서 무작위로 뽑히면 같은 문항의 난이도가 회차마다
    /// 달라집니다. 난이도를 낮추려는 것이 아니라 고정하려는 것입니다.
    ///
    /// - Note: 남은 보기가 `minimum` 보다 적으면 전체 모음으로 되돌아갑니다 —
    ///   문제집이 한 계열뿐일 때 보기가 비어 화면이 깨지는 것을 막습니다.
    func answerPool(excludingCategory category: String, atLeast minimum: Int = 3) -> [String] {
        let narrowed = Set(questions.filter { $0.category != category }.map(\.displayAnswer))
        return narrowed.count >= minimum ? Array(narrowed) : answerPool
    }
    
    /// 같은 종류(``Question/kind``)를 최대한 채우고, 모자란 자리만 다른 데서 채운 정답 모음.
    ///
    /// 지금 문제집은 종류별 문항 수가 적어서(인물은 6문항인데 답은 3개뿐) 필요한 오답
    /// 개수를 그 종류 안에서 다 못 채울 때가 있습니다. 그때 전체 모음으로 통째 돌아가면
    /// 「안익태」의 오답으로 「삼일절」 같은 게 나와 오히려 더 쉬워집니다. 그래서
    /// **있는 만큼은 같은 종류를 쓰고, 모자란 자리만** 무작위로 채웁니다.
    ///
    /// - Parameter count: 이번 문제에 실제로 필요한 오답 개수. 2지선다는 1, 4지선다는 3
    ///   — 필요한 만큼만 요구해야 "인물이 2명뿐이라 아쉽지만 못 쓴다"는 일이 안 생깁니다.
    func answerPool(preferringKindOf question: Question, count: Int) -> [String] {
        let sameKind = Array(Set(
            questions
                .filter { $0.kind == question.kind && $0.displayAnswer != question.displayAnswer }
                .map(\.displayAnswer)
        ))
        guard sameKind.count < count else { return sameKind }

        // 모자란 자리만 다른 종류에서 무작위로 채운다.
        let filler = answerPool
            .filter { $0 != question.displayAnswer && !sameKind.contains($0) }
            .shuffled()
            .prefix(count - sameKind.count)

        return sameKind + filler
    }
}
