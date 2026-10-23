//
//  ExplanationPrefetcher.swift
//  KCT
//
//  역할 : 문제가 뜨는 순간 정답 해설(.full)을 뒤에서 만들기 시작하고, 채점 때 그 결과를 건넨다
//  요점 : 「이 답이 왜 맞는지」는 무엇을 고르든 같은 글이다 — 채점을 기다릴 이유가 없다
//
//  ── 구성 ──────────────────────────────────────────────
//  ExplanationPrefetcher
//  ├─ tasks                     문제 id → 만들고 있거나 다 만든 해설 작업
//  ├─ start(for:)               만들기 시작한다 (이미 있으면 아무 일도 안 한다 — 한 문항에 두 번 시키지 않는다)
//  ├─ explanation(for:)         결과를 기다린다 (아직 시작 안 했으면 지금 시작해서)
//  └─ cancelAll()               회차를 새로 시작하거나 나갈 때 — 아무도 안 기다리는 작업을 멈춘다
//
//  ── 왜 따로 뺐나 (2차 리팩토링, 2026-10-23) ─────────────
//  QuizSession 안의 딕셔너리 하나와 함수 둘이었다. 예전에는 새 회차에서 딕셔너리를 비우기만 하고
//  **작업은 멈추지 않았다** — 회차를 나가도 모델이 뒤에서 계속 글을 썼다. cancelAll 이 그 자리다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession (start · moveToNextQuestion · 해설 창 셋)
//  기대는 것    : CommentaryWriter · Question
//  건드리지 않는 것 : 창을 띄우는 일 — QuizSession 의 몫
//

import Foundation

/// 정답 해설 미리 만들기.
final class ExplanationPrefetcher {

    private let writer: CommentaryWriter

    /// 문제 id → 해설 작업. 키는 ``Question/id``(= ``QuizItem/id``).
    private var tasks: [Int: Task<Writing, Never>] = [:]

    init(writer: CommentaryWriter) {
        self.writer = writer
    }

    /// 정답 해설을 뒤에서 만들기 시작한다. 이미 만들고 있거나 다 만들었으면 아무 일도 하지 않는다.
    func start(for question: Question) {
        guard tasks[question.id] == nil else { return }
        let writer = writer
        tasks[question.id] = Task {
            await writer.explain(question, length: .full)
        }
    }

    /// 미리 만들어 둔 정답 해설을 기다린다. 아직 시작하지 않았으면(프리뷰·안전망) 지금 시작해 기다린다.
    func explanation(for question: Question) async -> Writing {
        start(for: question)
        guard let task = tasks[question.id] else { return Writing(text: nil, failure: nil) }
        return await task.value
    }

    /// 모든 작업을 멈추고 비운다. 멈춘 작업은 ``CommentaryWriter`` 안에서 실패로 끝나고 아무도 그 결과를 안 쓴다.
    func cancelAll() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
    }
}
