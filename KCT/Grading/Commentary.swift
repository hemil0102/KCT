//
//  Commentary.swift
//  KCT
//
//  역할 : 해설 창에 들어갈 내용 두 가지(오답용·정답용)와, 글이 없을 때 쓸 문구
//  요점 : 창이 뜨는 것과 글이 도착하는 것은 따로다. 그 「아직 안 옴」을 타입이 들고 있는다
//
//  ── 구성 ──────────────────────────────────────────────
//  CommentaryPlaceholder (enum — 값만)   글이 없을 때 자리를 지키는 문구 셋
//  ├─ waiting     "잠시만 같이 살펴봐요."                        아직 만드는 중
//  ├─ failed      "해설을 준비 중입니다. 다음 문제로 이동해주세요."   끝내 못 만들었다
//  └─ noteFailed  "정답을 살펴볼까요?"                           고른 답을 설명할 재료가 없다
//
//  IncorrectCommentary   틀렸을 때 띄울 창의 내용 (고른 답 · 고른 답 설명 · 정답 · 해설)
//  CorrectCommentary     맞혔을 때 띄울 창의 내용 (정답 · 해설)
//  TrueFalseCommentary   O/X 창의 내용 (누른 라벨 · 맞았나 · 바르게 고친 문장 · 해설)
//
//  ── 이 파일이 생긴 이유 ────────────────────────────────
//  두 타입이 ``QuizSession`` 안에 중첩돼 있었다. 그러면 창을 그리는 화면
//  (FeedbackSheet·CorrectAnswerSheet)이 **회차 전체를 아는 타입을 거쳐야** 자기
//  내용을 받는다 — 화면이 필요한 것은 문장 네 줄뿐인데 900줄짜리 세션에 묶여 있었다.
//  최상위로 꺼내니 두 시트가 QuizSession 을 아예 모르게 됐고, 같은 문구가 두 타입에
//  두 벌씩 있던 것도 CommentaryPlaceholder 한 벌로 합쳐졌다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizSession.gradeCurrent()
//    → 창을 먼저 띄운다 (commentary: CommentaryPlaceholder.waiting)
//    → CommentaryWriter 가 글을 만들어 오면 같은 id 로 다시 만들어 갈아 끼운다
//    → 화면은 isReady 로 "더 기다릴 것이 있나"만 보고 맥동을 켜거나 끈다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizSession(만든다) · FeedbackSheet · CorrectAnswerSheet(그린다)
//  기대는 것    : Foundation 뿐. 문제도 진척도 모른다
//  건드리지 않는 것 : 글을 만드는 일 — CommentaryWriter 의 몫이다
//

import Foundation

/// 해설 글이 없을 때 자리를 지키는 문구.
///
/// 줄을 비워 두면 창이 갑자기 짧아져 「뭔가 사라졌나」 싶어집니다. 그리고
/// 어르신에게 「모델 오류」는 아무 뜻이 없으므로, 실패했을 때는 **다음에 할 일**을 알려 줍니다.
enum CommentaryPlaceholder {

    /// 아직 만드는 중일 때.
    static let waiting = "잠시만 같이 살펴봐요."

    /// 끝내 못 만들었을 때(안전 필터에 걸렸거나, 그 밖의 이유로).
    ///
    /// "실패"·"오류"라고 말하지 않습니다 — 어르신에게는 아무 뜻이 없는 말이라,
    /// **아직 준비 중이라는 말 + 다음에 할 일**로 대신합니다. 기다리라는 말만
    /// 계속 두면 **오지 않는 것을 기다리게** 되므로, "다음 문제로 이동해주세요"를
    /// 반드시 같이 둡니다(14차 후속 — 문구를 두 문장으로 늘렸다).
    static let failed = "해설을 준비 중입니다. 다음 문제로 이동해주세요."

    /// **고른 답 설명**이 없을 때.
    ///
    /// 두 경우에 나옵니다 — ① 만들다 실패했을 때 ② 「고죠선」 같은 오타라
    /// 어느 문항의 정답도 아니어서 **설명할 재료가 아예 없을 때.**
    static let noteFailed = "정답을 살펴볼까요?"
}

/// 틀렸을 때 띄우는 창의 내용.
///
/// 창에는 세 덩어리가 있고, 이 타입의 세 값과 하나씩 대응합니다 —
/// 「고르신 것」 · 「이 문제의 답」 · 해설.
///
/// - Note: `commentary` 가 옵셔널이 아닌 이유 — 모델이 해설을 못 만들어도
///   **창은 뜨고 정답은 보여 줍니다.** 그때는 ``CommentaryPlaceholder/failed`` 가 들어갑니다.
///   다만 **로그에는 `nil` 로 남깁니다** — 그래야 실패한 횟수를 셀 수 있습니다.
///   화면에 보여줄 값과 로그에 남길 값은 달라도 됩니다.
struct IncorrectCommentary: Identifiable {

