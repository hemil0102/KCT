# Q&A

막혔던 것과 그 해결을 남기는 기록입니다. `CLAUDE.md` 규칙 6에 따라 쌓아갑니다.

빌드가 막혔던 것, 개념을 오해했던 것, 문서와 실제가 달랐던 것만 남깁니다. 최신 항목이 위에 옵니다.

---

## SwiftData에 `insert`만 하고 `save()`를 안 불러서, 화면 단독 경로의 기록이 서버로 안 올라갔다

**Q** — 낱말 사전 예문이 세이프티에 걸려 실패하면 `QuizSession.saveFailures(_:)`가 그 기록을 `ModelFailure`(SwiftData)로 남기고, 언젠가 `ObsUploader`가 Supabase `model_failure` 표로 올리도록 짜 놓았다. 그런데 실제로 며칠간 써 보니 오답 해설(`job = "note"`) 실패는 Supabase에 잘 쌓이는데, 낱말 사전(`job = "glossary_example"`) 실패는 CSV로 표를 통째로 내려받아 봐도 단 한 줄도 없었다.

**A** — 두 가지가 겹쳐서 생긴 문제였다.

1. `saveFailures(_:)`는 `modelContext.insert(...)`만 하고 그 자리에서 `try? modelContext.save()`를 부르지 않았다. 오답 채점 경로(`gradeCurrent()`)에서 이 메서드를 부를 때는 바로 뒤이어 `saveObsRecord()`가 어차피 저장을 하기 때문에 지금까지는 "우연히" 문제가 없었던 것뿐이다. 그런데 낱말 사전 탭(`QuestionScreen.onTapWord`)은 그런 뒤따르는 저장이 전혀 없는, 채점과 무관한 독립된 경로다. `insert`만 하고 `save()`가 없으면 그 변경은 메모리상의 미확정 상태로 남고, 다른 저장이 한 번도 안 일어난 채 앱이 백그라운드로 가거나 종료되면 그 기록만 조용히 사라질 수 있다.
2. 설령 저장이 잘 됐다 해도, `ObsUploader.uploadPendingFailures()`를 부르는 곳이 `QuizSession.uploadObservations()` 하나뿐이었고, 그건 회차가 시작되거나 끝날 때만 호출된다. 낱말 사전 실패는 회차 중간 아무 때나 생기는데, 그 회차를 끝내거나 새로 시작하기 전까지는 저장된 기록이 있어도 업로드 자체가 시도조차 안 됐다.

**해결** — `saveFailures(_:)` 끝에 `try? modelContext.save()`를 추가해 이 메서드가 스스로 저장을 책임지게 하고, `QuizSession`에 `uploadFailuresNow()`를 새로 추가해 회차 경계를 기다리지 않고 그 자리에서 바로 업로드를 시도하게 했다. `QuestionScreen`은 `session.saveFailures([writing.failure])` 뒤에 실패가 있을 때만 `session.uploadFailuresNow()`를 부른다.

```swift
// QuizSession.swift
func saveFailures(_ drafts: [ModelFailureDraft?]) {
    let toInsert = drafts.compactMap { $0 }
    guard !toInsert.isEmpty else { return }

    for draft in toInsert {
        modelContext.insert(ModelFailure(draft: draft))
    }
    try? modelContext.save()   // 뒤따르는 저장에 기대지 않는다
}

func uploadFailuresNow() {
    Task {
        await ObsUploader(modelContext: modelContext).uploadPendingFailures()
    }
}
```

**교훈** — SwiftData의 `modelContext.insert(...)`는 그 자체로 디스크에 반영되지 않는다. 어떤 경로에서 `insert`를 부르든, **그 경로가 스스로 `save()`까지 책임질지 다른 곳의 저장에 기대고 있는지**를 분명히 해야 한다. 지금처럼 "여러 화면이 공유하는 메서드"(`saveFailures`)를 원래 한 경로(채점)만 쓰다가 다른 경로(낱말 탭)로 재사용을 넓힐 때는, 그 메서드가 원래 경로의 "뒤따르는 저장"에 암묵적으로 의존하고 있지 않은지부터 확인해야 한다. 업로드처럼 "이벤트가 생기면 보낸다"는 로직도 마찬가지다 — 그 이벤트가 정말 모든 발생 경로를 커버하는 시점(회차 시작/종료)에 걸려 있는지, 아니면 특정 경로(회차 흐름)만 염두에 두고 짠 것이라 다른 경로(화면 단독 동작)에서는 그 시점이 아예 안 올 수도 있는지를 따로 짚어야 한다.

---

## `selectedWord:` 인자를 `glossary:` 뒤에 뒀다가, 컴파일 에러가 났을 뻔했다

**Q** — `KoreanText.swift`에 새 프로퍼티 `selectedWord`/`selectedWordColor`를 추가하고, 호출부(`QuestionScreen.swift`)에서 `KoreanText(...)`를 부르며 인자를 채워 넣었다. 처음엔 `selectedWord:` 를 `glossary:` 뒤에 적었다 — 라벨을 다 붙였으니 순서는 상관없을 거라 생각했다.

**A** — Swift는 라벨 붙은 인자라도 **호출부의 인자 나열 순서가 선언부의 프로퍼티(파라미터) 선언 순서를 따라가야** 한다. 건너뛰는 건 된다(기본값이 있는 프로퍼티는 생략 가능) — 하지만 뒤에 있는 걸 앞에, 앞에 있는 걸 뒤에 쓰는 **역순은 안 된다.** `KoreanText`의 선언 순서는 `marker → markerColor → selectedWord → selectedWordColor → glossary → onTapWord`인데, 호출부에서 `selectedWord`를 `glossary` 뒤에 쓰면 이 순서를 거스르게 되어 컴파일이 안 된다.

**해결** — 실기기에 올려 확인하기 전에, 코드를 다시 훑다가 스스로 발견해 `selectedWord:` 를 `glossary:` 앞으로 옮겼다.

```swift
KoreanText(
    text: item.displayText,
    font: .systemFont(ofSize: 30, weight: .bold),
    highlight: item.highlightText,
    marker: sessionMode.showsFocusHighlight ? item.markerText : nil,
    selectedWord: glossarySelection?.word,   // glossary 보다 앞이어야 한다
    glossary: item.glossary,
    onTapWord: { ... }
)
```

**교훈** — 다른 언어(Python·Kotlin 등)의 키워드 인자는 순서 없이 아무 데나 놓을 수 있지만, Swift의 라벨 붙은 인자는 그렇지 않다 — 선언 순서를 그대로 따라야 한다. 구조체에 새 프로퍼티를 추가한 순서와 기존 호출부의 인자 나열 순서가 다르면 이 문제가 생기기 쉽다. 새 프로퍼티를 추가할 때는 어디에 끼워 넣었는지(선언 순서)를 그 자리에서 바로 기억해 두는 편이 안전하다.

---

## "Static member 'collapsedHeight' cannot be used on instance of type 'GlossaryPanel'"

**Q** — `.presentationDetents([.height(collapsedHeight), .medium], ...)` 줄에서 Xcode가 이 에러를 냈다.

**A** — `collapsedHeight`를 `private static let`으로 선언했다 — 타입(`GlossaryPanel`) 자체에 딸린 값이지, 인스턴스에 딸린 값이 아니다. 그런데 이걸 쓴 자리(`@State` 기본값, `body` 안의 `.presentationDetents`, `onChange` 클로저)는 전부 **인스턴스 문맥**이다. 인스턴스 문맥에서는 같은 타입의 static 멤버라도 이름만 써서 바로 꺼낼 수 없다 — `Self.collapsedHeight`나 `GlossaryPanel.collapsedHeight`처럼 어디 것인지 밝혀야 한다.

**해결** — 세 군데 전부 `Self.collapsedHeight`로 고쳤다.

```swift
private static let collapsedHeight: CGFloat = 150

@State private var selectedDetent: PresentationDetent = .height(Self.collapsedHeight)
...
.presentationDetents([.height(Self.collapsedHeight), .medium], selection: $selectedDetent)
...
selectedDetent = .height(Self.collapsedHeight)
```

**교훈** — 반복되는 매직 넘버를 상수로 뽑아낼 때, 그 상수를 `static let`으로 선언하면 인스턴스 코드(연산 프로퍼티, 메서드, 클로저, `@State` 기본값)에서 쓸 때마다 `Self.`를 붙여야 한다는 걸 잊기 쉽다. 반대로 상수를 인스턴스 프로퍼티(`let`)로 뒀다면 이 문제가 아예 없었을 것이다 — 여러 인스턴스가 값을 공유할 필요가 없다면(이번처럼 항상 같은 값이라도), `static` 대신 그냥 `let`으로 두는 것도 간단한 대안이다.

