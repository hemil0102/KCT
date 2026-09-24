//
//  QuizSession.swift
//  KCT
//
//  역할 : 한 회차(7칸)의 상태를 들고, 시작·제출·채점을 결정한다
//  요점 : 화면은 "무엇을 그릴까"만 묻고, "무엇이 맞나"는 전부 여기서 답한다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuizSession                 회차의 주인. 화면이 아니라 진행을 소유한다
//  ├─ items                    이번 회차 출제 항목 (SessionBuilder 가 만든 것).
//  │                           **연결 문제는 여기 안 들어 있다** — 아래 참고
//  ├─ matchingSet/matchingSlot 이번 회차의 연결 문제와 그것이 놓인 칸 번호
//  ├─ slotCount                회차의 칸 수 = items.count + (연결 문제 있으면 1)
//  ├─ isMatchingSlot           지금 칸이 연결 문제인가 (QuizView 가 화면을 고르는 기준)
//  ├─ completeMatchingSlot()   연결 문제를 다 맞혔다 → 다음 칸으로
//  ├─ currentIndex             몇 번째 **칸**인가 (0부터). items 의 자리가 아니다
//  ├─ userAnswer               지금 고르거나 입력한 답
//  │                           └ 값이 들어오면 안내를 스스로 거둔다 (setter 안에서)
//  ├─ results                  채점 결과 (문제 id → 결과)
//  ├─ isGrading                채점 중인가
//  ├─ encouragements           이번 회차의 응원 문구 (뒤에서 만들어 둔다)
//  ├─ isWrappingUp             회차를 마무리하는 3초인가
//  ├─ needsAnswerHint          "답을 고르세요" 안내를 띄울까
//  ├─ sessionID                이번 회차를 묶는 번호 (관찰 기록용)
//  ├─ shownAt / firstTouchAt   지금 문제가 뜬 시각 / 처음 답에 손댄 시각
//  ├─ timingByID               채점 전까지 잠깐 들고 있는 시간 (문제 id → ObsTiming)
//  ├─ wasFirstEverByID         처음 보는 문항이었나 — start() 에서 미리 읽어 둔다
//  ├─ start()                  회차 구성 — 진척 확보 → 출제 계획 → 초기화 → 캐시 워밍
//  ├─ submitCurrent()          답 기록 → 다음 문제. 마지막이면 채점 시작
//  ├─ eraseAllProgress()       학습 기록 전체 삭제 후 새 회차
//  ├─ gradeCurrent()           한 문제를 채점하고 진척에 반영
//  ├─ judge()                  ① 규칙 ② 코드 ③ 모델 — 세 층으로 한 문제를 판정
//  ├─ nextEncouragement()      응원 문구를 하나 꺼낸다 (없으면 앱에 박힌 것)
//  ├─ holdWaitingLine()        응원 문구를 적어도 3초는 보여 준다
//  ├─ saveFailures()           모델이 실패한 기록을 저장소에 넣고 바로 저장한다 (QuestionScreen 도 부른다)
//  ├─ uploadFailuresNow()      회차 경계를 안 기다리고 실패 기록을 바로 올려 본다 (QuestionScreen 도 부른다)
//  ├─ wrapUp()                 회차 끝의 3초 박자
//  ├─ recordTiming()           지금 문항에서 잰 시간을 채점 때까지 보관
//  ├─ saveObsRecord()          정오답이 정해진 뒤 ObsRecord 한 줄을 남긴다
//  ├─ feedback                 지금 띄워야 할 오답 해설 창(IncorrectCommentary). nil 이면 창이 없다
//  ├─ correctFeedback          지금 띄워야 할 정답 해설 창(CorrectCommentary). nil 이면 창이 없다
//  ├─ reviewItems / reviewIndex  복습할 문항(본 풀이에서 틀린 것) / 지금 자리 (11차 4-37)
//  ├─ isShowingReviewIntro     복습 시작 화면을 띄울 차례인가
//  ├─ isInReview               복습 중인가 — current 가 복습 문항을 준다
//  ├─ reviewResults            문항 id → 복습에서 맞혔나 (본 풀이 results 와 따로)
//  ├─ startReview()            복습 시작 화면의 버튼 → 첫 복습 문제
//  ├─ trueFalseFeedback        지금 띄워야 할 O/X 해설 창(TrueFalseCommentary). 맞힘·틀림 공용
//  ├─ trueFalseVerdict         O/X 판정 — 누른 버튼을 녹색·붉은색으로 칠한다 (채점 전 nil)
//  ├─ isShowingCommentary      셋 중 하나라도 떠 있는가 (뒤 화면의 손가락을 막는 데 쓴다)
//  ├─ presentCorrectFeedback() 정답 해설 창을 띄우고 CommentaryWriter.explain(_:length: .full) 로 채운다
//  ├─ presentTrueFalseFeedback() 0.6초 뒤 O/X 창을 띄운다. 바른 문장은 코드, 해설만 모델
//  ├─ dismissTrueFalseFeedback() O/X 해설 창의 「다음 문제」
//  ├─ dismissFeedback()        오답 해설 창의 「다음 문제」 — 창을 닫고 다음 문제로
//  ├─ dismissCorrectFeedback() 정답 해설 창의 「다음 문제」 — 같은 일
//  ├─ moveToNextQuestion()     다음 문제로 넘어간다 — 두 창을 닫을 때 모두 (맞았을 때도 이제 창을 거친다)
//  ├─ completeMatchingSlot()   연결 문제 칸을 마쳤다 → 다음 칸 (채점도 해설도 없다)
//  ├─ applyProgress()          countAttempt + moveLadder/nudgeLadder 를 한 자리에서
//  ├─ ensureProgressExists()   진척이 없는 문항에 QuestionProgress 를 만들어 둔다
//  ├─ fetchProgressByID()      저장소에서 진척을 읽어 id 로 찾을 수 있게
//  ├─ itemIndex(for:)          칸 번호 → items 안의 자리 (연결 문제 칸을 건너뛴다)
//  ├─ clearAnswers()           답·결과·시간을 회차 단위로 처음 상태로
//  ├─ warmFocusCache()         묻는 대상을 뒤에서 분석해 캐시에 채운다
//  ├─ reasonForLog()           채점 이유를 로그에 남길 모양으로 다듬는다
//  └─ uploadObservations()     안 올라간 기록을 뒤에서 밀어 올린다 (기다리지 않는다)
//
//  ⚠️ 해설 창에 **들어갈 내용**(IncorrectCommentary · CorrectCommentary ·
//     CommentaryPlaceholder)은 이 파일에 없다 — Grading/Commentary.swift 로 옮겼다.
//     창을 그리는 화면이 회차 전체를 아는 타입을 거치지 않게 하려는 것이다.
//
//  ── 연결 문제가 낀 회차 ────────────────────────────────
//  연결 문제(MatchingSet)는 Question 이 아니라서 items 에 못 담는다. 그래서
//  회차를 "칸(slot)" 으로 세고, 그중 한 칸만 연결 문제로 비워 둔다.
//
//    칸:    0      1      2          3      4      5      6
//         [문제] [문제] [연결문제]  [문제] [문제] [문제] [문제]
//    items: 0      1       —         2      3      4      5
//
//  currentIndex 는 **칸 번호**이고, items 를 찾을 때만 itemIndex(for:) 로
//  한 칸 당겨 본다. 연결 문제 칸에서는 current 가 nil 이라 submitCurrent()·
//  낭독 같은 일반 문제용 경로가 저절로 비활성된다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  화면 진입
//    → start()
//        → 진척이 없는 문제에 QuestionProgress 생성
//        → 연결 문제를 한 세트 뽑고(있으면) 3·4·5번째 중 한 칸을 그 자리로 예약
//        → SessionBuilder.build() 로 나머지 칸의 출제 계획을 받아 items 에 보관
//        → FocusStore 로 백그라운드 캐시 워밍 (기다리지 않는다)
//    → 사용자가 답 선택 → userAnswer 에 저장 (안내 자동 해제)
//    → submitCurrent() → 답 기록 → currentIndex += 1
//    → gradeCurrent() : 문제마다 그 자리에서 채점
//        → judge() : ① RuleGrader(선다·O/X) ② AnswerMatcher(코드) ③ AnswerChecker(모델)
//        → QuestionProgress.countAttempt() 로 모든 문항을 센다 (격려용 포함)
//        → 격려용 슬롯이면 nudgeLadder() 로 2지선다 → O/X 한 칸만
//        → 아니면 moveLadder() 로 사다리를 올리거나 내린다
//        → 맞았으면 presentCorrectFeedback() 으로 정답 해설 창을 띄운다
//              (오답 해설과 같은 CommentaryWriter.explain(_:length: .full) 을 그대로 쓴다)
//              → 「다음 문제」를 누르면 dismissCorrectFeedback() → moveToNextQuestion()
//        → 틀렸으면 오답 해설 창(feedback) → 「다음 문제」→ dismissFeedback() → moveToNextQuestion()
//        → saveObsRecord() 로 관찰 기록 한 줄을 남긴다 (진척과 무관하게)
//        → uploadObservations() 로 뒤에서 서버에 올린다 (기다리지 않는다)
//        → modelContext.save()
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView 와 그 아래 화면들 (QuestionScreen · ResultScreen)
//  기대는 것    : QuestionCatalog(문제), SessionBuilder(출제 계획),
//                RuleGrader·AnswerMatcher·AnswerChecker(채점), QuestionProgress(진척), FocusStore(하이라이트)
//  건드리지 않는 것 : 낭독과 화면 그리기 — 소리는 QuizView 가, 모양은 각 Screen 이 맡는다
//

