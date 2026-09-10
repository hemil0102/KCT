//
//  ModelCall.swift
//  KCT
//
//  역할 : 모델을 부를 때 공통으로 하는 것 - 지금은 시한 하나
//  요점 : 안 돌아오는 것과 실패하는 것을 같게 다룬다. 화면이 멈추지 않게
//
//  ── 구성 ──────────────────────────────────────────────
//  ModelTimeout            시한이 지났다는 오류
//  withTimeout(seconds:_:) 시한 안에 안 끝나면 던진다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : AnswerChecker · CommentaryWriter
//  기대는 것    : 없음 - Swift Concurrency 뿐
//

import Foundation

/// 모델이 시한 안에 답하지 않았다.
struct ModelTimeout: Error {}

/// 시한 안에 끝나지 않으면 ``ModelTimeout`` 을 던진다.
///
/// **안 돌아오는 것을 실패와 같게** 만듭니다. 부르는 쪽은 `catch` 하나만 쓰면 되고,
/// 화면은 어느 쪽이든 같은 문구를 냅니다 — 어르신에게 「모델이 느립니다」는 아무 뜻이 없습니다.
///
/// - Note: 먼저 끝난 쪽을 받고 나머지는 취소합니다. 모델 쪽이 이기면 잠자기가 취소되고,
///   잠자기가 이기면 모델 쪽이 취소됩니다.
func withTimeout<T: Sendable>(
    seconds: Double,
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw ModelTimeout()
        }

        let first = try await group.next()!
        group.cancelAll()
        return first
    }
}
