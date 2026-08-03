# 계획: 문제별 적응형 난이도 + 자동 반복 출제 학습 앱

## Context (배경)

귀화 시험 준비 앱. 사용자(어머니)가 **선택을 거의 하지 않아도**, 약 1000개의
문제를 쉬운 것 → 어려운 것으로 자연스럽게 반복 학습하도록 만드는 것이 목표다.

현재는 모든 문제가 주관식 한 포맷으로만 나오고(`QuizView` + `AnswerGrader`),
영구 저장소가 없다. 앱 구조는 `KCT.swift(App) → ContentView → QuizView`.

### 핵심 학습 규칙 (사용자 정의)

- **문제별 난이도 사다리 (4단계)**: `2지선다(0) → O/X(1) → 4지선다(2) → 직접입력(3)`
- **세션(날짜) 간 승급/강등**: 오늘 맞힌 문제는 다음 세션에서 한 단계 위 모드로.
  틀리면 한 단계 아래로.
- **마스터**: 직접입력(3단계)까지 맞히면 마스터.
- **반복**: 못 맞힌 문제는 계속 다시 출제.
- **라운드 첫·마지막 문제는 무조건 2지선다** — 격려용, 진척에 영향 없음.
- **자동 진행**: "오늘의 학습 시작"만 누르면 신규 문제를 쉬운 것부터 도입, 단원 균등.

### 두 개의 축 (반드시 분리)

| 축 | 의미 | 저장 위치 | 성격 |
|----|------|-----------|------|
| A. 문제 고유 난이도 | 문항 자체 난이도 | `Question.difficulty` | 고정 |
| B. 어머니 학습 레벨 | 얼마나 마스터했나 | `QuestionProgress.mode` | 동적 |

- 축 A = "도입 순서"만 결정. 축 B = 출제 모드(사다리). 모든 문제가 동일한 사다리.

### 최종 목표 (향후) — 스토리 모드 게이팅

어머니가 읽은(개방된) 콘텐츠의 문제만 출제. 지금은 미구현 →
`SessionBuilder`에 `isUnlocked(question)` 게이트 seam만 두고 프로토타입은 항상 true.

## 단계별 구현 순서

1. **모드 렌더링 & 채점** (← 현재): `Question.unit/difficulty`, `DifficultyMode`,
   `PracticeItem`/`ModePayload`, 파생 빌더, `PracticeGrader`, QuizView 4모드 렌더.
2. **영구 진척 & 승급/강등**: `QuestionProgress`(@Model) + `modelContainer`.
3. **자동 스케줄러**: `SessionBuilder`(복습 반복 + 신규 점진 도입 + 단원 균등 +
   첫/마지막 격려용 2지선다).
4. **1000문제 데이터 & 단원 풀**.
5. **음성 입력**(직접입력 대체) → 이후 키워드조합 보너스.

## 파일

- `Question.swift` — `difficulty`(구 `level`), `unit` 추가 + 파생 빌더.
- `DifficultyMode.swift` (신규) — 4단계 사다리 [축 B].
- `PracticeItem.swift` (신규) — `PracticeItem`, `ModePayload`, 데모 세션.
- `PracticeGrader.swift` (신규) — 결정적 채점.
- `QuestionProgress.swift` (2단계, 신규) — SwiftData `@Model`.
- `SessionBuilder.swift` (3단계, 신규) — 자동 스케줄러.
- `QuizView.swift` — 모드별 렌더링/채점.
- `AnswerGrader.swift` — 변경 없음(직접입력 채점).

_이 문서는 살아있는 계획서로, 단계 진행에 따라 갱신한다._