---

## 배경을 탭해서 사전을 닫으려다, 낱말을 탭해서 여는 것과 같은 손가락 탭에서 겹칠 뻔했다

**Q** — 사전 시트를 ✕ 버튼 없이, 답을 고르거나 "다시 읽기"를 누르거나 배경(지문·여백)을 탭하면 닫히게 만드는 중이었다. 배경 탭 감지를 지문(`KoreanText`)을 감싸는 조상 뷰에 SwiftUI `.onTapGesture`로 달았는데 — 실기기에 올리기 전에 코드만 보고 짚어보니, 낱말을 탭해서 사전을 새로 여는 바로 그 탭이 배경 탭으로도 잡힐 수 있어 보였다.

**A** — `KoreanText`의 낱말 탭은 `UIViewRepresentable` 안에서 `UILabel.addGestureRecognizer(UITapGestureRecognizer(...))`로 UIKit 제스처를 직접 단다. 배경 탭 감지는 그 지문을 감싸는 조상 뷰의 SwiftUI `.onTapGesture`다. 둘 다 결국 같은 뷰 계층 안의 `UITapGestureRecognizer`인데, 서로 "하나가 실패해야 인식된다"는 관계(`require(toFail:)`)를 걸어 두지 않으면 **iOS는 둘 중 어느 게 먼저 인식될지 보장하지 않는다.** 배경 쪽이 낱말 탭과 같은 시점에(또는 그 직후에) 처리되면, 방금 낱말을 탭해서 새로 연 시트를 배경 탭 처리가 바로 그 자리에서 닫아 버릴 수 있다 — "낱말을 눌러도 사전이 안 뜬다"로 보일 텐데, 사실은 떴다가 즉시 닫히는 것이다.

**해결** — 어느 제스처가 먼저 실행되는지에 기대는 대신, 한 틱 뒤에 다시 확인하는 방식으로 경합 자체를 없앴다.

```swift
@State private var glossaryOpenToken = 0   // 낱말을 탭할 때마다 +1

onTapWord: { word, gloss, examples in
    glossaryOpenToken += 1   // 배경 탭보다 먼저 "낱말 탭이 있었다"는 표시부터 남긴다
    ...
}

private func dismissGlossaryFromBackgroundTap() {
    guard glossarySelection != nil else { return }
    let tokenAtTap = glossaryOpenToken
    DispatchQueue.main.async {
        guard glossaryOpenToken == tokenAtTap else { return }   // 그 사이 낱말 탭이 있었다 → 닫지 않는다
        dismissGlossaryIfNeeded()
    }
}
```

같은 탭에서 낱말 탭도 걸렸다면 `DispatchQueue.main.async`가 실행될 때는 이미 토큰이 올라가 있어 배경 탭 쪽은 아무 것도 하지 않는다. 순수한 배경 탭이면 토큰이 그대로라 정상적으로 닫힌다.

**교훈** — SwiftUI의 `.onTapGesture`와 UIKit의 `UITapGestureRecognizer`가 조상·자손 관계로 같은 화면 영역에 겹쳐 있으면, 어느 쪽이 먼저 인식되는지는 정해져 있지 않다 — 이전에 겪은 "ScrollView가 드래그를 먼저 가져간다"(우선순위가 한쪽으로 고정된 경우)와는 다른 종류의 문제다. 우선순위를 다투는 대신, 상태에 "방금 그 일이 있었다"는 표시를 남기고 한 틱 뒤에 다시 확인하면 어느 순서로 실행되든 안전하다. 이번엔 실기기에서 직접 겪은 버그가 아니라 코드 구조를 보고 미리 짚어낸 것이라, 실기기 확인이 여전히 필요하다.

---

## 손잡이로 끌거나 다른 데를 쓸어도 해설이 안 나온다 — 트리거를 경로마다 심고 있었다

**Q** — 안내 문구를 탭하면 해설이 잘 나온다. 그런데 시트 위쪽 손잡이를 직접 끌어서 키우거나, 안내 문구가 아닌 다른 빈 자리를 쓸어 올려도 해설이 안 나온다.

**A** — `revealExampleHint`에 달린 제스처(탭, 그 위에서의 스와이프)가 `showsExample = true`와 `selectedDetent = .medium`을 직접 호출하는 구조였다. 그런데 시트가 `.medium`으로 커지는 길은 그 말고도 둘 더 있다 — 손잡이를 직접 끄는 것, 그리고 스크롤할 내용이 없을 때 시트 아무 데서나 위로 쓸어 올리는 것. 이 둘은 iOS가 알아서 처리하는 제스처라 우리 코드를 거치지 않고 `selectedDetent`만 바로 바뀐다 — 그 경로들에서 `showsExample`을 켜 주는 코드가 없으니 안 나온 것이다.

**해결** — "무엇이 시트를 키웠는가"를 하나하나 처리하는 대신, 그 결과인 `selectedDetent` 하나만 지켜보게 바꿨다.

```swift
.onChange(of: selectedDetent) { _, newValue in
    guard newValue == .medium else { return }
    withAnimation(.easeOut(duration: 0.25)) { showsExample = true }
}
```

`reveal()`은 이제 `selectedDetent = .medium`만 하고, 실제로 해설을 펴는 일은 이 `onChange` 하나가 도맡는다. 손잡이든, 빈 자리든, 안내 탭이든 — 결과가 `.medium`이면 다 똑같이 반응한다.

**교훈** — 하나의 결과("시트가 커졌다")에 이르는 길이 여러 개이고 그중 일부가 시스템이 대신 처리해 내 코드를 거치지 않을 수 있을 때는, 경로마다 후속 동작을 심지 말고 **그 경로들이 공통으로 만드는 상태를 지켜보다가 거기서 한 번만 반응**하는 편이 맞다. 이번처럼 시스템 제스처가 섞여 있으면 사실상 그게 유일하게 빠짐없이 잡는 방법이다.

---

## 안내는 보이는데 쓸어 올려도 안 먹힌다 — ScrollView가 드래그를 먼저 가져갔다

**Q** — "쓸어 올려서 해설을 확인하세요." 안내는 이제 뜨는데, 그 위에서 쓸어 올려도 아무 반응이 없고 눌러야만(탭) 펼쳐진다. 실기기에서 확인했으니 확실하다.

**A** — `revealExampleHint`가 `ScrollView` 안에 있는데, 거기에 `.gesture(DragGesture(...))`로만 제스처를 달았다. SwiftUI에서 **조상 뷰(ScrollView)가 세로 드래그의 우선권을 먼저 가져가는 것이 기본 동작**이라, 안내 위의 위로-쓸기는 우리가 만든 제스처가 아니라 ScrollView 자신의 스크롤로 흡수됐다. 탭은 스크롤과 겹칠 일이 없는 별개 제스처라 처음부터 잘 됐던 것이고, 그래서 "탭은 되는데 스와이프만 안 되는" 정확히 이 증상이 나왔다.

**해결** — `.gesture(...)`를 `.highPriorityGesture(...)`로 바꿨다. 이 작은 안내 영역에서 시작된 드래그는 ScrollView보다 우리 쪽이 먼저 가져간다.

```swift
.highPriorityGesture(
    DragGesture(minimumDistance: 12)
        .onEnded { value in
            guard value.translation.height < -12 else { return }
            reveal()
        }
)
```

**교훈** — `ScrollView` 안의 자식 뷰에 별도 드래그 제스처를 달 때 `.gesture(...)`는 조상의 스크롤에 거의 항상 진다. `.highPriorityGesture(...)`(또는 `.simultaneousGesture(...)`)를 써야 자식이 먼저 인식한다. 그리고 이번 건 **탭 같은, 스크롤과 절대 안 겹치는 안전장치를 같이 심어 둔 덕에** "완전히 안 됨"이 아니라 "스와이프만 안 됨"으로 증상이 정확히 좁혀졌다 — 안전장치가 디버깅 단서도 같이 준 셈이다.

---

## 스와이프 안내 자체가 아예 안 보였다 — "실패"를 "기능 없음"처럼 숨겼다

**Q** — 낱말을 클릭했는데 "쓸어 올려서 해설을 확인하세요." 안내가 아예 안 뜬다.

