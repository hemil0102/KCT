# Q&A

막혔던 것과 그 해결을 남기는 기록입니다. `CLAUDE.md` 규칙 6에 따라 쌓아갑니다.

빌드가 막혔던 것, 개념을 오해했던 것, 문서와 실제가 달랐던 것만 남깁니다. 최신 항목이 위에 옵니다.

---

## 알림창의 「다음 문제」를 한 번 눌렀는데 두 문제가 넘어간다

**Q** — 틀리면 뜨는 `alert` 에서 「다음 문제」를 누르면 진행 막대가 **두 칸** 찬다. 한 번만 눌렀는데.

**A** — `dismissFeedback()` 이 **두 번 불렸습니다.**

```swift
isPresented: Binding(
    get: { session?.feedback != nil },
    set: { if !$0 { session?.dismissFeedback() } }   // ← 여기서 한 번
)
) {
    Button("다음 문제") { session?.dismissFeedback() }  // ← 여기서 또 한 번
}
```

`alert` 은 버튼을 누르면 **스스로 닫으면서** `isPresented` 에 `false` 를 씁니다. 그 쓰기가 `set` 을 부릅니다. 버튼과 `set` 양쪽에 같은 일을 시켜 둔 것이 원인이었습니다.

**처음 고친 방법이 틀렸다** — 버튼의 중괄호를 비워 「`set` 만 일하게」 했더니 여전히 두 칸 넘어갔습니다. **`set` 이 몇 번 불리는지는 SwiftUI 가 정합니다.** 화면을 다시 그리는 도중에 또 부를 수 있습니다.

**해결** — 「누가 부르는가」를 맞히지 않고, **몇 번 불려도 한 번만 넘어가게** 만들었습니다.

```swift
    func dismissFeedback() {
        guard feedback != nil else { return }

        feedback = nil
        moveToNextQuestion()
    }
```

그리고 `set` 은 아무것도 하지 않게 두고(`set: { _ in }`), 넘기는 일은 버튼 하나가 합니다. `feedback` 이 `nil` 이 되면 `get` 이 `false` 를 돌려주므로 창은 알아서 닫힙니다.

**교훈** — **화면이 부르는 상태 변경 함수는 「두 번 불려도 결과가 같게」 만듭니다.** 이벤트가 몇 번 오는지는 우리가 정하지 않습니다. ``ObsUploader`` 의 `isUploading` 깃발이 같은 이유로 있었고, 그때도 증상은 「한 번인데 두 줄」이었습니다.

---

## 버튼에서 `async` 채점을 부르기 — `Task` 는 필요하고, `defer` 는 아니었다

**Q** — 채점을 회차 끝이 아니라 **문항마다** 하려고 `submitCurrent()` 안에서 `judge()` 를 부르려는데, `judge()` 에는 `async` 가 붙어 있고 `submitCurrent()` 에는 없다. 그리고 아래 세 줄은 도대체 뭘 하는 건가?

```swift
let usesModel = (item.mode == .typing)
if usesModel { isGrading = true }
defer { if usesModel { isGrading = false } }
```

**A** — 두 가지가 섞여 있었습니다.

### ① `Task { }` — 기다릴 수 없는 곳에서 기다리는 일을 시작하는 법

`async` 함수는 **중간에 멈췄다가 나중에 이어지는** 함수입니다. 직접입력은 기기 안의 모델이 답하는 데 1~3초가 걸려서 그렇게 만들어져 있습니다.

그런데 `submitCurrent()` 는 **버튼이 부르는 함수**라 `async` 가 될 수 없습니다. SwiftUI 의 버튼은 기다려 주지 않습니다.

`Task { }` 는 그 틈을 메웁니다 — **「이 일을 시작해 두고, 나는 먼저 돌아간다」**.

```swift
Task { await gradeCurrent(item, answer: trimmed) }
```

이 파일에는 같은 모양이 이미 두 군데 있었습니다. `uploadObservations()` 와, 예전 `submitCurrent()` 의 `Task { await gradeAll() }` 입니다. **처음 보는 문제가 아니라 이미 쓰던 도구였습니다.**

### ② `defer` — 「나갈 때 이걸 해라」

`defer` 는 **함수를 어떤 길로 빠져나가든** 블록 안을 실행합니다. 그래서 「켰으면 반드시 끈다」 같은 짝을 지킬 때 씁니다. 중간에 `return` 이 여러 개거나 오류를 던질 수 있으면 값어치가 큽니다.

