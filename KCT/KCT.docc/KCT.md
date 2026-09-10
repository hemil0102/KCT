# ``KCT``

70대 어르신이 아무것도 고르지 않아도 귀화 시험 문제를 매일 조금씩 익히게 하는 앱.

## Overview

이 앱은 하루 **5문제**를 냅니다. 무엇을 낼지, 어떻게 물을지는 **앱이 정합니다** —
사용자는 답만 고르면 됩니다.

핵심은 같은 문제를 **점점 어렵게 묻는 것**입니다. 맞히면 한 칸 위 방식으로,
틀리면 한 칸 아래로 옮깁니다.

```
2지선다 → O/X → 4지선다 → 직접입력 → 마스터
```

이 사다리와 "문제 자체의 난이도" 는 **전혀 다른 축**입니다. 이 구분이 설계의
중심이고, 섞으면 코드 전체가 이상해 보입니다. 먼저 <doc:TwoAxes> 를 읽으세요.

### 한 바퀴 흐름

문제 한 개가 화면에 뜨고 채점되어 기록되기까지:

| 무엇이 | 누가 |
|---|---|
| 문제·낱말을 읽어 온다 | ``ContentFile`` → ``QuestionCatalog`` · ``GlossaryCatalog`` |
| 이번 회차를 계획한다 | ``SessionBuilder`` |
| 묻는 방식대로 재료를 만든다 | ``QuizItem`` |
| 회차를 진행하고 결정한다 | ``QuizSession`` |
| 화면에 그린다 | ``QuizView`` → ``QuestionScreen`` |
| 정오답을 판정한다 | ``RuleGrader`` → ``AnswerMatcher`` → ``AnswerChecker`` |
| 사다리를 올리거나 내린다 | ``QuestionProgress`` |
| 틀리면 해설을 쓴다 | ``CommentaryWriter`` → ``FeedbackSheet`` |
| 무엇이 있었는지 남긴다 | ``ObsRecord`` · ``ModelFailure`` → ``ObsUploader`` |

### 의존성은 한 방향

`Data` 는 아무것도 모르고, 색·조판·낭독은 도메인을 모르며, 화면만 전부를 압니다.
각 타입의 문서에 **"건드리지 않는 것"** 이 적혀 있습니다 — 무엇을 하는지보다
무엇을 하지 않는지가 역할을 규정합니다.

> Note: 저장소를 **어떤 순서로 읽을지**와 단계별 실습은 저장소 루트의
> `STUDY_GUIDE.md` 에 있습니다. 이 문서는 개념과 심볼을 잇는 쪽을 담당합니다.

## Topics

### 먼저 읽을 개념

- <doc:TwoAxes>
- <doc:SessionPlanning>
- <doc:GradingPath>
- <doc:FeedbackModal>
- <doc:FocusLayers>
- <doc:ElderAccessibility>

### 문제 콘텐츠 — 변하지 않는 데이터

- ``Question``
- ``QuestionPayload``
- ``QuestionFact``
- ``QuestionCatalog``
- ``ContentFile``
- ``GlossaryEntry``
- ``GlossaryPayload``
- ``GlossaryCatalog``

### 학습 진척 — 변하는 데이터

- ``AskingMode``
- ``QuestionProgress``

### 관찰 기록 — 무슨 일이 있었나

- ``ObsRecord``
- ``ModelFailure``
- ``ModelFailureDraft``
- ``ObsUploader``

### 이번 회차 출제 구성

- ``SessionBuilder``
- ``QuizItem``
- ``ModePayload``
- ``SessionMode``

### 채점

- ``RuleGrader``
- ``AnswerMatcher``
- ``AnswerChecker``
- ``AnswerCheck``
- ``GradingResult``
- ``CommentaryWriter``
- ``Writing``
- ``Commentary``
- ``ChoiceNote``
- ``EncouragementWriter``

### 답을 보는 낱말들

- ``AnswerShape``
- ``AnswerKind``
- ``AnswerSource``
- ``MatchBasis``
- ``CheckBasis``

### 묻는 대상 하이라이트

- ``QuestionFocus``
- ``QuestionFocusExtractor``
- ``FocusStore``
- ``FocusAnalyzer``
- ``QuestionFocusRecord``
- ``GeneratedFocus``

### 회차 진행과 화면

- ``QuizSession``
- ``QuizView``
- ``QuestionScreen``
- ``GradingScreen``
- ``ResultScreen``

### 색 · 조판 · 낭독 · 부품

- ``AppColor``
- ``KoreanText``
- ``SpeechReader``
- ``ChoiceButton``
- ``PrimaryActionButton``
- ``SessionProgressBar``

### 앱 시작점

- ``KCTApp``
- ``RootView``
