//
//  QuestionProgress.swift
//  KCT
//
//  [축 B] 문제별 학습 진척. 어머니가 맞히면 다음 세션에서 한 단계 위 모드로 승급하고,
//  틀리면 한 단계 내려간다. 세션(날짜)을 넘어 유지되도록 SwiftData로 영구 저장한다.
//

import Foundation
import SwiftData

@Model
final class QuestionProgress {
    /// 대응하는 문제의 고유 번호. (문제당 하나)
    @Attribute(.unique) var questionID: Int
    /// 현재 출제 모드 레벨 (DifficultyMode.rawValue, 0..3)
    var modeRaw: Int
    /// 직접입력까지 맞혀 마스터했는지 여부
    var isMastered: Bool
    /// 한 번이라도 출제된 적 있는지 (신규 문제 구분용 — 스케줄러에서 사용)
    var isIntroduced: Bool
    var totalAttempts: Int
    var totalCorrect: Int
    var lastSeenAt: Date?
    /// 다음 출제 예정 시점 (반복 간격 조절 — 스케줄러가 이른 순으로 우선 출제)
    var nextDueAt: Date?

    init(questionID: Int) {
        self.questionID = questionID
        self.modeRaw = DifficultyMode.binaryChoice.rawValue
        self.isMastered = false
        self.isIntroduced = false
        self.totalAttempts = 0
        self.totalCorrect = 0
        self.lastSeenAt = nil
        self.nextDueAt = nil
    }

    /// 현재 출제 모드.
    var mode: DifficultyMode { DifficultyMode(rawValue: modeRaw) ?? .binaryChoice }

    /// 채점 결과를 반영해 모드를 승급/강등하고, 다음 출제 시점을 정한다.
    /// 격려용(첫/마지막) 슬롯에서는 호출하지 않는다.
    func record(correct: Bool, now: Date = .now) {
        totalAttempts += 1
        if correct { totalCorrect += 1 }
        lastSeenAt = now
        isIntroduced = true

        if correct {
            if mode == .mastery {
                isMastered = true                                     // 직접입력 정답 → 마스터
            } else {
                modeRaw = min(DifficultyMode.mastery.rawValue, modeRaw + 1)   // 한 단계 승급
            }
        } else {
            modeRaw = max(DifficultyMode.binaryChoice.rawValue, modeRaw - 1)  // 한 단계 강등
            isMastered = false
        }

        nextDueAt = Self.nextDue(mastered: isMastered, correct: correct, from: now)
    }

    /// 다음 출제 예정 시점. 틀리면 곧 다시, 맞으면 하루 뒤, 마스터는 멀리 미룬다.
    private static func nextDue(mastered: Bool, correct: Bool, from now: Date) -> Date {
        let day: TimeInterval = 60 * 60 * 24
        if mastered { return now.addingTimeInterval(day * 365) }
        if correct { return now.addingTimeInterval(day) }
        return now   // 틀리면 즉시 복습 대상
    }
}
