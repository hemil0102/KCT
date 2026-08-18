# 이번 회차를 어떻게 정하나

어르신이 아무것도 고르지 않아도 되게 하려면, 그 선택을 누군가 대신해야 합니다.
``SessionBuilder`` 가 그 일을 합니다.

## Overview

"오늘 뭘 공부할까?" 는 어르신에게 물어서는 안 되는 질문입니다. 물어보면 매일
같은 것을 고르거나, 고르기 싫어서 앱을 열지 않게 됩니다.

그래서 ``SessionBuilder/build(size:progressByID:focusByID:now:)`` 가 네 단계로
회차를 짭니다. 각 단계는 이름 있는 함수라서, 알고리즘이 문장처럼 읽힙니다.

### 1단계 · 후보 걸러내기

``SessionBuilder/isUnlocked`` 를 통과한 문제만 후보가 됩니다. 지금은 항상 통과합니다.

이건 **이음새(seam)** 입니다 — 앞으로 "읽은 콘텐츠의 문제만 개방" 하는 스토리 모드를
넣을 때, 이 클로저 하나만 갈아끼우면 나머지 코드는 그대로입니다.

### 2단계 · 세 줄 세우기

후보를 성격별로 세 줄로 나눕니다 (``SessionBuilder/Queues``).

| 줄 | 무엇 | 순서 | 만드는 곳 |
|---|---|---|---|
| 복습 | 나온 적 있고 아직 마스터 못 함 | 예정 시각 이른 순 → 쉬운 순 | ``SessionBuilder/reviewQueue(from:progressByID:)`` |
| 신규 | 아직 한 번도 안 나옴 | 쉬운 순 + 단원 번갈아 | ``SessionBuilder/newcomerQueue(from:progressByID:)`` |
| 마스터 | 직접입력까지 맞힘 | 랜덤 | ``SessionBuilder/masteredQueue(from:progressByID:)`` |

``SessionBuilder/Queues/learning`` 은 **복습 + 신규** 순서로 이어 붙입니다.
이 순서가 정책입니다 — **배운 것을 굳히는 편이 새것을 들이는 것보다 먼저**입니다.

### 3단계 · 칸 채우기

``SessionBuilder/fillSlots(size:from:)`` 가 5칸을 채웁니다. 순서가 규칙입니다.

1. 학습 문제(복습+신규)로 먼저 채운다 — 단 **마스터 복습용 1칸을 미리 비워 둔다**
2. 비워 둔 칸을 마스터 문제로 메운다
3. 둘 다 모자라면 남은 학습 문제로 마저 채운다
4. **섞는다**

마지막에 섞는 이유: 마스터 문제가 늘 끝자리에만 오면 "이제 쉬운 거 나올 차례" 라는
패턴이 생겨 복습 효과가 떨어집니다.

### 4단계 · 모양 잡기

``SessionBuilder/shapeRound(_:progressByID:focusByID:)`` 가 각 문제에 묻는 방식을
배정하고 ``QuizItem`` 으로 완성합니다.

- 보통 문제 → ``QuestionProgress/mode`` 가 기억한 칸
- **첫·마지막 문제 → 항상 ``AskingMode/binaryChoice``**, 그리고
  ``QuizItem/affectsProgress`` 는 `false`

자세한 이유는 <doc:TwoAxes> 의 「격려용 슬롯」 절에 있습니다.

## 진척은 읽기만 한다

``SessionBuilder`` 는 ``QuestionProgress`` 를 **읽기만** 합니다. 승급·강등 기록은
채점이 끝난 뒤 ``QuizSession`` 이 합니다.

계획을 세우는 일과 결과를 남기는 일을 한 타입에 두면, "계획하다가 기록이 바뀌는"
상황이 생겨 같은 입력에도 다른 회차가 나옵니다. 그러면 테스트할 수 없습니다.

## 아직 쓰이지 않는 것

> Note: ``SessionBuilder/build(size:progressByID:focusByID:now:)`` 의 `now` 는
> **어느 판단에도 쓰이지 않습니다.** 복습은 `nextDueAt` 이 이른 **순서만** 쓰고,
> "지금 시점이 지났는가" 로 걸러내지 않습니다.
>
> 즉 미마스터 문제는 항상 후보이며, 회차를 언제나 꽉 채웁니다. 하루에 한 번만
> 공부하는 사람에게는 이 편이 낫습니다 — 오늘 볼 게 없다고 빈 화면을 보여주면
> 앱을 다시 열지 않습니다.

## See Also

- ``SessionBuilder``
- ``QuizItem``
- <doc:TwoAxes>
- <doc:GradingPath>
