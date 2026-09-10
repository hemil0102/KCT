# 채점의 세 층

**규칙으로 먼저, 코드로 다음, 그래도 안 되면 모델로.** 이 한 문장이 채점 설계의 전부입니다.

## Overview

같은 앱 안에 채점기가 셋 있습니다. 아래로 갈수록 느리고 덜 확실합니다.

| | ``RuleGrader`` | ``AnswerMatcher`` | ``AnswerChecker`` |
|---|---|---|---|
| 판정 근거 | 값 비교 | 글자·집합 비교 | 온디바이스 모델 |
| 다루는 것 | 선다형 · O/X | 직접입력의 확실한 것 | 남은 것 |
| 속도 | 즉시 | 즉시 | 몇 초 |
| 모델이 없는 기기 | **동작한다** | **동작한다** | 실패한다 |
| 같은 답에 같은 결과 | 항상 | 항상 | 보장 못 함 |

**답이 하나로 정해지는 일은 위쪽 둘이 합니다.** 「고죠선 = 고조선인가」는 답이 하나뿐이라
95%를 맞혀도 못 씁니다 — 나머지 5%가 언제 나올지 모르고, 어제 맞힌 것을 오늘 틀려도
원인을 찾을 수 없습니다.

> Important: 2026-09-10 에 지침을 여섯 번 고치는 동안 **한 글자 오타**(「고죠선」·「태국가」·
> 「단검왕검」)가 계속 통과했습니다. 모델은 한글을 글자가 아니라 **조각(token)** 으로 읽어
> 「몇 번째 글자가 다른가」를 물어볼 수단 자체가 없습니다. 반대로 아예 다른 답
> (「홍길동/안익태」)은 10건 모두 걸렀습니다. **글자는 코드가, 뜻은 모델이.**

## `nil` 이 신호다

``RuleGrader/grade(_:userAnswer:)`` 는 `Bool` 이 아니라 **`Bool?`** 을 돌려줍니다.

```swift
if let byRule = RuleGrader.grade(item, userAnswer: answer) {
    // 규칙으로 정해졌다
} else {
    // nil — "나는 못 정한다, 아래층으로 넘겨라"
}
```

`nil` 은 「틀렸다」가 아니라 **「내 소관이 아니다」** 입니다. ``AnswerMatcher/Outcome`` 의
`needsModel` 도 같은 역할을 합니다 — 층마다 「여기서 끝났다」와 「못 정했다」를 구별해
돌려주므로, ``QuizSession/judge(_:answer:)`` 가 분기를 늘리지 않고 순서대로 부를 수 있습니다.

## 답의 모양이 길을 정한다

``AnswerMatcher/check(_:against:shape:from:)`` 는 ``AnswerShape`` 를 받아 갈립니다.
**정답 글자를 보고 짐작하지 않고 문항이 밝힌 것을 씁니다.**

| ``AnswerShape`` | 어떻게 판정하나 | 문항 수 |
|---|---|---|
| ``AnswerShape/word`` | 표기 후보와 글자 비교. 한 글자만 다르면 오타로 확정 | 911 |
| ``AnswerShape/closedList`` | 항목을 집합으로 만들어 **같아야** 정답 | 32 |
| ``AnswerShape/openList`` | 정답 항목을 **셋 이상** 대면 정답 | 13 |
| ``AnswerShape/sentence`` | 코드가 손대지 않고 모델에게 넘긴다 | 174 |

집합으로 견주므로 **순서는 저절로 무시됩니다.** 「신라 백제 고구려」는 정답이고,
「신라 백**재** 고구려」는 한 항목이 달라 오답입니다.

> Note: ``AnswerShape`` 는 답의 **모양**이고 ``AnswerKind`` 는 **주제**입니다. 축이 둘인
> 이유는 「고구려, 백제, 신라」가 목록이면서 동시에 ``AnswerKind/place`` 이기 때문입니다.
> 채점은 모양을 보고, 해설은 주제를 봅니다.