**A** — `GlossaryPanel`이 `exampleState == .unavailable`이면 안내를 포함한 구획 전체를 `EmptyView()`로 숨기고 있었다. 그런데 `composeExample(...)`은 기기가 Foundation Models 를 지원 안 하면 모델을 부르지도 않고 곧바로 `nil`을 돌려준다 — `.loading`에서 `.unavailable`로 사실상 즉시 넘어간다는 뜻이다. 시트가 화면에 자리 잡기도 전에 이미 `.unavailable`이 되어 있었을 가능성이 커서, 안내가 뜰 틈도 없이 사라진 것처럼 보였다.

**해결** — 숨기는 조건에서 `.unavailable`을 뺐다. 안내는 상태와 무관하게 항상 먼저 보이고, 펼쳤을 때만 그 상태에 맞는 내용(완성된 해설 / "해설 준비 중입니다." / "이 기기에서는 해설을 만들 수 없어요.")을 보여준다.

**교훈** — 처리 결과가 실패("이 기기에서는 안 된다")로 아주 빠르게 정해지는 비동기 작업은, 그 실패를 이유로 UI 전체를 숨기면 **성공하는 경우와 달리 사용자가 그 기능이 있었는지조차 모르게 된다.** "기능이 있다"는 신호(여기서는 스와이프 안내)는 결과와 무관하게 먼저 보여주고, 실패는 사용자가 그 신호를 실제로 눌러봤을 때 설명하는 편이 안전하다 — 특히 결과가 빨리 나올수록 이 차이가 크다.

---

## 쓸어 올려도 모달이 안 커졌다 — 콘텐츠만 바꾸는 것과 시트를 키우는 것은 다른 일이었다

**Q** — 낱말 사전 시트에서 안내를 위로 쓸어 올리면, 모달 자체가 펼쳐지면서 해설이 나와야 하는데 같은 크기 안에서 내용만 바뀐다.

**A** — `revealExampleHint`의 제스처가 하던 일은 `showsExample = true`뿐이었다. `.presentationDetents([.height(180), .medium])`처럼 배열만 주는 형태는 **어떤 크기를 쓸지 코드에서 정할 방법이 없다** — 오직 사용자가 손잡이를 직접 끌 때만 크기가 바뀐다. 안에서 `showsExample`을 바꿔 봐야 시트 틀 자체는 그대로였던 이유다.

**해결** — `.presentationDetents(_:selection:)`로 지금 크기를 `@State`에 묶고, 스와이프 제스처가 그 값을 직접 바꾸게 했다.

```swift
@State private var selectedDetent: PresentationDetent = .height(180)
.presentationDetents([.height(180), .medium], selection: $selectedDetent)

private func reveal() {
    withAnimation(.easeOut(duration: 0.3)) {
        selectedDetent = .medium
        showsExample = true
    }
}
```

**교훈** — SwiftUI에서 "화면 크기 자체가 바뀌는 것"과 "그 안 콘텐츠가 바뀌는 것"은 서로 다른 상태를 건드려야 하는 별개의 일이다. `.presentationDetents`처럼 값의 배열만 주는 API는 시스템이 알아서 고르거나 사용자 제스처로만 바뀌고, 코드에서 직접 트리거하려면 `selection:` 바인딩처럼 그 상태를 노출하는 오버로드를 찾아 써야 한다.

---

## 마지막 줄에서만 밑줄이 글자와 겹쳤다 — line fragment의 여분이 모든 줄에 똑같지 않았다

**Q** — 실기기에서 보니 "목숨을"·"기리는"(점선) 밑줄은 정상인데 "현충일"(실선) 밑줄만 글자와 겹친다. 셋 다 같은 코드로 그리는데 왜 하나만 다를까?

**A** — 차이는 위치였다. "현충일"은 그 지문의 **진짜 마지막 줄**에 있고, 나머지 둘은 그 앞 줄들에 있었다. 전에(2-C) 넣은 `lineFragmentPadding`(10) 보정은 "모든 줄의 line fragment 아래쪽에 `lineSpacing`만큼 여분이 붙어 있다"는 가정으로 정한 값인데, 이 여분은 문단 스타일상 **"다음 줄과의 사이"에만 들어간다.** 뒤에 이어지는 줄이 없는 진짜 마지막 줄에는 애초에 이 여분이 없다. 그런데도 그 줄에서 똑같이 10을 빼 버리니, 있지도 않은 여분을 뺀 만큼 밑줄이 위로 더 올라가 글자와 겹친 것이다.

**해결** — 밑줄을 그릴 줄마다, 그 줄이 전체 글자의 마지막 줄인지 먼저 확인해서 마지막 줄이면 보정을 안 한다.

```swift
let isLastLine = effectiveGlyphRange.location + effectiveGlyphRange.length >= layoutManager.numberOfGlyphs
let correction = isLastLine ? 0 : padding
let y = originY + box.maxY - correction + gap
```

**교훈** — TextKit에서 "모든 줄이 똑같이 생겼을 것"이라고 가정하면 틀리기 쉽다. 문단 스타일의 줄 간격처럼 "줄과 줄 사이"에만 적용되는 값은 정의상 **첫 줄의 위쪽과 마지막 줄의 아래쪽에는 없다.** 여러 줄에 걸친 커스텀 레이아웃 계산을 할 때는 "이 줄이 몇 번째 줄인가(처음/중간/마지막)"까지 조건에 넣어야 값이 항상 맞는다 — 실기기에서 두 가지 경우(중간 줄, 마지막 줄)를 다 눈으로 봐야 이런 차이가 드러난다는 것도 이번에 확인했다.

---

## "로딩 중"이 안 보였다 — String? 하나로 두 가지 nil을 구분하려 했다

**Q** — 낱말 사전 시트에서 예문을 위로 쓸어 올리면, 모델이 문구를 만드는 동안 "모델 문구가 로딩 중입니다"가 나오고, 다 되면 실제 예문으로 바뀌어야 하는데 — 로딩 문구 자체가 아예 안 나온다.

**A** — 애초에 로딩 상태를 표현할 자리가 코드에 없었다. `generatedExample: String?` 하나로 예문을 넘기고 있었는데, 이 타입은 값이 있으면(`.some`) "완성", 없으면(`nil`) 그걸로 끝 — **"아직 만드는 중"과 "기기가 지원 안 해서 끝내 못 만듦"이 똑같이 `nil`이라 구분이 안 됐다.** `GlossaryPanel`도 `if let generatedExample`로만 게이트를 걸어서, 값이 생기기 **전에는 스와이프 안내조차 안 보였고**, 값이 생긴 뒤에는 항상 완성된 예문만 보여줄 수 있었다 — "로딩 중"을 그릴 방법 자체가 없었다.

**해결** — `String?` 대신 의미를 셋으로 나눈 열거형을 만들었다.

```swift
enum GlossaryExampleState {
    case loading
    case unavailable   // 기기 미지원 또는 생성 실패
    case ready(String)
}
```

`QuestionScreen`은 낱말을 탭하는 순간 `exampleState = .loading`으로 시작해서, `composeExample(...)`의 결과에 따라 `.ready(text)` 또는 `.unavailable`로 바꾼다. `GlossaryPanel`은 `.unavailable`이면 스와이프 안내 자체를 안 보여주고, `.loading`이나 `.ready`면 안내를 보여주다가 펼쳐지면 그 상태에 맞는 내용(로딩 스피너+문구, 또는 실제 예문)을 그린다. 이미 펼친 채로 `.loading`에서 `.ready`로 바뀌어도 — SwiftUI가 상태 변화를 그대로 반영하므로 — 다시 스와이프할 필요 없이 자동으로 갱신된다.

**교훈** — **"값이 없다"는 뜻이 하나가 아닐 수 있다.** `nil`을 "아직 모른다"와 "확인했는데 없다"라는 서로 다른 의미로 같이 쓰면, 그 둘을 다르게 보여줘야 하는 UI를 절대 만들 수 없다. 로딩·완료·실패(또는 불가)처럼 상태가 셋 이상이면, `Optional`을 억지로 겹쳐 쓰지 말고 처음부터 그 상태 수만큼 케이스가 있는 열거형을 쓰는 편이 코드로도, UI로도 더 정직하다.

---

## underlineGap 0이 원하는 자리가 아니었고, 음수를 주니 형광펜이 잘렸다

**Q** — 실기기에서 `underlineGap`을 이것저것 넣어 보니, `-10`을 줘야 정확히 원하는 자리(받침 바로 아래)가 나온다. 그런데 의미상 `0`이 그 자리여야 하지 않나? 그리고 `-10`처럼 크게 음수를 주면 형광펜(노란 배경) 아래쪽이 잘려 나간다 — 밑줄 때문인 것 같은데?

**A** — 두 가지 다 실제 버그였다.

