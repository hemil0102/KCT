# REFACTORING

리팩토링의 **역사**입니다. 무엇을 · 왜 · 어느 파일 · 동작이 바뀌었나를 한 줄씩 남깁니다.

되돌리려는 유혹이 생길 자리를 남기는 것이 목적입니다 — 「이 색은 왜 지웠지」,
「이 파일은 왜 나눴지」를 나중에 다시 묻지 않도록.

---

## 2026-09-23 · 1차 리팩토링

**범위** — 47개 `.swift` 8,715줄 전체. 사용자 승인 하에 AI 가 직접 수정했고,
**단계마다 `BuildProject` 를 돌렸습니다**(총 12회, 전부 성공).

**결과** — 파일 55개 9,433줄. 줄 수가 늘어난 것은 **주석이 늘어서**입니다
(새 파일 9개의 최상단 요약·`///`). 실행되는 줄은 줄었습니다.

### 동작은 안 바꿨다 — 이것이 이번 작업의 유일한 성공 기준

화면에 보이는 것이 한 군데도 바뀌지 않아야 리팩토링이고, 바뀌면 기능 변경입니다.
실측으로 정해진 값은 **전부 지금 값 그대로 옮기기만** 했습니다.

| 그대로 둔 것 | 값 | 왜 |
|---|---|---|
| `KoreanText.showsMarkerHighlight` | `false` | PROGRESS「임시로 꺼 둔 것」 — 진단용이라 판단이 남아 있다 |
| `FocusStore.usesModelAnalysis` | `false` | 결정 기록에 있는 의도된 상태 |
| 시트 배경 진하기 | `0.75` | 11차에 0.5 → 0.58 → 0.65 → 0.75 로 여러 번 올려 정한 값 |
| 접힌 시트 높이 | 낱말 150 · 정답 260 | 같은 이유 |
| 글자 크기 | 21 / 28 / 20 / 64 … | 전부 실기기 실측 |
| 안내 배너 글자 | 문제 18pt · 연결 17pt | **합치면서 통일하지 않았다** — 인자로 각자 값을 넘긴다 |
| 안내 배너 여백 | 12/12 · 13/14 | 같은 이유 |
| `ObsUploader` 실패 업로드 재진입 가드 | **없음** | 넣으면 동작 변경. Brainstorm.md 후보로 남김 |
| `EncouragementWriter` 실패 기록 | **안 남김** | 남기려면 서버 RLS 정책을 먼저 고쳐야 한다. 같은 이유 |
| 지시문·프롬프트 문장 | 한 글자도 안 바꿈 | 안전 필터에 걸리는 조건이 달라진다 |
| `questions.json` | 한 글자도 안 바꿈 | 1,130문항 확장 작업과 충돌하지 않게 |

**지우지 않은 것** — `Focus/FocusAnalyzer.swift` · `Focus/QuestionFocusRecord.swift` 는
아무도 부르지 않지만 **의도된 상태**라 남겼습니다. 대신 `FocusStore` 헤더에
「지금 아무도 부르지 않는 코드」임을 분명히 적었습니다.

---

### 1단계 · 죽은 코드 걷어내기

호출 0건을 `grep` 으로 **확인한 것만** 지웠습니다.

| 파일 | 지운 것 | 확인 |
|---|---|---|
| `DesignSystem/AppColor.swift` | 색 **9개** — `chosenAnswer` · `pendingText` · `answerBackground` · `wrongBackground` · `answerSheetBackground` · `wrongSheetBackground` · `wrongSheetAccent` · `answerHeader` · `answerAccent` | `AppColor.<이름>` 호출 0건 |
| `Data/QuestionCatalog.swift` | `question(id:)` | 호출 0건 |
| `Data/ContentFile.swift` | `load()` | 두 카탈로그가 `loadDownloaded`/`loadBundled` 를 직접 쓴다 |
| `Data/Question.swift` | `tags` 프로퍼티 + 그 `decodeIfPresent` | 해독만 하고 읽는 곳 0건 |
| `DesignSystem/PrimaryActionButton.swift` | `fill` 인자 | 넘기는 곳 0건 |
| `Screens/FeedbackSheet.swift` | 헤더의 「아직 반영 안 한 것」 블록 | 11차에 이미 반영돼 **거짓이었다** |

