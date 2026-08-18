# STUDY GUIDE — 이 코드를 읽는 방법

이 저장소의 코드를 **어디서부터, 어떤 순서로 읽을지** 안내하는 문서입니다.

파일이 27개입니다. 알파벳 순으로 열면 `AppColor.swift` 부터 나오는데, 그건 이 앱을
이해하는 데 **가장 도움이 안 되는 시작점**입니다. 아래 순서로 읽으세요.

**다른 문서와의 경계** — 같은 사실을 두 곳에 쓰지 않습니다.

| 알고 싶은 것 | 볼 곳 |
|---|---|
| **코드를 어떤 순서로 읽을까** | **이 문서** |
| 개념 설명 + 심볼로 따라가기 | Xcode → Product → **Build Documentation** (`KCT.docc`) |
| 파일 하나하나가 무슨 역할인가 | [LEARNING_PLAN.md](LEARNING_PLAN.md) 의 「파일 구성」 |
| 왜 이렇게 설계했나, 다음에 뭘 만들 건가 | [LEARNING_PLAN.md](LEARNING_PLAN.md) |
| 지금 어디까지 왔나 | [PROGRESS.md](PROGRESS.md) |
| 이 낱말이 무슨 뜻인가 | [GUIDE.md](GUIDE.md) |
| 막혔던 것과 그 해결 | [Q&A.md](Q&A.md) |

---

## 0. 이 앱이 하는 일 (3줄)

귀화 시험 문제를 **하루 5문제씩** 낸다. 사용자는 70대 어르신이고 **아무것도 고르지 않는다** —
무엇을 낼지, 어떻게 물을지는 앱이 정한다. 맞히면 같은 문제를 조금 더 어려운 방식으로 다시 묻고,
틀리면 조금 더 쉬운 방식으로 되돌린다.

---

## 1. 엔트리 포인트 — 문제 한 개의 여행

**이 장 하나가 이 문서의 핵심입니다.** 파일 목록을 훑는 것보다, 문제 한 개가 화면에 뜨고
채점되어 기록되기까지를 **손가락으로 한 번 따라가는 것**이 구조 전체를 이해하는 가장 빠른 길입니다.

Xcode 에서 각 심볼을 `⌘+클릭` 해서 따라가 보세요.

### ① 문제가 앱으로 들어온다

| 단계 | 어디서 | 무엇이 일어나나 |
|---|---|---|
| 1 | `Content/questions.json` | 문제 데이터. 지문·정답·단원·난이도·O/X 진술문 틀 |
| 2 | `BundledQuestionSource.loadFromBundle()` | 번들에서 파일을 찾아 `QuestionPayload` 로 해독 |
| 3 | `QuestionCatalog.bundled()` | 문제집을 보관. **오답 보기용 정답 모음**(`answerPool`)을 미리 계산 |
| 4 | `KCTApp.body` | 문제집을 `.environment` 로, 저장소를 `.modelContainer` 로 아래에 내려보냄 |

> **여기서 멈춰 생각해볼 것** — 왜 `Question` 이 문제집 전체를 모르게 만들었을까?
> (답: `Question.makeChoices(count:answerPool:)` 의 주석에 있습니다)

### ② 이번 회차를 계획한다

| 단계 | 어디서 | 무엇이 일어나나 |
|---|---|---|
| 5 | `RootView` → `QuizView` | 홈 화면 없이 곧바로 퀴즈로 |
| 6 | `QuizView.prepareSession()` | `QuizSession` 을 만들고 `start()` |
| 7 | `QuizSession.start()` | 진척이 없는 문제에 `QuestionProgress` 를 새로 만든다 |
| 8 | `FocusStore.focuses(for:)` | 각 문제가 "무엇을 묻는지" 를 모아 온다 (형광펜용) |
| 9 | `SessionBuilder.build(size:progressByID:focusByID:)` | **출제 계획** — 아래 ③ |

### ③ 무엇을 어떻게 물을지 정한다 (`SessionBuilder`)

