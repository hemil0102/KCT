# Q&A

막혔던 것과 그 해결을 남기는 기록입니다. `CLAUDE.md` 규칙 6에 따라 쌓아갑니다.

빌드가 막혔던 것, 개념을 오해했던 것, 문서와 실제가 달랐던 것만 남깁니다. 최신 항목이 위에 옵니다.

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