> **왜 색 9개를 지웠나** — 아홉 개 모두 문서 주석에 「현재 미사용」이라고 적혀 있었습니다.
> 「다시 갈라 볼 때를 위해 남겨 둔다」는 이유였는데, 정작 **그 시도가 왜 실패했는지**가
> 함께 적혀 있었습니다(밝은 배경이 흰 글자를 못 받친다). 되돌릴 일이 없는 값이
> 팔레트에 남아 있으면 「이 중 뭘 써야 하지」를 매번 다시 고르게 됩니다.
> 값이 필요하면 이 파일의 git 이력에 그대로 있습니다.

`saveDownloaded(_:)` · `replace(with:)` · `SessionMode.exam` 은 **남겼습니다** —
문서가 「서버 도입 시 여기」라고 밝힌 씸(seam)입니다. 대신
`/// - Note: 아직 부르는 곳이 없다` 를 붙여 두었습니다.

---

### 2·3단계 · 두 해설 시트의 공통 부품 (가장 큰 덩어리)

**문제** — `FeedbackSheet`(413줄)와 `CorrectAnswerSheet`(357줄)가
`noteRow` · `notesCard` · `justifiedBody` · `title` · 시트 외장 4줄 · 상수 4개를
**거의 글자 그대로** 공유하고 있었습니다. `CorrectAnswerSheet.swift:243` 의 주석이
「FeedbackSheet.noteRow(...) 와 똑같다」고 스스로 적고 있었습니다.

**똑같다는 것을 주석으로 적어야 하는 상태가 곧 갈라질 상태입니다** — 한쪽만 고치면
주석은 그대로 남고 화면만 어긋납니다.

**새 파일** `DesignSystem/CommentarySheet.swift`

| 부품 | 무엇 |
|---|---|
| `CommentaryMetrics` | 제목 21 · 본문 21 · 이모지 20 · 버튼 64 · 배경 0.75 · 카드 모서리 16 · 배지 모서리 7 |
| `CommentarySheetTitle` | 보라 배경 위 흰 제목 |
| `CommentaryCard` | 완전 불투명 흰 카드 |
| `CommentaryRow` | 이모지 + 배지 한 줄, 그 아래 설명 |
| `WordBadge` | 낱말 배지 |
| `CommentaryBodyStyle` | ← `BodyStyle` 개명 |
| `CommentaryBodyText` | 양쪽 정렬 본문 + 낱말만 칠하기 |
| `View.pulsingWhileWaiting` | `FeedbackSheet.swift` 에서 이사 |
| `View.commentarySheetChrome(detents:[selection:]blocksInteractiveDismiss:)` | 배경·크기·손잡이·닫기 막기 |

`BodyStyle` 과 `pulsingWhileWaiting` 이 `Screens/FeedbackSheet.swift` 안에 있으면서
`Screens/CorrectAnswerSheet.swift` 가 그것을 가져다 쓰고 있었습니다 — 화면이 다른
화면의 내부를 아는 모양이라 `DesignSystem` 으로 옮겼습니다.

`GlossaryPanel` 도 **시트 외장만** 같은 것을 씁니다. 다만 그쪽은 아래로 쓸어내려 닫는 것을
막지 않아야 해서 `blocksInteractiveDismiss: false` 인자를 두었습니다.

| 파일 | 전 | 후 |
|---|---:|---:|
| `FeedbackSheet.swift` | 413 | **244** |
| `CorrectAnswerSheet.swift` | 357 | **265** |

---

### 4단계 · 해설 창 내용을 `QuizSession` 에서 떼어냄

**새 파일** `Grading/Commentary.swift` — `IncorrectCommentary` · `CorrectCommentary` ·
`CommentaryPlaceholder`.

두 타입이 `QuizSession` 안에 **중첩**돼 있었습니다. 그러면 창을 그리는 화면이
**회차 전체를 아는 타입을 거쳐야** 자기 내용을 받습니다 — 화면이 필요한 것은 문장
네 줄인데 900줄짜리 세션에 묶여 있었습니다.

- 두 시트가 이제 `QuizSession` 을 **아예 모릅니다**
- 같은 문구가 두 타입에 두 벌씩 있던 것(`placeholder`·`failed`)을
  `CommentaryPlaceholder` 한 벌로 합쳤습니다 (`waiting`·`failed`·`noteFailed`)

> **판단이 갈렸던 지점** — 이 타입을 `Grading/` 에 둘지 `Screens/` 에 둘지.
> 「모델이 만든 해설」이라 `Grading` 같기도 하고 「창에 그릴 내용」이라 `Screens` 같기도
> 합니다. `Grading` 으로 정한 이유 — 이 타입을 **만드는 쪽**이 `QuizSession`·`CommentaryWriter`
> 이고, 「해설 창에 줄을 하나 더 넣자」가 오면 먼저 볼 곳이 만드는 쪽이기 때문입니다.