**① 0이 원하는 자리가 아니었던 이유** — 밑줄 Y좌표를 구할 때 쓰는 `NSLayoutManager.boundingRect(forGlyphRange:in:)`는 글자 하나가 아니라 **그 글자가 속한 줄 한 칸 전체**(line fragment)의 사각형을 돌려준다. `KoreanText`는 문단에 `lineSpacing = 8`을 주고 있는데, 이 줄 간격이 각 줄의 line fragment 아래쪽에 포함돼 있어서 `box.maxY`가 실제 글자(받침 포함) 아래쪽보다 이미 8~10pt 더 내려가 있었다. `underlineGap = 0`을 줘도 이 여분 때문에 밑줄이 처져 보였고, `-10`을 줘야 그 여분이 상쇄된 것이다. TextKit은 이 여분을 공개 API로 알려주지 않아서, 실측(0일 때와 -10일 때의 차이)으로 상수를 정했다.

**② 형광펜이 잘린 이유** — `KoreanText.sizeThatFits(...)`가 라벨 전체 높이를 `fitting.height + (underlineGap + 2)`로 계산하고 있었다. `underlineGap`이 `-10`처럼 크게 음수면 이 합이 **자연스러운 글자 높이보다 작아진다.** SwiftUI는 이 값을 그대로 믿고 라벨에 그만큼 작은 자리를 주므로, 그 안에 다 못 들어간 마지막 줄의 형광펜 배경(또는 글자 자체)이 잘려 나간다. 밑줄 간격 조절이 형광펜과 전혀 무관한 값(라벨 전체 높이)에 직접 영향을 준 것이 진짜 원인이었다 — 두 조절이 몰래 얽혀 있었다.

**해결**

```swift
// UnderlineLabel — box.maxY 의 여분을 먼저 빼서 0을 "받침 바로 아래"로 맞춘다
let lineFragmentPadding: CGFloat = 10   // 실측값
let y = originY + box.maxY - lineFragmentPadding + gap

// KoreanText.sizeThatFits — 절대 자연스러운 높이 밑으로는 안 내려가게 막는다
let underlineAllowance = uiView.underlines.isEmpty
    ? 0
    : max(0, uiView.underlineGap - uiView.lineFragmentPadding + uiView.underlineThickness / 2 + 2)
```

이제 `underlineGap = 0`이 기본값이자 원하는 자리이고, 이 값을 얼마로 조절하든(음수 포함) 라벨은 절대 원래 필요한 높이보다 작아지지 않아 형광펜도 글자도 잘리지 않는다.

**교훈** — TextKit의 "박스"(line fragment, bounding rect)는 글자의 시각적 경계가 아니라 **레이아웃이 그 줄에 확보해 둔 자리**다. 문단에 `lineSpacing`처럼 줄과 줄 사이 여백을 주면, 그 여백이 조용히 각 줄의 박스 안에 포함되어 커스텀 드로잉의 기준점을 밀어낸다. 그리고 **한 조절값(`underlineGap`)이 시각 효과 하나만 바꾸는 것처럼 보여도, 그 값이 레이아웃 크기 계산에도 같이 쓰이고 있으면 전혀 다른 요소(형광펜)까지 건드릴 수 있다** — 값 하나가 여러 계산에 재사용될 때는 그 값의 극단(0, 음수, 매우 큰 값)에서 다른 계산이 안전한지 따로 확인해야 한다.

---

## 밑줄 여유를 더했더니 글자가 가운데로 밀렸다 — 위쪽 정렬을 직접 강제해야 했다

**Q** — 바로 위 항목(직접 그리는 밑줄)을 적용한 뒤, 다음 부분을 짚으며 "에러나 재검토"를 요청받았다.

```swift
let box = layoutManager.boundingRect(forGlyphRange: intersection, in: textContainer)
                let y = bounds.origin.y + box.maxY + underlineGap
                let startX = bounds.origin.x + box.minX
                let endX = bounds.origin.x + box.maxX
```

이 세션이 쓰는 `device_bash`는 사용자 맥 위의 **Linux VM**이라 `xcodebuild`가 없다 (`which xcodebuild` 빈 결과, 실행하면 "command not found"). 그래서 Xcode가 실제로 무슨 에러를 냈는지는 확인할 방법이 없었다 — 코드를 직접 추적해서 원인을 찾아야 했다.

**A** — 두 가지를 찾았다.

**① 진짜 문제 — 세로 가운데 정렬과 밑줄 계산이 서로 다른 좌표계를 봤다.** 바로 앞 수정에서 `sizeThatFits`가 `fitting.height + underlineGap + 2`를 돌려주도록 높이를 늘렸다. 그런데 `UILabel`의 기본 `drawText(in:)`는 **rect가 글자에 필요한 실제 높이보다 크면 그 안에서 글자를 세로 가운데 정렬**한다 — 잘 알려진 UIKit 함정이다. 늘어난 만큼 글자가 아래로 밀려 그려지는데, 밑줄 위치를 계산하는 `NSTextContainer(size: bounds.size)`는 이걸 모르고 **항상 위쪽 정렬**을 가정하고 있었다. 글자는 가운데, 밑줄은 위쪽 정렬 기준 — 어긋난다.

**② 확인은 못 했지만 방어적으로 정리한 것 — 클로저 안 `self.` 요구 여부.** `enumerateLineFragments(forGlyphRange:using:)`의 클로저가 escaping인지 non-escaping인지 SDK 문서로 확정하지 못했다. escaping이라면 `bounds`·`underlineGap`처럼 `self`의 프로퍼티를 클로저 안에서 바로 쓸 때 `self.`를 요구했을 수 있다. 답을 모르니, **클로저 밖에서 지역 상수로 미리 꺼내 두는 것**으로 두 경우 모두를 피해 가는 쪽을 택했다.

**해결** — `drawText(in:)`를 다시 썼다. `super.sizeThatFits(...)`로 글자의 진짜 필요 높이(`textHeight`)를 구해, 그 높이만큼만 위쪽에 붙인 `topAlignedRect`를 만들고 `super.drawText(in:)`에도 밑줄 계산용 `NSTextContainer`에도 **같은 이 사각형**을 쓰게 했다. `originX`/`originY`/`gap`/`thickness`는 클로저 앞에서 지역 상수로 뽑아 두고, `boundingRect(forGlyphRange:in:)`에는 바깥 변수 대신 클로저 자신의 `container` 매개변수를 넘겼다.

```swift
let textHeight = super.sizeThatFits(CGSize(width: rect.width, height: .greatestFiniteMagnitude)).height
let topAlignedRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: textHeight)
super.drawText(in: topAlignedRect)
// ... 밑줄 계산용 NSTextContainer(size: topAlignedRect.size) 도 같은 사각형을 쓴다
```

**교훈** — `sizeThatFits`에 여유(padding)를 더할 때는 "그 여유만큼 실제로 그려지는 자리가 어떻게 되는가"까지 같이 봐야 한다. `UILabel`은 rect가 남으면 **말없이 가운데 정렬**해 버리므로, 커스텀 드로잉이 rect를 그대로 믿으면 그 여유가 생긴 순간 어긋난다. 그리고 이 환경에는 컴파일러가 없다는 것 — "에러나 재검토해줘"라는 요청에 정확한 컴파일러 메시지 없이 코드만 손으로 추적해서 답해야 한다는 제약을 앞으로도 기억해 둔다.

---

## 밑줄이 받침과 겹쳐 보인다 — `.underlineStyle`엔 간격을 조절하는 옵션이 없었다

**Q** — O/X 강조 밑줄과 낱말 사전 점선 밑줄이 "국", "정" 같은 받침 있는 글자 아래쪽과 겹쳐 보인다. `.underlineStyle` 속성에 간격을 주는 옵션이 있나?

**A** — **없습니다.** `NSAttributedString`의 `.underlineStyle`은 폰트가 정한 자리에만 그려지고, 그 자리를 얼마나 띄울지는 공개 API로 조절할 수 없습니다. 이 위치는 원래 로마자 기준으로 정해져 있어서, 받침 때문에 아래로 더 내려가는 한글에서는 자주 겹칩니다. `.baselineOffset`으로 글자를 살짝 들어 올려도 밑줄이 그 글자를 따라 같이 움직이므로 둘 사이 간격은 그대로입니다 — 소용이 없습니다.

**해결** — `.underlineStyle`을 아예 버리고 **밑줄을 직접 그렸습니다.** `UILabel`을 상속한 `UnderlineLabel`을 만들어, 글자를 다 그린 뒤(`drawText(in:)`) `NSLayoutManager`로 각 강조 구간의 실제 사각형을 다시 계산하고, 그 사각형 아래에 원하는 만큼(`underlineGap`, 기본 4pt) 띄운 자리에 `CGContext`로 선을 직접 긋습니다.

