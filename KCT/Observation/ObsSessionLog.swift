//
//  ObsSessionLog.swift
//  KCT
//
//  역할 : 한 회차 동안 관찰 기록에 쓸 시간과 사실을 들고 있다가, 채점이 끝나면 ObsRecord 한 줄로 만든다
//  요점 : 정오답은 채점 뒤에야 정해지는데 시간은 「다음」을 누른 순간 지나간다 — 그 사이를 이 값이 메운다
//
//  ── 구성 ──────────────────────────────────────────────
//  ObsSessionLog (struct — 값)
//  ├─ sessionID          이번 회차를 묶는 번호 (startNewSession 마다 새로)
//  ├─ shownAt            지금 문제가 화면에 뜬 시각
//  ├─ firstTouchAt       지금 문제에서 처음 답에 손댄 시각 (처음 것만)
//  ├─ timingByID         문제 id → 잰 시간 (채점이 끝나면 ObsRecord 로 옮긴다)
//  ├─ wasFirstEverByID   문제 id → 처음 보는 문항이었나 (채점 **전에** 읽어 둔다)
//  ├─ startNewSession()  회차가 바뀔 때 — 번호를 새로, 시간을 비운다
//  ├─ markShown()        새 문제가 떴다 — shownAt 을 지금으로, 첫 손댐을 비운다
//  ├─ touch()            답에 손댔다 — 처음이면 시각을 적는다
//  ├─ recordTiming(for:) 「다음」을 누른 순간 시간을 잰다
//  └─ record(...)        채점이 끝난 뒤 ObsRecord 한 줄을 만든다 (시간을 못 쟀으면 nil)
//
//  ── 왜 따로 뺐나 (2차 리팩토링, 2026-10-23) ─────────────
//  QuizSession 안에 저장 프로퍼티 다섯 개 + 함수 둘로 흩어져 있었다. 모두 「관찰 기록」 한 주제라
//  같이 쓰이고 같이 바뀐다 (규칙 24). 저장소에 넣는 일(insert)과 올리는 일(ObsUploader)은 QuizSession 에 남겼다 —
//  이 값은 ModelContext 를 모른다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession
//  기대는 것    : ObsRecord(만들기만 한다) · QuizItem
//  건드리지 않는 것 : 저장·업로드 — QuizSession.saveObsRecord · ObsUploader 의 몫
//

import Foundation

/// 한 회차의 관찰 기록 재료.
struct ObsSessionLog {

    /// 한 문항에서 잰 시간.
    private struct Timing {
        let askedAt: Date
        let secToFirstTouch: Double?
        let secToSubmit: Double
    }

    /// 이번 회차를 묶는 번호. 이것 하나로 나중에 「이번 회차 평균 대기」와 「회차에 걸린 총 시간」을 센다.
    private(set) var sessionID = UUID()

    /// 지금 문제가 화면에 뜬 시각. 화면의 `onAppear` 가 아니라 세션이 스스로 찍는다 — 판단이 화면에 흩어지지 않게.
    private var shownAt: Date?

    /// 지금 문제에서 **처음** 답에 손댄 시각. 답을 바꿔도 처음 것만 남는다.
    private var firstTouchAt: Date?

    /// 문제 id → 이번 회차에 잰 시간.
    private var timingByID: [Int: Timing] = [:]

    /// 문제 id → **이번이 처음 보는 문항이었나.**
    ///
    /// - Important: 채점 뒤에 읽으면 **전부 `false`** 가 된다 —
    ///   ``QuestionProgress/countAttempt(correct:now:)`` 가 ``QuestionProgress/isIntroduced`` 를 켜 버리기 때문이다.
    ///   그래서 ``QuizSession/start()`` 가 아직 아무것도 일어나지 않았을 때 채운다.
    var wasFirstEverByID: [Int: Bool] = [:]

    /// 회차가 바뀔 때. 번호를 새로 만들고 시간을 비운다. (``wasFirstEverByID`` 는 ``QuizSession/start()`` 가 따로 채운다)
    mutating func startNewSession() {
        sessionID = UUID()
        timingByID = [:]
        markShown()
    }

    /// 새 문제가 화면에 떴다.
    mutating func markShown() {
        shownAt = .now
        firstTouchAt = nil
    }

    /// 답에 손댔다. 처음일 때만 시각을 적는다.
    mutating func touch() {
        if firstTouchAt == nil { firstTouchAt = .now }
    }

    /// 지금 문항에서 잰 시간을 채점 때까지 들고 있는다.
    ///
    /// ``shownAt`` 이 `nil` 이면 지금을 기준으로 삼는다 — 0초로 적으면 「0초 만에 풀었다」는 거짓말이 되고,
    /// 기록을 통째로 버리면 그 문항이 사라진다.
    mutating func recordTiming(for questionID: Int) {
        let asked = shownAt ?? .now
        timingByID[questionID] = Timing(
            askedAt: asked,
            secToFirstTouch: firstTouchAt.map { $0.timeIntervalSince(asked) },
            secToSubmit: Date.now.timeIntervalSince(asked))
    }

    /// 이 문항에서 일어난 일을 ``ObsRecord`` 한 줄로 만든다.
    ///
    /// - Returns: 시간을 못 잰 문항이면 `nil` — **조용히 건너뛴다.** 추측한 값으로 채우면 나중에 그 줄이 참인지 알 수 없다.
    func record(
        for item: QuizItem,
        isCorrect: Bool,
        chosen: String?,
        reason: String?,
        explanation: String?,
        basis: String?
    ) -> ObsRecord? {
        guard let timing = timingByID[item.id] else { return nil }
        return ObsRecord(
            sessionID: sessionID,
            askedAt: timing.askedAt,
            questionID: item.id,
            secToFirstTouch: timing.secToFirstTouch,
            secToSubmit: timing.secToSubmit,
            isCorrect: isCorrect,
            modeRaw: item.mode.rawValue,
            wasFirstEver: wasFirstEverByID[item.id] ?? false,
            affectsProgress: item.affectsProgress,
            chosen: chosen,
            reason: reason,
            explanation: explanation,
            basis: basis,
            explanationSource: explanation == nil ? nil : "device")
    }
}