`isGrading` 은 켜지면 화면이 「채점 중이에요」(``GradingScreen``)로 바뀌는 깃발입니다. 직접입력만 모델을 부르므로 **직접입력일 때만** 켭니다 — 선다형에도 켜면 켜자마자 꺼져서 **화면이 한 번 깜빡입니다.**

### 그런데 여기서는 `defer` 가 필요 없었다

`gradeCurrent()` 에는 **중간에 빠져나가는 길이 없습니다.** 항상 끝까지 갑니다. 그러면 `defer` 는 하는 일이 평범한 한 줄과 똑같으면서 읽기만 어렵습니다.

```swift
if item.mode == .typing { isGrading = true }

let isCorrect = await judge(item, answer: answer)
isGrading = false
```

끌 때는 조건도 필요 없습니다 — **켠 적이 없으면 이미 `false`** 라, 끄나 마나 같습니다. 세 줄이 두 줄이 되고 `usesModel` 이라는 이름 하나가 사라졌습니다.

**교훈 둘**

- **`defer` 는 「나갈 길이 여럿일 때」 쓰는 도구입니다.** 길이 하나면 그냥 마지막 줄에 적습니다. 습관으로 붙이면 읽는 사람이 「무슨 함정이 있길래」 하고 멈춥니다.
- **「이해가 안 된다」는 대개 코드가 어려워서가 아니라 필요 없는 것이 들어 있어서입니다.** 설명이 길어지면 코드를 의심합니다.

---

## 여러 파일에 sed 를 돌렸는데 아무것도 안 바뀜 — zsh 는 단어 분리를 하지 않는다

**Q** — 이름 일괄 변경을 하려고 아래처럼 썼는데, `sed: ...: No such file or directory` 가 뜨고 파일이 하나도 안 바뀌었다.

```sh
FILES=$(find . -name "*.swift")
for f in $FILES; do sed -i '' 's/옛이름/새이름/g' "$f"; done
```

**A** — **zsh 는 따옴표 없는 변수를 단어로 쪼개지 않습니다.** bash 라면 `$FILES` 가 공백에서 갈라져 파일별로 반복되지만, zsh 에서는 **전체 목록이 하나의 문자열**로 들어갑니다. 그래서 `sed` 가 "`./A.swift ./B.swift ...`" 라는 이름의 파일 하나를 찾다가 실패합니다.

오류 메시지가 파일 목록을 쭉 늘어놓고 끝에 `: No such file or directory` 를 붙이는 것이 이 증상의 특징입니다.

**해결** — 셸의 단어 분리에 의존하지 않고 `find` 가 직접 넘기게 합니다.

```sh
find . -name "*.swift" -exec sed -i '' 's/옛이름/새이름/g' {} +
```

`{} +` 는 "찾은 파일들을 한 번에 인자로 넘겨라" 는 뜻이라 빠르기도 합니다. (배열 `FILES=(...)` 를 쓰거나 zsh 에서 `${=FILES}` 로 분리를 강제할 수도 있지만, `-exec` 가 셸 종류와 무관해서 가장 안전합니다.)

**교훈** — 일괄 변경 뒤에는 **바뀐 것을 세어 확인합니다.** `grep -rn '옛이름' .` 이 비어 있는지 보면 조용한 실패를 놓치지 않습니다. macOS 기본 셸은 zsh 이므로 bash 습관이 그대로 통하지 않습니다.

---

## CLAUDE.md 규칙이 하나도 지켜지지 않음 — 파일이 없었다

**Q** — CLAUDE.md에 Guide·Progress·Q&A 규칙을 적어놨는데 AI가 전혀 따르지 않는다. 규칙이 확인되고 있나?

**A** — **확인되지 않고 있었습니다. KCT에 `CLAUDE.md` 파일 자체가 없었습니다.**

규칙을 적어둔 곳은 `realitykit-audio-lab/CLAUDE.md` 였고, KCT는 빈손이었습니다. 다음을 모두 확인했습니다.

- 저장소 전체(깊이 4)에 `CLAUDE*.md`·`AGENTS.md` 없음
- `.claude/` 디렉터리 없음, `~/.claude/CLAUDE.md` 없음
- git 히스토리에도 추가된 적 없음 (`git log --diff-filter=A`)

