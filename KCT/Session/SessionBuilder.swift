//
//  SessionBuilder.swift
//  KCT
//
//  역할 : 이번 회차에 어떤 문제를 어떤 방식으로 낼지 자동으로 정한다
//  요점 : 어머니가 아무것도 고르지 않아도 되도록, 선택을 전부 여기서 대신한다
//
//  ── 구성 ──────────────────────────────────────────────
//  SessionBuilder              출제 계획을 세우는 주인
//  ├─ catalog                  문제집 (어떤 문제가 있는지)
//  ├─ isUnlocked               스토리 모드 게이트. 지금은 항상 열림
//  ├─ masteredReviewSlots      마스터 복습용으로 남겨 둘 칸 수 (1칸)
//  ├─ newcomerSlots            신규 도입용으로 남겨 둘 칸 수 (2칸)
//  ├─ build()                  계획 전체를 지휘 — 아래 넷을 순서대로 부른다
//  │   ├─ Queues               후보를 세 줄로 나눠 담은 것 (복습·신규·마스터)
//  │   │   ├─ reviewQueue()    복습 줄 세우기 (예정 시각 이른 순 → 쉬운 순)
//  │   │   ├─ newcomerQueue()  신규 줄 세우기 (쉬운 순 + 단원 번갈아)
//  │   │   │   └─ introduceOrder()   단원 라운드로빈
//  │   │   └─ masteredQueue()  마스터 줄 세우기 (랜덤)
//  │   ├─ fillSlots()          size 칸을 채운다 (신규 2칸·마스터 1칸 먼저 예약)
//  │   └─ shapeRound()         묻는 방식 배정 + 첫·마지막을 격려용 2지선다로
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.start() 가 회차를 요청
//    → build(size:progressByID:focusByID:)
//    → 후보 걸러내기 : isUnlocked 로 열린 문제만
//    → 세 줄로 나누기 : 복습 / 신규 / 마스터
//    → fillSlots()   : 신규 2칸·마스터 1칸을 떼어 두고 나머지를 복습으로 채운 뒤 섞는다
//    → shapeRound()  : 각 문제에 진척이 기억한 묻는 방식을 붙인다
//                      단 첫·마지막은 2지선다 + 진척 무영향(격려용)
//    → QuizItem 배열로 돌려줌
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession.start()
//  기대는 것    : QuestionCatalog(문제), QuestionProgress(진척 읽기만), QuizItem(출제 항목)
//  건드리지 않는 것 : 진척 저장 — 채점 후 QuizSession 이 countAttempt·moveLadder·
//                    nudgeLadder 로 반영한다. 여기서는 진척을 **읽기만** 한다
//

import Foundation

/// 이번 회차에 낼 문제와 묻는 방식을 정하는 스케줄러.
///
/// 어머니가 아무것도 고르지 않아도 되도록, 후보를 복습·신규·마스터 세 줄로 세운 뒤 앞에서부터 뽑습니다.
///
/// - Note: 진척(``QuestionProgress``)은 읽기만 합니다. 승급·강등 기록은 채점이 끝난 뒤 ``QuizSession`` 이 합니다.
struct SessionBuilder {

    /// 출제할 문제집.
    let catalog: QuestionCatalog

    /// 스토리 모드 게이트를 끼울 자리(seam). 지금은 모든 문제가 열려 있습니다.
    ///
    /// 나중에 "읽은 콘텐츠의 문제만 개방" 을 넣을 때 이 클로저만 갈아끼우면 됩니다.
    var isUnlocked: (Question) -> Bool = { _ in true }

    /// 매 회차에 마스터 문제를 복습으로 끼워 넣을 칸 수.
    ///
    /// 마스터한 문제도 계속 만나야 잊지 않지만, 새 문제를 배울 자리를 잡아먹지 않도록 한 칸으로 제한합니다.
    private let masteredReviewSlots = 1
    
    /// 매 회차에 새 문제를 들일 칸 수.
    ///
    /// 이 예약이 없으면 복습 줄이 회차 크기만큼 차는 순간 신규가 영영 차례를 못 받습니다.
    /// 신규가 남아 있는 동안만 떼어 두므로, 문제집을 다 돌면 저절로 사라집니다.
    private let newcomerSlots = 2