```swift
let box = layoutManager.boundingRect(forGlyphRange: intersection, in: textContainer)
let y = bounds.origin.y + box.maxY + underlineGap   // "글자 아래 + 간격" 을 직접 계산
context.move(to: CGPoint(x: startX, y: y))
context.addLine(to: CGPoint(x: endX, y: y))
context.strokePath()
```

점선(사전)은 `context.setLineDash(phase:lengths:)`로, 실선(O/X 강조)은 `setLineWidth`만 다르게 줘서 구분합니다. 탭 판정(`Coordinator.glossaryHits`)은 전혀 안 건드렸습니다 — 어느 글자 범위가 눌렸는지 찾는 것과, 그 범위에 밑줄을 어떻게 그리는지는 서로 다른 일이었습니다.

**교훈** — 텍스트 렌더링에서 "그 속성엔 여백/간격 옵션이 없다"는 답이 나오면, 값을 조합해서 억지로 흉내 내려 하기보다(`baselineOffset`처럼 결과적으로 같이 움직여 버리는 값들) **아예 그 속성을 안 쓰고 직접 계산해서 그리는 편이 오히려 더 간단하고 확실합니다.** 이미 탭 판정용으로 `NSLayoutManager`를 다루고 있었던 것도 그 결정을 쉽게 만들었습니다 — 필요한 도구가 이미 코드 안에 있었습니다.

---

## 뒤 배경을 탭 가능하게 바꿨더니, 열린 시트에서 다른 낱말을 또 탭하면 시트가 커진다

**Q** — 낱말 사전 시트가 작게 떠 있는 상태에서, 뒤에 있는 **다른** 낱말을 또 탭하면 시트가 갑자기 아주 크게 펼쳐진다. 4-A로 고친 "처음 탭할 때만 크게 뜨는" 버그가 다시 생긴 건가?

**A** — 네, **같은 종류의 버그가 새 경로로 다시 생긴 것**입니다. 바로 전에 뒤 배경 어둡기를 껐죠(`.presentationBackgroundInteraction(.enabled)`) — 그 덕에 시트가 열려 있어도 뒤의 다른 낱말을 탭할 수 있게 됐는데, 그게 4-A가 막았던 것과는 **다른 통로로** 같은 증상을 다시 열었습니다.

`GlossarySelection`의 `id`를 탭마다 새로 만드는 `UUID()`로 두고 있었습니다.

```swift
private struct GlossarySelection: Identifiable {
    let id = UUID()   // 탭할 때마다 다른 값
    ...
}
```

시트가 **이미 열려 있는 채로** 다른 낱말을 탭하면, `glossarySelection`이 값 A에서 값 B로 바뀌는데 **`id`도 같이 바뀝니다.** `.sheet(item:)`은 열려 있는 동안 `id`가 바뀌면 "다른 항목이 떴다"고 보고 **지금 시트를 닫고 새 시트를 다시 엽니다.** 그 "다시 여는" 순간이 하필 4-A에서 고쳤던 것과 똑같은 조건(막 만들어지는 시트라 `.presentationDetents` 계산이 아직 안 된 상태)이라, 또 크게 뜹니다.

**해결** — `id`를 낱말마다 다르게 둘 이유가 애초에 없었습니다. 이 화면엔 "낱말 사전 시트" 자리가 **하나**뿐이고, 어떤 낱말을 보여주는지는 내용일 뿐 시트의 정체성이 아닙니다. `id`를 고정값으로 바꿨습니다.

```swift
private struct GlossarySelection: Identifiable {
    let id = "glossary"   // 낱말이 바뀌어도 항상 같다
    ...
}
```

이제 시트가 열려 있는 동안 다른 낱말을 탭하면 `id`가 그대로라 SwiftUI가 "같은 시트의 내용만 바뀌었다"로 보고, **닫았다 다시 열지 않고 그 자리에서 내용만 바꿉니다.** 크기도 그대로 유지됩니다.

**교훈** — `.sheet(item:)`으로 고칠 때 `id`를 정하는 기준은 "이 값이 유니크한가"가 아니라 **"이게 정말 다른 시트인가, 같은 시트의 다른 내용인가"** 입니다. 오답 해설 시트(`IncorrectCommentary`)는 "문항이 다르면 다른 시트"라 문항 id를 썼고, 낱말 사전 시트는 "낱말이 달라도 같은 시트"라 고정값을 씁니다. 같은 `.sheet(item:)` 패턴이라도 두 타입의 정답이 다릅니다.

---

## 시트 뒤 배경이 어두워지는 걸 "조금만" 줄일 수 있나 — 끄거나 켜거나, 둘 중 하나뿐이었다

**Q** — 낱말 사전 시트를 열면 뒤(문제 지문)가 어두워진다. 안 어둡게 하거나, 어둡기를 살짝만 줄일 수 있나?

**A** — **끄는 것은 공식 기능으로 됩니다. "살짝만 줄이는" 것은 공개 API가 없습니다.**

`.presentationBackgroundInteraction(.enabled)`를 붙이면 뒤가 안 어두워집니다. 다만 iOS는 이걸 "안 어둡게"와 "뒤도 탭 가능"을 **한 세트로만** 제공합니다 — 어둡게 가리는 것과 탭을 막는 것이 사실 같은 장치(뒤를 상호작용 못 하게 덮는 오버레이)이기 때문입니다. 애플 지도 앱에서 시트가 떠 있어도 지도를 계속 만질 수 있는 것과 같은 기능입니다.

```swift
.presentationBackgroundInteraction(.enabled)              // 완전히 안 어둡게 (+ 뒤도 탭 가능)
.presentationBackgroundInteraction(.enabled(upThrough: .height(180)))  // 작은 높이일 때만 안 어둡게
```

어둡기를 "50%만" 같은 식으로 숫자로 조절하는 공개 API는 없습니다. 되게 하려면 iOS가 내부적으로 그리는 어둠 레이어를 뷰 계층에서 몰래 찾아 알파값을 직접 바꾸는 식(비공식 방법)뿐인데, 다음 iOS 업데이트에 조용히 깨질 수 있어 쓰지 않았습니다.

**낱말 사전 시트에는 `.presentationBackgroundInteraction(.enabled)`(완전히 안 어둡게)를 적용했습니다.** 문제 지문을 계속 보면서 뜻만 확인하는 용도라, 뒤가 밝게 보이고 계속 탭도 되는 쪽이 이 화면의 목적에 맞습니다.

**(11차 갱신)** 오답 해설 시트(`FeedbackSheet`)도 이후 같은 처리를 받았습니다 — `.presentationBackgroundInteraction(.enabled)`가 걸려 뒤가 밝고 탭도 됩니다. 처음엔 "정답을 다 보기 전엔 못 넘어가게" 하려고 일부러 건드리지 않았던 화면인데, 이후 요청으로 정책이 바뀌어 두 시트 모두 뒤가 밝고 탭되는 쪽으로 확정됐습니다. `.interactiveDismissDisabled()`는 그대로 남아 있어 스와이프로 시트를 닫는 것만 막혀 있습니다.

**교훈** — iOS의 프레젠테이션 관련 API는 종종 "이것 아니면 저것"으로만 묶여 나옵니다. 세밀한 조절이 필요하면 먼저 공식 API가 그 세밀함을 제공하는지 확인하고, 없으면 "왜 없는지"(여기서는 어둠 = 상호작용 차단이라는 하나의 장치)를 먼저 이해한 뒤 대안을 고르는 편이, 비공식 방법을 시도하는 것보다 안전합니다.

---

## 리퀴드 글라스가 가독성이 떨어져 다시 흰 배경으로 — 그런데 유리 느낌은 그대로 남았다

**Q** — 낱말 사전·오답 해설 두 시트를 유리처럼 비치게 만들었는데, 막상 보니 가독성이 떨어진다. 다시 흰 배경으로 돌리면 리퀴드 글라스 자체를 포기하는 건가?

**A** — 아닙니다. **"시트 안 내용이 비치는 것"과 "시트 자체가 유리 재질로 떠 있는 것"은 다른 두 가지입니다.**

| | 무엇이 결정하나 | 오늘 상태 |
|---|---|---|
| 시트의 겉모습(모서리 둥글기·떠 있는 느낌·손잡이 뒤 재질) | `.presentationBackground`를 **안 쓰는가** | 계속 안 씀 → iOS 26에서 계속 Liquid Glass |
| 시트 **안** 내용이 비치는가 | 내용 뷰에 **불투명한 배경을 얹는가** | 오늘부터 다시 흰 배경 → 안 비침 |

