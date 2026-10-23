//
//  QuizSession.swift
//  KCT
//
//  역할 : 한 회차(8칸)의 상태를 들고, 시작·제출·채점을 결정한다
//  요점 : 화면은 "무엇을 그릴까"만 묻고, "무엇이 맞나"는 전부 여기서 답한다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuizSession                 회차의 주인. 화면이 아니라 진행을 소유한다
//  ├─ items                    이번 회차 출제 항목 (SessionBuilder 가 만든 것).
//  │                           **연결 문제는 여기 안 들어 있다** — 아래 참고
//  ├─ matchingSet/matchingSlot 이번 회차의 연결 문제와 그것이 놓인 칸 번호
//  ├─ slotCount                회차의 칸 수 = items.count + (연결 문제 있으면 1)
//  ├─ isMatchingSlot           지금 칸이 연결 문제인가 (QuizView 가 화면을 고르는 기준)
//  ├─ voiceSlot / placeVoiceItem()  7번째 칸을 음성 입력 문제로 — 가장 익숙한 문항을 데려와
//  │                           직접입력(.typing)을 말로 받게 한다 (QuizItem.isVoice)
//  ├─ completeMatchingSlot()   연결 문제를 다 맞혔다 → 다음 칸으로
//  ├─ currentIndex             몇 번째 **칸**인가 (0부터). items 의 자리가 아니다
//  ├─ userAnswer               지금 고르거나 입력한 답
//  │                           └ 값이 들어오면 안내를 스스로 거둔다 (setter 안에서)
//  ├─ results                  채점 결과 (문제 id → 결과)
//  ├─ isGrading                채점 중인가 (화면용 — 직접입력의 「채점 중」 표시)
//  ├─ hasSubmittedCurrent      이 문항의 답을 이미 냈나 — 이중 제출 문지기 (2차 리팩토링)
//  ├─ encouragements           이번 회차의 응원 문구 (뒤에서 만들어 둔다)
//  ├─ isWrappingUp             회차를 마무리하는 3초인가
//  ├─ needsAnswerHint          "답을 고르세요" 안내를 띄울까
//  ├─ obs                      관찰 기록 재료 (ObsSessionLog — 회차 번호·뜬 시각·첫 손댐·잰 시간·처음 보는 문항)
//  │                           └ wasFirstEverByID 는 start() 에서 채점 전에 미리 읽어 둔다
//  ├─ start()                  회차 구성 — 진척 확보 → 출제 계획 → 초기화 → 캐시 워밍
//  ├─ leave()                  화면을 떠날 때 — 아무도 안 볼 작업(해설 미리 만들기·응원·분석·3초 박자)만 멈춘다
//  ├─ submitCurrent()          답 기록 → 다음 문제. 마지막이면 채점 시작
//  ├─ eraseAllProgress()       학습 기록 전체 삭제 후 새 회차
//  ├─ gradeCurrent()           한 문제를 채점하고 진척에 반영
//  ├─ judge()                  ① 규칙 ② 코드 ③ 모델 — 세 층으로 한 문제를 판정
//  ├─ nextEncouragement()      응원 문구를 하나 꺼낸다 (없으면 앱에 박힌 것)
//  ├─ holdWaitingLine()        응원 문구를 적어도 3초는 보여 준다
//  ├─ saveFailures()           모델이 실패한 기록을 저장소에 넣고 바로 저장한다 (QuestionScreen 도 부른다)
//  ├─ uploadFailuresNow()      회차 경계를 안 기다리고 실패 기록을 바로 올려 본다 (QuestionScreen 도 부른다)
//  ├─ wrapUp()                 회차 끝의 3초 박자
//  ├─ saveObsRecord()          정오답이 정해진 뒤 obs 가 만든 ObsRecord 한 줄을 저장소에 넣는다
//  ├─ presented                지금 떠 있는 해설 창 (PresentedCommentary — 셋 중 하나만, nil 이면 없음)
//  │  ├─ feedback              └ 오답 해설 창 내용 (presented 에서 꺼내 읽기만)
//  │  ├─ correctFeedback       └ 정답 해설 창 내용
//  │  └─ trueFalseFeedback     └ O/X 해설 창 내용 (맞힘·틀림 공용)
//  ├─ review                   복습 한 바퀴 (ReviewRound, 11차 4-37). 화면은 아래 이름으로 읽는다
//  │  ├─ reviewItems / reviewIndex  복습할 문항(본 풀이에서 틀린 것) / 지금 자리
//  │  ├─ isShowingReviewIntro  복습 시작 화면을 띄울 차례인가
//  │  ├─ isInReview            복습 중인가 — current 가 복습 문항을 준다
//  │  └─ reviewOutcome(for:)   문항 id → 복습에서 맞혔나 (본 풀이 results 와 따로)
//  ├─ startReview()            복습 시작 화면의 버튼 → 첫 복습 문제
//  ├─ immediateVerdict         O/X·2지선다 판정 — 누른 버튼을 녹색·붉은색으로 칠한다 (채점 전 nil)
//  ├─ isShowingCommentary      셋 중 하나라도 떠 있는가 (뒤 화면의 손가락을 막는 데 쓴다)
//  ├─ explanations             정답 해설 미리 만들기 (ExplanationPrefetcher) — 문제가 뜨는 즉시 시작
//  ├─ explanation(for:)        미리 만들어 둔 정답 해설을 기다린다 (없으면 그때 시작)
//  ├─ presentCorrectFeedback() 정답 해설 창을 띄우고 explanation(for:) 로 채운다
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
//     CommentaryPlaceholder · PresentedCommentary)은 이 파일에 없다 — Grading/Commentary.swift 로 옮겼다.
//     창을 그리는 화면이 회차 전체를 아는 타입을 거치지 않게 하려는 것이다.
//  ⚠️ 2차 리팩토링(2026-10-23)에서 덩어리 셋을 제 파일로 뺐다 — 복습(Session/ReviewRound.swift),
//     관찰 기록 재료(Observation/ObsSessionLog.swift), 해설 미리 만들기(Grading/ExplanationPrefetcher.swift).
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
//                RuleGrader·AnswerMatcher·AnswerChecker(채점), QuestionProgress(진척), FocusStore(하이라이트),
//                ReviewRound(복습) · ObsSessionLog(관찰 기록 재료) · ExplanationPrefetcher(해설 미리 만들기)
//  건드리지 않는 것 : 낭독과 화면 그리기 — 소리는 QuizView 가, 모양은 각 Screen 이 맡는다
//

