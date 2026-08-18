# 두 개의 축

이 앱에서 "난이도" 라는 말은 **두 가지 다른 것**을 가리킵니다. 그 둘을 섞지 않는 것이
설계의 전부입니다.

## Overview

같은 질문을 두 사람이 던진다고 생각해 보세요.

- **"이 문제는 어려운 문제인가?"** — 문항 자체의 성질입니다. 누가 풀어도 같습니다.
- **"이 사람에게 이 문제를 얼마나 쉽게 물어야 하나?"** — 사람과 시점에 따라 달라집니다.

첫 번째가 축 A, 두 번째가 축 B입니다.

| | 축 A · 문제 고유 난이도 | 축 B · 묻는 방식 |
|---|---|---|
| 어디 있나 | ``Question/difficulty`` | ``QuestionProgress/mode`` (``AskingMode``) |
| 성격 | **고정** — 문제집에 적혀 온다 | **동적** — 맞히고 틀리며 변한다 |
| 무엇을 정하나 | 새 문제의 **도입 순서**만 | 이번에 **어떻게 물을지** |
| 누가 읽나 | ``SessionBuilder/introduceOrder(_:)`` | ``SessionBuilder/shapeRound(_:progressByID:focusByID:)`` |

### 축 A는 순서만 정한다

쉬운 문제가 먼저 등장합니다. 그게 전부입니다. 축 A는 **"어떻게 물을지" 에 관여하지
않습니다** — 어려운 문제도 처음 만날 때는 2지선다로 물어봅니다.

``SessionBuilder/introduceOrder(_:)`` 가 `difficulty` 오름차순으로 줄을 세우되
단원을 번갈아 꺼내서, 쉬운 순서를 지키면서도 한 단원에 편식하지 않게 합니다.

### 축 B는 모든 문제가 같은 사다리를 탄다

```
binaryChoice(0) → trueOrFalse(1) → multipleChoice(2) → typing(3) → 마스터
```

``QuestionProgress/record(correct:now:)`` 가 이 이동을 담당합니다.
맞히면 한 칸 위, 틀리면 한 칸 아래. 최고 칸(``AskingMode/typing``)에서 맞히면
``QuestionProgress/isMastered`` 가 켜집니다.

사다리를 문제마다 다르게 만들지 않는 이유는 **진척을 비교할 수 있어야** 하기
때문입니다. 어떤 문제는 3칸, 어떤 문제는 5칸이면 "얼마나 익혔나" 를 셀 수 없습니다.

### 왜 이름이 `AskingMode` 인가

예전 이름은 `DifficultyMode` 였습니다. 그래서 ``Question/difficulty`` 와 낱말이
겹쳐 두 축이 계속 헷갈렸습니다.

`AskingMode` 는 **"묻는 방식"** 이라고 말합니다. 이름이 축을 구분해 주면 주석으로
설명할 일이 줄어듭니다.

### 마스터해도 끝이 아니다

``QuestionProgress/isMastered`` 가 켜지면 다음 출제는 1년 뒤로 밀립니다.
하지만 아예 사라지지는 않습니다 — ``SessionBuilder`` 가 매 회차 **한 칸을 마스터
복습용으로 비워 둡니다.** 익힌 것도 계속 만나야 잊지 않기 때문입니다.

### 격려용 슬롯은 축 B를 건드리지 않는다

회차의 첫 문제와 마지막 문제는 진척과 무관하게 항상 2지선다로 냅니다.
쉽게 시작하고 쉽게 끝나야 계속하고 싶어집니다.

대신 그 두 문제는 ``QuizItem/affectsProgress`` 가 `false` 라서
``QuestionProgress/record(correct:now:)`` 를 부르지 않습니다.
**일부러 쉽게 낸 문제를 맞혔다고 승급시키면 사다리가 망가집니다.**

## 문제 id는 영구 고정

두 축을 잇는 것은 문제 id 하나입니다. ``QuestionProgress/questionID`` 가
``Question/id`` 를 가리킵니다.

> Important: id를 재사용하면 **남의 학습 기록이 엉뚱한 문제에 붙습니다.**
> 문제를 지우더라도 그 번호는 다시 쓰지 마세요.

이 분리 덕분에 문제집을 통째로 갈아끼워도(``QuestionCatalog/replace(with:)``)
학습 기록이 살아남습니다.

## See Also

- ``AskingMode``
- ``QuestionProgress``
- <doc:SessionPlanning>
