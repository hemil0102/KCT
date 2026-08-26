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
//  ├─ needsAnswerHint          "답을 고르세요" 안내를 띄울까
//  ├─ sessionID                이번 회차를 묶는 번호 (관찰 기록용)
//  ├─ shownAt / firstTouchAt   지금 문제가 뜬 시각 / 처음 답에 손댄 시각
//  ├─ timingByID               채점 전까지 잠깐 들고 있는 시간 (문제 id → ObsTiming)
//  ├─ wasFirstEverByID         처음 보는 문항이었나 — start() 에서 미리 읽어 둔다
//  ├─ start()                  회차 구성 — 진척 확보 → 출제 계획 → 초기화 → 캐시 워밍
//  ├─ submitCurrent()          답 기록 → 다음 문제. 마지막이면 채점 시작
//  ├─ eraseAllProgress()       학습 기록 전체 삭제 후 새 회차
//  ├─ gradeAll()               제출된 답을 모두 채점하고 진척에 반영
//  ├─ judge()                  규칙으로 먼저, 안 되면 의미로 — 한 문제의 정오답 판정
//  ├─ recordTiming()           지금 문항에서 잰 시간을 채점 때까지 보관
//  ├─ saveObsRecord()          정오답이 정해진 뒤 ObsRecord 한 줄을 남긴다
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
//    → 마지막 문제였다면 gradeAll()
//        → judge() : RuleGrader 로 즉시 판정, nil 이면 MeaningGrader(모델)
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
//                RuleGrader·MeaningGrader(채점), QuestionProgress(진척), FocusStore(하이라이트)
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
    private let meaningGrader = MeaningGrader()

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

        // 어머니가 문제를 푸는 동안, 아직 분석하지 않은 문제를 뒤에서 채워 둔다.
        warmFocusCache()

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

        let trimmed = rawAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        submittedAnswers[item.id] = trimmed

        // 시간을 여기서 잰다 — 화면이 바뀌기 전이 마지막 기회다.
        recordTiming(for: item)

        rawAnswer = ""
        needsAnswerHint = false
        currentIndex += 1

        // 다음 문제가 뜬 시각. 마지막이었다면 쓰이지 않고 버려진다.
        shownAt = .now
        firstTouchAt = nil

        if isFinished {
            Task { await gradeAll() }
        }
    }

    /// 답 없이 다음을 누른 경우 — 안내를 띄우라고 표시한다.
    ///
    /// 버튼을 아예 못 누르게 막지 않는 이유: 눌러도 아무 일이 없으면 어르신은
    /// 앱이 고장 났다고 생각한다. 눌리게 두고 무엇이 필요한지 알려 주는 편이 낫다.
    func requestAnswerHint() {
        needsAnswerHint = true
    }

    // MARK: - 채점

    /// 제출된 답을 모두 채점하고 결과를 진척에 반영한다.
    private func gradeAll() async {
        isGrading = true
        defer { isGrading = false }

        let progressByID = fetchProgressByID()

        for item in items {
            let isCorrect = await judge(item, answer: submittedAnswers[item.id] ?? "")
            
            // 관찰 기록은 진척과 무관하게 남는다 — 아래 guard 에 걸려도 사라지면 안 된다.
            saveObsRecord(for: item, isCorrect: isCorrect)
            
            guard let progress = progressByID[item.id] else { continue }
            
            // 센다 — 격려용도 포함. 어머니가 맞힌 것은 맞힌 것이다.
            progress.countAttempt(correct: isCorrect)
            
            if item.affectsProgress {
                // 사다리는 격려용을 뺀다. 일부러 쉽게 낸 문제로 승급하면 안 된다.
                progress.moveLadder(correct: isCorrect)
            } else {
                // 격려용은 바닥 칸에서만 한 칸 — 2지선다에 갇히지 않게.
                progress.nudgeLadder(correct: isCorrect)
            }
        }
        try? modelContext.save()

        // 방금 남긴 다섯 줄을 곧바로 보낸다. 실패해도 다음 회차가 다시 보낸다.
        uploadObservations()
    }

    /// 한 문제를 판정한다. **규칙으로 먼저, 안 되면 뜻으로.**
    ///
    /// 선다·O/X 는 정답이 명확하므로 모델을 부르지 않는다 — 빠르고, 기기에
    /// 모델이 없어도 동작한다. 직접입력만 ``MeaningGrader`` 에 넘긴다.
    private func judge(_ item: QuizItem, answer: String) async -> Bool {
        if let byRule = RuleGrader.grade(item, userAnswer: answer) {
            results[item.id] = GradingResult(isCorrect: byRule, reason: "")
            return byRule
        }

        do {
            let result = try await meaningGrader.grade(question: item.question, userAnswer: answer)
            results[item.id] = result
            return result.isCorrect
        } catch {
            // 채점 실패는 조용히 오답 처리한다.
            // 어르신에게 "모델 오류" 는 아무 의미가 없고, 부정적 표현은 화면에 내지 않는다.
            results[item.id] = GradingResult(isCorrect: false, reason: "")
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
    private func saveObsRecord(for item: QuizItem, isCorrect: Bool) {
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
                affectsProgress: item.affectsProgress
            )
        )
    }

    /// 안 올라간 관찰 기록을 뒤에서 밀어 올린다.
    ///
    /// **기다리지 않습니다.** 네트워크가 느려도 화면은 그대로 돌아갑니다 —
    /// 어머니는 업로드가 있는 줄도 모르는 채로 다음 문제를 봅니다.
    private func uploadObservations() {
            Task { await ObsUploader(modelContext: modelContext).uploadPending() }
        }

    // MARK: - 뒷정리

    /// 답과 채점 결과를 처음 상태로 되돌린다.
    private func clearAnswers() {
        currentIndex = 0
        rawAnswer = ""
        needsAnswerHint = false
        submittedAnswers = [:]
        results = [:]

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
}