## 표기가 여럿인 정답 — `/`

``Question/answer`` 는 인정할 표기를 **전부** 담습니다.

```
"삼일절/3.1절/31절"
```

`/` 를 아는 곳은 둘뿐입니다 — ``AnswerMatcher`` 가 채점에 쓰고, ``Question/displayAnswer`` 가
**맨 앞엣것**을 화면·보기·해설에 씁니다. 그래서 JSON 에는 정식 명칭을 맨 앞에 둡니다.

`,` 와 뜻이 다릅니다. **`/` 는 아무거나 맞고, `,` 는 다 대야 맞습니다.**

## 판정 근거를 남긴다

로그에 남는 `basis` 는 **누가 무엇을 보고 정했는지**를 낱말이 아니라 값으로 남깁니다.
그래야 셀 수 있습니다.

| 열거형 | 누가 고르나 | 값 |
|---|---|---|
| ``MatchBasis`` | 코드 | `exactMatch` · `typo` · `listMismatch` · `phoneticMatch` |
| ``CheckBasis`` | 모델 (`@Generable`) | `differentName` · `differentLetters` · `sameMeaning` … |

**둘을 한 열거형에 두지 않습니다.** 모델이 `exactMatch` 를 고를 수 있으면
「`exactMatch` 가 많으면 코드가 일하고 있다」는 확인이 거짓이 됩니다.

## 실패는 화면에 내지 않는다

``AnswerChecker/check(answer:correctAnswer:shape:)`` 는 실패하거나 시한을 넘기면 오류를
던지고, ``QuizSession`` 이 그것을 **조용히 오답으로** 처리합니다.

어르신에게 「모델을 사용할 수 없습니다」는 아무 의미가 없습니다. 그리고 이 앱은 화면에
부정적 표현을 쓰지 않기로 했습니다 — 오답도 「다시 볼 문제 / 곧 다시 만나요」로 표시합니다.

시한은 `withTimeout(seconds:_:)` 이 겁니다. **안 돌아오는 것과 실패하는 것을 같게** 만들어,
부르는 쪽이 `catch` 하나만 쓰면 되게 합니다.

> Note: 위 두 층이 코드라서, 모델이 없는 기기에서도 **직접입력의 상당수가 그대로 채점됩니다.**

## O/X 문구가 채점기에 있는 이유

``RuleGrader/trueLabel`` 과 ``RuleGrader/falseLabel`` 이 화면이 아니라 채점기에 있습니다.
화면이 「맞아요」를 보여주는데 채점기가 「예」를 기대하면 **모든 O/X 문제가 틀리게 됩니다.**
그리고 그 버그는 조용합니다 — 크래시도 경고도 없고, 그냥 어르신이 매번 틀립니다.

## 결과가 진척으로 이어지는 곳

판정이 끝나면 두 가지가 일어납니다. **세는 일과 사다리를 옮기는 일이 갈라져 있습니다.**

- ``QuestionProgress/countAttempt(correct:now:)`` — **모든 문항**을 맞힌 개수에 센다
- ``QuestionProgress/moveLadder(correct:now:)`` — 사다리를 한 칸 움직인다.
  ``QuizItem/affectsProgress`` 가 `false` 인 **격려용 슬롯은 건너뜁니다**
  (대신 ``QuestionProgress/nudgeLadder(correct:)`` 가 바닥 칸에서만 한 칸 올려 줍니다)

자세한 것은 <doc:TwoAxes> 의 「격려용 슬롯」 절에 있습니다.

``GradingResult`` 는 세 층이 함께 쓰는 결과 타입입니다. 모델이 만드는 것은 ``AnswerCheck``
이고, ``GradingResult`` 는 **화면과 로그가 쓰는 것**이라 `@Generable` 이 아닙니다.

## See Also

- ``RuleGrader``
- ``AnswerMatcher``
- ``AnswerChecker``
- ``AnswerShape``
- ``QuizSession``
- <doc:TwoAxes>
