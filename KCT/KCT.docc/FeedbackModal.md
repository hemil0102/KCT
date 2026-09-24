# 답을 확인하는 두 창

**고른 답도 어딘가의 정답이다.** 그것부터 알려 주고 정답으로 넘어갑니다.

## Overview

한 문제를 풀면 **맞아도 틀려도 창이 뜹니다.** 두 창이 같은 부품으로 만들어져 있어,
어머니가 「이건 다른 창」이라고 새로 배우지 않아도 됩니다.

| 언제 | 창 | 두 박자 |
|---|---|---|
| 틀렸을 때 | ``FeedbackSheet`` | ❌ 고른 답 → 「정답 보기」 → ✅ 정답·해설 |
| 맞았을 때 | ``CorrectAnswerSheet`` | 접힘(「잘 맞추셨어요!」) → 「정답 해설 보기」 → 펼침 |

오답 창을 한 화면에 다 쏟지 않는 이유 — 정답이 처음부터 보이면 **고른 답을 읽지 않고**
정답으로 눈이 갑니다. 한 번 누르는 사이에 「내가 무엇을 골랐더라」가 한 박자 남습니다.

정답 창은 반대로 **해설을 보는 것 자체가 선택**입니다. 안 봐도 되는 사람은 접힌 채로
바로 「다음 문제」를 누를 수 있게 두 버튼을 처음부터 나란히 뒀습니다.

## 고른 답도 설명한다

추석 문제에 「개천절」을 고르셨다면, **개천절도 어딘가의 정답**입니다.
``QuestionCatalog/question(answering:)`` 이 그 문항을 찾아오고,
``CommentaryWriter/describe(_:)`` 가 그 문항의 ``Question/facts`` 로 한 문장을 만듭니다.

**나무라는 것이 아니라 하나 더 알려 드리고 넘어가는 것**입니다.

O/X 는 고른 답이 「맞아요」·「아니에요」라 그 자체로는 설명할 것이 없습니다.
실제로 판단한 것은 진술문 안의 낱말이므로 ``QuizItem/judgedTerm(for:)`` 가 그것을 꺼냅니다.

> Note: 「고죠선」 같은 오타는 어느 문항의 정답도 아니라 설명할 재료가 없습니다.
> 그때는 지어내지 않고 ``CommentaryPlaceholder/noteFailed``(「정답을 살펴볼까요?」)로
> 다음 걸음을 알려 줍니다. 「아직 안 왔다」와 「재료가 없다」를 가르는 깃발이
> ``IncorrectCommentary/expectsNote`` 입니다 — 앞이면 자리를 비워 두고 기다리게 하고,
> 뒤면 그 줄을 아예 안 그립니다.

## 색이 뜻을 나른다

| 자리 | 색 | 왜 |
|---|---|---|
| ❌ 고르신 답 배지·글 속 낱말 | ``AppColor/wrongAccent`` 짙은 분홍 (배지 배경 ``AppColor/wrongHeader``) | 채도를 낮춰 놀라지 않게 |
| ✅ 정답 배지·글 속 낱말 | ``AppColor/answerSheetAccent`` 진한 녹색 (배지 배경 ``AppColor/answerSheetBadge``) | 「정답 = 녹색」이 뜻에 맞다 |
| 본문 | 검정 | **칠하는 것은 낱말뿐** |
| 창 배경 | ``AppColor/signature`` 보라, 진하기 0.75 | 두 창이 같다 |

같은 낱말이 **배지와 글 속 두 곳**에서 같은 색으로 보이면 눈이 그 색을 그 낱말로 배웁니다.
배지가 따로 있어야 하는 이유는 하나 더 있습니다 — **해설 문장에 정답 낱말이 아예 안 나오는
문항이 있습니다**(정답 「고조선」, 해설 「고는 옛날이라는 뜻이에요…」). 그때는 배지가 혼자
그 역할을 떠맡습니다.

> Important: 분홍·녹색은 **두 창 안에서만** 씁니다. 목록과 결과 화면의 「다시 볼 문제」는
> 여전히 시그니처 색입니다 — 그쪽은 「틀렸다」가 아니라 「또 만날 문제」이기 때문입니다.
>
> 한때 창 자체를 색으로 갈라 봤습니다(정답 연두 · 오답 주황). 되돌린 이유는 **밝은
> 배경이 흰 글자를 못 받쳐서**입니다 — 제목과 버튼까지 그 계열의 진한 색으로 바꿔야 했고,
> 그러면 앱의 다른 화면과 따로 놀았습니다. 맞았는지 틀렸는지는 창 색이 아니라
> **줄머리 배지**가 알려 줍니다.

## 두 창이 같은 부품을 쓴다

