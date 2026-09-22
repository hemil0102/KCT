# PROGRESS

**새 세션은 이 파일만 읽고 시작합니다.** 여기에 없는 것이 필요할 때만 아래 [파일 지도](#파일-지도)를 보고 그 파일의 **필요한 부분만** 엽니다.

- 갱신 시점 : 2026-09-15 (9차 「어려운 낱말 설명」 적용)
- 이 파일의 상한 : **100줄**. 넘으면 오래된 것을 각자의 집(LEARNING_PLAN·GUIDE·Q&A)으로 보내고 여기서 지웁니다.

---

## 지금

- **현재 단계** — **9차 「어려운 낱말 설명」 1~5단계 적용 완료.** 계획서는 [9차_계획_어려운낱말_설명.md](9차_계획_어려운낱말_설명.md)
- **마지막으로 끝낸 것** — `glossary.json`(5낱말)을 `questions.json` 에 합치고, 30문항 전체를 다시 검토해 **문항마다 내장한 39낱말**로 늘렸습니다. 낱말을 탭하면 뜻을 보여주는 방식을 커스텀 하단 패널에서 **iOS 기본 `.sheet`(Liquid Glass)** 로 다시 설계했습니다. 안 쓰게 된 `GlossaryCatalog.swift`·`Glossary.swift` 와 `KCTApp.swift` 의 참조는 삭제했습니다(`glossary.json` 원본 파일은 혹시 몰라 남겨 둠). 사용자 승인 하에 AI 가 `KoreanText.swift`·`GlossaryPanel.swift`·`QuestionScreen.swift` 세 파일을 직접 수정했습니다
- **다음 할 일** — **Xcode 빌드 확인 + 실기기 확인.** 이 세션엔 `xcodebuild` 가 없어(Linux VM) 컴파일 자체를 못 해 봤습니다. 마지막 줄 밑줄이 이제 안 겹치는지 · 사전 시트가 스와이프에 실제로 커지는지 · 로딩→해설 전환이 매끄러운지, 그리고 낱말 이름표·안내 문구 폰트/정렬이 원하는 대로 보이는지 · ✕ 버튼 없이도 답 고르기/다시 읽기/배경 탭 세 가지 전부로 시트가 닫히는지 · **낱말을 탭해서 사전을 열 때 배경 탭 처리와 겹쳐 바로 닫혀버리지는 않는지**(3-I, 코드만 보고 미리 막아 둔 위험이라 꼭 확인 필요) · 비슷한 낱말이 낱말칸 오른쪽에 자연스럽게 보이는지를 아직 눈으로 확인하지 못했습니다
- **막힌 것** — Supabase 에 `model_failure` 표를 아직 안 만들었습니다. 만들기 전까지 실패 기록이 폰에만 쌓입니다
- **임시로 꺼 둔 것** — `KoreanText.swift` 의 형광펜(marker, 노란 배경)을 `showsMarkerHighlight = false` 로 잠시 껐습니다(밑줄 버그를 따로 보려는 진단용). 형광펜이 다시 필요하면 그 값을 `true` 로 되돌리면 됩니다 — 지문의 marker 데이터 자체는 그대로 넘어오고 있습니다

**이번에 얻은 가장 큰 것** — **`OptionSet` 으로 된 스타일 값은 한 비트만 켜서는 안 되는 경우가 있습니다.** `NSUnderlineStyle.patternDot` 혼자서는 아무것도 안 그려지고 `.single` 과 OR 로 합쳐야 그려집니다 — 점선 밑줄이 안 보인 원인이었습니다. 그리고 **계획을 "데이터 단계"와 "화면 단계"로만 나누면 그 사이를 잇는 배선(모델 프로퍼티 추가)이 빠지기 쉽다**는 것도 이번에 확인했습니다. ([Q&A.md](Q&A.md))

---

## 파일 지도

소스는 `KCT/KCT/<폴더>/`, 문서는 저장소 루트. **의존성은 위에서 아래로 한 방향**입니다.

| 폴더 | 책임 | 파일 수 |
|---|---|:---:|
| `App/` | 앱 시작점 | 2 |
| `Data/` | 문제·낱말 (고정) — `questions.json`(**30문항**, 문항마다 `glossary` 내장·39낱말) · `glossary.json`(예전 자료, 지금은 안 씀) | 6 |
| `Progress/` | 학습 진척 (변동) | 2 |
| `Session/` | 이번 회차 출제 구성 | 3 |
| `Grading/` | 채점 세 층 + 해설 + 답을 보는 낱말들 | 6 |
| `Focus/` | 묻는 대상 하이라이트 (**2층·3층은 꺼져 있음**) | 4 |
| `Screens/` | 회차 상태(`QuizSession`) + 화면 5개 | 6 |
| `Observation/` | 관찰 기록·업로드 (Supabase) | 3 |
| `DesignSystem/` | 색·조판·낭독 + 재사용 부품 (도메인을 모른다) — `GlossaryPanel.swift`(낱말 사전 시트) 포함 | 7 |
| `KCT.docc/` | 랜딩 + 개념 아티클 5개. **앱 번들에 안 실린다** | 6 |

---

## 결정 기록

되돌리려는 유혹이 생길 만한 것만. 한 줄씩.

- **답이 하나로 정해지는 일은 모델에게 맡기지 않는다** — 95%를 맞혀도 못 쓴다. 나머지 5%를 찾을 방법이 없다
- **축이 둘이다 — `AnswerShape`(모양)와 `AnswerKind`(주제)** — 「고구려, 백제, 신라」는 목록이면서 동시에 `place`. 한 열거형에 넣으면 해설이 주제를 잃는다
- **`MatchBasis`(코드)와 `CheckBasis`(모델)를 안 섞는다** — 모델이 `exactMatch` 를 고를 수 있으면 「코드가 일하고 있다」는 확인이 거짓이 된다
- **`/` 는 아무거나 맞고 `,` 는 다 대야 맞는다** — `Question.displayAnswer` 가 맨 앞엣것을 화면에 쓴다. JSON 은 정식 명칭을 맨 앞에
- **`Codable` 에 칸을 더할 때 `= 기본값` 만으로 끝내지 않는다** — 자동 생성 해독기는 기본값을 안 쓴다. `decodeIfPresent` 가 필요하다 ([Q&A.md](Q&A.md))
- **격려용 슬롯은 세 규칙** — ① 맞힌 개수에 센다 ② 사다리 승급·강등에서 뺀다 ③ 바닥 칸에서만 한 칸 올린다
- **`isIntroduced` 는 `countAttempt` 에 있다** — 「한 번이라도 나왔는가」는 사다리가 아니라 일어난 사실이다
- **문서는 저장소 루트에** — file-system synchronized group 이라 소스 폴더에 두면 앱 번들로 복사된다
- **`FocusStore.usesModelAnalysis = false`** — `FocusAnalyzer`·`QuestionFocusRecord` 는 **지금 안 불리는 코드**
- **낱말 사전은 따로 두지 않고 문항마다 내장한다** — 예전에는 `GlossaryCatalog` 로 한 번만 저장하고 여러 문항이 참조하게 했지만, 지금은 각 문항의 `glossary` 배열에 직접 넣는다. 문항 JSON 하나만 보면 그 문항에 필요한 낱말 뜻이 다 보인다
- **낱말 사전 모달은 iOS 기본 `.sheet` 를 쓰고, 커스텀 배경을 넣지 않는다** — `.presentationBackground` 를 넣으면 iOS 26 Liquid Glass 자동 적용이 꺼진다 ([Q&A.md](Q&A.md))
- **시트 뒤 배경은 낱말 사전·오답 해설 둘 다 안 어둡게, 탭도 되게 통일했다** (11차 확정) — 처음엔 오답 해설(`FeedbackSheet`)만 어둡게·탭 안 되게 남겨 "정답을 다 보기 전엔 못 넘어감"을 지키려 했으나, 이후 요청으로 두 시트 모두 `.presentationBackgroundInteraction(.enabled)`로 통일했다. 스와이프로 닫는 것만 `.interactiveDismissDisabled()`로 막아 둔다 ([Q&A.md](Q&A.md))
- **PCC(Private Cloud Compute)는 보류** — 2M 다운로드까지만 무료이고 그 뒤 유료 등급이 없다

---

## 열린 질문

- **`facts` 가 환각을 실제로 멈추는가** — 4단계를 넣었지만 **어머니 로그로 확인하지 않았다.** 30문항을 다 틀려 보고 `explanation` 을 훑는 것이 다음 확인이다
- **안전 필터가 해설에서 종종 난다** — `Response may contain sensitive or unsafe content`. `model_failure` 표를 만들면 어떤 지침·프롬프트였는지 보인다
- **`basis` 가 흔들리면 첫 케이스(`listMatch`)로 도망간다** — `@Guide(description:)` 이 「판정의 근거」뿐이라 각 케이스가 뭔지 안 알려준다. 판정에는 영향 없고 로그만 흐려진다
- **정답 칸에 해설이 섞인 문항이 있다** — 「고구려, 백제, 신라, 3국 중 신라는…」. 채점에도 해설에도 해가 된다
- **괄호 병기 41건을 `/` 로 옮겨야 한다** — 「을사조약(을사늑약)」. 안 하면 맞힌 것이 모델로 넘어간다
- **음성 입력이 붙으면 채점 층을 다시 봐야 한다** — 지금은 `AnswerSource.typed` 만 들어온다. `typo` 층은 음성을 건너뛰게 해 두었다
- **마스터 복습 칸이 격려용에 먹힐 수 있다** — 확률 2/5. 마스터 문항이 아직 0개라 관측 불가
- **`nextDueAt` 이 늘 `nil`** — 복습 정렬이 사실상 `lastSeenAt` → `(난이도, id)` 순이다

---

## 세션 로그

최근 3개만 남깁니다.

- **2026-09-15** — 9차 「어려운 낱말 설명」 적용. `glossary.json`(5낱말)을 `questions.json` 에 합치고 30문항 전체를 검토해 39낱말로 확장(v9). 안 쓰는 `GlossaryCatalog.swift`·`Glossary.swift`·`KCTApp.swift` 참조 삭제. 낱말 탭 감지(`KoreanText.swift` 의 `Coordinator`)와 낱말 뜻 모달을 구현하되, 커스텀 하단 패널 대신 **iOS 기본 `.sheet` + Liquid Glass**(`GlossaryPanel.swift`)로 다시 설계. 점선 밑줄이 하나도 안 보이던 버그(`NSUnderlineStyle.patternDot` 을 `.single` 과 안 겹쳐 씀) 발견·수정. `Question`·`QuizItem` 에 `glossary` 연결이 계획에서 빠져 있던 것을 뒤늦게 채움(1-A). 낱말 사전 시트가 처음 탭할 때만 크게 뜨던 버그(`isPresented`+별도 옵셔널 → `.sheet(item:)`)를 4-A로 고치고, **같은 구조였던 오답 해설 시트(`FeedbackSheet`, `QuizView.swift`)도 함께 고침** — `IncorrectCommentary`에 문항 id를 그대로 쓰는 `id`를 붙여 `.sheet(item:)`으로 전환. 오답 해설 모달도 불투명 흰 배경을 걷어내 Liquid Glass가 비치게 하고, 하드코딩돼 있던 `.black` 글자색을 `.primary`(다크/라이트 자동 대응)로 바꿨다가, **가독성 때문에 두 시트 모두 안쪽은 다시 흰 배경 + 검정 글자로 되돌림** — 겉모습(Liquid Glass)은 `.presentationBackground`를 계속 안 쓰므로 그대로 유지됨. 낱말 사전 시트는 뒤 배경 어둡기도 없앰(`.presentationBackgroundInteraction(.enabled)`) — 뒤 지문을 계속 보며 뜻만 확인하는 용도라 밝고 계속 탭도 되게 함. 오답 해설 시트는 그대로 어둡게 둠(정답을 다 보기 전엔 못 넘어가게 하는 화면이라 어울리지 않음). 그런데 뒤 배경을 탭 가능하게 만들자 **열린 시트에서 다른 낱말을 또 탭하면 다시 크게 뜨는 버그**가 새로 생겼음 — `GlossarySelection.id`를 낱말마다 다른 `UUID()`로 두고 있어서, 내용이 바뀔 때마다 `.sheet(item:)`이 "새 시트"로 보고 닫았다 다시 열었기 때문. `id`를 고정값(`"glossary"`)으로 바꿔 해결. O/X 강조·사전 밑줄이 받침과 겹쳐 보이는 문제는 `.underlineStyle`(간격 조절 불가)을 버리고, `UnderlineLabel`(`UILabel` 하위 클래스)이 `drawText(in:)`에서 직접 계산해 간격을 두고 그리는 방식으로 교체. 사용자 승인 하에 AI 가 `KoreanText.swift`·`GlossaryPanel.swift`·`QuestionScreen.swift`·`QuizView.swift`·`QuizSession.swift`·`FeedbackSheet.swift` 를 직접 수정. 그 직접 그리는 밑줄 코드에서, 밑줄 여유만큼 `sizeThatFits` 가 높이를 늘려 준 것이 `UILabel` 기본 `drawText(in:)` 의 **세로 가운데 정렬**과 부딪혀 글자와 밑줄이 서로 다른 좌표계를 보는 버그를 새로 발견·수정 — `drawText(in:)` 가 글자의 실제 필요 높이만큼만 위쪽에 붙인 사각형을 직접 계산해, 그 글자 그리기와 밑줄 계산 양쪽에 똑같이 쓰게 함(이 환경엔 Xcode 가 없어 컴파일 확인은 못 함). 실기기 실측으로 `underlineGap` 이 밑줄 간격의 진짜 기준점이 아니었던 것도 드러남 — 줄 간격(`lineSpacing`)이 `boundingRect` 의 줄 박스 아래쪽에 이미 포함돼 있어 `0`이 너무 아래였고 `-10`이 원하는 자리였음. 보정 상수 `lineFragmentPadding`(10)을 더해 `0`이 그 자리가 되게 하고, `underlineGap` 이 라벨 전체 높이 계산에도 쓰이던 것 때문에 음수를 주면 형광펜(marker) 배경이 잘리던 버그도 `max(0, …)`로 막음. 그 안에서 `self.lineFragmentPadding`를 escaping 클로저 안에서 직접 쓰다 컴파일 에러가 나서, 다른 값들처럼 지역 상수(`padding`)로 미리 꺼내 고침 — 이 클로저가 escaping이라는 것을 실제로 확인함. 낱말 사전 모달(`GlossaryPanel.swift`)은 글자 크기를 질문 지문(30pt bold)에 맞춰 전체적으로 키우고, Foundation Models 생성 예문은 바로 안 보이고 위로 쓸어 올리거나 눌러야 펼쳐지게 바꿈(비슷한 낱말 목록은 그대로 바로 표시). 생성 예문 로딩 중 상태가 화면에 안 보이던 버그도 발견 — `generatedExample: String?` 하나로는 "아직 만드는 중"과 "기기 미지원이라 끝내 없음"이 둘 다 nil 이라 구분이 안 됐던 것이 원인. `GlossaryExampleState`(.loading/.unavailable/.ready) 세 값으로 나눠 `QuestionScreen`·`GlossaryPanel`에 반영 — 이제 스와이프하면 로딩 중엔 "모델 문구가 로딩 중입니다"가, 끝나면 실제 예문이 보임. 실기기 스크린샷으로 실제 버그 두 개를 더 확인·수정 — ① O/X 문항 지문의 진짜 마지막 줄(예: "현충일")에서만 밑줄이 글자와 겹침: lineSpacing 보정(lineFragmentPadding)이 모든 줄에 똑같이 있는 줄 알았는데, 다음 줄이 없는 마지막 줄에는 그 여분이 아예 없어서 생긴 과다 보정 — 지금 줄이 마지막 줄인지 확인해 그 줄만 보정을 뺌. ② 안내를 위로 쓸어 올려도 시트 자체는 안 커지고 내용만 바뀌던 문제 — `.presentationDetents(_:selection:)`로 시트 크기를 `@State`에 묶어, 스와이프 제스처가 직접 `.medium`으로 키우게 함. 문구도 "쓸어 올려서 해설을 확인하세요."/"해설 준비 중입니다."로 요청하신 그대로 맞춤. 그런데 그 직후 실기기에서 안내 자체가 아예 안 보이는 버그가 또 나옴 — `exampleState == .unavailable`이면 안내까지 통째로 숨기고 있었는데, 기기가 Foundation Models 를 지원 안 하면 `composeExample`이 거의 즉시 nil을 돌려줘서 시트가 뜨기도 전에 `.unavailable`이 되어 안내가 뜰 틈이 없었음. 이제 안내는 상태와 무관하게 항상 먼저 보이고, 펼쳤을 때만 완성/로딩/"이 기기에서는 해설을 만들 수 없어요" 중 맞는 내용을 보여줌. 실기기로 계속 확인하다 보니 트리거 관련 버그가 두 개 더 나옴 — 안내 문구 위에서 쓸어 올려도 반응이 없고 눌러야만(탭) 펼쳐지던 것은, `ScrollView` 안 자식 뷰에 `.gesture`로만 드래그를 달면 조상인 ScrollView 가 그 제스처를 먼저 가져가 버리기 때문 — `.highPriorityGesture`로 바꿔 해결. 그다음엔 안내 문구는 되는데 시트 위쪽 손잡이로 직접 끌거나 다른 빈 자리를 쓸어 올려도 해설이 안 나오는 문제 — 그 두 경로는 iOS 가 알아서 처리해 우리 코드를 안 거치고 `selectedDetent`만 바꿔서 생긴 것. 경로마다 따로 처리하지 않고 `.onChange(of: selectedDetent)` 하나로 "결과가 .medium이면 무조건 해설을 편다"로 통합해 손잡이·빈 자리 스와이프·안내 탭 세 경로 모두 같은 곳에서 처리하게 함 (3-F). 이어서 스타일 요청 두 가지를 반영 — 낱말 이름표(`word`) 폰트를 18pt heavy 에서 `gloss`와 똑같은 30pt bold 로 맞추고, 안내 문구도 15pt→18pt 로 키우면서 위쪽 여백을 더 둬(top 16 / bottom 8) 구분선에서 살짝 떨어져 보이게 함(3-G). 그다음 ✕ 닫기 버튼을 없애고 — 배경을 탭해도 시트가 안 닫히던 것을 답 고르기·"다시 읽기"·배경(지문·여백) 탭 세 경우 모두 `glossarySelection`을 nil로 되돌려 닫도록 `QuestionScreen`에 모음(3-H). 이 배경 탭 감지가 `KoreanText`의 UIKit 낱말 탭 제스처와 같은 손가락 탭에서 겹쳐 걸려 방금 연 사전을 바로 닫아버릴 수 있다는 걸 실기기 확인 전에 코드 검토로 미리 발견 — 낱말 탭마다 올라가는 `glossaryOpenToken`을 두고, 배경 탭은 한 틱 뒤(`DispatchQueue.main.async`) 토큰이 그대로일 때만 닫도록 고쳐 경합을 없앰(3-I, 아직 실기기 미확인). 마지막으로 비슷한 낱말 표시를 뜻(gloss) 아래 별도 줄에서 낱말 이름표와 같은 줄 오른쪽으로 옮김(3-J)(첫 시도는 Spacer 위치를 잘못 둬 모달 오른쪽 끝으로 밀렸던 것을 낱말칸 바로 옆에 붙게 다시 고침). 시트 위쪽 손잡이도 시스템 기본 알약 대신 넓적한 "^" 모양(`WideChevronShape`)을 직접 그리도록 바꿈 — `.presentationDragIndicator(.hidden)`로 시스템 손잡이만 숨기고, 끌어서 크기 바꾸는 동작 자체는 그대로 둠(3-K). 안내 문장 "쓸어 올려서 해설을 확인하세요."는 지우고 화살표 아이콘만 남김 — 탭/스와이프 영역과 제스처는 그대로 둠. 접힌 시트 높이는 여기저기 흩어져 있던 `.height(180)` 세 곳을 `collapsedHeight` 상수 하나로 합치고 150으로 낮춤(3-L). 이 상수 때문에 실제 Xcode 빌드에서 컴파일 에러 발생 — `Self.` 없이 `collapsedHeight`를 인스턴스 문맥(`body`·`@State` 기본값·`onChange`)에서 바로 썼던 것이 원인. 세 곳 다 `Self.collapsedHeight`로 고침(3-M). 고치면서 근처에 깨져 있던 주석 한 줄(패치 과정에서 코드가 섞여 들어감, 실행엔 무해)도 복구. 손잡이(`WideChevronShape`) 선 굵기를 2배(3→6)로, 프레임도 살짝 넓게(56×10→64×16)로 키움. 낱말·뜻 글자 크기는 30pt→21pt로 줄이고, 둘이 항상 같아야 한다는 요구를 `wordGlossFontSize` static 상수 하나로 강제 — `QuestionScreen`의 행동 안내 문구(21pt)와 맞춤(3-N). 손잡이 높이는 16→13(≈80%)으로 더 낮추고, 3-L에서 문장만 지우고 남겨 뒀던 아래쪽 화살표(^) 아이콘도 완전히 삭제 — 그 자리는 이제 투명하지만 탭/스와이프 제스처는 그대로 남김(3-O). 손잡이를 한 번 더 다듬음 — 선 굵기 6→4.8(80%로), 높이 13→10, 폭 64→48(75%로), 투명도 0.6→0.4(더 옅게)로 조정(3-P, "80% 줄이기"를 "80%로 줄이기"로 해석한 판단 지점 있음). 낱말·뜻 글자 크기 기준을 행동 안내 문구(21pt)에서 선다 보기 버튼(ChoiceButton, 22pt)으로 바꿈 — wordGlossFontSize 상수 하나만 고쳐 둘의 크기는 여전히 같음(3-Q). 그 직후 28pt로 직접 지정해 달라는 요청이 와서 다시 바꿈(3-R) — 둘의 크기는 여전히 상수 하나로 같이 묶여 있음. 마지막으로 낱말을 탭해 사전 시트가 열리면 지문에서 그 낱말에만 배경색을 칠하는 기능을 추가 — `KoreanText`에 `selectedWord`/`selectedWordColor`(기본값이 "다시 읽기" 버튼과 같은 `AppColor.secondaryBackground`)를 새로 두고, 이미 있던 형광펜(marker) 배경 적용과 같은 방식으로 `NSAttributedString`의 `.backgroundColor`를 그 낱말 범위에만 적용. `QuestionScreen`이 이 값을 `glossarySelection?.word`로 그대로 넘기므로, 시트가 어느 경로(답 고르기·다시 읽기·배경 탭·아래로 쓸어내리기)로 닫히든 `glossarySelection`이 nil이 되면서 배경도 자동으로 사라지고 원래부터 검정이던 글자만 남음 — 글자색은 따로 바꾼 적이 없어 별도 코드가 필요 없었음(3-S). 패치 중 `KoreanText(...)` 호출부에 `selectedWord:` 인자를 구조체 선언 순서(marker→markerColor→selectedWord→selectedWordColor→glossary→onTapWord)보다 뒤인 `glossary:` 뒤에 잘못 적어 컴파일 에러가 났을 실수를, 실기기 확인 전에 코드를 다시 훑다가 스스로 발견해 `glossary` 앞으로 옮겨 고침. 그 뒤 해설을 펼쳤다가 시트를 다시 접어도 만든 해설이 그대로 남아 있는 문제를 발견 — 시트가 커질 때(`.medium`)만 `showsExample`을 켜고 다시 작아질 때는 아무 것도 안 하던 `onChange(of: selectedDetent)`를, 두 방향 다 반응하도록 `showsExample = (newValue == .medium)`로 바꿔 접힐 때 자동으로 감춰지게 함 — 예문 자체(`exampleState`)는 그대로 남아 다시 펼치면 재생성 없이 다시 보임(3-T). 마지막으로, 어떤 낱말에서 예문 생성이 세이프티 가드레일에 걸리는지 확인하고 싶다는 요청에 — 이미 있던 장치(오답 해설 `CommentaryWriter`가 실패하면 `ModelFailureDraft`를 돌려주고 `QuizSession`이 `ModelFailure`로 저장, `ObsUploader`가 Supabase `model_failure` 표로 올리는 경로)를 낱말 사전 예문에도 그대로 연결 — `composeExample`의 반환 타입을 `String?`에서 `Writing`(text/failure)으로 바꾸고, 실패하면 `job: "glossary_example"`로 보낸 프롬프트·지시문·에러 문구를 그대로 담아 돌려주게 함. `QuestionScreen`이 그 실패를 `session.saveFailures(...)`로 넘기도록 `QuizSession.saveFailures`의 `private`을 뗌(modelContext는 세션만 들고 있어 화면이 직접 못 넣으므로). 새 표·새 SDK 없이 있던 Supabase 파이프라인 하나만 넓혀 씀 — 다음 회차 시작/종료 때 `model_failure` 표에 `job = 'glossary_example'`로 걸러 보면 어떤 프롬프트가 걸렸는지 그대로 보임(3-U). 그 에러 문구가 함께 알려준 애플 Feedback Assistant 신고용 API(`LanguageModelSession.logFeedbackAttachment`)도 연결해 달라는 요청 — 이 API는 iOS 26의 아주 최근 것이라 애플 공식 문서가 자바스크립트 렌더링이라 웹 검색으로 정확한 타입을 못 확인했고, 이 환경엔 Xcode가 없어 짐작으로 적으면 바로 컴파일 에러가 날 위험이 있어 사용자에게 Xcode Quick Help 화면을 직접 봐 달라고 요청 — 스크린샷으로 실제 서명 확인(사용자가 예상한 것과 달리 static이 아니라 인스턴스 메서드였고, 타입 이름도 `LanguageModelFeedbackAttachment`가 아니라 `LanguageModelFeedback`이었음). `Sentiment`/`Issue`의 정확한 케이스 이름까진 안 보였지만 셋 다 비워도 되는 타입(nil/[]/nil)이라 그 값으로 채워 연결 — `session`을 `do` 블록 밖으로 빼서 `catch`에서도 그 세션의 `logFeedbackAttachment(...)`를 부를 수 있게 하고, 결과 `Data`를 문서 폴더에 파일로 저장하는 `saveFeedbackAttachment(...)`를 추가. Xcode로 기기에 연결해야 꺼낼 수 있는 파일이라 `#if DEBUG`로 개발 중에만 남게 함 — 실기기(RELEASE)에는 안 쌓임(3-V). 이어서 사용자가 `logFeedbackAttachment`의 정확한 애플 공식 문서 URL을 직접 보내줘서, 그 URL 뒤에 `.md`를 붙이면 자바스크립트 없이도 문서 원문이 그대로 나온다는 걸 발견 — 이 방법으로 `LanguageModelSession` 전체 개요, `GenerationError.guardrailViolation(_:)`, 그 안의 `Context` 구조체까지 차례로 확인해 3-V의 짐작을 실제 문서 기준으로 다시 고침: `sentiment: nil` → `.negative`(문서가 세 케이스와 예시를 명시), 모든 실패에 반응하던 것 → `guardrailViolation` 케이스일 때만 반응하도록 좁힘(문맥 초과 등은 애플 신고 대상이 아니므로), 파일 확장자 `.data` → `.json`(문서가 JSON 인코딩이라고 명시), `Transcript.Entry?` 대신 더 간단한 `desiredResponseText: String?` 오버로드로 교체. `Issue.Category`의 전체 케이스는 끝내 못 찾아 `issues: []`로 남겨 둠 — 문서가 "실패로 롤백된 항목은 자동으로 첨부자료에 포함된다"고 명시해 막힌 프롬프트 자체는 그래도 담김(3-W). 마지막으로 사용자가 "낱말 해설도 model_failure에 담겨서 올라가면 좋겠는데"라며 확인을 요청하고 실제 Supabase model_failure 표 CSV(7줄, 전부 job=note, 세이프티 에러로 정상 업로드됨)를 보내 job=glossary_example 행이 하나도 없음을 확인해 줌 — 코드를 다시 훑어 원인 두 가지를 찾음: QuizSession.saveFailures(_:)가 insert만 하고 save()를 안 불러 뒤따르는 저장이 없는 낱말 사전 경로에서는 기록이 저장 안 된 채 사라질 수 있었던 것, ObsUploader.uploadPendingFailures()가 회차 시작/종료 때만 불려 회차 중간에 생긴 낱말 사전 실패는 회차가 끝나기 전까진 업로드 자체가 시도되지 않았던 것. saveFailures 끝에 try? modelContext.save()를 추가하고, 회차 경계를 안 기다리고 바로 올리는 QuizSession.uploadFailuresNow()를 새로 만들어 QuestionScreen이 낱말 사전 실패 직후 부르게 하고, ObsUploader.uploadPendingFailures()에도 uploadPending()과 같은 진단 로그(📤/✅/❌)를 추가함(3-X). 실기기로 실제 확인해 보니 save()는 되는데 업로드가 계속 실패 — send(_:to:)가 서버 응답 본문을 버리고 있어 원인이 하나도 안 보이던 것을 고쳐 실패 시 HTTP 상태 코드와 응답 본문을 그대로 찍게 함. 그 로그로 확인한 실제 원인은 코드 버그가 아니라 Supabase model_failure 표의 RLS(Row Level Security) INSERT 정책이 job='glossary_example'을 막고 있는 것(에러 42501) — note 는 계속 성공해 온 걸 보면 그 정책이 job 값에 따라 허용 여부를 가르는 조건을 갖고 있는 것으로 보이며, 이 저장소엔 정책을 담은 .sql 이 없어(Supabase 대시보드에서 직접 만들어짐) 사용자가 대시보드에서 직접 확인·수정해야 함. 사용자가 실제 정책 원문을 SQL 로 조회해 보내줘 확정 — job = ANY (ARRAY['commentary', 'note']) 로 두 값만 못 박혀 있었고 device_id·question_id·occurred_at·길이 제약은 낱말 사전 값도 다 통과하는 모양이라 job 값 하나만 문제였음. 'glossary_example' 을 그 배열에 추가하는 ALTER POLICY ... WITH CHECK SQL 문을 만들어 드림(코드가 아니라 DB 정책이라 이 환경이 대신 실행할 수 없어 사용자가 Supabase SQL Editor 에서 직접 실행해야 함, 아직 실행·재확인 전)
- **2026-09-10 (밤)** — 문서 정리 — 4·5·6차 단계별 `.md` 열두 장을 [HISTORY.md](HISTORY.md) 한 장으로 합치고 원본은 `_to_delete/` 로. DocC 에 <doc:FeedbackModal> 신설, 새 타입 다섯(`AnswerChecker`·`EncouragementWriter`·`ModelFailure`·`Writing`·`ModelCall`)을 `KCT.md` Topics 에 등록. 6차 **4단계** 적용. `facts` 를 30문항에 채우고([해설_재료_규칙.md](해설_재료_규칙.md)) `CommentaryWriter` 가 재료만 쓰게 함. `[구조]` 문장 틀은 제거 — 로그에 그대로 복사돼 나왔다. **오답 모달 재설계**(두 박자·👉/✅·붉은색/파랑), 고른 답도 설명(`describe`), 회차마다 새로 만드는 응원 문구(`EncouragementWriter`), 모델 실패를 지침·프롬프트째 남기는 `model_failure`. 국경일 날짜 문항 5개 추가(25 → 30)
- **2026-09-10** — 6차 1~3단계 적용. `ContentFile`·`AnswerMatcher`·`AnswerChecker`·`ModelCall`(시한) 신설, `MeaningGrader` 제거. **로그 여섯 회차로 「모델은 글자를 못 본다」를 확증**하고 한 글자 오타·목록을 코드로 옮김. 문제집 1,130문항에 `AnswerShape` 부여(word 911 · sentence 174 · closedList 32 · openList 13), `AnswerKind` 를 아홉으로 축소. 규칙 **24**(작은 타입은 한 파일에)·**25**(`.md` 는 초급자에게 짧게) 신설. 회차 끝 3초 `GradingScreen` 부활, 해설 맥동 정지 버그 수정

---

## 어디에 무엇을 쓰나

| 성격 | 파일 |
|---|---|
| 지금 어디까지 왔나 | **PROGRESS.md** (이 파일) |
| 코드를 어떤 순서로 읽을까 | [STUDY_GUIDE.md](STUDY_GUIDE.md) |
| 설계 원칙·파일별 역할 | [LEARNING_PLAN.md](LEARNING_PLAN.md) |
| 용어의 뜻 | [GUIDE.md](GUIDE.md) |
| 막혔던 것과 그 해결 | [Q&A.md](Q&A.md) |
| AI 작업 규칙 | [CLAUDE.md](CLAUDE.md) · [RULES.md](RULES.md) |
| 지금 진행 중인 계획 | [6차_계획_지식층.md](6차_계획_지식층.md) |
| **지나온 길과 그 이유** | [HISTORY.md](HISTORY.md) |
| 해설 재료를 채우는 규칙 | [해설_재료_규칙.md](해설_재료_규칙.md) |
