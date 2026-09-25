# ``KCT``

70대 어르신이 아무것도 고르지 않아도 귀화 시험 문제를 매일 조금씩 익히게 하는 앱.

## Overview

이 앱은 한 회차에 **8칸**을 냅니다. 무엇을 낼지, 어떻게 물을지는 **앱이 정합니다** —
사용자는 답만 고르면 됩니다. 그중 한 칸(3·4·5번째 중 하나)은 짝을 잇는
``MatchingQuestionScreen`` 이 차지하고, 7번째 칸은 답을 말로 하는 음성 입력 문제(``VoiceAnswerPanel``),
첫 칸과 마지막 칸은 격려용 쉬운 2지선다입니다.

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
| 문제·연결 문제를 읽어 온다 | ``ContentFile`` → ``QuestionCatalog`` · ``MatchingSetCatalog`` |
| 이번 회차를 계획한다 | ``SessionBuilder`` |
| 묻는 방식대로 재료를 만든다 | ``QuizItem`` |
| 회차를 진행하고 결정한다 | ``QuizSession`` |
| 화면에 그린다 | ``QuizView`` → ``QuestionScreen`` · ``MatchingQuestionScreen`` |
| 정오답을 판정한다 | ``RuleGrader`` → ``AnswerMatcher`` → ``AnswerChecker`` |
| 사다리를 올리거나 내린다 | ``QuestionProgress`` |
| 해설을 쓴다 (맞아도·틀려도) | ``CommentaryWriter`` → ``FeedbackSheet`` · ``CorrectAnswerSheet`` |
| 어려운 낱말의 뜻을 보여준다 | ``GlossaryEntry`` → ``GlossaryExampleWriter`` → ``GlossaryPanel`` |
| 무엇이 있었는지 남긴다 | ``ObsRecord`` · ``ModelFailure`` → ``ObsUploader`` |

### 의존성은 한 방향

`Data` 는 아무것도 모르고, 색·조판·낭독은 도메인을 모르며, 화면만 전부를 압니다.
각 타입의 문서에 **"건드리지 않는 것"** 이 적혀 있습니다 — 무엇을 하는지보다
무엇을 하지 않는지가 역할을 규정합니다.

> Important: 2026-09-23 리팩토링에서 이 방향을 한 군데 되살렸습니다 — 낱말 예문을
> 만드는 코드가 `Data/GlossaryComposer.swift` 에 있으면서 `Grading` 의 ``Writing`` 을
> 쓰고 있었습니다. ``GlossaryExampleWriter`` 로 옮겨 `Data` 는 다시 아무것도 모릅니다.
> 무엇이 어떻게 바뀌었는지는 저장소 루트의 `Refactoring.md` 에 있습니다.

### 같은 모습은 같은 코드로

세 해설 창(오답·정답·낱말 사전)이 카드·배지·본문·시트 외장을 **한 벌로 공유**합니다
(``CommentaryMetrics`` · ``CommentaryCard`` · ``CommentaryRow`` · ``WordBadge`` ·
``CommentaryBodyText``). 「똑같이 생겼다」를 주석으로 약속하면 한쪽만 고쳐질 때
주석이 거짓이 되므로, 같은 코드를 쓰게 해서 강제합니다.

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
- ``GlossaryEntry``
- ``QuestionCatalog``
- ``ContentFile``

### 연결 문제 — 별개의 문제 체계

- ``MatchingSet``
- ``MatchingPair``
- ``MatchingSetPayload``
- ``MatchingSetCatalog``

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

### 모델에게 글을 시키는 쪽

- ``ModelCall``
- ``ModelTimeout``
- ``Writing``
- ``CommentaryWriter``
- ``Commentary``
- ``ChoiceNote``
- ``GlossaryExampleWriter``
- ``GlossaryExample``
- ``EncouragementWriter``
- ``Encouragements``

### 해설 창에 들어갈 내용

- ``IncorrectCommentary``
- ``CorrectCommentary``
- ``CommentaryPlaceholder``

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
- ``MatchingQuestionScreen``
- ``GradingScreen``
- ``ResultScreen``
- ``FeedbackSheet``
- ``CorrectAnswerSheet``

### 탭과 그 첫 화면

- ``KCTApp``
- ``RootView``
- ``MyHistoryView``
- ``PracticeHomeView``
- ``StoryModeView``

### 색과 조판

- ``AppColor``
- ``KoreanTextLayout``
- ``KoreanText``
- ``JustifiedKoreanText``
- ``UnderlineLabel``
- ``SpeechReader``

### 재사용 부품

- ``ActionCapsuleLabel``
- ``PrimaryActionButton``
- ``SecondaryActionButton``
- ``ChoiceButton``
- ``CircleIconButton``
- ``ScreenTitle``
- ``GuidanceBanner``
- ``SessionProgressBar``
- ``CumulativeCountCard``
- ``MasteredBadge``

### 해설 창이 함께 쓰는 부품

- ``CommentaryMetrics``
- ``CommentarySheetTitle``
- ``CommentaryCard``
- ``CommentaryRow``
- ``WordBadge``
- ``CommentaryBodyStyle``
- ``CommentaryBodyText``

### 낱말 사전

- ``GlossaryPanel``
- ``GlossaryExampleState``
- ``GlossaryExampleText``
- ``WideChevronShape``

### 연결 문제의 판

- ``MatchCard``
- ``MatchLine``
- ``MatchSide``
- ``CardSlot``
- ``CardFrameKey``
