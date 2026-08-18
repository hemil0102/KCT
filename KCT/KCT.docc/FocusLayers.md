# 하이라이트 3층과 폴백

질문이 무엇을 묻는지 형광펜으로 칠해 줍니다. 그 값을 세 곳에서 가져오는데,
**지금 동작하는 것은 세 번째 뿐**입니다.

## Overview

어르신은 긴 질문에서 "무엇을 묻는지" 를 놓칩니다. "고조선을 세운 왕은 누구입니까?"
에서 나라 이름에 눈이 가고 "누구" 를 못 보는 일이 흔합니다.
그래서 묻는 대상에 연노랑 형광펜을 칠합니다.

문제는 그 값을 **어디서 얻느냐** 입니다.

| 층 | 무엇 | 지연 | 상태 |
|---|---|---|---|
| 1 | 서버가 내려준 값 | 0 | 아직 없음 |
| 2 | 모델 분석 캐시 (``FocusAnalyzer`` + ``QuestionFocusRecord``) | 0 (미리 계산됨) | **꺼짐** |
| 3 | 규칙 기반 (``QuestionFocusExtractor``) | 0 (즉시 계산) | ✅ 동작 |

``FocusStore/focuses(for:)`` 가 이 순서로 읽습니다.

## 3층이 안전망이다

한국어 의문사는 **닫힌 집합**입니다 — 누구 · 어디 · 언제 · 무엇 · 무슨 · 어느 · 몇.
새 의문사가 생기지 않으므로 목록으로 두고 찾으면 대부분 잡힙니다.

이게 중요한 이유:

- 온디바이스 모델이 없는 기기에서도 형광펜이 **동작한다**
- 문제집에 새 문제를 넣은 **직후에도 기다림이 없다**
- 모델은 "있으면 좋은 것" 이 되고, 앱은 모델 없이도 성립한다

``QuizItem/make(_:mode:answerPool:affectsProgress:focus:)`` 는 `focus` 를 못 받으면
그 자리에서 ``QuestionFocusExtractor/focus(in:)`` 를 부릅니다. 그래서 어떤 경로로
와도 형광펜이 비지 않습니다.

## 2층은 왜 꺼져 있나

> Important: ``FocusStore/usesModelAnalysis`` 가 `false` 입니다. 그래서
> ``FocusAnalyzer`` 와 ``QuestionFocusRecord`` 는 **호출되지 않습니다.**
> 중단점을 걸어도 걸리지 않는 것이 정상입니다 — 버그가 아닙니다.

끈 이유: 모델이 "묻는 대상" 대신 **질문 문장 전체를 돌려주는 경우가 많아**
지문이 통째로 형광펜 처리됐습니다. 강조가 전부면 강조가 없는 것과 같습니다.

### 다시 켤 때 함께 넣어야 하는 것

`true` 로 바꾸는 것만으로는 같은 문제가 재발합니다. 지금 있는 검증은
``FocusAnalyzer`` 안의 한 줄뿐입니다.

```swift
guard question.contains(generated.phrase) else { return nil }
```

이건 **환각(hallucination)만** 막습니다 — 지문에 없는 표현을 지어냈는지 봅니다.
"너무 긴 것" 은 걸러내지 못합니다. 그러니 **강조 길이 제한**(예: 지문 절반을
넘으면 버림)을 함께 넣으세요.

## 캐시는 어떻게 스스로 늙는가

캐시의 어려움은 "언제 버릴지" 입니다. ``QuestionFocusRecord`` 는 분석 당시
**질문 텍스트의 SHA256** 을 함께 저장합니다(``QuestionFocusRecord/hash(of:)``).
꺼낼 때 현재 질문의 해시와 비교하므로, 문구를 한 글자만 고쳐도 낡은 결과가
자동으로 버려집니다.

> Important: Swift 의 `hashValue` 는 **실행할 때마다 값이 달라져** 저장용으로 쓸 수
> 없습니다. 앱을 껐다 켜도 같아야 하므로 SHA256을 씁니다.

## 형광펜을 칠하지 않는 두 경우

- **실전 모드** — ``SessionMode/showsFocusHighlight`` 가 `false`.
  스스로 읽고 판단해야 실제 시험과 같은 연습이 됩니다.
- **O/X 문제** — ``QuizItem/markerText`` 가 `nil` 을 돌려줍니다.
  판단 대상인 답이 이미 밑줄로 강조되어 있어서, 강조가 둘이면 어디를 봐야 할지
  알 수 없게 됩니다.

## 무대는 화면이 만든다

``FocusStore`` 는 **무엇을 강조할지**만 정합니다. 어떤 색으로 어떻게 칠할지는
``KoreanText`` 와 ``AppColor/marker`` 의 몫입니다.

## See Also

- ``FocusStore``
- ``QuestionFocusExtractor``
- ``FocusAnalyzer``
- <doc:ElderAccessibility>