```
후보 걸러내기        isUnlocked 로 열린 문제만          (스토리 모드 자리)
      ↓
세 줄 세우기         reviewQueue()     복습  — 예정 시각 이른 순 → 쉬운 순
                    newcomerQueue()   신규  — 쉬운 순 + 단원 번갈아
                    masteredQueue()   마스터 — 랜덤
      ↓
칸 채우기            fillSlots()       학습 먼저, 마스터용 1칸 예약, 마지막에 섞기
      ↓
모양 잡기            shapeRound()      진척이 기억한 방식 배정
                                      단 첫·마지막은 격려용 2지선다
```

> **여기서 멈춰 생각해볼 것** — 첫 문제와 마지막 문제는 왜 항상 쉽게 낼까?
> 그리고 왜 그 두 문제는 승급에 반영하지 않을까? (`shapeRound()` 의 주석)

### ④ 문제 하나를 출제 항목으로 완성한다

| 단계 | 어디서 | 무엇이 일어나나 |
|---|---|---|
| 10 | `QuizItem.make(_:mode:answerPool:...)` | 방식에 맞는 재료를 파생 |
| 11 | `Question.makeChoices()` / `makeTrueFalse()` | 보기를 섞거나 진술문을 만든다 |
| 12 | `ModePayload` | 그 재료를 담는다 — 방식과 재료가 어긋날 수 없는 형태 |

**출제 시 한 번만** 계산합니다. 화면이 그릴 때마다 계산하면 다시 그릴 때마다
보기 순서가 바뀝니다.

### ⑤ 화면에 그린다

| 단계 | 어디서 | 무엇이 일어나나 |
|---|---|---|
| 13 | `QuizView.screen(for:)` | 문제 화면 / 채점 중 / 결과 중 하나를 고른다 |
| 14 | `QuestionScreen` | 진행 막대 · 지문 · 안내 한 줄 · 입력 영역 · 다음 버튼 |
| 15 | `KoreanText` | 한글 단어 단위 줄바꿈 + 형광펜 + 밑줄 강조 |
| 16 | `ChoiceButton` | 보기 버튼. 탭하면 `session.userAnswer` 에 값을 넣는다 |
| 17 | `SpeechReader` | `QuizView` 가 지문을 소리로 읽어준다 |

### ⑥ 채점하고 기록한다

| 단계 | 어디서 | 무엇이 일어나나 |
|---|---|---|
| 18 | `QuizSession.submitCurrent()` | 답을 기록하고 `currentIndex += 1` |
| 19 | 마지막 문제였다면 `gradeAll()` | 회차 전체를 채점 |
| 20 | `QuizSession.judge(_:answer:)` | **규칙으로 먼저** — `RuleGrader.grade()` |
| 21 | `RuleGrader` 가 `nil` 을 주면 | **뜻으로** — `MeaningGrader.grade()` (온디바이스 모델) |
| 22 | `QuestionProgress.record(correct:)` | 사다리 한 칸 승급 또는 강등 + 다음 출제 시점 |
| 23 | `modelContext.save()` | 디스크에 남는다. 앱을 껐다 켜도 유지 |
| 24 | `ResultScreen` | 누적 정답 수를 크게 보여준다 |

> **여기서 멈춰 생각해볼 것** — `RuleGrader.grade()` 가 `Bool` 이 아니라 `Bool?` 을
> 돌려주는 이유는? (`nil` 이 곧 "나는 못 정한다, 뜻으로 봐 달라" 는 신호입니다)

---

## 2. 구조 — 폴더가 곧 책임

의존성은 **위에서 아래로 한 방향**입니다. 아래로 갈수록 아는 것이 많아집니다.

| 폴더 | 책임 | 무엇을 모르나 |
|---|---|---|
| `Content/` | 문제 콘텐츠 (고정 데이터) | **아무것도.** 진척도 화면도 모른다 |
| `Progress/` | 학습 진척 (변하는 데이터) | 문제 내용. id 로만 연결된다 |
| `Session/` | 이번 회차 출제 구성 | 화면, 채점 |
| `Grading/` | 채점 | 진척 저장 (판정만 한다) |
| `Focus/` | 묻는 대상 하이라이트 | 어떻게 칠할지 (색은 화면의 몫) |
| `Screens/` | 회차 상태 + 화면 | — **전부를 안다** |
| `DesignSystem/` | 색·조판·낭독·재사용 부품 | **도메인 전부.** 문제도 진척도 모른다 |