`.presentationBackground(...)`를 안 쓰는 것은 겉모습(시스템이 그리는 부분)에만 영향을 줍니다. 내용 뷰(`GlossaryPanel`·`FeedbackSheet`) 안에 `.background(Color.white)`를 얹는 건 **완전히 다른 레이어** — 내용 자신의 배경일 뿐이라, 겉모습의 유리 효과와 서로 간섭하지 않습니다. 그래서 안을 다시 흰색으로 칠해도 시트 자체는 여전히 Liquid Glass로 뜹니다.

**같이 되돌린 것** — 안이 다시 항상 흰색(라이트/다크 상관없이 고정)이 됐으므로, 그 위 글자도 다시 **항상 검정**(`.foregroundStyle(.black)`)으로 되돌렸습니다. 지난번에 배경을 비치게 하면서 글자를 `.primary`(다크 모드에서 흰색에 가까워짐)로 바꿨는데, 배경이 다시 고정된 흰색으로 돌아갔으니 글자도 같이 되돌리지 않으면 다크 모드에서 흰 배경에 흰 글자가 됩니다.

**교훈** — 시트의 "겉"과 "안"은 서로 다른 스위치입니다. 유리 느낌이 부담스러우면 안(내용의 배경)만 다시 칠하면 되고, 겉모습(iOS가 자동으로 주는 떠 있는 모양)까지 포기할 필요는 없습니다. 반대로 배경 하나를 바꿀 때는 그 위에 얹힌 글자색이 **그 배경이 항상 같은 색인지, 시스템을 따라 바뀌는지**와 짝이 맞는지 매번 같이 확인해야 합니다.

---

## 같은 버그가 다른 모달에도 있었다 — `IncorrectCommentary`에 `id`를 주고 `.sheet(item:)`으로

**Q** — 낱말 사전 시트를 `.sheet(item:)`으로 고친 뒤, 오답 해설 모달(`FeedbackSheet`)도 `QuizView.swift`에서 같은 모양(`isPresented: Binding(get: { session?.feedback != nil }, ...)` + 내용은 `session.feedback`을 따로 읽음)으로 열고 있는 걸 봤다. 이것도 같은 버그일까?

**A** — 네, **구조가 완전히 같아서 같은 이유로 처음 한 번은 크게 뜰 수 있습니다.** 다만 여기는 낱말 사전보다 사정이 하나 더 있었습니다 — `feedback`은 **한 번 열린 뒤에도 값이 다시 채워집니다.** 오답 창은 두 박자로 뜹니다: ① "잠시만 같이 살펴봐요"(기다리는 자리) → ② 실제 해설이 도착하면 같은 `feedback`을 새 값으로 덮어씁니다. 시트를 열어 둔 채로요.

`.sheet(item:)`은 **바인딩한 값의 `id`가 바뀌면 그 자체를 "새 항목이 떴다"로 보고 시트를 닫았다 다시 엽니다.** `IncorrectCommentary`를 그냥 `Identifiable`로만 만들고 `id`를 매번 새 `UUID()`로 두면, ①에서 ②로 넘어가는 순간 `id`가 바뀌어 시트가 깜빡이며 다시 열리는 **새 버그**가 생깁니다.

**해결** — `id`를 "이 오답이 몇 번 문항 때문인가"로 고정했습니다. 같은 문항의 ①·②는 같은 `id`를 갖고, 다음 문항의 오답은 다른 `id`를 갖습니다.

```swift
struct IncorrectCommentary: Identifiable {
    let id: Int   // 문항 id. 기다리는 자리 → 도착한 해설로 값이 바뀌어도 같은 문항이면 그대로.
    let selectedAnswer: String
    // ...
}

// 두 생성 자리 모두
feedback = IncorrectCommentary(id: item.id, selectedAnswer: answer, ...)
```

**교훈** — `.sheet(item:)`으로 고칠 때 **"이 타입에 `id`만 하나 붙이면 끝"이 아닙니다.** 값이 한 번 뜬 뒤에도 갱신되는 타입이라면, **그 `id`가 "같은 화면인가"를 뜻하는 값이어야** 합니다. `UUID()`처럼 만들 때마다 새로 나오는 값을 무심코 쓰면, 처음 뜰 때 크게 뜨던 버그는 없어져도 "내용이 갱신될 때마다 시트가 깜빡인다"는 새 버그가 대신 생깁니다.

**참고 문서** — [SwiftUI `sheet(item:onDismiss:content:)`](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:))

---

## 오답 해설 모달을 유리로 바꾸니 검정 글씨가 다크 모드에서 안 보일 뻔했다

**Q** — 오답 해설 모달(`FeedbackSheet`)도 낱말 사전처럼 리퀴드 글라스로 보이게 해 달라고 했다. 그런데 이 모달은 `.background(Color.white)`로 안을 흰색으로 칠하고, 글자도 `.foregroundStyle(.black)`로 검정을 못박아 두고 있었다. 그냥 배경만 지우면 되나?

**A** — 배경만 지우면 **다크 모드에서 검정 글씨가 안 보일 뻔했습니다.** `.background(Color.white)`는 우연히 배경색이었을 뿐 아니라, 하드코딩된 `.black` 글씨가 항상 읽히게 보장해 주던 바닥이었습니다. 이 앱은 `.preferredColorScheme`로 라이트 모드를 강제하지 않으므로, 기기가 다크 모드면 유리(Liquid Glass) 배경이 어둡게 비칠 수 있고, 그 위에 고정된 검정 글씨를 얹으면 대비가 사라집니다.

**해결** — 배경은 지우고(유리가 비치게), 글자는 `.black` 대신 **시스템이 다크/라이트에 맞춰 자동으로 바꿔 주는 `.primary`** 로 바꿨습니다.

```swift
// ❌ 배경만 지우면 다크 모드에서 위험
.foregroundStyle(.black)     // 라이트에서만 안전

// ✅ 시스템이 알아서 바꿔 준다
.foregroundStyle(.primary)   // 라이트: 검정에 가까움 · 다크: 흰색에 가까움
```

`오답 해설` 제목과 `BodyStyle`(고른 답 설명·해설 본문이 같이 쓰는 글꼴)의 `.black`을 모두 `.primary`로 바꿨습니다. **`AppColor.wrongAccent`·`AppColor.answerAccent` 같은 강조색은 그대로 뒀습니다** — 이 색들은 원래도 흰색이 아니라 진한 보라·파랑·빨강 계열이라 배경이 유리로 바뀌어도 대비가 크게 흔들리지 않고, 문항 카드(`chosenBlock`·`answerBlock`)는 각자 옅은 색 배경(`AppColor.wrongBackground`·`answerBackground`)을 여전히 깔고 있어 그 안의 글자는 영향이 없습니다.

**교훈** — "배경을 지워서 유리처럼 보이게 한다"는 요청은 필연적으로 **"그 위에 얹힌 고정색 글자도 같이 봐야 한다"는 요청을 숨기고 있습니다.** `AppColor`처럼 앱 전체가 라이트 모드 전제로 색을 하드코딩해 둔 곳에서는, 배경 하나만 유리로 바꿔도 그 위 글자의 가정("배경은 항상 밝다")이 깨질 수 있습니다.

---

## 낱말 밑에 점선이 하나도 안 보인다 — `NSUnderlineStyle` 패턴은 혼자 못 그린다

**Q** — `KoreanText` 에 낱말 사전 밑줄을 넣었는데, 실기기에서 보니 국기 등 어떤 낱말에도 점선이 안 보인다. `.underlineStyle: NSUnderlineStyle.patternDot.rawValue` 를 분명히 넣었는데 왜 안 그려지나?

**A** — `NSUnderlineStyle` 은 `OptionSet` 이고, **패턴 계열(`.patternDot`, `.patternDash` 등)은 기반이 되는 선 스타일과 겹쳐 써야만 그려집니다.** 패턴만 주면 "어떤 무늬로 그릴지"는 정해지는데 "선을 긋는다" 자체가 빠져서 아무것도 안 나옵니다.

```swift
// ❌ 아무것도 안 그려진다 — 패턴만 있고 기반 선이 없다
.underlineStyle: NSUnderlineStyle.patternDot.rawValue,

// ✅ .single(기반 선) 과 .patternDot(무늬)를 OR 로 합친다
.underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
```

