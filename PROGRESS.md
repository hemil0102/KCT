# PROGRESS

**새 세션은 이 파일만 읽고 시작합니다.** 저장소를 훑거나 소스 전체를 읽지 않습니다.
여기에 없는 것이 필요할 때만 아래 [파일 지도](#파일-지도)를 보고 그 파일의 **필요한 부분만** 엽니다.

- 갱신 시점 : 2026-08-18
- 이 파일의 상한 : **100줄**. 넘으면 오래된 것을 각자의 집(LEARNING_PLAN·GUIDE·Q&A)으로 보내고 여기서 지웁니다.

---

## 지금

이 네 줄만 읽어도 작업을 이어갈 수 있어야 합니다.

- **현재 단계** — 학습용 리팩토링 5단계 중 **4단계 완료**
- **마지막으로 끝낸 것** — `KCT.docc` 신설 (랜딩 페이지 + 개념 아티클 5개). `xcodebuild docbuild` 로 심볼 링크 전부 해석 확인
- **다음 할 일** — **5단계**: 테스트 타겟 신설 + Swift Testing 으로 순수 로직 검증
- **막힌 것** — 없음

**리팩토링 5단계 계획** (사용자 합의됨)

| 단계 | 내용 | 상태 |
|---|---|:---:|
| 1 | 폴더 정렬 (책임별 8개) | ✅ |
| 2-a | 이름 변경 6건 + 죽은 코드 제거 + 헤더 정리 | ✅ |
| 2-b | `QuizView` 573줄 → 상태(`QuizSession`) + 화면 3개 + 부품 3개 | ✅ |
| 2-c | `SessionBuilder.build()` 를 단계별 함수로 분해 | ✅ |
| 2-d | 전 파일 DocC 주석 + 최상단 요약 블록(규칙 5) | ✅ 27/27 |
| 3 | 학습 가이드 `.md` (구조·엔트리 포인트·단계) | ✅ |
| 4 | DocC 카탈로그 `KCT.docc` | ✅ |
| 5 | 테스트 타겟 + 순수 로직 테스트 | ⬜ |

---

## 파일 지도

소스는 `KCT/KCT/<폴더>/`, 문서는 저장소 루트. **의존성은 위에서 아래로 한 방향**입니다. **파일별 역할은 [LEARNING_PLAN.md](LEARNING_PLAN.md) 의 「파일 구성」** 에 있습니다 — 여기 옮겨 적지 않습니다.

| 폴더 | 책임 | 파일 수 |
|---|---|:---:|
| `App/` | 앱 시작점 | 2 |
| `Content/` | 문제 콘텐츠 (고정) + `questions.json` | 3 +1 |
| `Progress/` | 학습 진척 (변동) | 2 |
| `Session/` | 이번 회차 출제 구성 | 3 |
| `Grading/` | 채점 | 2 |
| `Focus/` | 묻는 대상 하이라이트 (**2층·3층은 꺼져 있음**) | 4 |
| `Screens/` | 회차 상태(`QuizSession`) + 화면 4개 | 5 |
| `DesignSystem/` | 색·조판·낭독 + 재사용 부품 (도메인을 모른다) | 6 |
| `KCT.docc/` | 문서 카탈로그 — 랜딩 + 개념 아티클 5개. **`.docc` 는 앱 번들에 안 실린다** | 6 `.md` |

**폴더가 생기거나 파일 수가 바뀌면 이 표를, 파일이 생기면 LEARNING_PLAN 을 고칩니다.**

---

## 결정 기록

되돌리려는 유혹이 생길 만한 것만 남깁니다. 한 줄씩, 최대 10개.

- **폴더에 `01_` 같은 번호를 붙이지 않는다** — 순서는 바뀌고 번호는 썩는다. 읽는 순서는 DocC 아티클(4단계)이 담당
- **문서는 저장소 루트에, 소스 폴더 안에 두지 않는다** — file-system synchronized group 이라 `KCT/KCT/` 안의 파일은 앱 번들로 복사된다 (Q&A 참조)
- **`DifficultyMode` → `AskingMode`** — 이건 난이도가 아니라 **묻는 방식**이다. `Question.difficulty`(축 A)와 이름이 겹쳐 두 축이 헷갈렸다
- **채점기 이름을 판정 방식으로 바꿨다** — `PracticeGrader`→`RuleGrader`, `AnswerGrader`→`MeaningGrader`. **규칙으로 먼저, 안 되면 뜻으로** 가 이름만으로 보인다. `PracticeItem`→`QuizItem` 도 같은 이유("practice" 가 연습 모드와 무관하게 겹쳤다)
- **`SessionBuilder.build(now:)` 를 지우지 않고 남긴다** — 지금 어느 판단에도 쓰이지 않지만 5단계 테스트에서 시각을 고정할 자리로 쓴다. 사실은 `- Note:` 에 적어 두었다
- **`FocusStore.usesModelAnalysis = false`** — 모델이 묻는 대상 대신 질문 전체를 돌려줘서 지문이 통째로 형광펜 처리됐다. 규칙 기반만으로 충분. **`FocusAnalyzer`·`QuestionFocusRecord` 는 지금 안 불리는 코드**
- **Mermaid 다이어그램은 쓰지 않는다** — 사용자가 선택하지 않음. 표와 텍스트 흐름으로 표현
- **주석을 늘리기보다 함수를 쪼개 이름을 붙인다** — 기존 코드는 이미 주석이 촘촘하다. 더 붙이면 코드가 주석에 묻힌다
- **`README.md` 를 만들지 않는다** — `LEARNING_PLAN.md` 가 그 자리다. 중복은 낡은 쪽이 거짓말을 하게 만든다

---

## 열린 질문

답이 나오면 지우고, 개념 질문이면 GUIDE.md·Q&A.md 로 옮깁니다.

- 없음

---

## 세션 로그

최근 3개만 남깁니다. 넷째가 생기면 가장 오래된 것을 지웁니다.

- **2026-08-18** — 3·4단계, 학습 문서 두 겹. ① `STUDY_GUIDE.md` — **1장이 "문제 한 개의 여행"(파일 목록이 아니라 데이터 추적)**, 「자주 헷갈리는 다섯 가지」로 의도된 설계를 버그로 오해하는 것을 막음 ② `KCT.docc` — 랜딩(9개 Topics) + 개념 아티클 5개. **STUDY_GUIDE 는 "읽는 순서·실습", DocC 는 "개념·심볼 연결"** 로 역할 분담. `xcodebuild docbuild` 검증 — 심볼 링크 경고 0, `.docc` 는 앱 번들에 안 실림. `SpeechReader` 까지 27/27 달성
- **2026-08-18** — 리팩토링 2단계 전체(a·b·c·d). ⓪ 27개 `.swift` 전부에 규칙 5 요약 블록 + DocC 주석. **꺼져 있는 코드(`Focus` 2층)에 "왜 껐는지와 다시 켤 조건" 을 명시** — 버그로 오해하거나 그냥 켜서 같은 문제를 다시 만들지 않도록 ① 이름 6건 변경(`KCT`→`KCTApp`, `ContentView`→`RootView`, `DifficultyMode`→`AskingMode`, `PracticeItem`→`QuizItem`, `PracticeGrader`→`RuleGrader`, `AnswerGrader`→`MeaningGrader`) + 죽은 코드 2건 제거 + `LEARNING_PLAN.md` 를 루트로 옮겨 앱 번들에서 빼냄 ② `QuizView` 573줄 → 8파일. **`QuizSession` 이 결정 / 각 Screen 이 표현 / `QuizView` 는 화면 선택과 낭독.** `@Query` 대신 세션이 진척을 직접 조회하게 바꾸자 `resetProgress()` 중복이 저절로 사라짐 ③ `SessionBuilder.build()` 60줄 → 「세 줄 세우기 → 칸 채우기 → 모양 잡기」로 분해, 테스트용으로 internal 공개

---

## 어디에 무엇을 쓰나

같은 사실을 두 곳에 쓰지 않습니다. 중복은 낡은 쪽이 거짓말을 하게 만듭니다.

| 성격 | 파일 |
|---|---|
| 지금 어디까지 왔나, 다음에 뭘 하나 | **PROGRESS.md** (이 파일) |
| 코드를 어떤 순서로 읽을까 | [STUDY_GUIDE.md](STUDY_GUIDE.md) |
| 설계 원칙, 파일별 역할, 단계별 계획 | [LEARNING_PLAN.md](LEARNING_PLAN.md) |
| 용어의 뜻 | [GUIDE.md](GUIDE.md) |
| 막혔던 것과 그 해결 | [Q&A.md](Q&A.md) |
| AI 작업 규칙 — 목록 | [CLAUDE.md](CLAUDE.md) |
| 규칙의 취지와 지키는 방법 | [RULES.md](RULES.md) |
