# Claude설정 — 프로젝트가 달라도 쓰는 규칙

KCT 의 규칙을 세 층으로 나눈 것입니다. **원본은 이 폴더**이고, 아래 세 곳으로 내보냅니다. 원본을 고치면 세 곳에 반영해야 합니다.

| 층 | 파일 | 언제 적용되나 |
|---|---|---|
| 범용 | `01_working-agreement.md` | 모든 프로젝트 |
| 학습 모드 | `02_learning-mode.md` | 프로젝트 `CLAUDE.md` 에 **「학습 모드: 켬」** 이 있을 때만 |
| 새 프로젝트 틀 | `03_새프로젝트_CLAUDE.md` | 새 프로젝트를 시작할 때 복사 |

KCT 전용 규칙(7·14·16·19·20·24와 프로젝트 정보)은 KCT 의 `CLAUDE.md` 에 그대로 있습니다.

## 어디에 두나

| 환경 | 방법 |
|---|---|
| **Cowork (데스크톱 앱)** | 스킬 `working-agreement`, `learning-mode` 로 저장 (계정에 동기화됨) |
| **Claude Code (터미널)** | `cp 01_working-agreement.md ~/.claude/CLAUDE.md` · `cp 02_learning-mode.md ~/.claude/learning-mode.md` (이미 `~/.claude/CLAUDE.md` 가 있으면 덮어쓰지 말고 이어 붙입니다) |
| **Xcode 의 Claude 에이전트** | 별도 설정 폴더를 쓸 수 있습니다(`~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/`, fatbobman 글 기준 — **내 Mac 에서 확인 필요**). 거기에도 같은 파일을 두거나 프로젝트 `CLAUDE.md` 가 자립하게 둡니다 |

⚠️ 공식 문서상 Cowork 세션은 사용자 파일의 **바깥 경로 import 와 심볼릭 링크를 건너뜁니다.** 그래서 `@` import 나 링크 대신 **복사본 또는 스킬**을 씁니다.

## 지키는 것
- 새 프로젝트 `CLAUDE.md` 는 `03_` 틀에서 시작해 **200줄 이하**로 유지합니다.
- 범용 규칙을 프로젝트 `CLAUDE.md` 에 다시 베끼지 않습니다(복사가 낡으면 서로 충돌합니다). 프로젝트 쪽이 다르게 해야 할 때만 그 차이를 적습니다.
- 가끔 `/doctor prompt-audit` 으로 낡았거나 충돌하는 규칙을 찾습니다.
