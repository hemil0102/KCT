# 2차 리팩토링 검토 — iOS 27 · Swift 6.4 기준

- 검토일 : 2026-10-23
- 범위 : `KCT/KCT/` 소스 59파일 · 12,217줄 (1차 때 8,715줄 → **3,500줄 늘었다**)
- 방법 : 코드를 읽고 `grep` 으로 패턴을 셌다. **빌드는 못 돌렸다** (이 검토는 Mac 밖에서 했다). 그래서 아래의 「버그 가능성」은 전부 **실기기·빌드로 확인할 것**이다
- 규칙 1 : 이 문서는 무엇을 왜 고칠지까지만 적는다. 고르면 그 단계만 「넣는 순서 · 코드 · 확인」 `.md` 를 따로 만든다 (규칙 23)

---

## 지금 설정

| 항목 | 값 | 뜻 |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | 26.2 | iOS 27 기능은 `if #available(iOS 27, *)` 뒤에서만 쓸 수 있다 |
| `SWIFT_VERSION` | **5.0** | 컴파일러는 Swift 6.x 인데 **언어 모드는 5** — 데이터 경합 검사가 경고에 그친다 |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor | 이미 켜져 있다 (좋음) |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES | 이미 켜져 있다 (좋음) |
| 테스트 타깃 | **없음** | 규칙 26 이후에도 아직 0개 |

---

## A. 동작이 틀릴 수 있는 곳 — 먼저

### A1. 답을 두 번 제출할 틈 (`QuizSession.submitCurrent`)
`guard !isGrading` 이 문을 지키는데, `isGrading = true` 는 **`gradeCurrent` 안에서, 그것도 `item.mode == .typing` 일 때만** 켜진다(815행). 선다·O/X·2지선다는 깃발이 안 켜지고, 직접입력도 `Task { … }` 가 실제로 돌기 전까지 한 틱이 빈다.
→ 빠르게 두 번 누르면 같은 문항이 **두 번 채점**되어 사다리·관찰 기록이 두 번 움직일 수 있다. 화면 쪽이 버튼을 막고 있다면 실제로는 안 날 수도 있다 — **그걸 확인하는 첫 테스트 후보.**
→ 고치는 방향: 깃발을 `Task` 를 만들기 **전에** 모든 모드에서 켠다.

### A2. 시간차 실행 10곳이 `DispatchQueue.main.asyncAfter`
`QuestionScreen` 4곳 · `MatchingQuestionScreen` 6곳. 「그 사이 다음 문제로 넘어갔으면 건너뛴다」를 `id` 비교로 손수 지키고 있다.
→ 화면이 사라져도 **취소되지 않는다.** 지금은 `id` 가드가 막아 주지만, 가드를 빠뜨린 한 곳이 생기면 다음 문제를 건드린다.
→ 방향: `Task { try await Task.sleep(for:) }` 로 바꾸고 핸들을 들고 있다가 문제가 바뀔 때 `cancel()`. 흔들림(`shake`)은 `keyframeAnimator` 로 바꾸면 시간차 코드 자체가 사라진다.

### A3. 주인 없는 `Task { … }` 6곳 (`QuizSession`)
489(응원 문구) · 526(채점) · 621(실패 업로드) · 657(마무리 3초) · 714(해설 미리 만들기) · 1045(관찰 업로드). 회차를 나가도 계속 돈다.
→ 채점·해설 미리 만들기는 회차가 끝나면 **취소돼야 맞다.** 업로드는 끝까지 가는 게 맞다. 둘을 나눠서 앞쪽만 핸들을 모아 `endSession()` 에서 취소.

---

## B. Swift 6 언어 모드로 넘어가기