import OSLog   // Log.* (진단 기록) — MemberImportVisibility 라 쓰는 파일마다 가져온다
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

    /// 문제가 뜨는 순간 정답 해설(`.full`)을 미리 만들기 시작해 두는 곳.
    ///
    /// 맞혔든 틀렸든 "이 답이 왜 맞는지"는 문제가 뜨는 순간 이미 정해진 사실이라 채점을 기다릴 이유가 없다 —
    /// 문제가 화면에 뜨자마자(``start()``·``moveToNextQuestion()``) 시작해 둔다. (2차 리팩토링에서 제 파일로)
    private let explanations: ExplanationPrefetcher

    /// 이번 회차의 응원 문구를 만드는 작업. 새 회차·나가기에서 멈춘다.
    private var encouragementTask: Task<Void, Never>?

    /// 회차 끝 3초 박자 작업. 새 회차·나가기에서 멈춘다.
    private var wrapUpTask: Task<Void, Never>?

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
    /// 격려용 쉬운 2지선다로 쓰는 자리라 비켜 둔다. 7번째 칸은 음성 입력 문제
    /// 자리(``voiceSlot``)라 역시 비켜 둔다.
    private static let matchingSlotCandidates = [2, 3, 4]

    /// 음성 입력 문제가 오는 칸 — 8칸 중 7번째(0부터 세면 6).
    ///
    /// 마지막 칸(격려용 2지선다) 바로 앞이다. 가장 어려운 입력을 끝에서 두 번째에 두고,
    /// 쉬운 문제로 회차를 닫는다.
    private static let voiceSlot = 6

    // MARK: - 상태

    /// 이번 회차의 출제 항목. ``start()`` 가 채운다.
    private(set) var items: [QuizItem] = []

    /// 현재 몇 번째 문제인지 (0부터). ``items`` 의 개수와 같아지면 회차가 끝난 것이다.
    private(set) var currentIndex = 0

    /// 채점 결과 (문제 id → 결과).
    private(set) var results: [Int: GradingResult] = [:]

    /// 채점이 진행 중인지. **화면용** — 직접입력에서 「채점 중」 표시를 띄우는 데만 쓴다.
    private(set) var isGrading = false

    /// 이 문항의 답을 이미 냈는가. **이중 제출을 막는 문지기.**
    ///
    /// ``isGrading`` 은 직접입력에서만, 그것도 채점 `Task` 가 실제로 돈 뒤에야 켜져서
    /// 선다·O/X·2지선다를 빠르게 두 번 누르면 같은 문항이 두 번 채점될 틈이 있었다(2차 리팩토링에서 찾음).
    /// 이 깃발은 `Task` 를 만들기 **전에** 모든 방식에서 켜지고, 다음 문항으로 넘어갈 때(``moveToNextQuestion()``) 꺼진다.
    private var hasSubmittedCurrent = false

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
                obs.touch()
            }
        }
    }

    private var rawAnswer = ""

    /// 제출된 답 기록 (문제 id → 답). 채점할 때 한 번에 꺼내 쓴다.
    private var submittedAnswers: [Int: String] = [:]

    /// 백그라운드 하이라이트 분석 작업. 회차가 바뀌면 취소한다.
    private var focusWarmingTask: Task<Void, Never>?

    // MARK: - 관찰 기록용 상태

    /// 이번 회차의 관찰 기록 재료 — 회차 번호 · 문제가 뜬 시각 · 첫 손댐 · 잰 시간 · 처음 보는 문항이었나.
    /// (2차 리팩토링에서 ``ObsSessionLog`` 로 묶었다. 저장과 업로드는 여기 남아 있다)
    private var obs = ObsSessionLog()

    /// 지금 떠 있는 해설 창. `nil` 이면 **창이 없다.**
    ///
    /// 별도의 `Bool` 을 두지 않은 이유 — **값이 있으면 떠 있는 것**입니다.
    /// 예전에는 창마다 옵셔널이 하나씩(셋) 있어서 「한 번에 하나만」을 **호출 순서**가 지켰습니다.
    /// 열거형 하나로 두면 둘이 동시에 뜬 상태를 **만들 수가 없습니다.** (2차 리팩토링)
    ///
    /// `private(set)` 인 이유 — 화면은 **읽어서 그리기만** 하고, 넣고 비우는 것은 ``QuizSession`` 만 합니다.
    private(set) var presented: PresentedCommentary?

    /// 지금 띄워야 할 **오답 해설** 창의 내용. ``QuizView`` 의 `.sheet(item:)` 이 읽는다.
    var feedback: IncorrectCommentary? {
        if case .incorrect(let content) = presented { content } else { nil }
    }

    /// 지금 띄워야 할 **정답 해설** 창의 내용.
    var correctFeedback: CorrectCommentary? {
        if case .correct(let content) = presented { content } else { nil }
    }

    /// 지금 띄워야 할 **O/X 해설** 창의 내용. 맞혔든 틀렸든 O/X 는 이 창 하나를 쓴다.
    var trueFalseFeedback: TrueFalseCommentary? {
        if case .trueFalse(let content) = presented { content } else { nil }
    }

    // MARK: - 복습 (11차 4-37)
    //
    // 회차의 모든 칸을 지나면, 결과 화면 전에 **이번 회차에 틀린 문제만** 한 번 더 묻는다.
    // 흐름: 마지막 칸 → 복습 시작 화면(isShowingReviewIntro) → 복습 문제들(isInReview)
    //       → 3초 박자(isWrappingUp) → 결과 화면. 틀린 게 없으면 복습 없이 곧바로 결과로 간다.

    /// 복습 한 바퀴의 상태 (2차 리팩토링에서 ``ReviewRound`` 로 묶었다). 화면은 아래 이름들로 읽는다.
    private(set) var review = ReviewRound()

    /// 복습할 문항 — 이번 회차 본 풀이에서 틀린 것들.
    var reviewItems: [QuizItem] { review.items }

    /// 지금 복습 중인 자리.
    var reviewIndex: Int { review.index }

    /// 복습 시작 화면을 띄울 차례인가.
    var isShowingReviewIntro: Bool { review.isShowingIntro }

    /// 복습 문제를 푸는 중인가. 이 동안 ``current`` 는 복습 문항을 돌려준다.
    var isInReview: Bool { review.isActive }

    /// 복습에서 맞혔는지. 복습하지 않은 문항이면 `nil`.
    func reviewOutcome(for questionID: Int) -> Bool? { review.outcomes[questionID] }

    /// 복습 시작 화면의 버튼. 첫 복습 문제로 들어간다.
    func startReview() {
        guard review.begin() else { return }
        rawAnswer = ""
        obs.markShown()
    }

    /// 지금 문항의 판정. 누른 보기를 녹색(맞음)·붉은색(틀림)으로 칠하는 데 쓴다.
    /// 아직 채점 전이면 `nil`.
    ///
    /// O/X 는 **누르는 순간 채점**된다 — 버튼 색이 곧 결과라, 해설 창이 올라온 뒤에도
    /// 창 위로 보이는 버튼에서 「내가 뭘 골랐는지」가 남는다(11차 4-30). 13차 후속부터
    /// **2지선다도 같은 방식**이라(누르면 곧장 채점 → 해설 창) 이름을 O/X 전용에서
    /// 일반화했다. 4지선다는 다른 흐름(오답은 조용히 소거, 정답을 찾아야 채점)이라
    /// 이 값을 쓰지 않는다.
    private(set) var immediateVerdict: Bool?

    init(
        catalog: QuestionCatalog,
        modelContext: ModelContext,
        matchingCatalog: MatchingSetCatalog? = nil,
        size: Int = 8
    ) {
        self.catalog = catalog
        self.modelContext = modelContext
        self.matchingCatalog = matchingCatalog
        self.size = size
        self.explanations = ExplanationPrefetcher(writer: commentaryWriter)
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
            return review.current
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

    /// 7번째 칸(``voiceSlot``)을 음성 입력 문제로 만든다. ``start()`` 가 부른다.
    ///
    /// ① 가운데 칸들(첫·마지막 격려 칸 제외) 중 **사다리가 가장 높이 올라간 문항**을
    ///    음성 칸 자리로 데려온다 — 말로 답하는 것이 가장 어려운 입력이라, 가장 익숙한
    ///    문항을 고른다. 처음 보는 낱말을 소리로 떠올리기는 어렵다.
    /// ② 그 문항을 직접입력(`.typing`)으로 다시 만들고 `isVoice` 를 켠다.
    /// ③ `affectsProgress: false` — 이 칸은 사다리 칸과 상관없이 늘 직접입력으로
    ///    묻는다. 그래서 격려 칸처럼 사다리를 크게 움직이지 않고 살짝만 민다(nudgeLadder).
    private func placeVoiceItem() {
        let voiceIndex = itemIndex(for: Self.voiceSlot)

        // 문제집이 작아 칸이 모자라면 음성 칸 없이 간다. 첫 칸·마지막 칸은 격려 칸이라 안 건드린다.
        guard items.count >= 3, voiceIndex > 0, voiceIndex < items.count - 1 else { return }

        let middle = 1..<(items.count - 1)
        let mostFamiliar = middle.max { items[$0].mode < items[$1].mode } ?? voiceIndex
        items.swapAt(mostFamiliar, voiceIndex)

        let original = items[voiceIndex]
        var voiceItem = QuizItem.make(
            original.question,
            mode: .typing,
            answerPool: [],               // 직접입력은 보기가 없어 오답 후보가 필요 없다
            affectsProgress: false,
            focus: original.focus)
        voiceItem.isVoice = true
        items[voiceIndex] = voiceItem
    }

    /// 해설 창(오답·정답)이 떠 있는가.
    ///
    /// 창이 떠 있는 동안은 뒤 문제 화면의 답을 못 바꾸게 막는 데 쓴다
    /// (``QuestionScreen`` 의 `allowsHitTesting`). 두 창 모두 배경을 어둡게 하지
    /// 않고 뒤가 그대로 비치도록 열어 두었는데(`presentationBackgroundInteraction`),
    /// 그러면 창이 덮지 않은 위쪽의 보기 버튼이 **그대로 눌린다.** 이미 채점이
    /// 끝난 뒤라 그때 답을 바꿔도 결과는 안 바뀌지만, 눌리는데 아무 일도 안
    /// 일어나면 고장으로 보인다.
    var isShowingCommentary: Bool { presented != nil }

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
        obs.wasFirstEverByID = progressByID.mapValues { !$0.isIntroduced }

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

        // 7번째 칸을 음성 입력 문제로 만든다. 연결 문제 칸이 정해진 **뒤에** 해야 한다 —
        // 칸 번호 → items 자리 계산(itemIndex)이 연결 문제 칸에 따라 달라진다.
        placeVoiceItem()

        clearAnswers()
        wrapUpTask?.cancel()
        isWrappingUp = false

        // 이전 회차에서 만들던 해설이 남아 있으면 멈추고 비운다 — 아무도 그 결과를 기다리지 않는다.
        explanations.cancelAll()

        // 첫 문제가 뜨는 순간부터 정답 해설을 미리 만들기 시작한다 — 채점을 기다리지 않는다.
        if let first = current {
            explanations.start(for: first.question)
        }

        // 어머니가 문제를 푸는 동안, 아직 분석하지 않은 문제를 뒤에서 채워 둔다.
        warmFocusCache()
        
        // 첫 직접입력이 나오기 전에 모델을 깨워 둔다.
        answerChecker.prepare()

        // 어머니가 첫 문제를 읽는 동안 이번 회차의 응원 문구를 만들어 둔다.
        // 늦게 와도 상관없다 — 그 전에 틀리면 앱에 박힌 것을 쓴다.
        encouragements = []
        encouragementTask?.cancel()
        encouragementTask = Task { encouragements = await encouragementWriter.write() }

        // 지난번에 못 올린 기록이 있으면 여기서 따라잡는다.
        uploadObservations()
    }

    /// 회차 화면을 떠날 때 부른다(``QuizView`` 의 `onDisappear`). **아무도 결과를 안 볼 작업만** 멈춘다.
    ///
    /// - Important: 채점(`gradeCurrent`)은 멈추지 **않는다.** 채점 도중 멈추면 모델 판정이 실패로 끝나
    ///   맞힌 답이 오답으로 사다리에 적힐 수 있다. 관찰 기록 업로드도 끝까지 간다 — 그게 맞는 일이다.
    func leave() {
        explanations.cancelAll()
        encouragementTask?.cancel()
        focusWarmingTask?.cancel()
        wrapUpTask?.cancel()
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
        guard !isGrading, !hasSubmittedCurrent else { return }
        
        let trimmed = rawAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 복습 풀이는 본 풀이의 답·시간 기록을 덮어쓰지 않는다 (관찰 기록은 본 풀이만 남긴다).
        if !isInReview {
            submittedAnswers[item.id] = trimmed
        }

        // 시간을 여기서 잰다 — 화면이 바뀌기 전이 마지막 기회다.
        if !isInReview {
            obs.recordTiming(for: item.id)
        }

        // 깃발은 Task 를 만들기 **전에** — Task 가 실제로 돌기까지 한 틱이 비는데, 그 사이 두 번째 탭을 막는다.
        hasSubmittedCurrent = true
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
    /// - Important: 뜬 시각(``ObsSessionLog/markShown()``)을 ``currentIndex`` **뒤에** 찍습니다.
    ///   그래야 「다음 문제가 뜬 시각」이 됩니다.
    private func moveToNextQuestion() {
        rawAnswer = ""
        needsAnswerHint = false
        immediateVerdict = nil
        hasSubmittedCurrent = false

        // 복습 중이면 복습 안에서 다음으로. 다 풀면 결과 화면으로 간다.
        if isInReview {
            obs.markShown()

            if !review.advance() {
                uploadObservations()
                wrapUp()
            } else if let next = current {
                // 복습 문항은 본 풀이에서 이미 다 만들어져 있다 — 있으면 그걸 그대로
                // 쓰고, 없으면(안전망) 여기서 새로 시작해 둔다.
                explanations.start(for: next.question)
            }
            return
        }

        currentIndex += 1

        obs.markShown()

        // 다음 문제가 뜨는 순간부터 정답 해설을 미리 만들기 시작한다. 연결 문제 칸이면
        // current 가 nil 이라 아무 일도 일어나지 않는다 — 그 다음 실제 문항 차례에서 시작된다.
        if let next = current {
            explanations.start(for: next.question)
        }

        if isFinished {
            // 틀린 문제가 있으면 결과 전에 복습부터. 회차에 나온 순서 그대로 다시 묻는다.
            let missed = items.filter { results[$0.id]?.isCorrect == false }
            if review.offer(missed) {
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

        wrapUpTask?.cancel()
        wrapUpTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            // 새 회차가 이 박자를 멈췄으면 손대지 않는다 — start() 가 이미 false 로 두었다.
            guard !Task.isCancelled else { return }
            isWrappingUp = false
        }
    }
    
    func dismissFeedback() {
        guard feedback != nil else { return }
        presented = nil
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
        presented = nil
        moveToNextQuestion()
    }

    /// 정답 해설 창의 「다음 문제」. (``dismissFeedback()`` 과 같은 이유)
    func dismissCorrectFeedback() {
        guard correctFeedback != nil else { return }
        presented = nil
        moveToNextQuestion()
    }

    /// 답 없이 다음을 누른 경우 — 안내를 띄우라고 표시한다.
    ///
    /// 버튼을 아예 못 누르게 막지 않는 이유: 눌러도 아무 일이 없으면 어르신은
    /// 앱이 고장 났다고 생각한다. 눌리게 두고 무엇이 필요한지 알려 주는 편이 낫다.
    func requestAnswerHint() {
        needsAnswerHint = true
    }

    // MARK: - 정답 해설

    /// 미리 만들어 둔 정답 해설을 기다린다. (``ExplanationPrefetcher`` 가 들고 있다)
    ///
    /// 정답이든 오답이든, O/X 든 선다든 — 이 문항의 "이 답이 왜 맞는지"는 모두 같은 글이므로 같은 자리에서 가져다 쓴다.
    private func explanation(for item: QuizItem) async -> Writing {
        await explanations.explanation(for: item.question)
    }

    /// 맞혔을 때 정답 해설 창을 띄운다.
    ///
    /// 오답을 만났을 때 정답을 설명하던 바로 그 재료(``explanation(for:)``, `.full`)를
    /// 그대로 쓴다 — "이 답이 왜 맞는지"는 이번에 맞혔든 틀렸든 같은 사실에서 나오는
    /// 같은 문장이기 때문이다. 이제는 채점 시점이 아니라 **문제가 뜬 순간부터** 이미
    /// 만들어지고 있던 것을 기다리기만 한다.
    ///
    /// - Important: 최소 대기(``holdWaitingLine(shownAt:)``)를 **일부러 두지 않는다.**
    ///   그 대기는 "자리표시 문구가 뜨자마자 바뀌어 깜빡이는" 것을 막으려던 것인데,
    ///   ``CorrectAnswerSheet`` 는 접힌 채로 뜨고 「정답 해설 보기」를 눌러야 펼쳐지므로
    ///   자리표시 문구 자체를 어머니가 볼 일이 없다 — 깜빡일 것이 없다. 여기서 대기를
    ///   두면 오히려 미리 다 만들어 둔 해설(``ExplanationPrefetcher``)이 있어도
    ///   그 시간만큼 버튼이 계속 로딩으로 보이는, 정반대의 문제가 생긴다.
    private func presentCorrectFeedback(for item: QuizItem) async {
        presented = .correct(CorrectCommentary(
            id: item.id,
            correctAnswer: item.question.displayAnswer,
            commentary: CommentaryPlaceholder.waiting))

        let written = await explanation(for: item)
        saveFailures([written.failure])

        let text = written.text

        // 실패해도 반드시 갱신한다 — 안 그러면 자리표시 문구가 오지 않는 것을
        // 계속 기다리며 반짝인다.
        if correctFeedback != nil {
            presented = .correct(CorrectCommentary(
                id: item.id,
                correctAnswer: item.question.displayAnswer,
                commentary: text ?? CommentaryPlaceholder.failed))
        }

        saveObsRecord(for: item, isCorrect: true, explanation: text)
    }

    /// O/X 를 누른 뒤 창이 올라오기까지의 한 박자 — 버튼 색이 바뀐 것을 먼저 보게 한다.
    private static let trueFalseColorBeat: Duration = .milliseconds(600)

    /// O/X 해설 창을 띄운다.
    ///
    /// 바른 문장은 **코드가** 만든다(``Question/correctedStatementParts()``) — 답이 하나로
    /// 정해지는 일이라 모델에게 맡기지 않는다. 아래 해설(``explanation(for:)``, `.full`)은
    /// 이미 문제가 뜰 때부터 뒤에서 만들어지고 있던 것을 기다리기만 한다.
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

        async let written = explanation(for: item)

        try? await Task.sleep(for: Self.trueFalseColorBeat)

        presented = .trueFalse(content(CommentaryPlaceholder.waiting))
        let shownAt = ContinuousClock.now

        let result = await written
        saveFailures([result.failure])

        // 글이 너무 빨리 오면 창이 뜨자마자 바뀌어 깜빡여 보인다. 다른 창과 같은 최소 대기.
        await holdWaitingLine(shownAt: shownAt)

        // 실패해도 반드시 갱신한다 — 안 그러면 자리표시 문구가 계속 반짝인다.
        if trueFalseFeedback != nil {
            presented = .trueFalse(content(result.text ?? CommentaryPlaceholder.failed))
        }

        saveObsRecord(for: item, isCorrect: isCorrect, explanation: result.text)
    }

    // MARK: - 채점
    private func gradeCurrent(_ item: QuizItem, answer: String) async {
        // 직접입력만 모델이 판정해 시간이 걸린다. 선다·O/X 는 곧바로 다음 문제로 이어진다.
        if item.mode == .typing { isGrading = true }

        // 복습 풀이는 본 풀이 결과를 덮어쓰지 않는다 — judge 가 results 에 적으므로
        // 미리 들고 있다가 되돌리고, 복습 결과는 review(ReviewRound) 에 따로 적는다.
        let mainResult = isInReview ? results[item.id] : nil

        let isCorrect = await judge(item, answer: answer)
        isGrading = false

        if isInReview {
            review.record(item.id, correct: isCorrect)
            results[item.id] = mainResult
        }

        // O/X · 2지선다는 판정이 나오는 즉시 버튼 색으로 보여 준다(13차 후속 —
        // 2지선다도 O/X처럼 누르는 순간 채점되므로 같은 값을 쓴다). 4지선다는
        // 다른 흐름(QuestionScreen 이 오답을 그 자리에서 소거)이라 여기 안 온다 —
        // 오답을 눌러도 submitCurrent() 자체가 안 불린다.
        if item.isTrueFalse || item.mode == .binaryChoice { immediateVerdict = isCorrect }

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

            presented = .incorrect(IncorrectCommentary(
                id: item.id,
                selectedAnswer: answer,
                // 설명할 재료가 아예 없으면 기다릴 것도 없다. 바로 다음 걸음을 알려 준다.
                selectedNote: chosenQuestion == nil ? CommentaryPlaceholder.noteFailed : nil,
                waitingLine: waitingLine,
                expectsNote: chosenQuestion != nil,
                correctAnswer: item.question.displayAnswer,
                commentary: CommentaryPlaceholder.waiting))

            // 둘을 나란히 부른다. 하나씩 기다리면 대기가 두 배가 된다.
            async let commentary = explanation(for: item)
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

                presented = .incorrect(IncorrectCommentary(
                    id: item.id,
                    selectedAnswer: answer,
                    selectedNote: note,
                    waitingLine: waitingLine,
                    // 더 기다릴 것이 없다. 맥동을 멈춘다.
                    expectsNote: false,
                    correctAnswer: item.question.displayAnswer,
                    commentary: text ?? CommentaryPlaceholder.failed))
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
            from: item.isVoice ? .voice : .typed) {
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
            Log.grading.error("채점 실패 q\(item.id): \(String(describing: error), privacy: .public)")
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

    /// 이 문항에서 일어난 일을 ``ObsRecord`` 한 줄로 저장소에 넣는다. 줄을 만드는 일은 ``ObsSessionLog/record(for:isCorrect:chosen:reason:explanation:basis:)``.
    ///
    /// - Important: **정오답이 정해진 뒤에만** 부를 수 있습니다. 시간을 못 잰 문항은 **조용히 건너뜁니다.**
    private func saveObsRecord(for item: QuizItem, isCorrect: Bool, explanation: String?) {
        // 복습 풀이는 남기지 않는다 — obs_record 에는 「복습이었나」를 가를 칸이 아직 없어,
        // 섞이면 본 풀이 통계(정답률·시간)가 흐려진다. 칸을 만든 뒤 남기기로 한다.
        guard !isInReview else { return }
        guard let record = obs.record(
            for: item,
            isCorrect: isCorrect,
            chosen: submittedAnswers[item.id],
            reason: reasonForLog(item.id),
            explanation: explanation,
            basis: results[item.id]?.basis
        ) else { return }

        modelContext.insert(record)
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
        presented = nil
        immediateVerdict = nil
        hasSubmittedCurrent = false
        review = ReviewRound()

        // 관찰 기록도 회차 단위로 새로 시작한다.
        obs.startNewSession()
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