---

### 5단계 · 남은 화면 중복 제거

| 새 파일 | 지운 중복 |
|---|---|
| `DesignSystem/CircleIconButton.swift` | `QuestionScreen` X·다시읽기 + `MatchingQuestionScreen` X — **세 곳이 같은 코드** |
| `DesignSystem/GuidanceBanner.swift` | `QuestionScreen.hintBanner` + `MatchingQuestionScreen.toastBanner` |
| `DesignSystem/CumulativeCountCard.swift` | `ResultScreen` + `MyHistoryView` — **한 줄(caption)만 다른 판박이** |
| `DesignSystem/ActionCapsule.swift` | `ActionCapsuleLabel`(`PrimaryActionButton` + 두 `NavigationLink` 진입 버튼) · `SecondaryActionButton`(`GlossaryPanel.closeButton` + `CorrectAnswerSheet.revealButton`) · `ScreenTitle`(제목 2곳) |
| `Screens/MatchBoard.swift` | `MatchCard` · `MatchLine` · `MatchSide` · `CardSlot` · `CardFrameKey` |

`MatchingQuestionScreen` 안에서 셋을 더 줄였습니다.

1. **`shakeLeft`·`shakeRight`·`shakeNext` 세 함수가 글자까지 똑같았습니다.** 다른 것은
   「어디에 값을 넣는가」 하나뿐이라, 그것만 클로저로 받는 `shake(_:)` 하나로 합쳤습니다.
   → `shake { cardOffsetX[key] = $0 }`
2. **`LeftFrameKey`·`RightFrameKey` 두 `PreferenceKey` 가 똑같았습니다.**
   `PreferenceKey` 는 타입 하나가 키 하나라서 왼쪽·오른쪽을 가르려면 둘이 필요했던
   것인데, 가르는 것을 **타입이 아니라 값**(`CardSlot.side`)으로 옮기면 하나로 충분합니다.
   덕분에 카드 쪽 `GeometryReader` 안의 `if/else` 도 사라졌습니다.
3. **진행 막대를 따로 한 벌 더 그리고 있었습니다.** `SessionProgressBar` 에
   `currentIsComplete`(기본 `true`)와 `upcomingFill`(기본 옅은 보라)을 더해 세 단계를
   표현할 수 있게 하고, 그 화면이 `allMatched` 를 넘기게 했습니다.
   기본값 덕분에 `QuestionScreen` 쪽 모습은 그대로입니다.

| 파일 | 전 | 후 |
|---|---:|---:|
| `MatchingQuestionScreen.swift` | 505 | **388** (+ `MatchBoard.swift` 162) |

---

### 6단계 · 모델 호출 보일러플레이트를 한 벌로

**문제** — 세 곳이 같은 넷을 각자 적고 있었습니다.
① 지시문으로 `LanguageModelSession` 만들기 ② `respond(to:generating:)`
③ `catch` 에서 `print("❌ …")` ④ `ModelFailureDraft(job:questionID:…)` 채우기.

**새 것**

- `Grading/Writing.swift` — `Writing` 을 `CommentaryWriter.swift` 에서 이사.
  세 writer 가 함께 쓰는 타입이 그중 한 파일에 숨어 있었습니다
- `Grading/ModelCall.swift` — 최상위 함수 `withTimeout` 을 `ModelCall` 안으로 넣고,
  `ModelCall.generate(job:questionID:instructions:prompt:generating:…)` 추가.
  `ModelCall.isAvailable` 도 함께
- `Grading/AnswerTypes.swift` — `GradingResult` 를 `AnswerChecker.swift` 에서 이사.
  채점 결과 타입이 「모델 채점기」 파일에만 있을 이유가 없습니다

**`generate` 를 안 쓰는 두 곳**이 있고, 둘 다 이유가 있습니다.

| 안 쓰는 곳 | 왜 |
|---|---|
| `AnswerChecker` | 실패를 **던져 올려야** 한다 — `QuizSession.judge()` 가 그 `throw` 를 받아 조용히 오답으로 둔다. 공통으로 쓰는 것은 시한 하나 |
| `EncouragementWriter` | 글 하나가 아니라 **다섯 개 목록**을 받고, 실패 기록을 안 남긴다(남기려면 서버 RLS 정책을 먼저 고쳐야 한다) |

