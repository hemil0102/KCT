//
//  ModelFailure.swift
//  KCT
//
//  역할 : 모델이 글을 못 만들었을 때 무엇을 시켰는지 그대로 남긴다
//  요점 : 안전 필터에 걸린 이유는 우리가 보낸 글에 있다. 그 글이 없으면 고칠 수가 없다
//
//  ── 구성 ──────────────────────────────────────────────
//  ModelFailureDraft           만들다 실패한 그 자리에서 채우는 값 (저장 아님)
//  ModelFailure (@Model)       폰에 남는 한 줄
//  ├─ occurredAt               언제
//  ├─ job                      무슨 일을 시켰나 (commentary · note)
//  ├─ questionID               어느 문항
//  ├─ reason                   오류 문구 그대로
//  ├─ instructions / prompt    실제로 보낸 글 전문
//  └─ uploadedAt               서버로 갔나. nil 이면 아직
//
//  ── 흐름 ──────────────────────────────────────────────
//  CommentaryWriter 가 실패하면 ModelFailureDraft 를 함께 돌려준다
//    → QuizSession 이 ModelFailure 로 만들어 저장한다
//    → ObsUploader 가 관찰 기록과 함께 서버로 보낸다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : CommentaryWriter(만든다) · QuizSession(저장) · ObsUploader(보낸다)
//  기대는 것    : SwiftData
//  건드리지 않는 것 : 화면 — 어머니에게는 아무것도 안 보인다
//

import Foundation
import SwiftData

/// 실패한 자리에서 채우는 값. **아직 저장된 것이 아니다.**
///
/// 글을 만드는 쪽(``CommentaryWriter``)은 저장소를 모르므로, 무엇을 시켰는지만 담아
/// 돌려주고 저장은 ``QuizSession`` 이 합니다.
struct ModelFailureDraft {
    /// 무슨 일을 시켰나. `"commentary"`(정답 해설) · `"note"`(고른 답 설명)
    let job: String
    let questionID: Int
    let reason: String
    let instructions: String
    let prompt: String
}

/// 모델이 실패한 한 번의 기록.
///
/// `Response may contain sensitive or unsafe content` 는 **우리가 보낸 글** 때문에 납니다.
/// 그런데 그 글은 매번 조금씩 달라서(재료를 섞어 뽑으므로) 나중에 되살릴 수가 없습니다.
/// **그 자리에서 통째로 남겨야** 무엇을 고칠지 알 수 있습니다.
///
/// - Note: ``ObsRecord`` 와 같은 방식으로 쌓였다가 나중에 올라갑니다 —
///   ``uploadedAt`` 이 `nil` 인 줄이 곧 재시도 큐입니다.
@Model
final class ModelFailure {
    var occurredAt: Date
    var job: String
    var questionID: Int
    var reason: String
    var instructions: String
    var prompt: String

    /// 서버로 올라간 시각. `nil` 이면 **아직 안 올라간 것**입니다.
    var uploadedAt: Date?

    init(draft: ModelFailureDraft, occurredAt: Date = .now) {
        self.occurredAt = occurredAt
        self.job = draft.job
        self.questionID = draft.questionID
        self.reason = draft.reason
        self.instructions = draft.instructions
        self.prompt = draft.prompt
    }
}