    // MARK: - 계획 세우기 (입구)

    /// 이번 회차의 출제 항목을 만든다.
    ///
    /// `progressByID` 로 무엇을 복습할지 정하고, `focusByID` 가 비어 있으면 묻는 대상을 규칙 기반으로 즉시 계산합니다.
    ///
    /// - Note: `now` 는 아직 어느 판단에도 쓰이지 않습니다. 미마스터 문제는 항상 후보이고 `nextDueAt` 은 순서만 정합니다.
    func build(
        size: Int,
        progressByID: [Int: QuestionProgress],
        focusByID: [Int: QuestionFocus] = [:],
        now: Date = .now
    ) -> [QuizItem] {
        let candidates = catalog.questions.filter(isUnlocked)

        let queues = Queues(
            review: reviewQueue(from: candidates, progressByID: progressByID),
            newcomers: newcomerQueue(from: candidates, progressByID: progressByID),
            mastered: masteredQueue(from: candidates, progressByID: progressByID)
        )

        let chosen = fillSlots(size: size, from: queues)

        return shapeRound(chosen, progressByID: progressByID, focusByID: focusByID)
    }

    // MARK: - 세 가지 줄

    /// 출제 후보를 성격별로 나눠 담은 것.
    ///
    /// 이름을 붙여 두면 채우는 규칙과 줄 세우는 규칙이 섞이지 않습니다.
    struct Queues {
        /// 이미 나온 적 있고 아직 마스터 못 한 문제. 예정 시각이 이른 순.
        let review: [Question]
        /// 아직 한 번도 안 나온 문제. 쉬운 순 + 단원 번갈아.
        let newcomers: [Question]
        /// 마스터한 문제. 복습용이라 랜덤.
        let mastered: [Question]
    }

    /// 복습 줄을 세운다. 예정 시각이 이른 쪽 → 오래 안 본 쪽 → 쉬운 쪽 순입니다.
    func reviewQueue(
        from questions: [Question],
        progressByID: [Int: QuestionProgress]
    ) -> [Question] {
        questions
            .filter { !isMastered($0, progressByID) && isIntroduced($0, progressByID) }
            .sorted { isDueEarlier($0, than: $1, progressByID: progressByID) }
    }

    /// 신규 도입 줄을 세운다. 쉬운 순으로 두되 단원을 번갈아 꺼낸다.
    func newcomerQueue(
        from questions: [Question],
        progressByID: [Int: QuestionProgress]
    ) -> [Question] {
        introduceOrder(
            questions.filter { !isMastered($0, progressByID) && !isIntroduced($0, progressByID) }
        )
    }

    /// 마스터 복습 줄을 세운다. 순서를 섞어 매 회차 다른 문제가 오게 한다.
    func masteredQueue(
        from questions: [Question],
        progressByID: [Int: QuestionProgress]
    ) -> [Question] {
        questions.filter { isMastered($0, progressByID) }.shuffled()
    }