### B1. `SWIFT_VERSION` 5 → 6
기본 격리가 이미 `MainActor` 이고 Approachable Concurrency 도 켜져 있어서, **오류는 적게 나올 것으로 예상한다**(예상일 뿐 — 빌드로 확인). 걸릴 만한 자리는 셋:
- `SpeechListener` 의 오디오 탭·인식 결과 클로저 (이미 `nonisolated static` + `@Sendable` 로 정리돼 있어 통과할 가능성이 높다)
- `SpeechReader.audioSessionSetup` 의 `Task.detached`
- `ObsUploader.isUploading` 같은 `static var`
→ 이것 하나만 하는 단계로 쪼갠다. 오류 목록이 곧 다음 할 일 목록이 된다.

### B2. Swift 6.4 의 `defer` 안 `await` (SE-0493)
`SpeechListener.start()` 의 `catch` 처럼 **async 함수 안에서** 「무슨 일이 있어도 오디오 세션을 되돌린다」는 자리에 맞다. 다만 `finish()`·`cancel()` 은 동기 함수라 거기 `Task { await restoreSessionIfNeeded() }` 는 그대로 남는다 — **쓸 자리가 생각보다 좁다.**

### B3. `print` 12곳 → `Logger`(os)
어머니 폰에서 생긴 일을 콘솔 앱으로 볼 수 있게 된다. 관찰 기록과 겹치는 역할이라 **급하지 않다.**

---

## C. 구조 — 규칙 24 (200줄에서 쪼갠다)

| 파일 | 줄 | 쪼갤 자리 |
|---|---:|---|
| `Screens/QuizSession.swift` | **1,105** | ① 복습(281–338행) ② 해설 창 상태 ③ 관찰 기록(시간 재기·저장·업로드) ④ 칸 계산(`itemIndex`·`placeVoiceItem`) |
| `Screens/QuestionScreen.swift` | 706 | 낱말 사전 시트 다루기 · 보기 버튼 묶음 · 직접입력 칸 |
| `Screens/CorrectAnswerSheet.swift` | 530 | 1차 때 공통 부품을 뺐는데도 크다 — 세 해설 창이 아직 각자 가진 것 |
| `Screens/FeedbackSheet.swift` | 471 | 〃 |
| `DesignSystem/SpeechListener.swift` | 435 | `BandAnalyzer`(파형) 를 제 파일로 |
| `Screens/TrueFalseSheet.swift` · `MatchingQuestionScreen.swift` | 391 · 389 | |

### C1. 해설 창 셋 → 상태 하나 (`QuizSession`)
`feedback` · `correctFeedback` · `trueFalseFeedback` 세 옵셔널이 따로 있다. 「셋 중 하나만 떠 있어야 한다」는 지금 **코드가 아니라 순서**가 지킨다.
→ `enum PresentedCommentary { case incorrect(…), correct(…), trueFalse(…) }` 하나로 두면 **둘이 동시에 뜨는 상태를 만들 수 없게 된다.** 결정 기록의 「같은 모습은 같은 코드로 강제한다」와 같은 생각.

### C2. `shake` 가 두 화면에 각자 있다
1차 기록은 「흔들림 3중복 정리」인데 `QuestionScreen` 과 `MatchingQuestionScreen` 에 같은 함수가 아직 둘이다. 주석에는 「서로를 몰라도 되게 각자 둔다」고 적혀 있다.
→ 이건 **결정 기록과 충돌한다**(「같은 모습은 같은 코드로」). 어느 쪽을 따를지 정해야 한다.

### C3. 안 쓰는 것
- `Focus/FocusAnalyzer.swift` · `QuestionFocusRecord` — `usesModelAnalysis = false` 로 안 불린다. **단, `QuestionFocusRecord` 는 `@Model` 이고 저장소 스키마에 들어 있다** → 그냥 지우면 어머니 폰의 저장소가 열리지 않을 수 있다. D1 을 먼저.
- `Data/glossary.json` — 안 쓰는데 앱 번들에 실린다
- `_to_delete/` — 저장소 루트라 번들에는 안 실리지만, `LegacyFeedbackSheet.swift` 와 `git-index.lock.stale` 이 남아 있다

