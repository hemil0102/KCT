//
//  QuestionProgress.swift
//  KCT
//
//  역할 : [축 B] 문제별 학습 진척. 승급·강등과 다음 출제 시점을 기억한다
//  요점 : 세션(날짜)을 넘어 유지되어야 하므로 SwiftData 로 디스크에 남긴다
//
//  ── 구성 ──────────────────────────────────────────────
//  QuestionProgress (@Model)    문제 하나의 학습 기록
//  ├─ questionID                어느 문제인지. 문제당 하나(.unique)
//  ├─ modeRaw / mode            지금 사다리의 몇 칸인가 (AskingMode)
//  ├─ isMastered                직접입력까지 맞혔는가
//  ├─ isIntroduced              한 번이라도 출제됐는가 (신규/복습을 가르는 기준)
//  ├─ totalAttempts / totalCorrect   시도·정답 누적 (결과 화면의 "지금까지 맞힌 문제")
//  ├─ lastSeenAt / nextDueAt    마지막으로 본 때 / 다음에 낼 때
//  ├─ record(correct:now:)      채점 결과 반영 — 승급·강등 + 다음 시점 계산
//  └─ nextDue(...)              간격 규칙: 틀리면 즉시, 맞으면 하루, 마스터는 1년
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.start()
//    → 진척이 없는 문제에 이 객체를 새로 만든다 (modeRaw = 0, isIntroduced = false)
//  SessionBuilder
//    → isMastered · isIntroduced · nextDueAt 을 **읽어서** 출제 순서를 정한다
//  QuizSession.gradeAll()
//    → record(correct:) 로 사다리를 한 칸 올리거나 내리고 nextDueAt 을 다시 잡는다
//    → modelContext.save() 로 디스크에 남는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession(생성·기록), SessionBuilder(읽기), ResultScreen(누적 통계)
//  기대는 것    : AskingMode(사다리), SwiftData
//  건드리지 않는 것 : 문제 내용 — Question 은 따로 있고 id 로만 연결된다
//

import Foundation
import SwiftData

/// 문제 하나의 학습 진척. 맞히면 한 칸 위 방식으로, 틀리면 아래로 옮깁니다.
///
/// 앱을 껐다 켜도 유지되어야 하므로 SwiftData 로 영구 저장합니다.
/// 문제 내용(``Question``)과 분리되어 있어, 문제집을 갈아끼워도 기록이 남습니다.
///
/// - Important: ``questionID`` 로만 문제와 연결됩니다. 문제 id를 재사용하면
///   엉뚱한 문제에 남의 학습 기록이 붙습니다.
@Model
final class QuestionProgress {

    /// 대응하는 문제의 고유 번호. 문제당 하나만 존재한다.
    @Attribute(.unique) var questionID: Int

    /// 지금 사다리의 몇 칸인지 (``AskingMode`` 의 rawValue, 0..3).
    ///
    /// - Note: enum 을 그대로 저장하지 않고 `Int` 로 두는 이유는 저장 형식을
    ///   단순하게 유지하기 위해서입니다. 읽을 때는 ``mode`` 를 씁니다.
    var modeRaw: Int

    /// 직접입력까지 맞혀 마스터했는지.
    var isMastered: Bool

    /// 한 번이라도 출제된 적 있는지.
    ///
    /// 스케줄러가 **신규 문제와 복습 문제를 가르는 기준**입니다.
    var isIntroduced: Bool

    /// 이 문제를 시도한 총 횟수.
    var totalAttempts: Int

    /// 이 문제를 맞힌 총 횟수. 결과 화면의 누적 정답 수에 합산된다.
    var totalCorrect: Int

    /// 마지막으로 본 시각.
    var lastSeenAt: Date?

    /// 다음 출제 예정 시각. 스케줄러가 **이른 순으로** 우선 출제한다.
    var nextDueAt: Date?

    /// 새 진척을 만든다. 모든 문제는 가장 쉬운 칸에서, 아직 나오지 않은 상태로 시작한다.
    init(questionID: Int) {
        self.questionID = questionID
        self.modeRaw = AskingMode.binaryChoice.rawValue
        self.isMastered = false
        self.isIntroduced = false
        self.totalAttempts = 0
        self.totalCorrect = 0
        self.lastSeenAt = nil
        self.nextDueAt = nil
    }

    /// 지금 이 문제를 묻는 방식.
    ///
    /// 저장된 숫자가 알 수 없는 값이면 가장 쉬운 칸으로 되돌립니다 —
    /// 잘못된 데이터로 앱이 죽는 것보다 쉬운 문제를 한 번 더 내는 편이 낫습니다.
    var mode: AskingMode { AskingMode(rawValue: modeRaw) ?? .binaryChoice }

    /// 채점 결과를 반영해 사다리를 올리거나 내리고, 다음 출제 시점을 정한다.
    ///
    /// - Parameters:
    ///   - correct: 맞혔는지
    ///   - now: 기준 시각. 테스트에서 고정할 수 있게 열어 둔다
    ///
    /// - Important: 격려용(첫·마지막) 슬롯에서는 **호출하지 않습니다.**
    ///   그 슬롯은 일부러 쉽게 낸 것이므로, 맞혔다고 승급시키면 사다리가 망가집니다.
    ///   호출 여부는 ``QuizItem/affectsProgress`` 가 정합니다.
    func record(correct: Bool, now: Date = .now) {
        totalAttempts += 1
        if correct { totalCorrect += 1 }
        lastSeenAt = now
        isIntroduced = true

        if correct {
            if mode == .mastery {
                isMastered = true                                          // 직접입력 정답 → 마스터
            } else {
                modeRaw = min(AskingMode.mastery.rawValue, modeRaw + 1)     // 한 칸 승급
            }
        } else {
            modeRaw = max(AskingMode.binaryChoice.rawValue, modeRaw - 1)    // 한 칸 강등
            isMastered = false
        }

        nextDueAt = Self.nextDue(mastered: isMastered, correct: correct, from: now)
    }

    /// 다음 출제 예정 시각 — 간격 반복(spaced repetition)의 간격 규칙.
    ///
    /// | 상황 | 다음 출제 |
    /// |---|---|
    /// | 틀렸다 | **즉시** (곧 다시 만나야 한다) |
    /// | 맞혔다 | 하루 뒤 |
    /// | 마스터했다 | 1년 뒤 — 사실상 "급하지 않다" 는 표시 |
    ///
    /// - Note: 마스터 문제가 1년 뒤로 밀려도 아예 안 나오지는 않습니다.
    ///   ``SessionBuilder`` 가 매 회차 한 칸을 마스터 복습용으로 따로 비워 둡니다.
    private static func nextDue(mastered: Bool, correct: Bool, from now: Date) -> Date {
        let day: TimeInterval = 60 * 60 * 24

        if mastered { return now.addingTimeInterval(day * 365) }
        if correct { return now.addingTimeInterval(day) }
        return now
    }
}