`NSUnderlineStyle` 문서를 보면 `.single`·`.thick`·`.double` 은 **두께(기반 선)**를, `.patternDot`·`.patternDash`·`.patternDashDot`·`.patternDashDotDot` 은 **무늬**를 나타내는 서로 다른 비트입니다. 무늬 비트만 켜고 기반 선 비트를 안 켜면 "무늬는 정했지만 선을 그리라는 지시가 없는" 상태가 됩니다.

같은 파일에 이미 참고할 예시가 있었습니다 — 형광펜 밑줄은 `.underlineStyle: NSUnderlineStyle.thick.rawValue` 하나만으로 잘 그려지고 있었는데, `.thick` 은 패턴이 아니라 **그 자체로 기반 선**이라 혼자서도 됩니다. 패턴 계열에만 이 규칙이 붙습니다.

**교훈** — 이 버그는 코드를 처음 작성할 때부터 들어가 있던 것으로, 사용자의 실수가 아니었습니다. `OptionSet` 으로 된 스타일 값은 "이 값 하나로 충분한가, 다른 비트와 짝을 지어야 하는가"를 문서에서 먼저 확인합니다. 특히 "패턴"·"무늬"처럼 **모양만 표현하는 이름**이 붙은 케이스는 대개 기반 값과 따로 있습니다.