이 방향을 거스르는 코드(예: `Content/` 가 `Screens/` 를 참조)는 **설계가 틀어진 신호**입니다.

각 파일 최상단의 요약 블록에 `건드리지 않는 것` 한 줄이 있습니다.
**무엇을 하는지보다 무엇을 하지 않는지가 역할을 규정합니다.**

---

## 3. 반드시 알아야 하는 한 가지 — 두 개의 축

이걸 섞으면 코드가 전부 이상해 보입니다.

| | 축 A | 축 B |
|---|---|---|
| 무엇 | 문제 자체가 얼마나 어려운가 | 같은 문제를 얼마나 쉽게 묻는가 |
| 어디 | `Question.difficulty` | `QuestionProgress.mode` (`AskingMode`) |
| 성격 | **고정** | **동적** |
| 쓰임 | 신규 문제 **도입 순서**만 | 출제 **방식**(사다리) |

```
축 B 사다리 :  2지선다(0) → O/X(1) → 4지선다(2) → 직접입력(3) → 마스터
```

**모든 문제가 같은 사다리를 탑니다.** 쉬운 문제도 어려운 문제도 2지선다에서 시작합니다.

`AskingMode` 라는 이름을 쓰는 이유가 여기 있습니다 — 이건 *난이도* 가 아니라 *묻는 방식* 입니다.
(예전 이름은 `DifficultyMode` 였고, 그래서 두 축이 계속 헷갈렸습니다)

---

## 4. 학습 단계

한 단계씩. 각 단계는 **읽고 → 스스로 답하고 → 직접 만져보는** 순서입니다.

### 1단계 · 데이터가 어디서 오나
- **읽기** `Content/` 전부 (`Question` → `QuestionSource` → `QuestionCatalog`)
- **답해보기** 오답 보기는 어디서 오는가? 문제집을 서버로 바꾸면 몇 개 파일을 고쳐야 하나?
- **해보기** `questions.json` 에 문제 하나를 추가하고 실행해 등장하는지 확인

### 2단계 · 진척이 어떻게 남나
- **읽기** `Progress/AskingMode.swift` → `Progress/QuestionProgress.swift`
- **답해보기** 왜 `mode` 를 enum 이 아니라 `modeRaw: Int` 로 저장하나?
  틀리면 다음 출제 시점이 언제인가?
- **해보기** 결과 화면의 "학습 기록 초기화" 를 눌러 보고, 다시 시작하면 무엇이 달라지는지 관찰

### 3단계 · 출제 계획
- **읽기** `Session/SessionBuilder.swift` — `build()` 부터 아래로
- **답해보기** 복습이 신규보다 먼저인 이유는? 마스터한 문제는 왜 계속 나오나?
- **해보기** `masteredReviewSlots` 를 2로 바꿔 보고 회차 구성이 어떻게 달라지는지 확인

### 4단계 · 출제 항목과 채점
- **읽기** `Session/QuizItem.swift` → `Grading/RuleGrader.swift` → `Grading/MeaningGrader.swift`
- **답해보기** `ModePayload` 를 struct 가 아니라 enum 으로 둔 이점은?
  O/X 버튼 문구가 왜 화면이 아니라 채점기에 있나?
- **해보기** O/X 문제를 만나 "맞아요"·"아니에요" 를 각각 눌러보고 판정을 확인

### 5단계 · 회차 상태와 화면의 분리 ★
- **읽기** `Screens/QuizSession.swift` → `Screens/QuizView.swift` → `Screens/QuestionScreen.swift`
- **답해보기** 화면은 정답을 아는가? 낭독은 왜 `QuizSession` 이 아니라 `QuizView` 에 있나?
  `QuizSession` 은 왜 `@Query` 대신 진척을 직접 조회하나?
- **해보기** `QuestionScreen` 의 안내 문구를 바꿔 보고, 그 변경이 다른 파일에 번지지 않는 것을 확인

### 6단계 · 어르신 접근성
- **읽기** `DesignSystem/KoreanText.swift` → `AppColor.swift` → `SpeechReader.swift`
- **답해보기** SwiftUI `Text` 를 안 쓰고 `UILabel` 을 감싼 이유는?
  "2333년" 이 갈라지지 않는 원리는? 오디오 세션 설정을 왜 백그라운드로 뺐나?
