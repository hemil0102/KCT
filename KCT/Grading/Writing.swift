//
//  Writing.swift
//  KCT
//
//  역할 : 모델에게 글 한 덩어리를 시킨 결과. 성공하면 글, 실패하면 무엇을 시켰는지
//  요점 : 실패를 nil 로만 돌려주면 「왜 실패했는지」가 사라진다
//
//  ── 구성 ──────────────────────────────────────────────
//  Writing
//  ├─ text      만들어진 글. 실패했거나 시킬 재료가 없었으면 nil
//  ├─ failure   실패했을 때 무엇을 시켰는지 (ModelFailureDraft). 성공이면 nil
//  └─ empty     둘 다 nil — 「아예 시키지 않았다」
//
//  ── 왜 셋이 필요한가 ───────────────────────────────────
//  결과가 세 가지다. 「글이 왔다」·「시켰는데 실패했다」·「시킬 재료가 없어 안 시켰다」.
//  세 번째를 두 번째와 섞으면 **실패 기록에 빈 프롬프트가 쌓인다** — 보낸 게 없는데
//  안전 필터에 걸렸다고 적히는 셈이다. 그래서 empty 를 따로 둔다.
//
//  ── 이 파일이 생긴 이유 ────────────────────────────────
//  세 writer(CommentaryWriter · EncouragementWriter · GlossaryExampleWriter)가
//  함께 쓰는 타입인데, 그중 한 파일(CommentaryWriter.swift) 안에 숨어 있었다.
//  "이 타입을 보려면 어느 파일을 열지"가 곧 "누가 주인인지"라서, 주인이 셋이면
//  파일을 따로 둔다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : CommentaryWriter · GlossaryExampleWriter · ModelCall.generate ·
//                QuizSession(failure 를 꺼내 저장한다) · QuestionScreen
//  기대는 것    : ModelFailureDraft(Observation/ModelFailure.swift)
//  건드리지 않는 것 : 실패를 저장·업로드하는 일 — QuizSession·ObsUploader 의 몫
//

import Foundation

/// 글 한 덩어리를 만든 결과. **성공하면 글이, 실패하면 무엇을 시켰는지가 담긴다.**
///
/// 실패를 `nil` 로만 돌려주면 「왜 실패했는지」가 사라집니다. 안전 필터에 걸린 이유는
/// **우리가 보낸 글 안에** 있으므로, 그 글을 함께 들고 나옵니다.
struct Writing {
    /// 만들어진 글. 실패했거나 애초에 안 시켰으면 `nil`.
    let text: String?

    /// 실패했을 때 무엇을 시켰는지. 성공했거나 안 시켰으면 `nil`.
    let failure: ModelFailureDraft?

    /// **아예 시키지 않았다.** 기기가 모델을 지원 안 하거나, 시킬 재료가 없을 때.
    ///
    /// 보낸 것이 없으니 남길 실패도 없습니다 — `failure` 까지 `nil` 인 것이 이 값의 뜻입니다.
    static let empty = Writing(text: nil, failure: nil)
}