---

## D. 데이터 안전 — 리팩토링 전에

### D1. SwiftData 스키마에 버전이 없다
`@Model` 4개(`QuestionProgress` · `QuestionFocusRecord` · `ObsRecord` · `ModelFailure`)가 `VersionedSchema` 없이 들어 있다. 칸 하나 바꾸는 순간 **어머니의 학습 기록이 걸린다.**
→ C3 처럼 모델을 지우거나 이름을 바꾸기 전에 `VersionedSchema` + `SchemaMigrationPlan` 을 먼저 깐다. **지금 스키마를 V1 으로 얼려 두기만 해도** 다음 변경이 안전해진다.

### D2. 미리보기 저장소가 앱과 다르다
앱은 모델 4개, `#Preview` 4곳은 2개(`QuestionProgress`·`QuestionFocusRecord`)만 연다. 미리보기에서 관찰 기록을 건드리는 경로를 타면 미리보기가 죽는다. 한 곳에 `previewContainer` 를 두고 같이 쓴다.

---

## E. iOS 27 에서 새로 생긴 것 — 리팩토링이 아니라 「쓸지 말지」

규칙 14·15 에 따라 **기능 후보로만** 적는다. 셋 다 지금 당장 할 것이 아니다.

| 후보 | 닿는 곳 | 대가 |
|---|---|---|
| **Foundation Models 의 Evaluations 프레임워크** | 열린 질문 「`facts` 가 환각을 멈추는가」 — 30문항 해설을 사람이 훑는 대신 자동으로 잴 수 있다 | iOS 27 이상에서만. 평가 기준을 우리가 정해야 한다 |
| **`SpeechAnalyzer` + `SpeechTranscriber`** (iOS 26+) 로 `SFSpeechRecognizer` 교체 | `SpeechListener` | 지금 설계는 `contextualStrings` 로 정답을 힌트로 준다. 개발자 포럼에 **`SpeechTranscriber` 가 문맥 낱말을 잘 안 따른다**는 보고가 있다 — 확인 전에는 옮기지 않는 편이 맞다 |
| **PCC 조건 다시 보기** | 결정 기록 「PCC 보류」 | WWDC26 기준 「소상공인 프로그램 + 첫 다운로드 200만 미만이면 무료」. 보류 이유(200만 이후 유료 등급 없음)는 **여전히 같다** — 결정을 바꿀 근거는 아직 없다 |

Swift 6.4 의 「Swift Testing ↔ XCTest 상호운용」은 **테스트가 하나도 없어서** 지금은 해당 없음.

---

## 추천 순서 — 고르는 건 사용자

| 길 | 순서 | 얻는 것 | 대가 |
|---|---|---|---|
| ① 안전 먼저 | D1 → `KCTTests` 타깃 + A1 테스트 → B1 → C1 → C | 어머니 기록을 지킨 채로 크게 고칠 수 있다 | 첫 두 걸음은 눈에 보이는 변화가 없다 |
| ② 큰 파일 먼저 | C1 → C(QuizSession 쪼개기) → A | 매일 여는 파일이 읽기 쉬워진다 | 테스트 없이 1,105줄을 옮긴다 — 1차 때 `logFeedbackAttachment` 가 조용히 사라진 것과 같은 일이 다시 날 수 있다 |
| ③ Swift 6 먼저 | B1 → 나온 오류부터 | 컴파일러가 할 일을 정해 준다 | 오류 수를 모른다 |

**생각해 볼 것** — 1차 리팩토링의 「다음 할 일」이었던 **실기기 확인 9개**가 아직 PROGRESS 에 남아 있다. 2차를 1차 확인보다 먼저 시작하면, 나중에 무언가 깨졌을 때 1차 탓인지 2차 탓인지 가를 수 없다.

---

