# BRAINSTORM — 도입할까 말까

**70대 어머니가 1,130문항을 외우는 일**에 도움이 되는 것만 담습니다.
애플 HIG · Apple AI · 새 프레임워크를 훑어 고른 후보와, **안 쓸 것**과 그 이유입니다.

- 작성 : 2026-09-23 (1차 리팩토링 직후, 코드 전체를 본 상태에서)
- 근거 : 기억이 아니라 `DocumentationSearch` 로 확인한 것만 (규칙 8·9). 링크를 함께 남깁니다
- 형식 : 항목마다 **① 어머니에게 무엇이 일어나나 ② 그러려면 무엇이 참이어야 하나
  ③ 뺄 것 하나** (규칙 14·15). 셋을 못 적은 것은 「아직 만들 것이 아니다」로 두었습니다

> ⚠️ **이 파일은 할 일 목록이 아닙니다.** 고르는 것은 어머니 로그를 보고 정합니다
> ([PROGRESS.md](PROGRESS.md) 「열린 질문」). 여기 있는 것을 다 하면 앱이 무거워집니다.

---

## 지금 할 것 — 셋을 다 적을 수 있는 것

### 1. Dynamic Type ⭐️ 가장 큰 구멍

**지금 앱의 모든 글꼴이 `.system(size:)` 고정값입니다.** 어머니가 설정에서 글자를 키워도
**한 글자도 안 커집니다.** 70대 어르신용 앱에서 이게 HIG 쪽 가장 큰 결함입니다.

| 셋 | |
|---|---|
| ① 어머니에게 | 설정 → 손쉬운 사용 → 글자 크기를 키우면 지문·보기·해설이 **다 같이** 커진다. 지금은 우리가 정한 30pt 가 최대치다 |
| ② 참이어야 할 것 | 「지문이 화면 절반 안에서 끝난다」는 규칙(`QuestionScreen.questionFont`)이 **커진 글자에서도** 성립해야 한다. 지금은 절반을 넘기면 글꼴을 줄이는데, Dynamic Type 은 그 반대로 키운다 — **두 규칙이 부딪힌다** |
| ③ 뺄 것 | 「지문을 화면 절반 안에」 규칙 자체. 해설 모달이 `.medium`(아래 절반)이라 생긴 제약인데, 시트를 **`.large` 까지 끌 수 있게** 하면 절반 규칙을 버리고 스크롤에 맡길 수 있다 |

**확인한 API**

