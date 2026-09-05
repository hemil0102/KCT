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
//  ├─ isIntroduced              한 번이라도 출제됐는가 — 격려용 포함 (신규/복습 기준)
//  ├─ totalAttempts / totalCorrect   시도·정답 누적 (결과 화면의 "지금까지 맞힌 문제")
//  ├─ lastSeenAt / nextDueAt    마지막으로 본 때 / 다음에 낼 때 (nextDueAt 은 지금 늘 nil)
//  ├─ countAttempt(correct:now:)  본 것을 센다 — 격려용 포함 모든 출제
//  ├─ moveLadder(correct:now:)    사다리 한 칸 이동 — 격려용 제외
//  ├─ nudgeLadder(correct:)       격려용 정답 — 2지선다 → O/X 한 칸만
//  └─ nextDue(...)              간격 규칙 — ⚠️ 정의만 있고 지금 아무도 부르지 않는다
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.start()
//    → 진척이 없는 문제에 이 객체를 새로 만든다 (modeRaw = 0, isIntroduced = false)
//  SessionBuilder
//    → isMastered · isIntroduced 를 **읽어서** 출제 순서를 정한다
//      (nextDueAt 도 읽지만 늘 nil 이라 사실상 난이도·id 순이 된다)
//  QuizSession.gradeAll()
//    → countAttempt(correct:) 로 모든 문항을 센다 (결과 화면의 누적 숫자)
//    → 격려용이면 nudgeLadder(correct:) 로 바닥 칸(2지선다)에서만 한 칸 올린다
//    → 격려용이 아니면 moveLadder(correct:) 로 사다리를 옮긴다
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
/// 앱을 껐다 켜도 유지되어야 하므로 SwiftData 로 영구 저장하며, 문제 내용(``Question``)과
/// 분리되어 있어 문제집을 갈아끼워도 기록이 남습니다.
///
/// - Important: 문제 id 를 재사용하면 남의 학습 기록이 엉뚱한 문제에 붙습니다.
@Model
final class QuestionProgress {

    /// 대응하는 문제의 고유 번호. 문제당 하나만 존재한다.
    @Attribute(.unique) var questionID: Int

    /// 지금 사다리의 몇 칸인지 (``AskingMode`` 의 rawValue, 0..3).
    ///
    /// 저장 형식을 단순하게 두려고 `Int` 로 두며, 읽을 때는 ``mode`` 를 씁니다.
    var modeRaw: Int

    /// 직접입력까지 맞혀 마스터했는지.
    var isMastered: Bool

    /// 한 번이라도 출제된 적 있는지. 격려용 슬롯으로 나온 것도 포함합니다.
    ///
    /// 스케줄러가 신규 문제와 복습 문제를 가르는 기준입니다. 격려용을 제외했더니 거기
    /// 걸린 문항이 계속 신규 줄로 돌아가 2지선다에 갇혔습니다.
    ///
    /// - Note: 이때 ``nextDueAt`` 은 `nil` 로 남아 복습 줄 맨 앞에 서므로, 문항이 늘면
    ///   "매 회차 반드시 나오는 문항" 이 생깁니다 — 그때 다시 정할 자리입니다.
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
    /// 저장된 숫자가 알 수 없는 값이면 가장 쉬운 칸으로 되돌립니다 — 잘못된 데이터로
    /// 앱이 죽는 것보다 쉬운 문제를 한 번 더 내는 편이 낫습니다.
    var mode: AskingMode { AskingMode(rawValue: modeRaw) ?? .binaryChoice }

    /// 본 것을 셉니다. 격려용 슬롯을 포함해 모든 출제에서 부릅니다.
    ///
    /// 사다리(``moveLadder(correct:now:)``)와 나눈 이유가 있습니다. 격려용은 사다리에
    /// 반영하면 안 되지만 어머니가 실제로 맞힌 것은 맞아서, 한 함수에 두었더니 결과 화면의
    /// 누적 정답 수가 실제와 어긋났습니다.
    func countAttempt(correct: Bool, now: Date = .now) {
        totalAttempts += 1
        if correct { totalCorrect += 1 }
        lastSeenAt = now
        isIntroduced = true
    }
    
    /// 사다리를 한 칸 올리거나 내립니다.
    ///
    /// - Important: 격려용(첫·마지막) 슬롯에서는 호출하지 않습니다 — 일부러 쉽게 낸 문제로
    ///   승급하면 사다리가 망가집니다. 호출 여부는 ``QuizItem/affectsProgress`` 가 정합니다.
    ///
    /// - Note: `now` 는 지금 쓰이지 않습니다. ``nextDueAt`` 을 다시 잡던 줄이 빠졌지만,
    ///   이 이름이 DocC 링크로 여러 문서에 박혀 있어 인자를 남겨 둡니다.
    func moveLadder(correct: Bool, now: Date = .now) {
        if correct {
            if mode == .mastery {
                isMastered = true
            } else {
                modeRaw = min(AskingMode.mastery.rawValue, modeRaw + 1)
            }
        } else {
            modeRaw = max(AskingMode.binaryChoice.rawValue, modeRaw - 1)
            isMastered = false
        }
    }

    /// 격려용 슬롯에서 맞혔을 때 바닥 칸에서만 한 칸 올려 줍니다.
    ///
    /// 아무 일도 없으면 격려용에 자주 걸리는 문항이 2지선다에 갇히므로 `2지선다 → O/X` 만
    /// 열어 둡니다. 틀려도 강등하지 않는 것이 격려용 슬롯의 뜻입니다.
    ///
    /// - Note: ``nextDueAt`` 과 ``isMastered`` 는 건드리지 않습니다.
    func nudgeLadder(correct: Bool) {
        guard correct, mode == .binaryChoice else { return }
        modeRaw = AskingMode.trueOrFalse.rawValue
    }
    
    /// 다음 출제 예정 시각 — 간격 반복의 간격 규칙. 틀리면 즉시, 맞히면 하루 뒤,
    /// 마스터하면 1년 뒤로 잡습니다.
    ///
    /// - Important: ⚠️ 지금 아무도 부르지 않아 ``nextDueAt`` 은 늘 `nil` 입니다. 규칙이 아니라
    ///   호출 한 줄이 빠진 것이라, 로그로 실제 간격을 본 뒤 되살릴 자리입니다.
    private static func nextDue(mastered: Bool, correct: Bool, from now: Date) -> Date {
        let day: TimeInterval = 60 * 60 * 24

        if mastered { return now.addingTimeInterval(day * 365) }
        if correct { return now.addingTimeInterval(day) }
        return now
    }
}
