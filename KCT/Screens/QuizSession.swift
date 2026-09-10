//
//  QuizSession.swift
//  KCT
//
//  역할 : 한 회차(5문제)의 상태를 들고, 시작·제출·채점을 결정한다
//  요점 : 화면은 "무엇을 그릴까"만 묻고, "무엇이 맞나"는 전부 여기서 답한다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuizSession                 회차의 주인. 화면이 아니라 진행을 소유한다
//  ├─ items                    이번 회차 출제 항목 (SessionBuilder 가 만든 것)
//  ├─ currentIndex             몇 번째 문제를 풀고 있나 (0부터)
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
//  ├─ saveFailures()           모델이 실패한 기록을 저장소에 넣는다
//  ├─ wrapUp()                 회차 끝의 3초 박자
//  ├─ recordTiming()           지금 문항에서 잰 시간을 채점 때까지 보관
//  ├─ saveObsRecord()          정오답이 정해진 뒤 ObsRecord 한 줄을 남긴다
//  ├─ IncorrectCommentary      틀렸을 때 띄울 창의 내용 (고른 답 · 정답 · 해설)
//  ├─ feedback                 지금 띄워야 할 창. nil 이면 창이 없다
//  ├─ moveToNextQuestion()     다음 문제로 넘어간다 — 맞혔을 때와 창을 닫을 때 둘 다
//  ├─ reasonForLog()           채점 이유를 로그에 남길 모양으로 다듬는다
//  └─ uploadObservations()     안 올라간 기록을 뒤에서 밀어 올린다 (기다리지 않는다)
//
//  ── 흐름 ──────────────────────────────────────────────
//  화면 진입
//    → start()
//        → 진척이 없는 문제에 QuestionProgress 생성
//        → SessionBuilder.build() 로 출제 계획을 받아 items 에 보관
//        → FocusStore 로 백그라운드 캐시 워밍 (기다리지 않는다)
//    → 사용자가 답 선택 → userAnswer 에 저장 (안내 자동 해제)
//    → submitCurrent() → 답 기록 → currentIndex += 1
//    → gradeCurrent() : 문제마다 그 자리에서 채점
//        → judge() : ① RuleGrader(선다·O/X) ② AnswerMatcher(코드) ③ AnswerChecker(모델)
//        → QuestionProgress.countAttempt() 로 모든 문항을 센다 (격려용 포함)
//        → 격려용 슬롯이면 nudgeLadder() 로 2지선다 → O/X 한 칸만
//        → 아니면 moveLadder() 로 사다리를 올리거나 내린다
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

    /// 뜻으로 채점하는 쪽. 직접입력에만 쓴다. (선다·O/X 는 ``RuleGrader`` 가 즉시 처리)
    private let answerChecker = AnswerChecker()
    private let commentaryWriter = CommentaryWriter()
    private let encouragementWriter = EncouragementWriter()

    /// 이번 회차에 쓸 응원 문구. 회차를 시작할 때 뒤에서 만들어 채운다.
    ///
    /// 비어 있으면 ``EncouragementWriter/fallback`` 에서 뽑습니다 —
    /// 아직 안 만들어졌거나 모델이 실패한 경우입니다. **어느 쪽이든 화면은 기다리지 않습니다.**
    private var encouragements: [String] = []

    /// 한 회차에 낼 문제 수.
    let size: Int

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
    
    /// 틀렸을 때 띄우는 창의 내용.
    ///
    /// 창에는 세 덩어리가 있고, 이 타입의 세 값과 하나씩 대응합니다 —
    /// 「고르신 것」 · 「이 문제의 답」 · 해설.
    ///
    /// - Note: `private` 이 아닌 이유 — 창을 그리는 화면이 이 타입을 알아야 합니다.
    ///   ``ObsTiming`` 은 화면이 볼 일이 없어서 `private` 입니다.
    ///
    /// - Note: `commentary` 가 옵셔널이 아닌 이유 — 모델이 해설을 못 만들어도
    ///   **창은 뜨고 정답은 보여 줍니다.** 그때는 대체 문구가 들어갑니다.
    ///   다만 **로그에는 `nil` 로 남깁니다** — 그래야 실패한 횟수를 셀 수 있습니다.
    ///   화면에 보여줄 값과 로그에 남길 값은 달라도 됩니다(``reasonForLog(_:)`` 와 같은 방식).
    struct IncorrectCommentary {
        /// 해설이 아직 안왔을 때 창에 넣어두는 문구.
        static let placeholder = "잠시만 같이 살펴봐요."

        /// 해설을 끝내 못 만들었을 때의 문구.
        ///
        /// 기다리라는 말을 계속 두면 **오지 않는 것을 기다리게** 됩니다.
        /// 어르신에게 「모델 오류」는 아무 뜻이 없으므로 **다음에 할 일**을 알려 줍니다.
        static let failed = "다음 문제로 이동해주세요."

        /// **고른 답 설명**이 없을 때의 문구.
        ///
        /// 두 경우에 나옵니다 — ① 만들다 실패했을 때 ② 「고죠선」 같은 오타라
        /// 어느 문항의 정답도 아니어서 **설명할 재료가 아예 없을 때.**
        ///
        /// 줄을 비워 두면 창이 갑자기 짧아져 「뭔가 사라졌나」 싶어집니다.
        /// 자리를 지키면서 **다음에 할 일**로 이어 줍니다.
        static let noteFailed = "정답을 살펴볼까요?"
        
        let selectedAnswer: String

        /// 고른 답이 무엇인지 알려 주는 한 문장. 아직 안 왔거나 재료가 없으면 `nil`.
        let selectedNote: String?

        /// 기다리는 동안 보여줄 응원 한 줄. 창이 만들어질 때 정해진다.
        let waitingLine: String

        /// 고른 답 설명이 **올 예정인가.**
        ///
        /// `selectedNote` 가 `nil` 인 이유가 둘이라 깃발이 따로 필요합니다 —
        /// 「아직 안 왔다」와 「어느 문항의 정답도 아니라 설명할 재료가 없다」.
        /// 앞이면 자리를 비워 두고 기다리게 하고, 뒤면 그 줄을 아예 안 그립니다.
        let expectsNote: Bool

        let correctAnswer: String
        let commentary: String
        
        /// 기다림이 끝났는가. **성공이든 실패든 더 기다릴 것이 없으면 참**입니다.
        ///
        /// 화면은 이 값으로 맥동을 멈춥니다. 「도착했나」가 아니라 「더 기다릴 것이 있나」로
        /// 두는 이유 — 실패했을 때도 반짝임은 멈춰야 합니다.
        var isReady: Bool { commentary != Self.placeholder }
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

    init(catalog: QuestionCatalog, modelContext: ModelContext, size: Int = 5) {
        self.catalog = catalog
        self.modelContext = modelContext
        self.size = size
    }

    // MARK: - 화면이 물어보는 것

    /// 아직 회차가 구성되지 않았는지.
    var isEmpty: Bool { items.isEmpty }

    /// 모든 문제를 다 풀었는지.
    var isFinished: Bool { !items.isEmpty && currentIndex >= items.count }

    /// 지금 풀고 있는 문제. 다 풀었으면 `nil`.
    var current: QuizItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    /// 답을 고르거나 입력했는지.
    var hasAnswer: Bool {
        !rawAnswer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 지금이 마지막 문제인지. (하단 버튼 문구를 "제출" 로 바꾸는 데 쓴다)
    var isLastQuestion: Bool { currentIndex == items.count - 1 }

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

        let store = FocusStore(modelContext: modelContext)
        items = SessionBuilder(catalog: catalog).build(
            size: size,
            progressByID: progressByID,
            focusByID: store.focuses(for: catalog.questions)
        )

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

        submittedAnswers[item.id] = trimmed

        // 시간을 여기서 잰다 — 화면이 바뀌기 전이 마지막 기회다.
        recordTiming(for: item)

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
        currentIndex += 1

        shownAt = .now
        firstTouchAt = nil

        if isFinished {
            uploadObservations()
            wrapUp()
        }
    }

    /// 모델이 실패한 기록을 저장소에 넣는다. 서버로는 ``ObsUploader`` 가 나중에 보낸다.
    private func saveFailures(_ drafts: [ModelFailureDraft?]) {
        for draft in drafts.compactMap({ $0 }) {
            modelContext.insert(ModelFailure(draft: draft))
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

    /// 답 없이 다음을 누른 경우 — 안내를 띄우라고 표시한다.
    ///
    /// 버튼을 아예 못 누르게 막지 않는 이유: 눌러도 아무 일이 없으면 어르신은
    /// 앱이 고장 났다고 생각한다. 눌리게 두고 무엇이 필요한지 알려 주는 편이 낫다.
    func requestAnswerHint() {
        needsAnswerHint = true
    }

    // MARK: - 채점
    private func gradeCurrent(_ item: QuizItem, answer: String) async {
        // 직접입력만 모델이 판정해 시간이 걸린다. 선다·O/X 는 곧바로 다음 문제로 이어진다.
        if item.mode == .typing { isGrading = true }

        let isCorrect = await judge(item, answer: answer)
        isGrading = false
        
        applyProgress(for: item, isCorrect: isCorrect)
        
        if isCorrect {
            saveObsRecord(for: item, isCorrect: isCorrect, explanation: nil)
            moveToNextQuestion()
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
                selectedAnswer: answer,
                // 설명할 재료가 아예 없으면 기다릴 것도 없다. 바로 다음 걸음을 알려 준다.
                selectedNote: chosenQuestion == nil ? IncorrectCommentary.noteFailed : nil,
                waitingLine: waitingLine,
                expectsNote: chosenQuestion != nil,
                correctAnswer: item.question.displayAnswer,
                commentary: IncorrectCommentary.placeholder)

            // 둘을 나란히 부른다. 하나씩 기다리면 대기가 두 배가 된다.
            async let commentary = commentaryWriter.write(for: item)
            async let note = commentaryWriter.describe(chosenQuestion)

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
                    ?? (chosenQuestion != nil ? IncorrectCommentary.noteFailed : nil)

                feedback = IncorrectCommentary(
                    selectedAnswer: answer,
                    selectedNote: note,
                    waitingLine: waitingLine,
                    // 더 기다릴 것이 없다. 맥동을 멈춘다.
                    expectsNote: false,
                    correctAnswer: item.question.displayAnswer,
                    commentary: text ?? IncorrectCommentary.failed)
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
        let rows = (try? modelContext.fetch(FetchDescriptor<QuestionProgress>())) ?? []
        return Dictionary(rows.map { ($0.questionID, $0) }, uniquingKeysWith: { first, _ in first })
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
