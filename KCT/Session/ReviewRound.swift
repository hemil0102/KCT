//
//  ReviewRound.swift
//  KCT
//
//  역할 : 회차 끝의 복습 한 바퀴 — 본 풀이에서 틀린 문항만 한 번 더 묻는다 (11차 4-37)
//  요점 : 복습의 상태 다섯 개가 **함께 움직인다.** 따로 두면 하나만 바뀌는 순간이 생긴다
//
//  ── 구성 ──────────────────────────────────────────────
//  ReviewRound (struct — 값)
//  ├─ items            복습할 문항 (본 풀이에서 틀린 것, 회차에 나온 순서 그대로)
//  ├─ index            지금 자리
//  ├─ isShowingIntro   복습 시작 화면을 띄울 차례인가
//  ├─ isActive         복습 문제를 푸는 중인가
//  ├─ outcomes         문항 id → 복습에서 맞혔나 (본 풀이 결과와 따로)
//  ├─ current          지금 복습 문항 (없으면 nil)
//  ├─ offer(_:)        틀린 문항을 받아 시작 화면을 띄울지 정한다
//  ├─ begin()          시작 화면의 버튼 → 첫 문항으로
//  ├─ advance()        다음 문항으로. 다 풀었으면 끝내고 false
//  └─ record(_:correct:) 복습 결과 한 줄
//
//  ── 흐름 ──────────────────────────────────────────────
//  마지막 칸 → offer(틀린 것) → 시작 화면 → begin() → 문항마다 record → advance()
//    → 다 풀면 isActive = false → QuizSession 이 3초 박자(wrapUp) 뒤 결과 화면
//
//  ── 왜 따로 뺐나 (2차 리팩토링, 2026-10-23) ─────────────
//  QuizSession(1,105줄) 안에 저장 프로퍼티 다섯 개로 흩어져 있었다. 규칙 24 의 「쪼개는 때 ②」 —
//  자기만의 로직(시작·다음·끝)을 갖기 시작했다. 값 타입이라 QuizSession 의 @Observable 이 그대로 지켜본다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession (화면들은 QuizSession 의 reviewItems·isInReview 등을 그대로 읽는다)
//  기대는 것    : QuizItem 뿐
//  건드리지 않는 것 : 채점·진척·관찰 기록 — 복습이 사다리를 안 움직이는 규칙은 QuizSession.applyProgress 에 있다
//

import Foundation

/// 회차 끝의 복습 한 바퀴.
struct ReviewRound {

    /// 복습할 문항 — 본 풀이에서 틀린 것들. 순서는 회차에 나온 순서 그대로.
    private(set) var items: [QuizItem] = []

    /// 지금 복습 중인 자리 (``items`` 안의 번호).
    private(set) var index = 0

    /// 복습 시작 화면을 띄울 차례인가.
    private(set) var isShowingIntro = false

    /// 복습 문제를 푸는 중인가.
    private(set) var isActive = false

    /// 문항 id → 복습에서 맞혔나. 결과 화면이 「정답 / 다시 풀어서 정답 / 틀렸어요」를 가를 때 쓴다.
    private(set) var outcomes: [Int: Bool] = [:]

    /// 지금 복습 문항. 복습 중이 아니거나 자리가 범위 밖이면 `nil`.
    var current: QuizItem? {
        guard isActive, items.indices.contains(index) else { return nil }
        return items[index]
    }

    /// 본 풀이에서 틀린 문항을 받는다. 하나라도 있으면 시작 화면을 띄울 차례가 되고 `true`.
    mutating func offer(_ missed: [QuizItem]) -> Bool {
        guard !missed.isEmpty else { return false }
        items = missed
        isShowingIntro = true
        return true
    }

    /// 시작 화면의 버튼. 첫 복습 문제로 들어간다. 들어갈 수 없는 상태면 `false`.
    mutating func begin() -> Bool {
        guard isShowingIntro, !items.isEmpty else { return false }
        isShowingIntro = false
        isActive = true
        index = 0
        return true
    }

    /// 다음 복습 문항으로. 다 풀었으면 복습을 끝내고 `false`.
    mutating func advance() -> Bool {
        index += 1
        guard index < items.count else {
            isActive = false
            return false
        }
        return true
    }

    /// 복습에서 맞혔는지 적는다.
    mutating func record(_ questionID: Int, correct: Bool) {
        outcomes[questionID] = correct
    }
}