import Foundation
import Observation
import SwiftData

/// 퀴즈 한 회차의 진행 상태와 그 회차에서 일어나는 모든 결정을 담당합니다.
///
/// 화면(``QuizView`` 와 그 아래 뷰들)은 이 객체에 **묻기만** 합니다.
/// "지금 몇 번째인가", "답이 들어왔나", "채점 결과가 무엇인가" 를 물어 그리고,
/// 판단은 하지 않습니다. 덕분에 규칙이 바뀔 때 고칠 곳이 이 파일 하나로 모입니다.
///
/// - Note: 진척(``QuestionProgress``)을 **직접 조회**합니다. SwiftUI 의 `@Query` 는
///   지우고 바로 다시 만드는 흐름에서 즉시 갱신되지 않을 수 있어, 판단의 근거로 쓰기에
///   위험하기 때문입니다. 화면에 보여줄 누적 통계는 `@Query` 를 써도 괜찮습니다.
@MainActor
@Observable
final class QuizSession {

    // MARK: - 기대는 것

    private let catalog: QuestionCatalog
    private let modelContext: ModelContext

    /// 연결 문제 세트 보관소. `nil` 이면 이번 회차엔 연결 문제를 넣지 않는다
    /// (프리뷰·테스트처럼 안 넘긴 경우).
    private let matchingCatalog: MatchingSetCatalog?

    /// 뜻으로 채점하는 쪽. 직접입력에만 쓴다. (선다·O/X 는 ``RuleGrader`` 가 즉시 처리)
    private let answerChecker = AnswerChecker()
    private let commentaryWriter = CommentaryWriter()
    private let encouragementWriter = EncouragementWriter()

    /// 이번 회차에 쓸 응원 문구. 회차를 시작할 때 뒤에서 만들어 채운다.
    ///
    /// 비어 있으면 ``EncouragementWriter/fallback`` 에서 뽑습니다 —
    /// 아직 안 만들어졌거나 모델이 실패한 경우입니다. **어느 쪽이든 화면은 기다리지 않습니다.**
    private var encouragements: [String] = []

    /// 한 회차의 **칸 수**. 연결 문제가 들어가면 그중 한 칸을 차지하므로,
    /// 일반 문제는 그만큼 덜 뽑는다 — 회차 길이는 언제나 이 값이다.
    let size: Int

    /// 이번 회차에 낼 연결 문제. `nil` 이면 연결 문제 없이 예전처럼 일반 문제로만 찬다.
    private(set) var matchingSet: MatchingSet?

    /// 연결 문제가 놓인 칸 번호(0부터). 연결 문제가 없으면 `nil`.
    private(set) var matchingSlot: Int?

    /// 연결 문제가 올 수 있는 칸 — 3·4·5번째(0부터 세면 2·3·4).
    ///
    /// 첫 칸과 마지막 칸은 ``SessionBuilder/shapeRound(_:progressByID:focusByID:)`` 가
    /// 격려용 쉬운 2지선다로 쓰는 자리라 비켜 둔다. 6번째 칸은 음성 입력 문제
    /// 자리로 비워 둘 예정인데 아직 그 유형이 없어서, 지금은 일반 문제가 온다.
    private static let matchingSlotCandidates = [2, 3, 4]