한때 두 창이 카드·배지·본문·시트 외장·상수 네 개를 **각자 한 벌씩** 들고 있었습니다.
``CorrectAnswerSheet`` 의 주석이 「``FeedbackSheet`` 의 것과 똑같다」고 스스로 적고 있었는데,
**똑같다는 것을 주석으로 적어야 하는 상태가 곧 갈라질 상태**입니다 — 한쪽만 고치면
주석은 그대로 남고 화면만 어긋납니다.

| 부품 | 무엇 |
|---|---|
| ``CommentaryMetrics`` | 제목 21 · 본문 21 · 이모지 20 · 버튼 64 · 배경 진하기 0.75 |
| ``CommentarySheetTitle`` | 보라 배경 위 흰 제목 한 줄 |
| ``CommentaryCard`` | 완전 불투명 흰 카드 (모서리 16) |
| ``CommentaryRow`` | 이모지 + 낱말 배지가 한 줄, 그 아래 왼쪽 끝부터 설명 |
| ``WordBadge`` | 낱말 배지 (모서리 7) — 낱말 사전 패널의 배지와 같은 모양 |
| ``CommentaryBodyText`` | 도착한 글. 지문과 같은 양쪽 정렬 + 낱말만 칠하기 |
| ``CommentaryBodyStyle`` | 기다리는 동안 보여줄 글의 글꼴 |
| `View.commentarySheetChrome(detents:)` | 배경·크기·손잡이 숨김·스와이프 닫기 막기 |

낱말 사전 창(``GlossaryPanel``)도 **시트 외장만** 같은 것을 씁니다 — 다만 그쪽은
뜻만 확인하고 닫는 자리라 아래로 쓸어내려 닫는 것을 막지 않습니다
(`blocksInteractiveDismiss: false`).

## 기다리는 동안

글은 모델이 만들므로 몇 초 걸립니다. 그동안 **응원 한 줄**이 옅게 맥동합니다.

``EncouragementWriter`` 가 회차를 시작할 때 다섯 개를 뒤에서 만들어 두고,
못 만들었으면 앱에 박힌 ``EncouragementWriter/fallback`` 열 가지에서 뽑습니다.
**어느 쪽이든 화면은 기다리지 않습니다.**

담는 뜻은 하나입니다 — **「실수해도 괜찮아요. 다음에 잘하면 돼요.」**
여러 가지를 담으려 하면 어떤 문구는 위로가 되고 어떤 문구는 재촉이 됩니다.

> Note: 글이 1초 만에 와도 **3초는 유지합니다**(``QuizSession`` 의 `holdWaitingLine`).
> 그러지 않으면 응원 문구가 나타났다 사라집니다. 기다림을 없애는 것이 늘 좋은 것은 아닙니다.

## 맥동을 멈추는 법

`repeatForever` 는 한 번 걸리면 **애니메이션을 `nil` 로 바꿔도 멈추지 않습니다.**
그래서 글이 도착하면 **뷰를 통째로 갈아 끼웁니다** — 맥동하던 뷰가 사라지므로 확실히 멈춥니다.

```swift
if feedback.isReady {
    CommentaryBodyText(text: feedback.commentary, word: ..., color: ...)   // 맥동이 붙을 자리가 없다
} else {
    Text(feedback.commentary)
        .modifier(CommentaryBodyStyle())
        .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
}
```

``IncorrectCommentary/isReady`` 를 「도착했나」가 아니라 **「더 기다릴 것이 있나」**로
둔 것도 같은 이유입니다 — 실패했을 때도 반짝임은 멈춰야 합니다.

## 못 만들었을 때

어르신에게 「모델 오류」는 아무 뜻이 없습니다. **다음에 할 일**을 알려 줍니다.
문구는 ``CommentaryPlaceholder`` 한 곳에 모여 있습니다.

| 어디 | 문구 |
|---|---|
| 아직 만드는 중 | ``CommentaryPlaceholder/waiting`` 「잠시만 같이 살펴봐요.」 |
| 고른 답 설명을 못 만듦 | ``CommentaryPlaceholder/noteFailed`` 「정답을 살펴볼까요?」 |
| 정답 해설을 못 만듦 | ``CommentaryPlaceholder/failed`` 「다음 문제로 이동해주세요.」 |

무엇을 시켰길래 실패했는지는 ``ModelFailure`` 에 지침·프롬프트째 남아 서버로 갑니다 —
안전 필터에 걸린 이유는 **우리가 보낸 글 안에** 있는데, 재료를 섞어 뽑으므로 나중에
되살릴 수 없기 때문입니다. 그 기록을 만드는 자리가 ``ModelCall/generate(job:questionID:instructions:prompt:generating:options:timeout:extract:onFailure:)`` 입니다.

## See Also

- ``FeedbackSheet``
- ``CorrectAnswerSheet``
- ``IncorrectCommentary``
- ``CorrectCommentary``
- ``CommentaryWriter``
- ``EncouragementWriter``
- ``ModelFailure``
- <doc:GradingPath>