**참고 문서** — [NSUnderlineStyle](https://developer.apple.com/documentation/uikit/nsunderlinestyle)

---

## 계획에 `item.glossary` 를 쓰라고 적었는데 사실 그런 프로퍼티가 없었다 — 모델 배선이 빠진 채로 화면 코드부터 나갔다

**Q** — `QuestionScreen.swift` 에 `KoreanText(..., glossary: item.glossary, ...)` 를 그대로 입력했는데 값이 하나도 안 들어온다(밑줄이 안 생긴다). `item` 은 `QuizItem` 인데, `glossary` 라는 프로퍼티가 원래 있었나?

**A** — 없었습니다. **1단계(데이터)와 2·4단계(탭 감지·화면 연결)를 계획할 때, 그 둘을 잇는 자리 — `Question`과 `QuizItem`에 `glossary` 필드를 추가하는 것 — 를 계획 문서에 아예 넣지 않았습니다.** `questions.json` 에 `glossary` 배열을 채워 놓고도, 그 값을 Swift 타입으로 읽어 들이는 코드가 없었던 것입니다.

`Question.swift` 는 수동으로 짠 `init(from decoder:)` 를 쓰는데, 이 디코더는 **JSON에 모르는 키가 있어도 조용히 무시합니다** — 그래서 컴파일도 되고 앱도 켜지지만, `glossary` 값은 어디에도 담기지 않고 사라졌습니다.

**고친 방법** — 계획 문서에 「1-A. 빠졌던 자리」를 별도 절로 추가하고, 셋을 채웠습니다.

```swift
// Question.swift 에 추가
struct GlossaryEntry: Codable, Hashable {
    let word: String
    let gloss: String
    var examples: [String] = []
}
// Question 에 저장 프로퍼티 + 디코더 한 줄
glossary = try box.decodeIfPresent([GlossaryEntry].self, forKey: .glossary) ?? []

// QuizItem.swift 에 추가 — KoreanText 가 기대하는 튜플 모양으로 미리 바꿔 둔다
var glossary: [(word: String, gloss: String, examples: [String])] {
    question.glossary.map { (word: $0.word, gloss: $0.gloss, examples: $0.examples) }
}
```

**비슷한 시기에 같이 걸린 것** — `QuestionScreen.swift` 에 모달 코드를 새로 얹으면서, 옛 버전의 `content(for:)` 함수를 지우지 않고 새 버전만 추가해 "Invalid redeclaration of 'content(for:)'" 오류가 났습니다. 계획을 여러 번 고치는 동안 **바뀐 함수는 통째로 새로 쓰고, 옛 버전이 파일에 그대로 남아 있는지는 따로 확인**해야 했습니다.

**교훈** — 데이터 계층(모델)과 화면 계층(뷰)을 각각 계획하면, **그 둘을 잇는 배선 자체가 하나의 단계라는 걸 잊기 쉽습니다.** "데이터를 추가했다" + "화면에서 쓴다"만 있고 "그 사이에 타입을 연결한다"가 빠지면, 화면 코드는 그럴듯해 보여도 실제로는 존재하지 않는 프로퍼티를 참조하게 됩니다. 계획 단계에서 **"이 값이 JSON → 어떤 타입 → 어떤 프로퍼티를 거쳐 화면까지 오는가"**를 한 줄로 추적해 보면 이런 빈 자리가 미리 보입니다.

---

## iOS 기본 시트를 그냥 띄웠는데 왜 벌써 리퀴드 글라스 모양으로 보이나 — `presentationBackground` 를 안 쓰는 게 핵심이었다

**Q** — 낱말 사전 모달을 직접 만든 하단 패널 대신 iOS 기본 `.sheet` 로 바꾸기로 했다. **iOS 26의 리퀴드 글라스 디자인**을 적용해 달라는 요청까지 있었는데, 무슨 코드를 더 넣어야 그 디자인이 나오나?

**A** — **따로 넣을 코드가 없었습니다.** `.sheet` 를 `.presentationDetents` 와 함께 띄우면, iOS 26에서는 **그 자체로 리퀴드 글라스(떠 있는 느낌의 둥근 모서리) 모양이 자동으로 적용**됩니다.

```swift
.sheet(isPresented: $isGlossaryPresented, onDismiss: closeGlossary) {
    if let g = openGlossary {
        GlossaryPanel(word: g.word, gloss: g.gloss, ...)
    }
}

// GlossaryPanel.swift 안에서
.presentationDetents([.height(180), .medium])
.presentationDragIndicator(.visible)
```

**주의할 것은 오히려 "하지 말아야 할 것" 쪽입니다.** `.presentationBackground(...)` 로 배경을 직접 지정하면 **이 자동 효과가 꺼집니다.** 커스텀 배경색이나 재질을 넣고 싶은 유혹이 들 수 있지만, 그러면 iOS가 대신 그려 주는 리퀴드 글라스를 스스로 지우는 셈이 됩니다. 그래서 `GlossaryPanel` 에는 배경 관련 모디파이어를 아예 넣지 않았습니다.

구형 iOS(26 미만)에서는 같은 코드가 그냥 평범한 시트로 보입니다 — 버전 분기를 직접 짤 필요가 없습니다.

이 방식으로 바꾸면서 **직접 만들었던 것들이 전부 필요 없어졌습니다** — 드래그 손잡이(`.presentationDragIndicator` 가 대신 그림), 펼침/접힘 상태(`@State isExpanded` 통째로 삭제), 바깥을 탭하면 닫히는 투명 레이어(`Color.black.opacity(0.001)` 로 만들었던 탭 캐처 삭제), 닫는 애니메이션. **iOS 기본 컴포넌트를 쓰는 이유가 "디자인을 대신 해줘서"만이 아니라 "직접 짠 상태 관리 코드 자체가 사라져서"** 라는 걸 이번에 확인했습니다.

**교훈** — 새 OS 버전의 디자인 시스템(여기서는 Liquid Glass)은 대개 **커스텀 모디파이어를 추가해서 켜는 게 아니라, 커스텀 모디파이어를 안 넣어야 자동으로 켜지는 쪽**입니다. 공식 문서에서 "이 효과를 끄려면"이라고 적힌 부분을 뒤집어 읽으면 "기본값이 이미 새 디자인"이라는 뜻입니다.

**참고 문서** — [Presenting Liquid Glass Sheets in SwiftUI on iOS 26](https://nilcoalescing.com/blog/Presenting-Liquid-Glass-Sheets-in-SwiftUI-on-iOS-26/) (iOS 26 출시 시점 자료)

---

## `init(from:)` 을 적었더니 `Question(id:...)` 가 사라졌다 — 그리고 `.category` 는 어디서 왔나

**Q** — `init(from decoder: Decoder)` 라는 초기화가 낯설다. ① 구조체는 원래 프로퍼티를 바로 채워서 만드는데, 저걸 적으면 인스턴스는 어떻게 만드나? ② `decoder.container(keyedBy:)` 한 줄은 무슨 뜻인가? ③ `forKey: .category` 의 `.category` 는 선언한 적이 없는데 어떻게 쓸 수 있나?

**A**

### ① `init(from:)` 도 그냥 생성자다 — 그리고 멤버와이즈를 지운다

특별한 문법이 아니라 **매개변수가 `Decoder` 하나인 보통 생성자**입니다. 하는 일도 같습니다 — 모든 저장 프로퍼티에 값을 하나씩 채웁니다. 값을 부르는 쪽에서 받느냐, `decoder` 에게 물어서 꺼내느냐만 다릅니다.

```swift
protocol Decodable {
    init(from decoder: Decoder) throws   // 요구사항은 이것 하나뿐
}
```

`JSONDecoder().decode(Question.self, from: data)` 는 결국 이 생성자를 부르는 것입니다. 지금까지는 Swift 가 자동으로 써 주고 있었고, 우리가 손으로 적어 덮어썼습니다.

**여기서 함정** — 구조체는 **`struct` 본문 안에** 생성자를 하나라도 직접 적으면 **자동 멤버와이즈 생성자가 사라집니다.** `init(from:)` 도 본문 안이라 마찬가지입니다.

```swift
Question(id: 1, answer: "고조선")   // ❌ 컴파일 에러 — 그런 생성자 없음
```

**해결은 `extension`** 입니다. 확장 안의 생성자는 멤버와이즈를 지우지 않습니다.

```swift
extension Question {
    init(id: Int, category: String, /* ... */ tags: [String] = [], facts: [QuestionFact] = []) {
        self.id = id
        // ...
    }
}
```

`Question` 은 지금 손으로 만드는 곳이 없어(전부 JSON) 안 적어도 됩니다. **미리보기나 테스트에서 가짜 문항이 필요해지는 순간 걸립니다.** 그때 위처럼 확장에 넣습니다.

> `QuestionFact` · `GlossaryEntry` 는 손으로 만들 일이 있어 `init(kind:weight:text:)` 를 본문에 같이 적어 두었습니다.

### ② `container(keyedBy:)` — decoder 는 아직 모양이 없다

JSON 은 세 가지 모양 중 하나입니다.

```
{ "id": 1 }              열쇠가 있는 상자   → decoder.container(keyedBy:)
[ "고구려", "백제" ]      순서만 있는 상자   → decoder.unkeyedContainer()
"고조선"                  값 하나           → decoder.singleValueContainer()
```

그 한 줄은 **「이건 열쇠 있는 상자로 열어라, 열쇠 목록은 `CodingKeys` 다」** 라는 뜻입니다. 돌려받은 `box` 는 그 열쇠로만 열 수 있는 상자입니다. `try` 가 붙는 이유 — JSON 이 배열이었으면 열쇠 상자로 못 열어 여기서 던집니다.

### ③ `.category` 는 Swift 가 만들어 준 열거형이다

`Codable` 을 채택하는 순간 컴파일러가 **저장 프로퍼티 이름 그대로** 이것을 몰래 써넣습니다.

```swift
enum CodingKeys: String, CodingKey {
    case id, category, unit, question, answer, statementFormat, kind, difficulty, tags, facts
}
```

`forKey:` 의 타입이 `CodingKeys` 라 점만 찍으면 되고(타입 추론), `rawValue` 인 `"category"` 가 JSON 의 키가 됩니다.

**이 방식의 값어치는 오타가 컴파일에서 잡힌다는 것입니다.** `forKey: .tag` 라고 쓰면 그 자리에서 에러가 납니다. 문자열 `"category"` 를 직접 썼다면 런타임까지 살아남습니다.

`CodingKeys` 를 **손으로 적는 유일한 이유**는 JSON 키와 Swift 이름이 다를 때입니다.

```swift
case statementFormat = "statement_format"
```

우리 JSON 은 camelCase 라 손댈 이유가 없어, 자동 생성된 것을 그대로 쓰고 있습니다.

**교훈 셋**

- **`init(from:)` 이든 `encode(to:)` 든, 본문에 하나 적으면 자동으로 받던 것이 같이 멈춥니다.** 멤버와이즈 생성자가 그렇고, 예전 ``ObsUploader`` 때는 `CodingKeys` 자동 생성이 그랬습니다. **손으로 한 곳을 적으면 그 옆에 무엇이 사라졌는지 확인합니다**
- **자동 생성을 덮어쓰는 코드는 확장으로 뺄 수 있으면 뺍니다.** 본문은 「무엇을 담는가」, 확장은 「어떻게 만들고 읽는가」로 나뉘면 사라지는 것도 줄어듭니다
- **JSON 키를 문자열로 쓰지 않습니다.** `CodingKeys` 를 거치면 오타가 컴파일에서 걸리고, 키 이름을 바꿀 때 고칠 곳이 한 군데입니다

**참고 문서** — [Encoding and Decoding Custom Types](https://developer.apple.com/documentation/foundation/archives-and-serialization/encoding-and-decoding-custom-types) · [KeyedDecodingContainer](https://developer.apple.com/documentation/swift/keyeddecodingcontainer)

---

## `= []` 기본값을 적었는데 「기본 문제집을 읽지 못했습니다」로 앱이 안 켜진다

**Q** — `Question` 에 `var tags: [String] = []` 와 `var facts: [QuestionFact] = []` 를 더했다. 기본값을 적었으니 `questions.json` 에 그 칸이 없어도 될 줄 알았는데, 앱을 실행하면 `QuestionCatalog.loaded()` 의 `assertionFailure("기본 문제집을 읽지 못했습니다: ...")` 에서 멈춘다.

**A** — 파일을 못 찾은 것이 아니라 **해독(decode)에서 던졌습니다.**

**Swift 가 자동으로 만들어 주는 `Codable` 은 프로퍼티의 기본값을 쓰지 않습니다.** 자동 생성되는 해독 코드는 이렇게 생겼습니다.

```swift
self.tags = try container.decode([String].self, forKey: .tags)   // 없으면 throw
```

`decodeIfPresent` 가 아니라 `decode` 입니다. 그래서 **키가 없으면 `keyNotFound` 를 던집니다.** `= []` 는 `Question(id:...)` 처럼 **손으로 만들 때만** 쓰이는 값입니다.

`questions.json` 의 25문항에는 `tags` 도 `facts` 도 없으니 1번 문항에서 바로 멈췄습니다.

**같은 함정이 두 군데 더 있었다** — `QuestionFact.weight` (`= 1`), `GlossaryEntry.examples` (`= []`). 사전 쪽은 `assertionFailure` 가 없어 **소리 없이 빈 사전**이 됩니다. `glossary.json` 의 「시조·도읍·건국이념·신화」 네 낱말에 `examples` 가 없어 이미 그 상태였습니다.

**해결** — JSON 25문항에 빈 칸을 다 적는 길도 있었지만, 6차의 전제가 「서버가 문항을 늘린다」인데 **서버가 보낸 옛 파일에 새 칸이 없다고 앱이 안 켜지면** 그 전제가 무너집니다. 해독기를 손으로 적었습니다.

```swift
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        // ... 원래 있던 칸은 decode
        tags  = try box.decodeIfPresent([String].self,       forKey: .tags)  ?? []
        facts = try box.decodeIfPresent([QuestionFact].self, forKey: .facts) ?? []
    }
```

`init(from:)` 을 손으로 쓰면 **Swift 가 더 이상 자동으로 만들어 주지 않습니다.** `encode(to:)` 를 손으로 썼을 때 `CodingKeys` 를 같이 적어야 했던 것과 같은 이유입니다.

**AI 가 틀렸던 것** — 6차 계획 1단계에 「`tags`·`facts` 는 **기본값이 필요하다**. 없으면 해독이 깨진다」고 적어 두었습니다. **정확히 반대**입니다. 기본값은 해독을 구해 주지 않고, 필요한 것은 `decodeIfPresent` 입니다. 계획에 적힌 근거는 코드로 확인되기 전까지 가설입니다.

**교훈 셋**

- **`Codable` 구조체에 칸을 더할 때 `= 기본값` 만으로 끝내지 않습니다.** 파일에 그 칸이 없을 수 있으면 `decodeIfPresent` 를 쓰는 해독기가 같이 있어야 합니다
- **인코딩과 디코딩이 대칭이 아닙니다.** 내보낼 때 `Optional` 은 **키가 사라지고**(`encodeIfPresent`), 읽을 때 기본값은 **쓰이지 않습니다**(`decode`). 둘 다 Swift 의 좋은 기본값이지만, 둘 다 **파일이 우리 것이 아닐 때** 어긋납니다
- **`assertionFailure` 가 있는 쪽은 즉시 알려 주고, 없는 쪽은 조용히 비어 갑니다.** 사전이 빈 것을 이번에 문제집 덕분에 같이 찾았습니다. **읽는 길이 하나면 함정도 하나뿐이지만, 실패 신호는 길마다 따로 필요합니다**

**참고 문서** — [Encoding and Decoding Custom Types](https://developer.apple.com/documentation/foundation/archives-and-serialization/encoding-and-decoding-custom-types)

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