> **`onFailure` 훅을 왜 뒀나** — 처음엔 `generate` 만으로 합쳤다가, 낱말 예문이 세이프티
> 가드레일에 걸렸을 때 애플에 신고할 첨부자료를 만드는 코드(`session.logFeedbackAttachment`)가
> **사라지는 것을 발견**했습니다. 그 API 는 **세션 객체가 있어야** 부를 수 있는데, 호출을
> 공통 함수로 모으면 세션에 손이 닿지 않습니다. 그래서 `generate` 가 실패할 때 그 세션과
> 에러를 그대로 넘겨 주는 훅을 두었습니다. **중복 제거가 기능을 지우면 리팩토링이 아닙니다.**

---

### 7단계 · `composeExample` 을 제 자리로 (의존성 방향 복구)

`Data/GlossaryComposer.swift` → `Grading/GlossaryExampleWriter.swift`

`Data/` 에 있던 **최상위 함수** `composeExample(...)` 이 `FoundationModels` 를 부르고
`Grading` 의 `Writing` 을 돌려주고 있었습니다. CLAUDE.md 가 못 박은
**「의존성은 위에서 아래로 한 방향」** 위반입니다 — `Data` 는 아무것도 몰라야 합니다.

- `struct GlossaryExampleWriter { func write(...) async -> Writing }` 로 바꿔
  `CommentaryWriter.write(for:)`·`EncouragementWriter.write()` 와 같은 모양이 됐습니다
- `@Generable GlossaryExample` 과 `#if DEBUG saveFeedbackAttachment` 도 함께 이사
- 호출부는 `QuestionScreen` 한 곳

---

### 8단계 · 200줄 넘는 파일 쪼개기 (규칙 24)

| 쪼갠 것 | 새 파일 | 줄 수 변화 |
|---|---|---|
| `KoreanText.swift` 의 `UnderlineLabel`(TextKit 으로 밑줄·배경 직접 그리기) | `DesignSystem/UnderlineLabel.swift` | 613 → **339** (+ 324) |
| 최상위 `Coordinator` 클래스 | `KoreanText.Coordinator` 로 **중첩** | — |
| `GlossaryPanel.swift` 의 `HighlightedExample`·`highlightedExample(_:)`·`HighlightedSentenceView`·`WideChevronShape` | `DesignSystem/GlossaryExampleText.swift` | 453 → **328** (+ 194) |

> **`Coordinator` 를 왜 옮겼나** — 모듈 전체에 `Coordinator` 라는 이름의 최상위 클래스가
> 떠 있었습니다. 다음에 다른 `UIViewRepresentable` 을 만들면 이름이 부딪힙니다.
> `makeCoordinator()` 가 돌려주는 타입은 관례상 그 뷰 안에 중첩합니다.

`GlossaryExampleText` 는 `Self.wordGlossFontSize` 를 쓰던 것을 **인자로 받게** 했습니다 —
「낱말·뜻·해설이 항상 같은 크기」라는 규칙을 지키는 상수는 여전히 `GlossaryPanel` 의
`wordGlossFontSize` 하나뿐입니다.

---

### 9단계 · 이름 정리 (JSON 무수정)

| 전 | 후 | 왜 |
|---|---|---|
| `GlossaryEntry.examples` | `relatedWords` | 담긴 것이 예문이 아니라 **비슷한 낱말**이다. 이름이 거짓말을 하고 있어서 `referenceSentence` 의 주석이 「`examples` 와 헷갈리지 않게 일부러 다른 이름을 썼다」고 변명하고 있었고, 호출부 인자 이름은 이미 `relatedWords:` 였다 |
| 최상위 `Coordinator` | `KoreanText.Coordinator` | 8단계 |
| `BodyStyle` | `CommentaryBodyStyle` | 2단계 — 모듈 전체에 쓰기엔 너무 일반적인 이름 |
| 최상위 `composeExample` | `GlossaryExampleWriter.write` | 7단계 |
| 최상위 `withTimeout` | `ModelCall.withTimeout` | 6단계 |

`GlossaryEntry` 에 `CodingKeys` 를 넣어 **JSON 키는 `examples` 그대로** 읽습니다.

```swift
enum CodingKeys: String, CodingKey {
    case word, gloss
    case relatedWords = "examples"
    case referenceSentence
}
```

⭐️ **`questions.json` 은 한 글자도 안 바뀌었습니다.** 1,130문항 확장 작업(엑셀 → JSON)과
충돌하지 않게 하려는 것입니다.

---

### 10단계 · 남은 중복 세 곳

