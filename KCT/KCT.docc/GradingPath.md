# 채점의 두 갈래

**규칙으로 먼저, 안 되면 뜻으로.** 이 한 문장이 채점 설계의 전부입니다.

## Overview

같은 앱 안에 채점기가 둘 있습니다.

| | ``RuleGrader`` | ``MeaningGrader`` |
|---|---|---|
| 판정 근거 | 값 비교 | 온디바이스 모델 |
| 다루는 방식 | 선다형 · O/X | 직접입력 |
| 속도 | 즉시 | 잠깐 걸린다 |
| 모델이 없는 기기 | **동작한다** | 실패한다 |
| 같은 답에 같은 결과 | 항상 | 보장 못 함 |

선다형에서 정답은 딱 하나로 정해져 있습니다. 거기에 모델을 쓰면 느리고, 모델이
없는 기기에서는 채점이 아예 안 되고, 같은 답에 다른 결과가 나올 수도 있습니다.
**규칙으로 될 일에 모델을 쓰지 않습니다.**

반대로 직접입력은 규칙으로 안 됩니다. 어르신은 "세종대왕" 을 "세종" 이라고,
"1948년" 을 "천구백사십팔년" 이라고 씁니다. 글자를 그대로 비교하면 다 틀리게 됩니다.

## `nil` 이 신호다

``RuleGrader/grade(_:userAnswer:)`` 는 `Bool` 이 아니라 **`Bool?`** 을 돌려줍니다.

```swift
if let byRule = RuleGrader.grade(item, userAnswer: answer) {
    // 규칙으로 정해졌다
} else {
    // nil — "나는 못 정한다, 뜻으로 봐 달라"
}
```

`nil` 은 "틀렸다" 가 아니라 **"내 소관이 아니다"** 입니다. 이 신호 하나로
``QuizSession`` 이 두 채점기를 순서대로 부를 수 있고, 새 출제 방식이 생겨도
분기를 늘리지 않습니다.

## O/X 문구가 채점기에 있는 이유

``RuleGrader/trueLabel`` 과 ``RuleGrader/falseLabel`` 이 화면이 아니라 채점기에
있습니다. 어색해 보이지만 이유가 있습니다.

화면이 "맞아요" 를 보여주는데 채점기가 "예" 를 기대하면 **모든 O/X 문제가
틀리게 됩니다.** 그리고 그 버그는 조용합니다 — 크래시도 경고도 없고, 그냥
어르신이 매번 틀립니다.

한곳에서 정의하면 어긋날 수가 없습니다.

## 실패는 화면에 내지 않는다

``MeaningGrader/grade(question:userAnswer:)`` 는 실패하면 오류를 던집니다.
``QuizSession`` 이 그것을 **조용히 오답으로** 처리합니다.

어르신에게 "모델을 사용할 수 없습니다" 는 아무 의미가 없습니다. 그리고 이 앱은
화면에 부정적 표현을 쓰지 않기로 했습니다 — 오답도 "다시 볼 문제 / 곧 다시 만나요"
로 표시합니다.

> Note: 선다형·O/X 가 ``RuleGrader`` 로 처리되기 때문에, 모델이 없는 기기에서도
> **앱 전체가 멈추지 않습니다.** 사다리 최고 칸(직접입력)만 영향을 받습니다.

## 결과가 진척으로 이어지는 곳

판정이 끝나면 두 가지가 일어납니다. **세는 일과 사다리를 옮기는 일이 갈라져 있습니다.**

- ``QuestionProgress/countAttempt(correct:now:)`` — **모든 문항**을 맞힌 개수에 센다
- ``QuestionProgress/moveLadder(correct:now:)`` — 사다리를 한 칸 움직인다.
  ``QuizItem/affectsProgress`` 가 `false` 인 **격려용 슬롯은 건너뜁니다**
  (대신 ``QuestionProgress/nudgeLadder(correct:)`` 가 바닥 칸에서만 한 칸 올려 줍니다)

> Note: 이름에 `now:` 가 있지만 **지금은 쓰이지 않습니다.** 원래 여기서
> ``QuestionProgress/nextDueAt`` 을 다시 잡았는데, `record()` 를 셋으로 나눌 때
> 그 줄이 빠졌습니다. 되살릴 자리는 <doc:SessionPlanning> 의 「아직 쓰이지 않는 것」에
> 적어 두었습니다.

자세한 것은 <doc:TwoAxes> 의 「격려용 슬롯」 절에 있습니다.

``GradingResult`` 는 두 채점기가 함께 쓰는 결과 타입입니다.
규칙 채점일 때는 `reason` 을 빈 문자열로 둡니다 — 설명할 것이 없기 때문입니다.

## See Also

- ``RuleGrader``
- ``MeaningGrader``
- ``QuizSession``
- <doc:TwoAxes>