- **해보기** 기기 설정에서 글자 크기를 키워 보고 화면이 견디는지 확인

### 7단계 · 하이라이트 3층과 폴백
- **읽기** `Focus/FocusStore.swift` → `QuestionFocus.swift` → `FocusAnalyzer.swift`
- **답해보기** 3층(규칙 기반)이 없으면 무엇이 깨지나? 모델이 지어낸 답은 어떻게 걸러내나?
- **해보기** `FocusStore.usesModelAnalysis` 의 주석을 읽고, **켜기 전에 무엇을 함께 넣어야 하는지** 확인

---

## 5. 자주 헷갈리는 다섯 가지

읽다가 "버그 아닌가?" 싶을 때 여기를 먼저 보세요. **다섯 개 모두 의도된 것입니다.**

| 보이는 것 | 사실은 |
|---|---|
| `FocusAnalyzer` 에 중단점을 걸어도 안 걸린다 | `FocusStore.usesModelAnalysis == false` 라서 **2층이 꺼져 있다.** 이유와 다시 켤 조건이 주석에 있다 |
| 답을 안 골라도 "다음" 버튼이 눌린다 | 일부러 그렇게 뒀다. 눌러도 아무 일이 없으면 어르신은 앱이 고장 났다고 생각한다. 눌리게 두고 안내를 띄운다 (`PrimaryActionButton`) |
| 보기를 골라도 색이 꽉 안 찬다 | 채움은 **주 행동 하나에만.** 선택은 상태이므로 테두리+체크로 표시한다 (`ChoiceButton`) |
| 오답인데 빨간색이 아니다 | 화면에 "틀렸다" 신호를 주지 않기로 했다. "다시 볼 문제 / 곧 다시 만나요" (`AppColor.review`) |
| `build(now:)` 의 `now` 를 아무도 안 쓴다 | 사실이다. 복습은 예정 시각 **순서만** 쓰고 "지났는가" 로 걸러내지 않는다. `- Note:` 에 적혀 있다 |

---

## 6. 코드를 읽는 도구

| 하고 싶은 것 | 방법 |
|---|---|
| 이 타입이 무슨 일을 하나 | 심볼에 **`Option+클릭`** → `///` 주석이 팝업으로 |
| 이 파일의 전체 지도 | 파일 **최상단 요약 블록** (역할·구성·흐름·연결) |
| 파일 안에서 이동 | 상단 **점프바** → `// MARK: -` 로 만든 목차 |
| 정의로 가기 / 돌아오기 | `⌘+클릭` / `⌃⌘←` |
| 이 심볼을 누가 쓰나 | 우클릭 → **Find Call Hierarchy** |
| 문서 사이트로 읽기 | Product → **Build Documentation** (`⇧⌃⌘D`) |
| 개념부터 읽기 | 위 문서 브라우저의 **KCT** 랜딩 페이지 → 「먼저 읽을 개념」 |

**`///` 주석은 화면을 어지럽히지 않으면서 문서가 됩니다.** 그래서 긴 설명은 코드 위가 아니라
`///` 안에 있습니다. 코드만 보면 요약 한 줄, 더 알고 싶으면 `Option+클릭`.

> ⚠️ `private` 멤버는 **Build Documentation 결과에 나오지 않습니다.** 그래서
> `SessionBuilder` 의 단계별 함수들은 일부러 `private` 을 떼어 두었습니다
> (문서에 보이게, 그리고 테스트가 직접 부를 수 있게).

---

## 7. 다음은 무엇인가

- 앞으로 만들 기능과 그 이유 → [LEARNING_PLAN.md](LEARNING_PLAN.md) 의 「남은 작업」
- 지금 진행 상황과 다음 할 일 → [PROGRESS.md](PROGRESS.md)
- 손댈 때 지킬 규칙 → [CLAUDE.md](CLAUDE.md) (짧게) · [RULES.md](RULES.md) (자세히)

**마지막으로 기억할 것 하나** — 이 앱에서 빌드 성공은 성공이 아닙니다.
어르신이 **읽고, 듣고, 누를 수 있는지**까지가 완료입니다.