1. **`ContentFile.loadPreferringDownloaded(isEmpty:fallback:failureMessage:)`** —
   `QuestionCatalog.loaded()`·`MatchingSetCatalog.loaded()` 가 각자 들고 있던
   「받아 둔 것 → 번들 → 빈 것 + `assertionFailure`」 세 갈래를 한 벌로.
   두 카탈로그가 각각 12줄 → 6줄
2. **`ObsUploader.flush(_:to:label:payload:stamp:)`** — `uploadPending()` 과
   `uploadPendingFailures()` 가 밟던 네 걸음(보내기 → 도장 → 저장 → 로그)을 한 벌로.
   `pendingFailures()` 도 `pendingRecords()` 와 짝이 맞게 따로 뺐습니다.
   ⚠️ **재진입 가드는 지금 모양 그대로** — 실패 업로드에는 여전히 없습니다(동작 불변)
3. **`ModelContext.fetchKeyed(by:)`**(새 파일 `Progress/ModelContext+FetchKeyed.swift`) —
   `QuizSession.fetchProgressByID()`·`FocusStore.cachedRecords()` 가 반복하던
   `Dictionary(…, uniquingKeysWith: { first, _ in first })` 관용구를 키패스 하나로

---

### 11단계 · 거짓이 된 주석과 DocC

**코드는 안 바뀌었는데 이미 거짓이던 자리**를 함께 고쳤습니다.

| 파일 | 뭐라고 적혀 있었나 | 사실 |
|---|---|---|
| `MatchingQuestionScreen.swift` | "불러 쓰는 곳 : (아직 없음)" | `QuizView` 가 부른다 |
| `MatchingSetCatalog.swift` | "회차에 자동으로 끼워 넣지 않았다" | `QuizSession.start()` 가 끼운다 |
| `KCTApp.swift` | "아직 회차 안에 자동으로 끼워 넣지는 않지만" | 같은 이유 |
| `AnswerChecker.swift` | "시한 12초" | `timeout = 60` |
| `KoreanText.swift` | `selectedWordColor` | 실제 이름은 `selectedWordBackgroundColor`·`selectedWordTextColor`. 「주황」도 지금은 보라 |
| `QuizItem.swift` | "색+밑줄로 강조" · "굵은 밑줄" | 9차에 밑줄을 버리고 색+굵기+따옴표로 바꿨다 |
| `Question.swift` | "뜻은 낱말 사전(`Glossary`)에 있다" | `Glossary` 는 9차에 삭제 |
| `Question.swift` | 구성 목록에 `kind`·`shape`·`facts`·`glossary` 가 없다 | 넷 다 있다 |
| `AnswerTypes.swift` | 헤더가 "AnswerKind.swift" | 파일명이 다르다 |
| `ContentFile.swift` | 헤더가 "ContenFile.swift"(오타) · 최상단 요약 없음 | 규칙 5 위반 |
| `ObsUploader.swift` | "불러 쓰는 곳 … `moveToNextQuestion()`" | `uploadObservations()`·`uploadFailuresNow()` |
| `QuizSession.swift` | 구성 목록에 여섯 함수가 없다 | `applyProgress`·`clearAnswers`·`warmFocusCache`·`ensureProgressExists`·`itemIndex(for:)`·`isShowingCommentary` |
| `AppColor.swift` | 색 목록에 지운 9개가 남아 있다 | 갱신 |
| `PrimaryActionButton.swift`·`SessionProgressBar.swift` | 불러 쓰는 곳이 낡았다 | 갱신 |

**DocC**(규칙 20 — AI 가 그 자리에서 고친다)

- `KCT.md` — 삭제된 `GlossaryCatalog`·`GlossaryPayload` 제거, 「하루 5문제」→ **7칸**,
  Topics 를 새 구조에 맞게 재편(연결 문제 · 모델 호출 · 해설 창 내용 · 재사용 부품 ·
  낱말 사전 · 연결 문제의 판 — 여섯 절 신설), 심볼 **40여 개** 추가 등록
- `FeedbackModal.md` — 전면 재작성. 👉 → ❌, 파랑(`answerAccent`) → 녹색(`answerSheetAccent`),
  `BodyStyle` → `CommentaryBodyStyle`, 정답 창(`CorrectAnswerSheet`)과 공통 부품 절 추가
- `SessionPlanning.md` — 「5칸」→ 칸 수 일반화, **「연결 문제가 낀 칸」 절 신설**(칸 그림 포함)
- `GradingPath.md` — `withTimeout` → `ModelCall.withTimeout`, `GradingResult` 이사 반영
- `ElderAccessibility.md` — 「매일 5문제」→ 일곱 칸