    /// 이 창이 어느 문항 때문에 떴는지. **같은 문항의 창이 자리 잡는 동안
    /// (기다리는 문구 → 도착한 해설로) 값이 그대로라, 시트가 다시 열리지
    /// 않고 내용만 바뀝니다.** (9차에서 겪은 것과 같은 이유로 `QuestionScreen`도
    /// `.sheet(item:)`을 씁니다.)
    let id: Int

    let selectedAnswer: String

    /// 고른 답이 무엇인지 알려 주는 한 문장. 아직 안 왔거나 재료가 없으면 `nil`.
    let selectedNote: String?

    /// 기다리는 동안 보여줄 응원 한 줄. 창이 만들어질 때 정해진다.
    let waitingLine: String

    /// 고른 답 설명이 **올 예정인가.**
    ///
    /// `selectedNote` 가 `nil` 인 이유가 둘이라 깃발이 따로 필요합니다 —
    /// 「아직 안 왔다」와 「어느 문항의 정답도 아니라 설명할 재료가 없다」.
    /// 앞이면 자리를 비워 두고 기다리게 하고, 뒤면 그 줄을 아예 안 그립니다.
    let expectsNote: Bool

    let correctAnswer: String
    let commentary: String

    /// 기다림이 끝났는가. **성공이든 실패든 더 기다릴 것이 없으면 참**입니다.
    ///
    /// 화면은 이 값으로 맥동을 멈춥니다. 「도착했나」가 아니라 「더 기다릴 것이 있나」로
    /// 두는 이유 — 실패했을 때도 반짝임은 멈춰야 합니다.
    var isReady: Bool { commentary != CommentaryPlaceholder.waiting }
}

/// 맞혔을 때 띄우는 창의 내용.
///
/// ``IncorrectCommentary`` 와 달리 **고른 답을 따로 설명하지 않는다** — 이미
/// 맞혔으므로 「무엇을 골랐는지」를 짚을 필요가 없다. 정답 해설 하나만 있으면 된다.
/// 해설을 만드는 방법도 같다 — ``CommentaryWriter/explain(_:length:)`` 의 `.full` 을 그대로 쓴다.
/// "이 답이 왜 맞는지"는 맞고 틀리고와 무관하게 같은 사실(``Question/facts``)에서
/// 나오기 때문에, 오답 해설의 "정답 비교" 부분을 만들던 바로 그 함수를 재활용한다.
struct CorrectCommentary: Identifiable {

    /// 이 창이 어느 문항 때문에 떴는지. (``IncorrectCommentary/id`` 와 같은 이유)
    let id: Int

    let correctAnswer: String
    let commentary: String

    /// 기다림이 끝났는가. (``IncorrectCommentary/isReady`` 와 같은 이유)
    var isReady: Bool { commentary != CommentaryPlaceholder.waiting }
}

/// O/X 를 누른 뒤 띄우는 창의 내용. **맞혔을 때와 틀렸을 때를 한 타입이 맡습니다.**
///
/// 창에는 세 덩어리가 있습니다 —
/// ① 「고르신 답」 + 누른 라벨 배지 (맞힘 녹색 / 틀림 분홍)
/// ② ✅ **바르게 고친 문장** — 화면에 나왔던 문장이 틀렸으면 그 낱말에 줄을 긋고 정답을 이어 쓴다
/// ③ 모델이 쓴 정답 해설
///
/// - Note: O/X 는 고른 답이 「맞아요」·「아니에요」라 그 자체로는 무엇을 판단했는지가
///   안 보입니다. 9/11·9/14 에 어머니가 「내가 뭘 골랐지?」, 「왜 틀렸지?」 한 이유입니다.
///   그래서 누른 라벨과 **정답이 든 문장**을 한 카드에 나란히 둡니다.
///   틀린 낱말은 줄을 그어 한 번만 보이고, 크게 남는 것은 올바른 문장입니다 —
///   노년층에게 틀린 문장을 되풀이하면 오히려 참으로 기억될 수 있기 때문입니다
///   (Skurnik 외 2005, 11차 4-30).
struct TrueFalseCommentary: Identifiable {

    /// 이 창이 어느 문항 때문에 떴는지. (``IncorrectCommentary/id`` 와 같은 이유)
    let id: Int

    /// 어머니가 누른 라벨 — 「맞아요」 또는 「아니에요」.
    let pickedLabel: String

    let isCorrect: Bool

    /// 화면에 나왔던 문장이 참이었나. 거짓이었으면 그 문장 속 낱말에 줄을 긋는다.
    let statementWasTrue: Bool

    /// 화면에 나왔던 문장 속 낱말. 거짓 문장일 때 줄을 그을 대상이다.
    let shownCandidate: String

    let correctAnswer: String

    /// 바르게 고친 문장의 정답 앞·뒤 (``Question/correctedStatementParts()``).
    let sentenceBefore: String
    let sentenceAfter: String

    let commentary: String

    /// 기다림이 끝났는가. (``IncorrectCommentary/isReady`` 와 같은 이유)
    var isReady: Bool { commentary != CommentaryPlaceholder.waiting }
}