**AI 규칙 파일은 저장소마다 따로 있어야 합니다.** 한 프로젝트에 적어둔 규칙이 다른 프로젝트로 따라오지 않습니다. Claude Code는 **작업 디렉터리의 `CLAUDE.md`** 를 읽으므로, KCT의 경우 `KCT/KCT/CLAUDE.md`(git 루트, `.xcodeproj` 와 같은 자리)에 있어야 합니다.

**증상으로 알아채는 법** — AI가 규칙에 있는 형식(예: ⭐️GUIDE⭐️, 파일 최상단 요약 블록)을 **한 번도** 쓰지 않으면 규칙을 안 지키는 게 아니라 **못 읽고 있는** 것입니다. 일부만 지킨다면 읽고 있는 것이고, 전혀 안 지킨다면 파일 위치를 먼저 의심합니다.

**교훈** — 새 저장소를 시작하면 `CLAUDE.md` 부터 둡니다. 규칙은 복사되지 않습니다.

---

## 만들어진 DocC 문서를 어떻게 읽나

**Q** — `KCT.docc` 를 만들었다는데, 그 문서를 어디서 보나?

**A** — Xcode 안에서 읽습니다. 세 경로가 있고, 실제로는 2번을 가장 많이 씁니다.

**1) 문서 브라우저로 통째로**

```
Product → Build Documentation        (⌃⇧⌘D)
```

**Developer Documentation** 창이 열립니다. 사이드바의 **Workspace Documentation → KCT** 가 랜딩 페이지이고, 그 아래 「먼저 읽을 개념」 5개를 순서대로 읽으면 됩니다.

한 번 빌드하면 결과가 남으므로 다음부터는 `⇧⌘0` (Window → Developer Documentation) 으로 바로 엽니다.

**2) 코드에서 바로 튀어 들어가기**

| 하고 싶은 것 | 방법 |
|---|---|
| 요약만 빨리 | 심볼에 **`Option+클릭`** → Quick Help 팝업 |
| 전체 문서로 | 그 팝업 아래 **Open in Developer Documentation** |
| 정의 코드로 | **`⌘+클릭`** |

**3) 검색** — 문서 창 왼쪽 위 검색창에 타입 이름을 치면 바로 갑니다.

**⚠️ 함정 두 가지**

- **평소 빌드(`⌘B`)로는 문서가 만들어지지 않습니다.** `⌃⇧⌘D` 를 따로 눌러야 합니다. 주석을 고쳤는데 문서에 반영이 안 돼 보이면 대개 이것입니다.
- **`private` 멤버는 문서에 나오지 않습니다.** 코드엔 있는데 문서에 없으면 이 이유입니다. 그래서 `SessionBuilder` 의 단계별 함수들은 `private` 을 떼어 뒀습니다.

**터미널에서 검증만 하고 싶을 때** — 링크가 다 연결됐는지 확인하는 데 유용합니다. DocC 는 못 찾는 심볼 링크에 경고를 냅니다.

```sh
xcodebuild docbuild -scheme KCT \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/kct-docs CODE_SIGNING_ALLOWED=NO
```

`-derivedDataPath` 를 따로 준 이유는 평소 빌드 캐시를 건드리지 않기 위해서입니다. 확인 뒤 그 폴더는 지웁니다(200MB 넘습니다).

**교훈** — 문서는 "쓰는 것" 과 "보는 것" 이 다른 동작입니다. `⌃⇧⌘D` 를 눌러야 보입니다.

**참고 문서**