---

## 파일 지도 (리팩토링 뒤)

```
Data/          문제·연결문제 (고정) — 아무것도 모른다
Progress/      진척 (변동) + ModelContext.fetchKeyed
Session/       이번 회차 출제 구성
Grading/       채점 세 층 + 모델에게 글 시키기 + 해설 창 내용
Focus/         묻는 대상 하이라이트 (2·3층은 꺼져 있음)
Screens/       화면 + 회차 상태 + 연결 문제 판
Observation/   관찰 기록·업로드
DesignSystem/  색·조판·낭독 + 재사용 부품 (도메인을 모른다)
```

**새로 생긴 파일 9개**

| 파일 | 폴더 |
|---|---|
| `CommentarySheet.swift` | DesignSystem |
| `ActionCapsule.swift` | DesignSystem |
| `CircleIconButton.swift` | DesignSystem |
| `GuidanceBanner.swift` | DesignSystem |
| `CumulativeCountCard.swift` | DesignSystem |
| `UnderlineLabel.swift` | DesignSystem |
| `GlossaryExampleText.swift` | DesignSystem |
| `Commentary.swift` | Grading |
| `Writing.swift` | Grading |
| `GlossaryExampleWriter.swift` | Grading |
| `MatchBoard.swift` | Screens |
| `ModelContext+FetchKeyed.swift` | Progress |

**사라진 파일 1개** — `Data/GlossaryComposer.swift`(→ `Grading/GlossaryExampleWriter.swift`)

---

## 아직 안 한 것

| 무엇 | 왜 미뤘나 |
|---|---|
| `QuizSession.swift` 824줄 해체 | 앱의 심장이라 오동작 위험이 가장 크다. 이번 범위에서 제외하기로 사용자와 합의 |
| `QuestionScreen.swift` 468줄 쪼개기 | 낱말 사전 시트 상태 관리(`glossaryOpenToken` 경합)가 화면에 얽혀 있어, 떼면 그 경합을 다시 검증해야 한다 |
| `ObsUploader` 실패 업로드 재진입 가드 | 동작 변경 |
| `EncouragementWriter` 실패 기록 남기기 | 서버 RLS 정책 수정이 먼저 |
| Dynamic Type 대응 | 기능 변경. `Brainstorm.md` 1번 |
| 아이콘 버튼 VoiceOver 라벨 | 기능 변경. `Brainstorm.md` |

---

## 실기기에서 확인할 것

리팩토링은 **동작이 안 바뀌어야 성공**이라 빌드만으로는 부족합니다.

1. **오답 해설 시트** — 제목 두 박자, ❌ 분홍·✅ 녹색 배지, 기다리는 동안 맥동,
   「정답 보기」→「다음 문제」, 뒤 지문이 밝게 비침
2. **정답 해설 시트** — 접힘 260pt 에서 「잘 맞추셨어요!」 + 버튼 둘,
   「정답 해설 보기」로 `.medium` 펼침
3. **낱말 사전 시트** — 150pt 접힘, "^" 손잡이, 탭/스와이프/손잡이 세 경로로 펼침,
   지문의 그 낱말만 연라벤더 배경, 네 경로로 닫힘, **아래로 쓸어내려 닫히는지**
   (`blocksInteractiveDismiss: false` 가 제대로 갔는지)
4. **연결 문제** — 짝 맞으면 보라 선, 틀리면 흔들림 세 박자(`shake` 통합 확인),
   진행 막대 세 단계(회색·옅은 보라·진한 보라)
5. **지문** — 점선 밑줄이 받침과 안 겹침, **마지막 줄 점선도 보임**(`UnderlineLabel` 이사 확인),
   긴 지문이 화면 절반 안에서 끝남
6. **회차 한 바퀴** — 7칸(연결 문제 한 칸 포함) → `GradingScreen` 3초 → 결과 화면
7. **두 탭** — 나의 이력 누적 카드와 결과 화면 누적 카드가 **같은 모습**인지
8. **Supabase** — `obs_record`·`model_failure` 에 줄이 계속 쌓이는지
   (6·7·10단계가 그 경로를 만졌다). 특히 `job = 'glossary_example'`
9. **낱말 사전 예문** — `#if DEBUG` 첨부자료(`feedback_glossary_q*.json`)가 여전히
   문서 폴더에 남는지 (`onFailure` 훅이 제대로 걸렸는지)