- SwiftUI: [`Font.custom(_:size:relativeTo:)`](https://developer.apple.com/documentation/SwiftUI/Font/custom(_:size:relativeTo:)) ·
  [`@ScaledMetric`](https://developer.apple.com/documentation/SwiftUI/ScaledMetric)(여백·버튼 높이도 같이 키운다) ·
  [`DynamicTypeSize`](https://developer.apple.com/documentation/SwiftUI/DynamicTypeSize)(환경에서 읽어 레이아웃을 바꾼다)
- **UIKit 쪽이 관건** — 지문(`KoreanText`)·해설 본문(`JustifiedKoreanText`)이 `UILabel` 이다.
  [`UIFontMetrics(forTextStyle:).scaledFont(for:maximumPointSize:)`](https://developer.apple.com/documentation/UIKit/UIFontMetrics/scaledFont(for:maximumPointSize:)) 로
  감싸고 [`adjustsFontForContentSizeCategory = true`](https://developer.apple.com/documentation/UIKit/UIContentSizeCategoryAdjusting/adjustsFontForContentSizeCategory) 를 켜야 한다
  ([Scaling fonts automatically](https://developer.apple.com/documentation/UIKit/scaling-fonts-automatically))

> ⚠️ `scaledFont(for:)` 에 **이미 스케일된 글꼴을 넣으면 예외가 납니다.** `fittingFont(...)` 가
> 크기를 줄여 돌려주는 값을 그대로 넘기면 안 됩니다 — 순서를 정해야 합니다(먼저 스케일, 그다음 축소).

**작게 시작하는 길** — 전부 한 번에 바꾸지 않고 `CommentaryMetrics` 만 `@ScaledMetric` 으로
바꿔 봅니다. 해설 창 세 개가 그 상수 하나를 공유하므로(리팩토링 결과) **한 곳만 고치면
세 창이 같이 커집니다.** 커진 모습을 보고 나머지를 정합니다.

---

### 2. 아이콘 버튼의 VoiceOver 라벨

`CircleIconButton` 은 **글자가 없습니다.** VoiceOver 가 읽을 것이 `xmark` 라는 심볼 이름뿐입니다.

| 셋 | |
|---|---|
| ① 어머니에게 | 눈이 나빠져 VoiceOver 를 켰을 때 「나가기」·「다시 읽기」로 들린다. 지금은 안 들리거나 영어로 들린다 |
| ② 참이어야 할 것 | 라벨이 **행동**을 말해야 한다 — 「엑스」가 아니라 「문제 풀기 나가기」 |
| ③ 뺄 것 | 없다. 두 줄 추가일 뿐 뺄 것이 없다 — **그래서 이게 1번 다음으로 싼 항목이다** |

[`accessibilityLabel(_:)`](https://developer.apple.com/documentation/SwiftUI/View/accessibilityLabel(_:)) 하나면 됩니다.
`CircleIconButton` 에 `label: String` 인자를 더하고 부르는 세 곳이 넘깁니다.

같이 볼 것 — `MatchCard` 는 「선택됨·맞음·틀림」을 **색과 테두리로만** 말합니다.
VoiceOver 에는 `accessibilityAddTraits(.isSelected)` 가 필요하고,
[`supportsDifferentiateWithoutColorAlone`](https://developer.apple.com/documentation/AppStoreConnectAPI/configuring-accessibility-declarations#Read-accessibility-feature-details)
관점에서도 모양이나 글자가 하나 더 있어야 합니다.

---

### 3. 해설을 **흘려서** 보여주기 (스트리밍)

지금은 해설이 다 만들어질 때까지 기다린 뒤 한 번에 갈아 끼웁니다. 그래서 응원 문구를
**최소 3초** 붙들어 둡니다(`holdWaitingLine`) — 안 그러면 글자가 나타났다 사라집니다.

| 셋 | |
|---|---|
| ① 어머니에게 | 해설이 **한 문장씩 나타난다.** 기다림이 「비어 있는 3초」에서 「읽는 3초」로 바뀐다 |
| ② 참이어야 할 것 | 부분 생성된 글이 **그 자체로 읽을 만해야** 한다. 「단군왕검은 고조선을」에서 멈춘 화면이 어머니에게 고장으로 보이면 안 된다 — 문장 끝(`.`)까지 온 것만 보여주는 걸러내기가 필요하다 |
| ③ 뺄 것 | `holdWaitingLine`(3초 붙들기)과 맥동(`pulsingWhileWaiting`). 글이 흐르면 기다림을 꾸밀 필요가 없다 |

**확인한 API** — [`streamResponse(to:generating:options:)`](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession/streamResponse(to:generating:includeSchemaInPrompt:options:)) 가
[`ResponseStream`](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession/ResponseStream)(부분 생성 스냅샷의 async 시퀀스)을 돌려주고,
[`Generable.PartiallyGenerated`](https://developer.apple.com/documentation/FoundationModels/Generable#Converting-to-partially-generated) 로 중간 상태를 받습니다.

> ⚠️ 애플 문서가 명시 — **백그라운드에서는 스트리밍을 쓰지 말라**(`rateLimited` 위험).
> 낱말 사전 예문은 시트가 떠 있는 동안(포그라운드)이라 괜찮지만, 회차 시작 때 뒤에서 만드는
> 응원 문구(`EncouragementWriter`)는 **지금처럼 비스트리밍으로 둬야** 합니다.

**리팩토링이 이걸 쉽게 만들었습니다** — `ModelCall.generate` 한 곳에 `streamResponse` 변형을
더하면 세 writer 가 같이 얻습니다.

---

### 4. `ContentFile.saveDownloaded(_:)` 의 서명 고치기

[Q&A.md](Q&A.md) 에 적은 문제입니다. 받은 JSON 을 `Payload → Data` 로 **다시 인코딩**하므로
`Payload` 에 없는 키가 조용히 사라집니다. 서버 갱신을 실제로 붙이기 **전에** 고쳐야 합니다.

| 셋 | |
|---|---|
| ① 어머니에게 | (직접 보이는 것 없음) 앱 업데이트 없이 문제집이 1,130문항으로 늘어날 때, **새 칸이 사라지지 않는다** |
| ② 참이어야 할 것 | 서버가 주는 JSON 을 원본 바이트로 저장하면서도, 깨진 것을 **저장 전에** 걸러야 한다 |
| ③ 뺄 것 | 지금 서명(`saveDownloaded(_ payload: Payload)`). `saveDownloaded(_ data: Data)` 로 바꾸고 검증은 따로 |

---

## 나중 — ①은 적을 수 있는데 ②가 아직 안 참인 것

### 5. 음성 입력 (`SpeechAnalyzer` · iOS 26 새 API)

[PROGRESS.md](PROGRESS.md) 「열린 질문」에 이미 있습니다 — 「음성 입력이 붙으면 채점 층을
다시 봐야 한다」. 사다리 맨 위(`AskingMode.typing`)에서 **키보드가 벽**입니다. 70대에게
한글 키보드로 「팔만대장경」을 치는 것은 문제를 아는 것과 다른 능력입니다.

**확인한 API** — [`SpeechAnalyzer`](https://developer.apple.com/documentation/Speech/SpeechAnalyzer) + 모듈 조합

| 모듈 | 무엇 |
|---|---|
| [`SpeechTranscriber`](https://developer.apple.com/documentation/Speech/SpeechTranscriber) | 일반 목적. `init(locale:preset:)` 에 [`.progressiveTranscription`](https://developer.apple.com/documentation/Speech/SpeechTranscriber/Preset#Standard-presets)(실시간 즉시 전사)이 있다 |
| [`DictationTranscriber`](https://developer.apple.com/documentation/Speech/DictationTranscriber) | 시스템 받아쓰기와 비슷하고 **구형 기기 호환** |
| [`SpeechDetector`](https://developer.apple.com/documentation/Speech/SpeechDetector) | 사람이 말하는 중인지(VAD). 「말이 끝났다」를 스스로 아는 데 쓴다 |

절차도 문서에 그대로 있습니다 — 모듈 만들기 → [`AssetInventory.assetInstallationRequest(supporting:)`](https://developer.apple.com/documentation/Speech/AssetInventory) 로
한국어 자산 내려받기 → 입력 시퀀스 → [`AnalyzerInputConverter`](https://developer.apple.com/documentation/Speech/AnalyzerInputConverter) →
`transcriber.results` 를 `for try await` 로 받기.

**②가 아직 안 참인 이유** — 인식기가 「고조선」을 「고죠선」으로 적으면 **맞혔는데 틀렸다**가
됩니다. 지금 `AnswerMatcher` 는 「한 글자만 다르면 오타 = 오답」인데, 음성에서는 그게 **인식기의
잘못**입니다. `AnswerSource.voice` 자리와 `sounds(_:)`(발음 정규화)를 이미 비워 뒀지만
**비어 있습니다** — 한글 자모 단위 발음 비교를 먼저 만들어야 합니다.

| 셋 | |
|---|---|
| ① 어머니에게 | 마이크를 누르고 「고조선」이라 말하면 답이 된다. 사다리 맨 칸이 벽이 아니게 된다 |
| ② 참이어야 할 것 | 발음 정규화(`AnswerMatcher.sounds`). **이것부터다** |
| ③ 뺄 것 | 직접입력 칸의 키보드를 없애지는 않는다 — 말하기가 어려운 날도 있다. 대신 **6번째 칸을 음성 전용으로** 비워 두려던 계획(`QuizSession` 주석)을 되살린다 |

---

### 6. 「오늘 문제 풀기」를 앱 밖에서 (App Intents · 위젯 · Live Activity)

| 셋 | |
|---|---|
| ① 어머니에게 | 홈 화면 위젯에 「지금까지 412개」가 보이고, 탭하면 바로 회차가 시작된다. 앱을 찾아 여는 단계가 사라진다 |
| ② 참이어야 할 것 | 「오늘 할 것」이 정해져 있어야 한다. 지금은 **하루 몇 회차인지 정하지 않았다** — 회차는 끝없이 다시 풀 수 있다 |
| ③ 뺄 것 | 없다 — **그래서 아직 만들 것이 아니다.** 먼저 「하루 한 회차」 같은 규칙을 정해야 한다 |

간격 반복(`QuestionProgress.nextDueAt`)이 **아직 동작하지 않는다**는 것과 같은 뿌리입니다.
「오늘 복습할 것 N개」가 계산되지 않으면 위젯에 쓸 숫자가 없습니다.

---

### 7. Accessibility Nutrition Labels (App Store 접근성 표시)

App Store 제품 페이지에 「이 앱은 VoiceOver·큰 글자를 지원합니다」를 표시하는 것입니다.
[App Store Connect API 의 `AccessibilityDeclaration`](https://developer.apple.com/documentation/AppStoreConnectAPI/accessibility-declarations) 으로 선언합니다.

| 항목 | 지금 |
|---|---|
| `supportsLargerText` | ❌ **글자를 200% 이상 키울 수 있어야** 한다 — 1번을 해야 참이 된다 |
| `supportsVoiceover` | ❌ 아이콘 버튼 라벨이 없다 — 2번 |
| `supportsSufficientContrast` | 🤔 대비는 대체로 맞춰 뒀지만 측정한 것은 몇 곳뿐 |
| `supportsDarkInterface` | ❌ **`.black`/`.white` 하드코딩** 때문에 다크 모드가 막혀 있다 |
| `supportsReducedMotion` | ✅ `accessibilityReduceMotion` 을 이미 본다(맥동을 끈다) |
| `supportsDifferentiateWithoutColorAlone` | 🤔 `ChoiceButton` 은 체크 아이콘이 함께 바뀌어 ✅. `MatchCard` 는 색만이라 ❌ |

**아직 배포 계획이 없으니 지금 할 일은 아닙니다.** 다만 이 목록이 **접근성 점검표**로
좋습니다 — 「무엇을 지원한다고 말할 수 있나」가 곧 「무엇을 안 했나」입니다.

---

### 8. 다크 모드 (하드코딩된 `.black`/`.white` 걷어내기)

지금 앱은 **배경을 흰색으로 고정**해 두고, 그래서 글자를 `.black` 으로 **못 박아** 두었습니다
(`MatchingQuestionScreen.title` 의 주석이 그 이유를 적고 있습니다 — `.primary` 로 두면
다크 모드에서 흰 배경 위 흰 글자가 됩니다).

| 셋 | |
|---|---|
| ① 어머니에게 | 저녁에 눈이 덜 부시다. 어르신은 밝은 화면을 오래 보기 힘들다 |
| ② 참이어야 할 것 | **색을 `AppColor` 로 모아야** 한다. 지금 `.black`·`.white` 가 화면마다 흩어져 있어 한 번에 바꿀 수 없다 |
| ③ 뺄 것 | 「배경은 전부 흰색」 결정. 그게 `.black` 하드코딩의 원인이다 |

리팩토링에서 `AppColor` 를 정리해 두었으니(죽은 색 9개 제거) **여기에 `Color("…")`
에셋 카탈로그 색을 넣으면** 라이트/다크가 자동으로 갈립니다.
다만 **대비 값을 다시 다 재야 합니다** — 흰 카드 위 6.48:1 같은 숫자가 전부 바뀝니다.

---

### 9. 문항을 1,130개로 (코드가 아니라 데이터)

[CLAUDE.md](CLAUDE.md) 가 이미 적어 둔 것입니다 — `문제집_유형분류_v2.xlsx` 에 분류가 끝난
1,130문항이 있고 `questions.json` 으로 옮기는 일이 남았습니다.

**리팩토링과의 관계** — `CodingKeys` 맵핑으로 JSON 을 안 건드렸으므로(9단계) 이 작업과
**충돌하지 않습니다.** 엑셀 → JSON 변환 스크립트를 쓸 때 `examples` 키를 그대로 쓰면 됩니다.

> ⚠️ CLAUDE.md 의 경고 — **문항 확장과 근접 오답 설계는 같이 가야 합니다.** 지금 오답이
> 「설계가 아니라 우연」인 것은 전체 정답이 30개뿐이기 때문입니다.

---

## 안 할 것 — 이유를 적어 두는 쪽

| 무엇 | 왜 안 하나 |
|---|---|
| **Image Playground / 이미지 생성** | 「고조선」 그림이 어머니의 기억을 돕는다는 근거가 없다. 오히려 **모델이 지어낸 그림**이 틀린 것을 외우게 할 위험이 있다 — `facts` 로 환각을 막아 온 것과 정반대다 |
| **Writing Tools** | 어머니가 **글을 쓰지 않는다.** 답 한 낱말을 입력할 뿐이다 |
| **Translation framework** | 어머니는 한국어를 **배우는** 중이다. 번역을 붙이면 한국어를 안 읽고 번역을 읽는다. (다만 「모르는 낱말」은 이미 낱말 사전으로 풀고 있다 — 그게 맞는 방향이다) |
| **CloudKit 동기화** | 기기가 하나다. 어머니 폰 하나에서만 쓴다 |
| **TipKit** | 화면에 버튼이 두 개다. 팁을 띄울 만큼 복잡하지 않고, **팝업이 하나 더 뜨는 것이 더 해롭다** |
| **PCC(Private Cloud Compute)** | 이미 보류 결정이 있다([PROGRESS.md](PROGRESS.md)) — 2M 다운로드까지만 무료 |
| **게임화(뱃지·연속 기록·순위)** | 「며칠 연속」이 끊기면 그만두는 이유가 된다. 이 앱이 강조하는 숫자는 **누적 정답**이고 그건 절대 줄지 않는다 — 의도된 설계다 |
| **Combine** | CLAUDE.md 규칙 7 |

---

## 리팩토링에서 미룬 코드 정리 (기능이 아니라 빚)

| 무엇 | 왜 미뤘나 | 얼마나 급한가 |
|---|---|---|
| `QuizSession.swift` **824줄** 해체 | 앱의 심장. 오동작 위험이 가장 크다 | 🔸 지금은 주석이 지도를 해 준다. **다음에 회차 규칙을 고칠 때** 함께 |
| `QuestionScreen.swift` **468줄** 쪼개기 | 낱말 사전 시트 상태(`glossaryOpenToken` 경합)가 화면에 얽혀 있다 | 🔸 그 경합을 실기기로 확인한 **뒤에** |
| `ObsUploader` 실패 업로드 **재진입 가드 없음** | 동작 변경 | 🔹 실패는 드물어 겹칠 확률이 낮다. 로그에 중복이 보이면 그때 |
| `EncouragementWriter` **실패를 안 남긴다** | 서버 RLS 정책에 `job = 'encouragement'` 를 먼저 넣어야 한다 | 🔹 응원 문구는 틀려도 `fallback` 이 있어 해가 없다 |
| `KoreanText.showsMarkerHighlight = false` | 진단용으로 꺼 둔 것 | 🔸 **형광펜을 되살릴지 결정해야 한다.** 꺼 둔 채로 오래되면 그 코드가 죽는다 |
| `nextDueAt` 이 늘 `nil` | 간격 반복이 동작하지 않는다 | 🔸 6번(위젯)의 전제. 로그로 실제 간격을 본 뒤 |
| `Focus` 2층(`FocusAnalyzer`) | 의도적으로 꺼 둠 | 🔹 되살릴 때 「강조 길이 제한」 검증을 같이 넣어야 한다(주석에 적혀 있음) |

---

## 무엇부터 할까 — 한 줄 의견

**1번(Dynamic Type)입니다.** 이유 셋.

1. **70대 어르신용 앱에서 글자 크기를 못 바꾸는 것**이 가장 큰 결함입니다. 다른 어떤 기능도
   「글자가 안 보인다」를 이기지 못합니다
2. 리팩토링이 **이 작업을 싸게 만들었습니다** — `CommentaryMetrics` 하나를 고치면 세 해설 창이,
   `ActionCapsuleLabel` 하나를 고치면 버튼 다섯 자리가 같이 바뀝니다
3. **어머니에게 물어볼 수 있는 일**입니다(규칙 19). 「이 크기가 편하세요?」는 어머니가
   **평가할 수 있는** 질문입니다 — 「스트리밍이 자연스러운가」와 다릅니다

⭐️ **사용자님이 정할 지점** — 1번을 하려면 **「지문이 화면 절반 안에서 끝난다」 규칙을
버려야 할 수도 있습니다**(위 ③). 그 규칙은 「해설 모달을 내리지 않고 문제를 같이 본다」를
위한 것이었습니다. 어머니가 실제로 **해설을 보면서 지문을 다시 읽는지** — 그걸 먼저
관찰하면 이 판단이 쉬워집니다. 실기기로 한 회차 옆에서 보시는 것이 이 문서 전체보다
정확합니다.