- [Documenting apps, frameworks, and packages](https://developer.apple.com/documentation/Xcode/documenting-apps-frameworks-and-packages)

---

## `.docc` 는 소스 폴더에 둬도 앱에 안 실린다 — `.md` 와 다르다

**Q** — 평범한 `.md` 는 소스 폴더에 두면 앱 번들로 복사된다고 했는데(아래 항목), 그럼 DocC 카탈로그(`KCT.docc`) 안의 `.md` 들도 실려 나가나?

**A** — **안 실립니다.** Xcode 가 `.docc` 확장자를 **문서 카탈로그로 알아보고** 문서 컴파일러에게 넘기기 때문입니다. 리소스 복사 대상이 아닙니다.

`KCT.docc/` 에 `.md` 5개를 넣고 빌드한 뒤 확인한 결과:

```
KCT.app/
├── Info.plist
├── KCT
├── questions.json      ← 리소스는 이것뿐
└── ...                 (.md 도 .docc 도 없음)
```

빌드 로그에도 `CpResource` 가 `questions.json` 에만 붙고, `.docc` 는 `Discovering version info for docc` 로 별도 처리됩니다.

**정리** — 소스 폴더(`KCT/KCT/`)에 둬도 되는 것과 안 되는 것:

| | 앱 번들로 복사? | 어디에 둘까 |
|---|---|---|
| `.swift` | 컴파일됨 | 소스 폴더 |
| `.json` 등 실제 리소스 | ✅ 복사됨 (의도한 것) | 소스 폴더 |
| **`.docc` 카탈로그** | ❌ 안 됨 | **소스 폴더** — 여기 있어야 문서에 포함된다 |
| 평범한 `.md`, `.gitkeep` | ✅ 복사됨 (사고) | **저장소 루트** |

**교훈** — 확장자에 따라 Xcode 의 취급이 다릅니다. "폴더에 넣으면 앱에 들어간다" 는 규칙에도 예외가 있으니, 새 종류의 파일을 넣을 때는 **빌드 후 `KCT.app` 안을 직접 확인**하는 것이 가장 빠릅니다.

**참고** — 랜딩 페이지 파일명은 **모듈 이름과 같아야** 합니다(`KCT.md`). 다르면 랜딩 페이지가 아니라 그냥 아티클이 됩니다.

- [Adding structure to your documentation pages](https://developer.apple.com/documentation/Xcode/adding-structure-to-your-documentation-pages)

---

## 문서를 소스 폴더에 두면 앱에 실려 나간다 — 동기화 그룹

**Q** — `LEARNING_PLAN.md` 를 소스 폴더(`KCT/KCT/`) 안에 뒀는데 문제가 되나?

**A** — 됩니다. **이미 앱 번들 안에 들어가서 출하되고 있었습니다.**

```
KCT.app/
├── Info.plist
├── KCT
├── LEARNING_PLAN.md      ← 이게 왜 여기 있나
├── questions.json
└── ...
```

KCT는 **file-system synchronized group**(Xcode 16+) 방식입니다. `project.pbxproj` 에 `PBXFileSystemSynchronizedRootGroup` 이 3개 있습니다. 이 방식은 폴더 안의 파일을 자동으로 프로젝트에 포함시키는데, `.swift` 는 컴파일하고 **Xcode가 모르는 확장자는 리소스로 취급해 앱 번들 루트에 복사**합니다.

기능이 깨지지는 않지만 두 가지 문제가 있습니다.

1. 사용자에게 배포되는 앱에 개발 문서가 들어갑니다
2. **같은 이름의 파일이 두 폴더에 있으면 `Multiple commands produce ...` 로 빌드가 실패합니다.** 번들 루트가 평평하므로 목적지가 겹칩니다. `.gitkeep` 같은 빈 파일이 대표적인 사고 원인입니다

**해결** — 문서는 **저장소 루트**(`KCT/`, `.xcodeproj` 와 같은 자리)에 둡니다. 소스 폴더 안에는 소스와 실제 리소스만 넣습니다.

**교훈** — 동기화 그룹에서는 "폴더에 넣는다 = 앱에 넣는다" 입니다. 빌드가 통과했다고 안전한 게 아닙니다.

**참고** — `project.pbxproj` 의 `PBXFileSystemSynchronizedRootGroup` 개수와, 빌드 후 `KCT.app` 내용을 직접 확인해 검증했습니다.

---

## questions.json 을 하위 폴더로 옮겨도 찾을 수 있나

**Q** — 파일 정리하면서 `questions.json` 을 `Content/` 폴더로 옮겼다. `Bundle` 로 읽는 코드가 깨지지 않나?

**A** — 깨지지 않습니다. **번들 리소스는 폴더 구조와 무관하게 번들 루트에 평평하게 놓입니다.**

빌드 로그가 그대로 보여줍니다.

```
CpResource  .../KCT.app/questions.json  ←  .../KCT/Content/questions.json
```

소스는 `Content/` 안에 있지만 목적지는 `KCT.app/questions.json` 입니다. 그래서 아래 코드가 그대로 동작합니다.

```swift
bundle.url(forResource: "questions", withExtension: "json")
```

**단, 이 평탄화가 위 항목의 `Multiple commands produce` 사고의 원인이기도 합니다.** 서로 다른 폴더에 같은 이름의 리소스를 두면 목적지가 겹칩니다. 폴더로 이름 충돌을 피할 수 있다고 생각하면 안 됩니다.

**교훈** — 리소스는 폴더로 나눠도 번들에서는 한 바구니입니다. 이름은 프로젝트 전체에서 유일해야 합니다.

**참고 문서**

- [Bundle.url(forResource:withExtension:)](https://developer.apple.com/documentation/foundation/bundle/url(forresource:withextension:))

---

## FocusAnalyzer 가 왜 한 번도 안 불리나 — 꺼져 있는 층

**Q** — `FocusAnalyzer.swift` 와 `QuestionFocusRecord.swift` 를 만들어 뒀는데 중단점이 안 걸린다. 코드가 잘못됐나?

**A** — 코드는 맞습니다. **의도적으로 꺼져 있습니다.**

`FocusStore.swift` 맨 위에 스위치가 있습니다.

```swift
static let usesModelAnalysis = false
```

"묻는 대상" 하이라이트는 **3층 구조**입니다.

| 층 | 무엇 | 지금 상태 |
|---|---|:---:|
| 1. 서버가 내려준 값 | 아직 없음 (서버 도입 시 여기서 걸림) | — |
| 2. 모델 분석 캐시 | `FocusAnalyzer` + `QuestionFocusRecord` | **꺼짐** |
| 3. 규칙 기반 | `QuestionFocus` — 의문사 닫힌 집합 | ✅ 동작 |

**끈 이유** — 모델이 "묻는 대상" 대신 **질문 문장 전체를 돌려주는 경우가 많아** 지문이 통째로 형광펜 처리됐습니다. 한국어 의문사는 닫힌 집합(누구·어디·언제·무엇·무슨·어느·몇)이라 규칙만으로 대부분 잡히므로, 규칙 기반 층만으로 충분했습니다.

**다시 켤 때 함께 넣을 것** — `true` 로 바꾸는 것만으로는 같은 문제가 재발합니다. **강조 길이 제한**(예: 지문의 절반을 넘으면 버림) 같은 검증을 함께 넣어야 합니다. 지금 있는 검증은 "지문에 실제로 있는 문자열인가" 하나뿐입니다.

**교훈** — 꺼둔 코드에는 **왜 껐는지와 다시 켤 조건**을 주석으로 남깁니다. 이유 없이 꺼진 코드는 다음 사람이 버그로 오해하거나, 그냥 켜서 같은 문제를 다시 만듭니다.

---

## 결과 화면의 "맞힌 문제" 가 5문제 중 3개만 세는 줄 알았다 — 버그가 아니라 설계가 샌 것

**Q** — 어머니가 5문제를 다 맞혔는데 누적 정답 수가 3만 늘었다. 카운터 버그인가?

**A** — 버그가 아니라 **설계가 화면으로 샌 것**입니다.

``SessionBuilder/shapeRound(_:progressByID:focusByID:)`` 가 회차의 **첫·마지막 문항**을 격려용으로 만들면서 ``QuizItem/affectsProgress`` 를 `false` 로 둡니다. 그런데 그때는 채점 후 진척 반영이 `record(correct:now:)` **함수 하나**였고, `affectsProgress == false` 면 그 함수를 **통째로 건너뛰었습니다.** 그래서 세는 일까지 같이 건너뛰었습니다.

CBL 기록의 「15문제 중 9개」가 정확히 `15 × 3/5 = 9` 였습니다. **어머니가 겪은 사실과 화면의 숫자가 어긋난 것**입니다.

**고친 방법** — 한 함수를 셋으로 갈랐습니다.

| 함수 | 언제 | 무엇을 |
|---|---|---|
| ``QuestionProgress/countAttempt(correct:now:)`` | **모든 문항** | 센다 · `isIntroduced` 를 켠다 |
| ``QuestionProgress/moveLadder(correct:now:)`` | 격려용 제외 | 사다리를 옮긴다 |
| ``QuestionProgress/nudgeLadder(correct:)`` | 격려용만 | 바닥 칸에서만 한 칸 올린다 |

**교훈** — "이건 진척에 반영하지 않는다" 는 판단이 **여러 가지 일을 한꺼번에 끄고 있었습니다.** 한 함수가 두 가지 일(세기 · 사다리)을 하면, 그 함수를 건너뛰는 조건이 **의도하지 않은 쪽까지** 끕니다. 조건으로 통째로 건너뛰는 함수를 만들 때는, **그 안의 일이 전부 같은 조건에 걸리는 게 맞는지** 확인합니다.

---

## Supabase 로 올리는데 계속 401 — 키 문제가 아니었다

**Q** — 앱에서 `POST /rest/v1/obs_record` 가 8번 다 `401` 인데, 같은 키로 터미널 curl 은 `201` 이 된다. 키를 잘못 옮겨 적었나?

**A** — 키는 멀쩡했습니다. 범인은 **업서트**였습니다.

앱은 주소에 `?on_conflict=device_id,session_id,question_id` 를, 헤더에 `Prefer: resolution=ignore-duplicates` 를 붙이고 있었습니다. **중복이 와도 서버가 조용히 무시하게** 하려던 것입니다.

그런데 PostgREST 는 업서트를 `INSERT ... ON CONFLICT` 로 바꾸고, 그러려면 **UPDATE 권한까지** 요구합니다. 우리 표는 일부러 **입력만** 열어 뒀습니다. 권한이 모자라면 익명 요청에 **`401`** 이 돌아옵니다.

**가른 방법** — 앱과 똑같은 요청을 curl 로 두 번 보냈습니다.

```
on_conflict + Prefer 없음  → 201
on_conflict + Prefer 있음  → 401
```

**401 과 403 을 구분하는 것이 핵심이었습니다.** RLS 정책에 걸리면 `403` 에 `new row violates row-level security policy` 가 옵니다. `401` 은 그 앞 단계 — 값이 심사받기도 전입니다. 그래서 처음부터 "정책이 아니라 권한/인증" 쪽을 봐야 했습니다.

**고친 방법** — 업서트를 버렸습니다. UPDATE 정책을 여는 것은 **기록을 고칠 수 있게 만드는 일**이라 하지 않았습니다. 대신 표의 `unique` 제약도 함께 없애고, 중복은 **볼 때** 걸러냅니다.

```sql
select distinct on (device_id, session_id, question_id) *
from public.obs_record
order by device_id, session_id, question_id, received_at;
```

**교훈** — 「저장할 때 막기」와 「볼 때 걸러내기」는 맞바꿀 수 있습니다. **쌓기만 하고 덮어쓰지 않는 기록**이라면 후자가 싸고, 표를 잠근 상태를 지킬 수 있습니다.

---

## 한 회차 5줄인데 서버에 10줄이 들어갔다 — `@MainActor` 도 재진입은 못 막는다

**Q** — `@MainActor` 를 붙였는데 왜 업로드가 두 번 일어나나?

**A** — `@MainActor` 는 두 코드가 **같은 순간에** 도는 것만 막습니다. `await` 에서 **잠시 비켜 준 사이에 다른 호출이 끼어드는 것**(재진입, reentrancy)은 막지 않습니다.

```
A : 안 올라간 줄 5개를 꺼낸다
B : 안 올라간 줄 5개를 꺼낸다   ← A 가 아직 uploadedAt 표시를 안 남겼다
A : 5줄 POST
B : 같은 5줄 POST              ← 표에 10줄
```

`uploadPending()` 을 두 곳에서 부릅니다 — 회차 시작(`start()`)과 채점 끝(`gradeAll()`). 둘이 겹치는 순간이 있었습니다. 서버 기록의 `received_at` 이 **7마이크로초 차이**로 두 개였습니다.

**고친 방법** — ``ObsUploader`` 에 `static var isUploading` 깃발을 두고, 함수 첫머리에서 `guard` 로 막고 `defer` 로 반드시 내립니다.

```swift
guard !Self.isUploading else { return }
Self.isUploading = true
defer { Self.isUploading = false }
```

`static` 인 이유 — ``ObsUploader`` 는 부를 때마다 새로 만들어지는 `struct` 라, 보통 프로퍼티에 두면 매번 새것이라 소용이 없습니다.

**교훈 둘** — ① `async` 함수는 **자기가 이미 돌고 있을 수 있다**고 가정합니다. ② 깃발은 **부르는 쪽**이 아니라 **규칙이 깨지는 쪽**에 둡니다. 부르는 곳마다 조심하게 만들면 언젠가 한 곳을 빠뜨립니다.

---

## 직접입력이 나온 회차부터 Supabase 에 아무것도 안 올라간다 — `nil` 이면 키가 사라진다

**Q** — 선다형·O/X 만 있던 회차는 `201` 로 잘 올라갔는데, **직접입력이 처음 나온 뒤부터** 계속 `400` 이다. `reason` 컬럼은 분명히 추가했다. 무엇이 문제인가?

**A** — 컬럼 문제가 아니었습니다. **한 요청 안의 다섯 줄이 서로 다른 모양**이었습니다.

### 어떻게 좁혔나

Supabase **Logs → API Gateway** 의 시간선 하나로 갈렸습니다.

```
11:24:13   alter table ... add column reason text        ← 컬럼은 이때 이미 들어갔다
11:29~11:33  POST → 201 × 5                              ← 선다형·O/X 만 있던 회차
11:33:46   POST → 400
11:34:27   POST → 400                                    ← 같은 뭉치를 다시 보내는 중
```

**«언제부터 실패하나» 가 «무엇이 원인인가» 를 알려 줬습니다.** 11:33:11 과 11:33:46 사이에 달라진 것은 **직접입력 문항이 처음 나온 것** 하나뿐이었습니다.

### 진짜 원인

PostgREST 는 배열을 한 번에 넣을 때 **모든 객체가 똑같은 키를 갖고 있어야** 합니다. 아니면 `400 PGRST102 All object keys must match` 로 **배열 전체**를 거부합니다.

그런데 Swift 가 `Codable` 을 자동으로 만들어 주면 **옵셔널을 `encodeIfPresent` 로 처리합니다** — 값이 `nil` 이면 **그 키를 아예 안 씁니다.**

```
문항 1  2지선다   { ..., "chosen": "고조선" }                     ← reason 키 없음
문항 3  직접입력  { ..., "chosen": "단군신화", "reason": "..." }   ← reason 키 있음  ⚠️
문항 4  O/X      { ..., "chosen": "맞아요" }                      ← reason 키 없음
```

다섯 줄 중 **한 줄만 키가 하나 더 많아서** 회차가 통째로 막혔습니다. JSON 을 작게 만들려는 Swift 의 좋은 기본값이, **"null 이라도 키는 있어야 한다"** 는 상대에게는 정확히 안 맞았습니다.

### 고친 방법

`ObsUploader.Payload` 에 `CodingKeys` 와 `encode(to:)` 를 손으로 썼습니다. `encodeIfPresent` 가 아니라 **`encode`** 를 쓰면 `nil` 이 **`null` 로 나가고 키는 남습니다.**

```swift
try container.encode(reason, forKey: .reason)   // nil → "reason": null
```

`CodingKeys` 를 직접 적는 이유 — `encode(to:)` 를 손으로 쓰면 **Swift 가 더 이상 자동으로 만들어 주지 않습니다.**

### 같이 발견한 것

``ObsRecord/secToFirstTouch`` 도 **같은 폭탄**을 안고 있었습니다. 어머니가 답에 손을 안 댄 적이 아직 없어서 `nil` 이 나온 적이 없을 뿐입니다. 손으로 쓴 `encode(to:)` 가 이것도 같이 막았습니다.

### 교훈 셋

- **`Optional` 을 JSON 으로 내보낼 때는 «없으면 키가 사라진다» 를 먼저 확인합니다.** 받는 쪽이 그것을 허용하는지가 관건입니다.
- **«언제부터 실패하나» 가 «무엇이 원인인가» 보다 먼저 나옵니다.** 상태 코드만 보면 `400` 은 원인이 열 가지지만, 성공과 실패의 **경계에서 무엇이 달라졌는지**를 보면 하나로 좁혀집니다.
- **드물게만 나오는 조합은 드물게만 터집니다.** 이 결함은 직접입력이 나오는 회차가 드물어 **일주일을 숨어 있었습니다.** 조합을 강제로 만들어 볼 **개발용 스위치**(``SessionBuilder/isUnlocked`` 같은 이음새)가 있으면 30초에 확인됩니다 — 아직 없습니다.

> 이 오류는 **조용했습니다.** 업로드 실패가 화면에도 로그에도 안 남기 때문입니다. 재시도 큐가 기록을 지켜 준 것은 다행이지만, **사용자가 눈으로 «표에 안 올라오네» 를 알아챌 때까지 아무 신호가 없었습니다.** `chosen`·`reason` 을 남겨서 오채점을 찾았듯, **실패 이유도 남길 자리**입니다.