    /// 신규 문제를 쉬운 순으로 두되, 단원을 번갈아(라운드로빈) 도입한다.
    ///
    /// 쉬운 순으로만 세우면 한 단원이 통째로 먼저 나와 편식하게 됩니다.
    func introduceOrder(_ questions: [Question]) -> [Question] {
        let sorted = questions.sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) }

        // 단원별 큐로 나눈다. (처음 등장한 단원 순서를 유지해야 쉬운 단원이 앞에 온다)
        var byUnit: [String: [Question]] = [:]
        var unitOrder: [String] = []
        for question in sorted {
            if byUnit[question.unit] == nil {
                byUnit[question.unit] = []
                unitOrder.append(question.unit)
            }
            byUnit[question.unit]?.append(question)
        }

        // 단원을 번갈아 하나씩 꺼낸다. 한 바퀴에 아무것도 못 꺼내면 끝난 것이다.
        var result: [Question] = []
        var didAppend = true
        while didAppend {
            didAppend = false
            for unit in unitOrder where !(byUnit[unit]?.isEmpty ?? true) {
                result.append(byUnit[unit]!.removeFirst())
                didAppend = true
            }
        }
        return result
    }

    // MARK: - 칸 채우기

    /// `size` 개의 칸을 채운다.
    ///
    /// 신규 2칸·마스터 1칸을 먼저 떼어 둔 뒤 남은 자리를 복습이 씁니다. 떼어 두지 않으면 복습 줄이 가득 차는 순간 신규가 영원히 못 들어옵니다.
    /// 마지막에 섞는 이유는 마스터·신규가 늘 같은 자리에 오면 "이제 쉬운 거 나올 차례" 라는 패턴이 생기기 때문입니다.
    func fillSlots(size: Int, from queues: Queues) -> [Question] {
        var chosen: [Question] = []

        // 한 줄에서 뽑되, 이미 고른 문제는 건너뛰고, 상한에 닿으면 멈춘다.
        func take(_ queue: [Question], upTo limit: Int) {
            for question in queue where chosen.count < limit {
                guard !chosen.contains(where: { $0.id == question.id }) else {
                    continue
                }
                chosen.append(question)
            }
        }
        
        // 줄이 비어 있으면 그 몫은 떼지 않는다.
        let masteredReserve = min(masteredReviewSlots, queues.mastered.count)
        let newcomerReserve = min(newcomerSlots, queues.newcomers.count)
        
        take(queues.review, upTo: max(0, size - masteredReserve - newcomerReserve))
        take(queues.newcomers, upTo: max(0, size - masteredReserve))
        take(queues.mastered, upTo: size)
        
        // 세 줄을 다 훑고도 남으면 남은 것으로 마저 채운다.
        take(queues.review, upTo: size)
        take(queues.newcomers, upTo: size)

        return chosen.shuffled()
    }

    // MARK: - 회차 모양 잡기

    /// 고른 문제에 묻는 방식을 배정한다. **첫·마지막은 격려용 2지선다.**
    ///
    /// 쉽게 시작하고 쉽게 끝나야 계속하고 싶어집니다. 그래서 양 끝은 `affectsProgress: false` 로 두어 승급·강등에 영향을 주지 않습니다.
    func shapeRound(
        _ questions: [Question],
        progressByID: [Int: QuestionProgress],
        focusByID: [Int: QuestionFocus]
    ) -> [QuizItem] {
        questions.enumerated().map { index, question in
            let isBookend = questions.count >= 2
                && (index == 0 || index == questions.count - 1)

            let mode: AskingMode = isBookend
                ? .binaryChoice
                : (progressByID[question.id]?.mode ?? .binaryChoice)

            return QuizItem.make(
                question,
                mode: mode,
                // 같은 계열을 뺀 보기만 쓴다 — 근접 오답을 우연에 맡기지 않는다.
                answerPool: catalog.answerPool(excludingCategory: question.category),
                affectsProgress: !isBookend,
                focus: focusByID[question.id]
            )
        }
    }

    // MARK: - 진척 읽기 (작은 판단들)

    private func isMastered(_ question: Question, _ progressByID: [Int: QuestionProgress]) -> Bool {
        progressByID[question.id]?.isMastered == true
    }

    private func isIntroduced(_ question: Question, _ progressByID: [Int: QuestionProgress]) -> Bool {
        progressByID[question.id]?.isIntroduced == true
    }

    /// 복습 순서 비교. 예정 시각이 이른 쪽 → 오래 안 본 쪽 → 쉬운 쪽 순으로 먼저 옵니다.
    private func isDueEarlier(
        _ lhs: Question,
        than rhs: Question,
        progressByID: [Int: QuestionProgress]
    ) -> Bool {
        let left = progressByID[lhs.id]?.nextDueAt ?? .distantPast
        let right = progressByID[rhs.id]?.nextDueAt ?? .distantPast

        if left != right { return left < right }
        
        let leftSeen = progressByID[lhs.id]?.lastSeenAt ?? .distantPast
        let rightSeen = progressByID[rhs.id]?.lastSeenAt ?? .distantPast
        if leftSeen != rightSeen { return leftSeen < rightSeen }
        return (lhs.difficulty, lhs.id) < (rhs.difficulty, rhs.id)
    }
}