    // MARK: - 상태

    /// 이번 회차의 출제 항목. ``start()`` 가 채운다.
    private(set) var items: [QuizItem] = []

    /// 현재 몇 번째 문제인지 (0부터). ``items`` 의 개수와 같아지면 회차가 끝난 것이다.
    private(set) var currentIndex = 0

    /// 채점 결과 (문제 id → 결과).
    private(set) var results: [Int: GradingResult] = [:]

    /// 채점이 진행 중인지.
    private(set) var isGrading = false

    /// 회차를 마무리하는 한 박자. 결과 화면 앞에서 3초 동안 켜진다.
    private(set) var isWrappingUp = false

    /// "답을 고르면 다음으로 갈 수 있어요" 안내를 띄울지.
    private(set) var needsAnswerHint = false

    /// 지금 고르거나 입력한 답.
    ///
    /// 값이 들어오는 순간 안내(``needsAnswerHint``)를 스스로 거둡니다.
    /// 이 규칙을 화면에 두면 화면마다 되풀이해야 하므로 여기에 둡니다.
    var userAnswer: String {
        get { rawAnswer }
        set {
            rawAnswer = newValue
            if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                needsAnswerHint = false
                if firstTouchAt == nil { firstTouchAt = .now }
            }
        }
    }

    private var rawAnswer = ""

    /// 제출된 답 기록 (문제 id → 답). 채점할 때 한 번에 꺼내 쓴다.
    private var submittedAnswers: [Int: String] = [:]

    /// 백그라운드 하이라이트 분석 작업. 회차가 바뀌면 취소한다.
    private var focusWarmingTask: Task<Void, Never>?

    // MARK: - 관찰 기록용 상태

    /// 한 문항에서 잰 시간.
    ///
    /// ``ObsRecord`` 를 그 자리에서 만들지 못하는 이유가 있습니다 — **정오답은
    /// 채점이 끝나야 정해지는데, 시간은 「다음」을 누른 순간에 이미 지나갑니다.**
    /// 그 사이를 이 값이 메웁니다.
    private struct ObsTiming {
        let askedAt: Date
        let secToFirstTouch: Double?
        let secToSubmit: Double
    }
    
    /// 이번 회차를 묶는 번호. ``start()`` 마다 새로 만든다.
    ///
    /// 이것 하나로 나중에 「이번 회차 평균 대기」와 「회차에 걸린 총 시간」을 셉니다.
    private var sessionID = UUID()

    /// 지금 문제가 화면에 뜬 시각.
    ///
    /// 화면이 알려 주지 않고 **여기서 스스로 찍습니다.** ``start()`` 직후와
    /// ``submitCurrent()`` 로 다음 문제로 넘어간 직후가 그 순간입니다.
    /// 화면에 `onAppear` 를 심으면 화면이 판단을 하게 되어 규칙이 흩어집니다.
    private var shownAt: Date?

    /// 지금 문제에서 **처음** 답에 손댄 시각. 답을 바꿔도 처음 것만 남는다.
    private var firstTouchAt: Date?

    /// 문제 id → 이번 회차에 잰 시간. 채점이 끝나면 ``ObsRecord`` 로 옮긴다.
    private var timingByID: [Int: ObsTiming] = [:]

    /// 문제 id → **이번이 처음 보는 문항이었나.**
    ///
    /// - Important: 채점 뒤에 읽으면 **전부 `false`** 가 됩니다.
    ///   ``QuestionProgress/countAttempt(correct:now:)`` 가
    ///   ``QuestionProgress/isIntroduced`` 를 켜 버리기 때문입니다.
    ///   그래서 ``start()`` 에서, 아직 아무것도 일어나지 않았을 때 미리 읽어 둡니다.
    private var wasFirstEverByID: [Int: Bool] = [:]
    
    /// 지금 띄워야 할 창. `nil` 이면 **창이 없다.**
    ///
    /// 별도의 `Bool` 을 두지 않은 이유 — **값이 있으면 떠 있는 것**입니다.
    /// ``ObsRecord/uploadedAt`` 이 `nil` 이면 「아직 안 올라감」인 것과 같은 방식입니다.
    ///
    /// `private(set)` 인 이유 — 화면은 **읽어서 그리기만** 하고, 넣고 비우는 것은
    /// ``QuizSession`` 만 합니다.
    private(set) var feedback: IncorrectCommentary?

    /// 지금 띄워야 할 **정답 해설** 창. `nil` 이면 창이 없다. (``feedback`` 과 같은 이유)
    private(set) var correctFeedback: CorrectCommentary?

    /// 지금 띄워야 할 **O/X 해설** 창. 맞혔든 틀렸든 O/X 는 이 창 하나를 쓴다. (``feedback`` 과 같은 이유)
    private(set) var trueFalseFeedback: TrueFalseCommentary?

    // MARK: - 복습 (11차 4-37)
    //
    // 회차의 모든 칸을 지나면, 결과 화면 전에 **이번 회차에 틀린 문제만** 한 번 더 묻는다.
    // 흐름: 마지막 칸 → 복습 시작 화면(isShowingReviewIntro) → 복습 문제들(isInReview)
    //       → 3초 박자(isWrappingUp) → 결과 화면. 틀린 게 없으면 복습 없이 곧바로 결과로 간다.

    /// 복습할 문항 — 이번 회차 본 풀이에서 틀린 것들. 순서는 회차에 나온 순서 그대로.
    private(set) var reviewItems: [QuizItem] = []

    /// 지금 복습 중인 자리 (``reviewItems`` 안의 번호).
    private(set) var reviewIndex = 0

    /// 복습 시작 화면을 띄울 차례인가.
    private(set) var isShowingReviewIntro = false

    /// 복습 문제를 푸는 중인가. 이 동안 ``current`` 는 복습 문항을 돌려준다.
    private(set) var isInReview = false

    /// 문항 id → 복습에서 맞혔나. **본 풀이 결과(``results``)는 건드리지 않고** 따로 둔다 —
    /// 결과 화면이 「정답 / 다시 풀어서 정답 / 틀렸어요」를 가르려면 둘 다 필요하다.
    private(set) var reviewResults: [Int: Bool] = [:]

    /// 복습에서 맞혔는지. 복습하지 않은 문항이면 `nil`.
    func reviewOutcome(for questionID: Int) -> Bool? { reviewResults[questionID] }

    /// 복습 시작 화면의 버튼. 첫 복습 문제로 들어간다.
    func startReview() {
        guard isShowingReviewIntro, !reviewItems.isEmpty else { return }
        isShowingReviewIntro = false
        isInReview = true
        reviewIndex = 0
        rawAnswer = ""
        shownAt = .now
        firstTouchAt = nil
    }

    /// 지금 O/X 문항의 판정. 누른 버튼을 녹색(맞음)·붉은색(틀림)으로 칠하는 데 쓴다.
    /// 아직 채점 전이면 `nil`.
    ///
    /// O/X 는 **누르는 순간 채점**된다 — 버튼 색이 곧 결과라, 해설 창이 올라온 뒤에도
    /// 창 위로 보이는 버튼에서 「내가 뭘 골랐는지」가 남는다(11차 4-30).
    private(set) var trueFalseVerdict: Bool?

    init(
        catalog: QuestionCatalog,
        modelContext: ModelContext,
        matchingCatalog: MatchingSetCatalog? = nil,
        size: Int = 7
    ) {
        self.catalog = catalog
        self.modelContext = modelContext
        self.matchingCatalog = matchingCatalog
        self.size = size
    }

    // MARK: - 화면이 물어보는 것

    /// 아직 회차가 구성되지 않았는지.
    var isEmpty: Bool { items.isEmpty && matchingSet == nil }

    /// 이번 회차의 **칸 수**. 일반 문제 + (있다면) 연결 문제 한 칸.
    ///
    /// 진행 막대는 `items.count` 가 아니라 이 값을 써야 한다 — 연결 문제는
    /// ``items`` 에 안 들어 있어서, 그대로 두면 막대 칸이 하나 모자란다.
    var slotCount: Int { items.count + (matchingSet == nil ? 0 : 1) }

    /// 지금 칸이 연결 문제인가. ``QuizView`` 가 이 값으로 어느 화면을 띄울지 고른다.
    var isMatchingSlot: Bool { matchingSet != nil && currentIndex == matchingSlot }

    /// 모든 칸을 다 지났는지.
    var isFinished: Bool { !isEmpty && currentIndex >= slotCount }

    /// 지금 풀고 있는 문제. **연결 문제 칸이거나** 다 풀었으면 `nil`.
    var current: QuizItem? {
        // 복습 중이면 복습 문항을 준다. 화면(QuestionScreen)은 복습인지 몰라도 같은 식으로 그린다.
        if isInReview {
            return reviewItems.indices.contains(reviewIndex) ? reviewItems[reviewIndex] : nil
        }

        guard !isMatchingSlot else { return nil }

        let index = itemIndex(for: currentIndex)
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    /// 칸 번호 → ``items`` 안의 자리.
    ///
    /// 연결 문제는 ``items`` 에 없으므로, 그 칸을 지난 뒤로는 한 칸씩 당겨진다.
    private func itemIndex(for slot: Int) -> Int {
        guard let matchingSlot, matchingSet != nil, slot > matchingSlot else { return slot }
        return slot - 1
    }

    /// 해설 창(오답·정답)이 떠 있는가.
    ///
    /// 창이 떠 있는 동안은 뒤 문제 화면의 답을 못 바꾸게 막는 데 쓴다
    /// (``QuestionScreen`` 의 `allowsHitTesting`). 두 창 모두 배경을 어둡게 하지
    /// 않고 뒤가 그대로 비치도록 열어 두었는데(`presentationBackgroundInteraction`),
    /// 그러면 창이 덮지 않은 위쪽의 보기 버튼이 **그대로 눌린다.** 이미 채점이
    /// 끝난 뒤라 그때 답을 바꿔도 결과는 안 바뀌지만, 눌리는데 아무 일도 안
    /// 일어나면 고장으로 보인다.
    var isShowingCommentary: Bool {
        feedback != nil || correctFeedback != nil || trueFalseFeedback != nil
    }

    /// 답을 고르거나 입력했는지.
    var hasAnswer: Bool {
        !rawAnswer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 지금이 마지막 칸인지. (하단 버튼 문구를 "제출" 로 바꾸는 데 쓴다)
    var isLastQuestion: Bool { currentIndex == slotCount - 1 }

    /// 이번 회차에서 맞힌 개수.
    var correctCount: Int { results.values.filter(\.isCorrect).count }

    /// 문제 하나의 채점 결과.
    func result(for questionID: Int) -> GradingResult? { results[questionID] }

    // MARK: - 회차 시작

    /// 진척을 반영해 이번 회차를 구성한다.
    ///
    /// 처음 보는 문제에는 진척을 새로 만들어 두고(그래야 승급·강등을 기록할 수 있다),
    /// ``SessionBuilder`` 에게 "무엇을 어떤 방식으로 낼지" 계획을 받아 온다.
    func start() {
        let progressByID = ensureProgressExists()

        // 채점이 isIntroduced 를 켜기 전에 "처음 보는 문항" 을 미리 읽어 둔다.
        wasFirstEverByID = progressByID.mapValues { !$0.isIntroduced }

        // 이번 회차에 연결 문제를 넣을지 먼저 정한다. 넣으면 일반 문제를 한 칸
        // 덜 뽑아야 회차 길이(size)가 그대로 유지된다.
        let chosenSet = matchingCatalog?.randomSet()
        matchingSet = chosenSet

        let store = FocusStore(modelContext: modelContext)
        items = SessionBuilder(catalog: catalog).build(
            size: chosenSet == nil ? size : size - 1,
            progressByID: progressByID,
            focusByID: store.focuses(for: catalog.questions)
        )

        // 연결 문제가 들어갈 칸을 3·4·5번째 중 무작위로 고른다 — 매 회차 다른
        // 자리에 오게 하려는 것이다. 문제집이 작아 일반 문제가 그보다 적게
        // 뽑혔으면 맨 뒤 칸으로 물러선다(범위를 벗어나지 않게).
        matchingSlot = chosenSet == nil
            ? nil
            : min(Self.matchingSlotCandidates.randomElement() ?? 2, items.count)

        clearAnswers()
        isWrappingUp = false

        // 어머니가 문제를 푸는 동안, 아직 분석하지 않은 문제를 뒤에서 채워 둔다.
        warmFocusCache()
        
        // 첫 직접입력이 나오기 전에 모델을 깨워 둔다.
        answerChecker.prepare()

        // 어머니가 첫 문제를 읽는 동안 이번 회차의 응원 문구를 만들어 둔다.
        // 늦게 와도 상관없다 — 그 전에 틀리면 앱에 박힌 것을 쓴다.
        encouragements = []
        Task { encouragements = await encouragementWriter.write() }

        // 지난번에 못 올린 기록이 있으면 여기서 따라잡는다.
        uploadObservations()
    }

    /// 학습 기록을 모두 지우고 처음부터 다시 시작한다.
    ///
    /// 지운 뒤 ``start()`` 가 진척을 다시 만들어 주므로, 여기서 따로 만들 필요가 없다.
    func eraseAllProgress() {
        try? modelContext.delete(model: QuestionProgress.self)
        try? modelContext.save()

        start()
        try? modelContext.save()
    }

    // MARK: - 답 제출

    /// 현재 답을 기록하고 다음 문제로 넘어간다. 마지막 문제였다면 채점을 시작한다.
    func submitCurrent() {
        guard let item = current else { return }
        guard !isGrading else { return }
        
        let trimmed = rawAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 복습 풀이는 본 풀이의 답·시간 기록을 덮어쓰지 않는다 (관찰 기록은 본 풀이만 남긴다).
        if !isInReview {
            submittedAnswers[item.id] = trimmed
        }

        // 시간을 여기서 잰다 — 화면이 바뀌기 전이 마지막 기회다.
        if !isInReview {
            recordTiming(for: item)
        }

        Task { await gradeCurrent(item, answer: trimmed) }
    }
    
    /// 다음 문제로 넘어간다.
    ///
    /// **두 곳에서 부릅니다** — 맞혔을 때는 곧바로, 틀렸을 때는 창의 「다음 문제」를
    /// 누를 때. 끝에서 하는 일이 양쪽 다 같아서 함수 하나로 둡니다.
    ///
    /// 한때 이 다섯 줄이 ``submitCurrent()`` 안에 있었습니다. 그러면 제출과 동시에
    /// 다음 문제로 넘어가 버려서 **창이 낄 자리가 없습니다.**
    ///
    /// - Important: ``shownAt`` 을 ``currentIndex`` **뒤에** 찍습니다.
    ///   그래야 「다음 문제가 뜬 시각」이 됩니다.
    private func moveToNextQuestion() {
        rawAnswer = ""
        needsAnswerHint = false
        trueFalseVerdict = nil

        // 복습 중이면 복습 안에서 다음으로. 다 풀면 결과 화면으로 간다.
        if isInReview {
            reviewIndex += 1
            shownAt = .now
            firstTouchAt = nil

            if reviewIndex >= reviewItems.count {
                isInReview = false
                uploadObservations()
                wrapUp()
            }
            return
        }

        currentIndex += 1

        shownAt = .now
        firstTouchAt = nil

        if isFinished {
            // 틀린 문제가 있으면 결과 전에 복습부터. 회차에 나온 순서 그대로 다시 묻는다.
            let missed = items.filter { results[$0.id]?.isCorrect == false }
            if !missed.isEmpty {
                reviewItems = missed
                isShowingReviewIntro = true
                return
            }

            uploadObservations()
            wrapUp()
        }
    }

    /// 모델이 실패한 기록을 저장소에 넣는다. 서버로는 ``ObsUploader`` 가 나중에 보낸다.
    ///
    /// - Note: `private` 이 아니다. 여기(``gradeCurrent()``)뿐 아니라 ``QuestionScreen``도
    ///   낱말 사전 예문(``GlossaryExampleWriter/write(word:gloss:relatedWords:referenceSentence:questionID:)``)이
    ///   실패했을 때 이 메서드로 넘긴다 — modelContext 는 세션만 들고 있으므로, 화면이
    ///   직접 넣지 않고 항상 세션을 거친다.
    ///
    /// - Important: 여기서 바로 `save()` 한다. `gradeCurrent()` 에서 부를 때는 뒤이어
    ///   `saveObsRecord()` 가 어차피 저장을 하지만, `QuestionScreen`의 낱말 사전 실패는
    ///   회차가 끝나거나 새로 시작할 때까지 다른 저장이 한 번도 안 일어날 수 있다 —
    ///   그 사이 앱이 종료되면 이 기록만 저장 안 된 채로 사라질 수 있어, 여기서 직접
    ///   책임진다.
    func saveFailures(_ drafts: [ModelFailureDraft?]) {
        let toInsert = drafts.compactMap { $0 }
        guard !toInsert.isEmpty else { return }

        for draft in toInsert {
            modelContext.insert(ModelFailure(draft: draft))
        }
        try? modelContext.save()
    }

    /// 방금 저장한 실패 기록을 회차가 끝나거나 새로 시작할 때까지 기다리지 않고
    /// 바로 서버로 올려 본다.
    ///
    /// ``uploadObservations()``는 회차 시작/종료 시점에만 불리는데, 낱말 사전 예문
    /// 실패(``QuestionScreen``)는 그 사이 아무 때나 생긴다. 조용히 다음 기회를
    /// 기다려도 되지만(``saveFailures(_:)``가 이미 폰에 안전하게 남겨 뒀으므로),
    /// 세이프티 문제를 바로 확인하고 싶을 때(Supabase 대시보드를 그 자리에서 보는
    /// 경우 등) 기다리지 않게 이 메서드를 따로 둔다.
    ///
    /// - Note: 화면에는 아무것도 안 보인다 — 성공도 실패도 조용하다. 실패하면
    ///   ``uploadObservations()``가 다음 기회에 다시 시도한다.
    func uploadFailuresNow() {
        Task {
            await ObsUploader(modelContext: modelContext).uploadPendingFailures()
        }
    }

    /// 응원 문구를 읽을 시간을 준다. 창이 뜬 지 ``waitingLineHold`` 가 안 됐으면 그만큼 쉰다.
    ///
    /// 선다·O/X 는 해설이 1초 안에 오기도 해서, 그대로 두면 **글자가 나타났다 사라집니다.**
    /// 기다림을 없애는 것이 늘 좋은 것은 아닙니다 — 읽을 시간은 남겨 둡니다.
    private func holdWaitingLine(shownAt: ContinuousClock.Instant) async {
        let elapsed = ContinuousClock.now - shownAt
        guard elapsed < Self.waitingLineHold else { return }

        try? await Task.sleep(for: Self.waitingLineHold - elapsed)
    }

    /// 응원 문구를 적어도 이만큼은 보여 준다.
    private static let waitingLineHold: Duration = .seconds(3)

    /// 응원 문구를 하나 꺼낸다. 다 썼거나 아직 없으면 앱에 박힌 것에서 뽑는다.
    ///
    /// 꺼낸 것은 **목록에서 뺍니다.** 한 회차 안에서 같은 말이 두 번 나오지 않게 하려는 것입니다.
    private func nextEncouragement() -> String {
        encouragements.popLast()
            ?? EncouragementWriter.fallback.randomElement()
            ?? ""
    }

    /// 마지막 문제를 넘긴 뒤 3초 동안 「채점 중이에요」를 보여준다.
    ///
    /// 채점 자체는 문항마다 이미 끝나 있습니다. 그래도 한 박자를 두는 이유는,
    /// 마지막 답을 누른 손이 결과 화면의 버튼을 잘못 누르는 것을 막고
    /// **회차가 끝났다는 것을 몸으로 알리기** 위해서입니다.
    private func wrapUp() {
        isWrappingUp = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            isWrappingUp = false
        }
    }
    
    func dismissFeedback() {
        guard feedback != nil else { return }
        feedback = nil
        moveToNextQuestion()
    }

    /// 연결 문제 칸을 마쳤다. ``MatchingQuestionScreen`` 이 짝을 다 맞히고
    /// 「다음」을 눌렀을 때 부른다.
    ///
    /// 채점도 해설도 없다 — 화면이 짝이 맞는지 스스로 판정하고, **다 맞혀야만**
    /// 「다음」이 눌리기 때문이다. 진척(``QuestionProgress``) 사다리도 건드리지
    /// 않는다. 사다리는 문항 하나(=한 사실)가 한 칸을 오르내리는 구조인데,
    /// 연결 문제는 묶음 전체를 한 번에 묻는 것이라 올릴 자리가 없다.
    func completeMatchingSlot() {
        guard isMatchingSlot else { return }
        moveToNextQuestion()
    }

    /// O/X 해설 창의 「다음 문제」. (``dismissFeedback()`` 과 같은 이유)
    func dismissTrueFalseFeedback() {
        guard trueFalseFeedback != nil else { return }
        trueFalseFeedback = nil
        moveToNextQuestion()
    }

    /// 정답 해설 창의 「다음 문제」. (``dismissFeedback()`` 과 같은 이유)
    func dismissCorrectFeedback() {
        guard correctFeedback != nil else { return }
        correctFeedback = nil
        moveToNextQuestion()
    }

    /// 답 없이 다음을 누른 경우 — 안내를 띄우라고 표시한다.
    ///
    /// 버튼을 아예 못 누르게 막지 않는 이유: 눌러도 아무 일이 없으면 어르신은
    /// 앱이 고장 났다고 생각한다. 눌리게 두고 무엇이 필요한지 알려 주는 편이 낫다.
    func requestAnswerHint() {
        needsAnswerHint = true
    }

    /// 맞혔을 때 정답 해설 창을 띄운다.
    ///
    /// 오답을 만났을 때 정답을 설명하던 바로 그 함수(``CommentaryWriter/explain(_:length:)``, `.full`)를
    /// 그대로 쓴다 — "이 답이 왜 맞는지"는 이번에 맞혔든 틀렸든 같은 사실에서 나오는
    /// 같은 문장이기 때문이다. 창을 먼저 띄우고(자리표시 문구), 글이 오면 갈아 끼우는
    /// 흐름도 오답 해설과 같다 — 9차에서 겪은 "시트가 처음엔 안 채워진 채로 뜨는" 문제를
    /// 여기서도 피하기 위해서다.
    private func presentCorrectFeedback(for item: QuizItem) async {
        let shownAt = ContinuousClock.now

        correctFeedback = CorrectCommentary(
            id: item.id,
            correctAnswer: item.question.displayAnswer,
            commentary: CommentaryPlaceholder.waiting)

        let written = await commentaryWriter.explain(item.question, length: .full)
        saveFailures([written.failure])

        let text = written.text

        // 글이 너무 빨리 오면 창이 뜨자마자 바뀌어 깜빡여 보인다. 오답 해설과 같은
        // 최소 대기를 둔다.
        await holdWaitingLine(shownAt: shownAt)

        // 실패해도 반드시 갱신한다 — 안 그러면 자리표시 문구가 오지 않는 것을
        // 계속 기다리며 반짝인다.
        if correctFeedback != nil {
            correctFeedback = CorrectCommentary(
                id: item.id,
                correctAnswer: item.question.displayAnswer,
                commentary: text ?? CommentaryPlaceholder.failed)
        }

        saveObsRecord(for: item, isCorrect: true, explanation: text)
    }

    /// O/X 를 누른 뒤 창이 올라오기까지의 한 박자 — 버튼 색이 바뀐 것을 먼저 보게 한다.
    private static let trueFalseColorBeat: Duration = .milliseconds(600)

    /// O/X 해설 창을 띄운다.
    ///
    /// 바른 문장은 **코드가** 만든다(``Question/correctedStatementParts()``) — 답이 하나로
    /// 정해지는 일이라 모델에게 맡기지 않는다. 아래 해설만 모델(``CommentaryWriter/explain(_:length:)``, `.full`)이
    /// 쓴다. 해설은 버튼 색을 보여 주는 박자 동안 **뒤에서 미리** 만들기 시작한다.
    private func presentTrueFalseFeedback(for item: QuizItem, answer: String, isCorrect: Bool) async {
        guard case .trueFalse(_, let candidate, let isTrue) = item.payload else { return }

        let parts = item.question.correctedStatementParts()

        func content(_ text: String) -> TrueFalseCommentary {
            TrueFalseCommentary(
                id: item.id,
                pickedLabel: answer,
                isCorrect: isCorrect,
                statementWasTrue: isTrue,
                shownCandidate: candidate,
                correctAnswer: item.question.displayAnswer,
                sentenceBefore: parts.before,
                sentenceAfter: parts.after,
                commentary: text)
        }

        async let written = commentaryWriter.explain(item.question, length: .full)

        try? await Task.sleep(for: Self.trueFalseColorBeat)

        trueFalseFeedback = content(CommentaryPlaceholder.waiting)
        let shownAt = ContinuousClock.now

        let result = await written
        saveFailures([result.failure])

        // 글이 너무 빨리 오면 창이 뜨자마자 바뀌어 깜빡여 보인다. 다른 창과 같은 최소 대기.
        await holdWaitingLine(shownAt: shownAt)

        // 실패해도 반드시 갱신한다 — 안 그러면 자리표시 문구가 계속 반짝인다.
        if trueFalseFeedback != nil {
            trueFalseFeedback = content(result.text ?? CommentaryPlaceholder.failed)
        }

        saveObsRecord(for: item, isCorrect: isCorrect, explanation: result.text)
    }

    // MARK: - 채점
    private func gradeCurrent(_ item: QuizItem, answer: String) async {
        // 직접입력만 모델이 판정해 시간이 걸린다. 선다·O/X 는 곧바로 다음 문제로 이어진다.
        if item.mode == .typing { isGrading = true }

        // 복습 풀이는 본 풀이 결과를 덮어쓰지 않는다 — judge 가 results 에 적으므로
        // 미리 들고 있다가 되돌리고, 복습 결과는 reviewResults 에 따로 적는다.
        let mainResult = isInReview ? results[item.id] : nil

        let isCorrect = await judge(item, answer: answer)
        isGrading = false

        if isInReview {
            reviewResults[item.id] = isCorrect
            results[item.id] = mainResult
        }

        // O/X 는 판정이 나오는 즉시 버튼 색으로 보여 준다.
        if item.isTrueFalse { trueFalseVerdict = isCorrect }

        applyProgress(for: item, isCorrect: isCorrect)

        // O/X 는 맞혔든 틀렸든 전용 창 하나로 보여 준다.
        if item.isTrueFalse {
            await presentTrueFalseFeedback(for: item, answer: answer, isCorrect: isCorrect)
            try? modelContext.save()
            return
        }

        if isCorrect {
            await presentCorrectFeedback(for: item)
        } else {
            // 실제로 판단한 낱말이 다른 문항의 정답이면 그 문항의 재료로 설명한다.
            // O/X 는 고른 답이 「맞아요」라 진술문 안의 낱말을 대신 본다.
            //
            // 창을 띄우기 **전에** 찾아 둔다. 설명이 올 자리인지 알아야
            // 기다리는 표시를 띄울지 말지 정할 수 있다.
            let chosenQuestion = catalog.question(answering: item.judgedTerm(for: answer))

            // 창이 뜰 때 한 번 정한다. 뒤에 다시 만들 때도 같은 줄을 쓴다.
            let waitingLine = nextEncouragement()
            let shownAt = ContinuousClock.now

            feedback = IncorrectCommentary(
                id: item.id,
                selectedAnswer: answer,
                // 설명할 재료가 아예 없으면 기다릴 것도 없다. 바로 다음 걸음을 알려 준다.
                selectedNote: chosenQuestion == nil ? CommentaryPlaceholder.noteFailed : nil,
                waitingLine: waitingLine,
                expectsNote: chosenQuestion != nil,
                correctAnswer: item.question.displayAnswer,
                commentary: CommentaryPlaceholder.waiting)

            // 둘을 나란히 부른다. 하나씩 기다리면 대기가 두 배가 된다.
            async let commentary = commentaryWriter.explain(item.question, length: .full)
            async let note = commentaryWriter.explain(chosenQuestion, length: .oneLine)

            let written = await commentary
            let noted = await note

            let text = written.text
            let noteText = noted.text

            // 무엇을 시켰길래 실패했는지 남긴다. 안 남기면 다시 만들어 볼 수가 없다.
            saveFailures([written.failure, noted.failure])

            // 글이 너무 빨리 오면 응원 문구를 읽기도 전에 사라진다. 세 박자는 두고 바꾼다.
            await holdWaitingLine(shownAt: shownAt)

            // 실패해도 반드시 갱신한다. 안 그러면 「잠시만 같이 살펴봐요」가
            // 오지 않는 것을 계속 기다리며 반짝인다.
            if feedback != nil {
                // 설명을 기다리던 자리였다면, 못 만들었어도 그 자리를 문구로 채운다.
                let note = noteText
                    ?? (chosenQuestion != nil ? CommentaryPlaceholder.noteFailed : nil)

                feedback = IncorrectCommentary(
                    id: item.id,
                    selectedAnswer: answer,
                    selectedNote: note,
                    waitingLine: waitingLine,
                    // 더 기다릴 것이 없다. 맥동을 멈춘다.
                    expectsNote: false,
                    correctAnswer: item.question.displayAnswer,
                    commentary: text ?? CommentaryPlaceholder.failed)
            }
            
            saveObsRecord(for: item, isCorrect: isCorrect, explanation: text)
        }
        
        try? modelContext.save()
    }

    private func applyProgress(for item: QuizItem, isCorrect: Bool) {
        guard let progress = fetchProgressByID()[item.id] else {
            return
        }
        
        progress.countAttempt(correct: isCorrect)

        // 복습은 방금 정답을 본 직후라 실력보다 쉽게 맞힌다 — 맞힌 개수에는 세지만
        // 난이도 사다리는 움직이지 않는다 (11차 4-37).
        guard !isInReview else { return }

        if item.affectsProgress {
            progress.moveLadder(correct: isCorrect)
        } else {
            progress.nudgeLadder(correct: isCorrect)
        }
    }
    /// 한 문제를 판정한다. **규칙으로 먼저, 안 되면 뜻으로.**
    ///
    /// 선다·O/X 는 정답이 명확하므로 모델을 부르지 않는다 — 빠르고, 기기에
    /// 모델이 없어도 동작한다. 직접입력만 ``AnswerMatcher`` 를 거쳐 ``AnswerChecker`` 로 간다.
    private func judge(_ item: QuizItem, answer: String) async -> Bool {
        // ① 선다·O/X 는 정답이 명확하다
        if let byRule = RuleGrader.grade(item, userAnswer: answer) {
            results[item.id] = GradingResult(isCorrect: byRule, reason: "", basis: nil)
            return byRule
        }

        // ② 코드로 가릴 수 있는 것은 여기서 끝낸다
        switch AnswerMatcher.check(
            answer,
            against: item.question.answer,
            shape: item.question.shape,
            from: .typed) {
        case .correct(let basis):
            results[item.id] = GradingResult(isCorrect: true, reason: "", basis: basis.rawValue)
            return true
        case .wrong(let basis):
            results[item.id] = GradingResult(isCorrect: false, reason: "오타 입력", basis: basis.rawValue)
            return false

        case .needsModel:
            break
        }

        // ③ 애매한 것만 모델에게 넘긴다
        do {
            let check = try await answerChecker.check(
                            answer: answer,
                            correctAnswer: item.question.answer,
                            shape: item.question.shape)

            results[item.id] = GradingResult(
                isCorrect: check.isCorrect,
                reason: check.reason,
                basis: String(describing: check.basis))

            return check.isCorrect
        } catch {
            // 시한이 지난 것과 실패한 것을 같게 다룬다. 화면에는 조용히 오답.
            print("❌ 채점 실패:", error)
            results[item.id] = GradingResult(isCorrect: false, reason: "", basis: nil)
            return false
        }
    }

    // MARK: - 진척 다루기

    /// 문제집의 모든 문제에 진척이 있도록 보장하고, id → 진척 표를 돌려준다.
    private func ensureProgressExists() -> [Int: QuestionProgress] {
        var byID = fetchProgressByID()

        for question in catalog.questions where byID[question.id] == nil {
            let progress = QuestionProgress(questionID: question.id)
            modelContext.insert(progress)
            byID[question.id] = progress
        }
        return byID
    }

    /// 저장소에서 진척을 읽어 id 로 찾을 수 있게 만든다.
    private func fetchProgressByID() -> [Int: QuestionProgress] {
        modelContext.fetchKeyed(by: \.questionID)
    }

    // MARK: - 관찰 기록

    /// 지금 문항에서 잰 시간을 채점 때까지 들고 있는다.
    ///
    /// ``shownAt`` 이 `nil` 이면 지금을 기준으로 삼습니다 — 0초로 적으면
    /// "0초 만에 풀었다" 는 거짓말이 되고, 기록을 통째로 버리면 그 문항이 사라집니다.
    private func recordTiming(for item: QuizItem) {
        let asked = shownAt ?? .now
        let now = Date.now
        
        timingByID[item.id] = ObsTiming(
            askedAt: asked,
            secToFirstTouch: firstTouchAt.map { $0.timeIntervalSince(asked) },
            secToSubmit: now.timeIntervalSince(asked))
    }
 
    /// 이 문항에서 일어난 일을 ``ObsRecord`` 한 줄로 남긴다.
    ///
    /// - Important: **정오답이 정해진 뒤에만** 부를 수 있습니다.
    ///   시간을 못 잰 문항(``timingByID`` 에 없는 경우)은 **조용히 건너뜁니다** —
    ///   추측한 값으로 채우면 나중에 그 줄이 참인지 알 수 없게 됩니다.
    private func saveObsRecord(for item: QuizItem, isCorrect: Bool, explanation: String?) {
        // 복습 풀이는 남기지 않는다 — obs_record 에는 「복습이었나」를 가를 칸이 아직 없어,
        // 섞이면 본 풀이 통계(정답률·시간)가 흐려진다. 칸을 만든 뒤 남기기로 한다.
        guard !isInReview else { return }
        guard let timing = timingByID[item.id] else { return }
        
        modelContext.insert(
            ObsRecord(
                sessionID: sessionID,
                askedAt: timing.askedAt,
                questionID: item.id,
                secToFirstTouch: timing.secToFirstTouch,
                secToSubmit: timing.secToSubmit,
                isCorrect: isCorrect,
                modeRaw: item.mode.rawValue,
                wasFirstEver: wasFirstEverByID[item.id] ?? false,
                affectsProgress: item.affectsProgress,
                chosen: submittedAnswers[item.id],
                reason: reasonForLog(item.id),
                explanation: explanation,
                basis: results[item.id]?.basis,
                explanationSource: explanation == nil ? nil : "device"
            )
        )
    }

    /// 안 올라간 관찰 기록을 뒤에서 밀어 올린다.
    ///
    /// **기다리지 않습니다.** 네트워크가 느려도 화면은 그대로 돌아갑니다 —
    /// 어머니는 업로드가 있는 줄도 모르는 채로 다음 문제를 봅니다.
    private func uploadObservations() {
            Task {
                let uploader = ObsUploader(modelContext: modelContext)
                await uploader.uploadPending()
                await uploader.uploadPendingFailures()
            }
        }

    // MARK: - 뒷정리

    /// 답과 채점 결과를 처음 상태로 되돌린다.
    private func clearAnswers() {
        currentIndex = 0
        rawAnswer = ""
        needsAnswerHint = false
        submittedAnswers = [:]
        results = [:]
        feedback = nil
        correctFeedback = nil
        trueFalseFeedback = nil
        trueFalseVerdict = nil
        reviewItems = []
        reviewIndex = 0
        isShowingReviewIntro = false
        isInReview = false
        reviewResults = [:]

        // 관찰 기록도 회차 단위로 새로 시작한다.
        sessionID = UUID()
        shownAt = .now
        firstTouchAt = nil
        timingByID = [:]
    }

    /// 백그라운드로 묻는 대상을 분석해 캐시에 채운다. (화면을 막지 않는다)
    private func warmFocusCache() {
        focusWarmingTask?.cancel()

        let store = FocusStore(modelContext: modelContext)
        let questions = catalog.questions
        focusWarmingTask = Task {
            await store.analyzeMissing(in: questions)
        }
    }
    
    /// 채점 이유를 로그에 남길 모양으로 다듬는다.
    ///
    /// 두 가지를 합니다.
    ///
    /// - **빈 문자열은 `nil` 로.** ``RuleGrader`` 가 채점한 선다형·O/X 는 설명할
    ///   것이 없어 빈 문자열이 옵니다. 그대로 저장하면 «이유가 없는 것» 과
    ///   «이유를 안 남긴 것» 이 구별되지 않습니다.
    /// - **200자에서 자른다.** 모델이 길게 쏟아내면 서버의 길이 검사에 걸리는데,
    ///   그러면 그 한 줄 때문에 **회차 다섯 줄이 통째로 거부됩니다.** 배치로
    ///   한 번에 올리기 때문입니다.
    private func reasonForLog(_ questionID: Int) -> String? {
        let text = results[questionID]?.reason ?? ""
        guard !text.isEmpty else { return nil }

        return String(text.prefix(200))
    }
}