## 참고
- [Swift 6.4 released — InfoQ](https://www.infoq.com/news/2026/09/swift-6-4-released/)
- [What's new in Swift — WWDC26 guide](https://developer.apple.com/wwdc26/guides/swift/)
- [WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)
- [SpeechTranscriber 문서](https://developer.apple.com/documentation/speech/speechtranscriber) · [포럼: 전문 용어 인식 개선](https://developer.apple.com/forums/thread/801877)

---

## 적용 결과 (2026-10-23, 같은 날)

사용자가 「앱을 수정해줘」로 이번 작업을 맡겨서(규칙 1 예외) AI 가 `.swift` 를 직접 고쳤다. 브랜치 `refactor-2`, **아직 커밋하지 않았다.**

### 확인한 것 (증거)

| 확인 | 결과 |
|---|---|
| 고치기 전 빌드 (Xcode 27.2 · Swift 6.4.2, 언어 모드 5) | 성공, 경고 2개 |
| 단계별 빌드 7번 | 마지막 빌드 **성공, 오류 0 · 경고 0** |
| 저장소 이전 시험 (iPhone 17 Pro 시뮬레이터) | 예전 앱(HEAD `ba66262`)으로 저장소를 만들고 그 위에 새 앱을 설치 → **켜졌고 10초 뒤에도 살아 있음**, 같은 `default.store` 를 열었음, 첫 화면 스크린샷이 예전과 같음 |
| 회차 흐름 (문제 풀기·해설 창·복습·연결 문제·음성) | **확인 못 함** — 화면을 누르는 자동 시험이 없다. 아래 실기기 목록으로 |

### 고친 것

| 단계 | 파일 | 무엇을 | 왜 |
|---|---|---|---|
| B1 | `KCT.xcodeproj` | `SWIFT_VERSION` 5.0 → **6.0** | 데이터 경합 검사를 경고가 아니라 오류로. 나온 오류 5개를 아래에서 고쳤다 |
| B1 | `Progress/AskingMode.swift` | `nonisolated enum` | `@Model`(액터에 안 묶임)이 `mastery` 를 못 읽었다 |
| B1 | `Grading/ModelCall.swift` | `Content: Generable & Sendable` | 시한(withTimeout)의 `@Sendable` 클로저가 결과를 들고 나와야 한다 |
| B1 | `GlossaryExampleText.swift` · `MatchBoard.swift` | 두 `Shape` 에 `nonisolated` | `Shape` 는 메인 액터 밖에서도 불린다 |
| B1 | `SpeechListener.swift` | `@preconcurrency import Speech`, `BandAnalyzer: @unchecked Sendable` | Speech 가 아직 Sendable 표시가 없다. `@unchecked` 의 약속 근거는 그 자리 주석에 |
| B1 | `ObsUploader.swift` | `ISO8601DateFormatter` → `Date.ISO8601FormatStyle(includingFractionalSeconds:)` | 경고 제거. 결과 글자 모양(소수점 세 자리, Z)은 같다 |
| D1 | **새** `App/ModelStore.swift` · `KCTApp.swift` | `KCTSchemaV1` + `KCTMigrationPlan`, `.modelContainer(ModelStore.shared)` | 저장 모양을 한 칸도 안 바꾸고 V1 로 얼렸다. 다음 변경부터 옮길 길이 있다 |
| D2 | `RootView` · `QuizView` · `MyHistoryView` · `PracticeHomeView` | 미리보기 저장소 → `ModelStore.preview` | 모델 2개만 열던 것을 앱과 같은 4개로 |
| A1 | `QuizSession.swift` | `hasSubmittedCurrent` 문지기 | 이중 제출 틈. `Task` 를 만들기 **전에** 켜고, 다음 문항에서 끈다 |
| A2·C2 | **새** `DesignSystem/MotionBeats.swift` · `QuestionScreen` · `MatchingQuestionScreen` | `DispatchQueue` 10곳 → `Beat.after`, 두 `shake` → `Beat.shake` 하나 | async·await 하나로(규칙 7). 박자 값은 그대로. 「같은 모습은 같은 코드로」를 따랐다 |
| A3 | `QuizSession.swift` · `QuizView.swift` | `leave()` + `.onDisappear` | 화면을 떠나면 해설 미리 만들기·응원·분석·3초 박자를 멈춘다. **채점은 안 멈춘다**(맞힌 답이 오답으로 적힐 수 있어서) |
| A3 | `ModelCall.swift` | 취소면 `Writing.empty` | 멈춘 작업이 `model_failure` 표에 「실패」로 쌓이지 않게 |
| C1 | `Grading/Commentary.swift` · `QuizSession` | `PresentedCommentary` 열거형 하나 | 해설 창 셋이 동시에 뜰 수 없게. `feedback` 등 세 이름은 읽기 전용으로 남겨 `QuizView` 는 그대로 |
| C | **새** `Session/ReviewRound.swift` | 복습 상태 다섯 개 + 시작·다음·기록 | QuizSession 쪼개기 ① |
| C | **새** `Observation/ObsSessionLog.swift` | 회차 번호·시각·잰 시간 + ObsRecord 만들기 | QuizSession 쪼개기 ② |
| C | **새** `Grading/ExplanationPrefetcher.swift` | 해설 미리 만들기 + `cancelAll()` | QuizSession 쪼개기 ③. 예전엔 새 회차에서 딕셔너리만 비우고 작업은 안 멈췄다 |
| B3 | **새** `App/Log.swift` + 6개 파일 | `print` 12곳 → `Logger` (grading·model·upload·voice) | 어머니 폰에서 난 일을 Mac 콘솔 앱으로 볼 수 있다 |

`QuizSession.swift` 1,105줄 → 1,051줄 (덩어리 셋을 뺐지만 그 자리에 설명 주석과 읽기용 이름이 늘었다). **200줄 기준에는 아직 한참 멀다** — 남은 덩어리는 채점(`gradeCurrent`·`judge`)과 해설 창 띄우기 셋이다.

### 일부러 안 한 것

- **`QuestionScreen` 706줄 · 해설 시트 셋 쪼개기** — 화면 코드는 눈으로 확인해야 하는데 이번엔 볼 수단이 없었다
- **`QuestionFocusRecord` · `FocusAnalyzer` 지우기** — 이제 V1 이 있으니 V2 로 지울 수 있다. 다만 「2층 하이라이트를 다시 켤지」가 먼저 정해져야 한다
- **`glossary.json` · `_to_delete/`** — 지우기는 사용자가
- **`SpeechAnalyzer` 로 옮기기 · Evaluations 프레임워크** — 리팩토링이 아니라 기능 (E절)
- **`KCTTests` 타깃** — 규칙대로 사용자가 Xcode 에서 만든다. 만들면 첫 테스트는 「같은 문항을 두 번 내면 한 번만 채점되는가」(A1)

### 실기기에서 볼 것 (1차의 9개와 함께)

1. 선다·O/X 를 **빠르게 두 번** 눌러도 사다리·관찰 기록이 한 번만 움직이나 (A1)
2. 오답 보기 흔들림·연결 카드 흔들림이 예전 박자 그대로인가 (`Beat.shake`)
3. 오답 보기를 누르고 0.32초 안에 다음 문제로 넘어가도 새 문제의 보기가 안 지워지나
4. 해설 창 셋이 예전처럼 뜨고 닫히나, 복습 → 결과 화면이 이어지나
5. 회차 중간에 X 로 나갔다 다시 들어와도 정상인가 (`leave()`)
6. **어머니 폰에 덮어 깔아도 기록이 그대로 있나** — 시뮬레이터에서는 확인했지만 실제 기록이 든 저장소는 처음이다
7. Mac 콘솔 앱에서 `category:model` 로 모델 실패가 보이나
