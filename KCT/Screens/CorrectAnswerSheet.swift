//
//  CorrectAnswerSheet.swift
//  KCT
//
//  역할 : 맞혔을 때 올라와 축하하고, 원하면 정답을 한 번 더 설명해 주는 모달
//  요점 : 처음엔 접힌 채로 "잘 맞추셨어요!" + 버튼 두 개만 보여준다. 해설은 이 창이
//        뜨는 순간부터 뒤에서 이미 만들어지고 있으니, "정답 해설 보기"를 눌렀을 때
//        이미 다 와 있으면 **로딩 없이 곧장** 그 높이로 펼쳐지고, 아직이면 버튼이
//        도는 인디케이터로 바뀌었다가 해설이 도착하는 순간 **딱 한 번에** 그 높이로
//        펼쳐진다(14차 후속). 어느 쪽이든 .medium 같은 중간 크기를 거쳤다가 다시
//        줄어드는 두 번 움직임은 없다 — 그게 "갑자기 확 접힌다"는 어색함의 원인이었다.
//
//  ── 구성 ──────────────────────────────────────────────
//  CorrectAnswerSheet
//  ├─ feedback              정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext                「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ startsExpanded        미리보기 전용 — 처음부터 펼친 채로 띄운다
//  ├─ isExpanded            해설을 펼쳤는가 — collapsedContent / expandedContent 를 가른다
//  ├─ hasRequestedReveal    「정답 해설 보기」를 눌렀는가 (한 번 켜지면 계속 켜져 있다)
//  ├─ isLoadingCommentary   지금 로딩 인디케이터를 보여줄지 — hasRequestedReveal &&
//  │                        !feedback.isReady 로 그때그때 계산한다
//  ├─ selectedDetent        지금 시트 크기. 접힘(collapsedHeight) ↔ 펼침(expandedDetent)
//  ├─ expandedHeight        해설 내용에 딱 맞춘 높이 — **누르기 전부터** 계속 캐시된다
//  ├─ appliedHeight         시트를 실제로 옮긴 적 있는 높이 — 같은 높이로 또
//  │                        애니메이션을 걸지 않도록 막는 용도
//  ├─ expandedDetent        펼침 시트가 쓸 크기. 못 쟀으면 .medium(사실상 안 쓰인다),
//  │                        쟀으면 그 높이
//  ├─ isPulsing             기다리는 동안 맥동시키는 깃발
//  ├─ collapsedContent      "잘 맞추셨어요!" + 「정답 해설 보기」(로딩 중엔 인디케이터)·
//  │                        「다음 문제」 두 버튼
//  ├─ reveal()              이미 준비돼 있으면 곧장 펴고, 아니면 hasRequestedReveal 만 켠다
//  ├─ expandedInnerContent  제목("정답 해설") + notesCard. **펼친 화면과 숨은 측정
//  │                        사본이 똑같이 이 뷰를 쓴다** — 잰 높이와 실제 높이가
//  │                        어긋나지 않도록
//  ├─ backgroundMeasurement 접힌 동안(눌리기 전부터) 화면 밖(숨김)으로 계속 그려 두는
//  │                        expandedInnerContent 사본 — 해설 도착과 무관하게 미리 잰다
//  ├─ expandedContent       expandedInnerContent + 「다음 문제」, 실제로 펼쳐 보여준다
//  ├─ updateExpandedHeight  잰 내용 높이 + 여백을 더해 expandedHeight 를 항상 캐시하고,
//  │                        hasRequestedReveal 이 켜져 있을 때만 selectedDetent 도
//  │                        바꾼다 — backgroundMeasurement · expandedContent 양쪽에서
//  │                        다 부른다
//  ├─ notesCard             체크 아이콘 + 정답 낱말 + 해설을 감싸는 흰 카드
//  └─ commentary            기다릴 때와 도착한 뒤가 서로 다른 뷰(해설이 끝내 실패하면
//                           ``CommentaryPlaceholder/failed`` 문구가 이 자리에 그대로 온다)
//
//  카드·배경·시트 외장은 DesignSystem/CommentarySheet.swift 의 부품을 그대로
//  쓴다 — **오답 해설 창(FeedbackSheet)이 같은 부품을 쓴다.** 다만 정답 줄
//  하나만 보여주는 이 카드는 CommentaryRow(이모지+배지)가 아니라 체크 아이콘 +
//  배경 없는 굵은 글자를 직접 그린다(11차 후속) — 비교할 오답이 없는 이 창에서는
//  "배지"보다 "확정된 사실"처럼 보이는 편이 어울린다는 피드백을 반영했다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.correctFeedback 이 생기면 이 창을 접힌 채로 띄운다
//    → 접힘: "잘 맞추셨어요!" + 「정답 해설 보기」+ 「다음 문제」
//        ├─ 이 순간부터 이미 QuizSession.presentCorrectFeedback(for:) 가 해설을
//        │     만들고 있고, backgroundMeasurement 가 화면 밖에서 그 결과의 높이를
//        │     계속 잰다 — 버튼을 누르기 훨씬 전부터다.
//        ├─ 「정답 해설 보기」를 누르면 → reveal()
//        │     ├─ 해설이 **이미 준비돼 있으면** → 로딩 없이 selectedDetent 를
//        │     │     바로 그 높이로 바꾼다 → 시트가 collapsedHeight 에서 곧장 커진다
//        │     └─ 아직이면 → hasRequestedReveal 만 켠다 → 버튼 글자가 도는
//        │           인디케이터로 바뀐다. **시트는 아직 collapsedHeight 그대로다** —
//        │           「다음 문제」는 로딩 중에도 계속 누를 수 있다
//        ├─ (로딩 중이었다면) 해설이 도착하면 updateExpandedHeight 가 **진짜 높이를
//        │     계산해 딱 한 번** selectedDetent 를 그 높이로 바꾼다 → onChange 가
//        │     isExpanded 를 켠다 → 시트가 그 높이로 **곧장** 애니메이션과 함께 커진다
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다 — 해설을 안 보고 바로 넘어간다
//    → 펼침: 제목("정답 해설") + ✅ 체크 아이콘 + 정답 낱말 + 해설 + 「다음 문제」
//        ├─ 해설을 끝내 못 만들었으면(안전 필터 등) ``CommentaryPlaceholder/failed``
//        │     문구("해설을 준비 중입니다. 다음 문제로 이동해주세요.")가 해설 자리에
//        │     그대로 온다 — 별도 처리 없이도 이 창은 그 문구 길이에 맞춰 펴진다
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다
//
//  ── FeedbackSheet 와 다른 점 ───────────────────────────
//  오답 해설은 "고른 답 → 정답"으로 넘어가는 두 박자(「정답 보기」)이지만, 여기는
//  "접힘(축하, 로딩 포함) → 펼침(해설)"으로 넘어가는 두 박자다 — 맞았을 때는
//  해설을 보는 것 자체가 **선택**이라, 안 봐도 되는 사람은 곧바로 다음 문제로
//  갈 수 있게 두 버튼을 처음부터 나란히 뒀다. 해설 문장을 만드는 방법은 오답
//  해설과 완전히 같다 — ``QuizSession/presentCorrectFeedback(for:)`` 가
//  ``CommentaryWriter/explain(_:length:)``(`.full`)를 그대로 호출해 만든다
//  (Foundation Model 재활용).
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.correctFeedback 이 있는 동안
//  기대는 것    : CorrectCommentary, AppColor,
//                CommentarySheet.swift 의 부품들, PrimaryActionButton · SecondaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// 맞혔을 때 올라오는 모달.
///
/// **접힘(축하, 로딩 포함) → 펼침, 두 박자입니다.** 해설은 이 창이 뜨는 순간부터
/// 뒤에서 이미 만들어지고 있습니다. 「정답 해설 보기」를 눌렀을 때 이미 다
/// 와 있으면 **로딩 없이 곧장** 그 높이로 펼쳐지고, 아직이면 버튼이 도는
/// 인디케이터로 바뀌었다가 해설이 도착하는 순간 **한 번에** 그 높이로
/// 펼쳐집니다 — 어느 쪽이든 중간 크기를 거쳤다가 다시 줄어드는 두 번 움직임이
/// 없습니다. 해설이 궁금하지 않으면 로딩 중이라도 바로 「다음 문제」를 눌러
/// 넘어갈 수 있습니다.
///
/// - Note: 펼쳤을 때의 카드·시트 외장은 ``FeedbackSheet`` 와 **같은 부품**을
///   씁니다 — 어머니가 "이건 다른 창"이라고 새로 배우지 않아도 되도록, 맞았을
///   때와 틀렸을 때가 같은 시각 언어로 보이게 하려는 것입니다. 다만 정답 줄
///   모양(체크 아이콘 + 배경 없는 글자)과 시트 높이(내용에 맞춤, 미리 재 두고
///   눌렸을 때 한 번에 펼침)는 이 창만의 것입니다.
struct CorrectAnswerSheet: View {
    let feedback: CorrectCommentary
    let onNext: () -> Void

    /// 처음부터 펼친 채로 보여줄지. **미리보기 전용**이다 — 실제 사용에서는
    /// QuizView 가 이 시트를 띄울 때마다 항상 접힌 채로 시작한다.
    var startsExpanded: Bool = false

    /// 해설을 펼쳤는가. collapsedContent(축하 + 버튼 둘) 와 expandedContent(해설)를 가른다.
    @State private var isExpanded: Bool

    /// 「정답 해설 보기」를 눌렀는가. **한 번 켜지면 계속 켜져 있다** — 이 값과
    /// `feedback.isReady`를 조합해 로딩 인디케이터를 켤지, 바로 펼칠지를 결정한다
    /// (``isLoadingCommentary``, 14차 후속).
    @State private var hasRequestedReveal = false

    /// 지금 로딩 인디케이터를 보여줘야 하는가 — 눌렀는데(`hasRequestedReveal`)
    /// 아직 해설이 안 왔을 때(`!feedback.isReady`)뿐이다. 저장하지 않고 그때그때
    /// 계산한다 — `feedback`이 갈아 끼워지면(해설 도착) 저절로 꺼진다.
    ///
    /// `collapsedContent`의 버튼이 이 값을 보고 글자 대신 도는 인디케이터를
    /// 그린다. **시트 크기와는 별개다** — 로딩 중에도 시트는 여전히
    /// `collapsedHeight`다(13차 후속).
    private var isLoadingCommentary: Bool {
        hasRequestedReveal && !feedback.isReady
    }

    /// 지금 시트 크기. 손잡이가 없으므로(``commentarySheetChrome`` 이 숨긴다)
    /// `reveal()`과 `updateExpandedHeight`만 이 값을 바꾼다 — 눌렀을 때 해설이
    /// 이미 준비돼 있으면 `reveal()`이 곧장 바꾸고, 아직이면 나중에
    /// `updateExpandedHeight`가 바꾼다(14차 후속). GlossaryPanel 과 달리 스와이프로
    /// 펼치는 경로는 없다. 접힌 채로(로딩 중이든 아니든) 남아 있으면 「다음 문제」만
    /// 누를 수 있다.
    @State private var selectedDetent: PresentationDetent

    /// 펼쳤을 때 해설 내용에 딱 맞춘 시트 높이. 아직 재지 못했으면(해설이 안 왔거나)
    /// 0이다 — `expandedDetent`가 이 값을 보고 "쟀으면 그 높이, 아직이면 .medium"을
    /// 고른다. **눌리기 전부터** 계속 최신값으로 캐시된다(14차 후속).
    @State private var expandedHeight: CGFloat = 0

    /// 시트를 실제로 그 높이로 옮긴 적이 있다면 그 값. `PresentationDetent`는
    /// 열거형이 아니라 구조체라 `selectedDetent`에서 직접 `.height` 값을 다시
    /// 꺼낼 수 없어서, "지금 이미 이 높이로 펴져 있는가"를 확인하려고 따로 든다 —
    /// `updateExpandedHeight`가 같은 높이로 또 애니메이션을 걸지 않도록 막는 용도다.
    @State private var appliedHeight: CGFloat = 0

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 접혔을 때(처음 열릴 때) 시트 높이. "잘 맞추셨어요!" 한 줄 + 버튼 두 개
    /// (각 64pt) + 그 사이 간격을 어림잡은 값이다 — 실제 기기에서 위아래 여백이
    /// 어색하면 조정이 필요할 수 있다(GlossaryPanel 의 collapsedHeight 도 같은
    /// 방식으로 어림해 잡은 값이었다).
    private static let collapsedHeight: CGFloat = 260

    /// 펼침 시트가 쓸 크기. `expandedHeight`를 이미 재 뒀으면(``backgroundMeasurement``가
    /// 눌리기 전부터 미리 재 두는 경우가 흔하다) 그 값을, 아직이면 `.medium`을 쓴다.
    ///
    /// - Note: 정상적인 흐름에서는 `.medium` 쪽이 실제로 화면에 쓰이는 일이
    ///   거의 없다 — `isExpanded`는 오직 `reveal()`이나 `updateExpandedHeight`가
    ///   진짜 높이를 알고 `selectedDetent`를 바꾼 **다음에만** 켜지기 때문이다
    ///   (13·14차 후속). 이 폴백은 `detents` 집합이 항상 유효한 두 값을 가져야
    ///   한다는 시스템 요구 때문에 남겨 둔 자리표시일 뿐이다.
    private var expandedDetent: PresentationDetent {
        expandedHeight > 0 ? .height(expandedHeight) : .medium
    }

    /// `expandedContent` 안에서 실제로 재는 것은 제목+카드 내용 높이뿐이다.
    /// 시트 전체 높이가 되려면 그 아래 고정된 부분들을 더해야 한다 —
    /// 내용과 버튼 사이 간격(8) + 버튼 높이(``CommentaryMetrics/buttonHeight``) +
    /// 시트 바깥 아래 여백(``body`` 의 `padding(.bottom, 14)`).
    private static let expandedChromeHeight: CGFloat = 8 + CommentaryMetrics.buttonHeight + 14

    /// 정답 낱말 글자 크기. **28pt로 지정.**
    private static let answerWordSize: CGFloat = 28

    /// 체크 아이콘 크기. 정답 낱말과 **같은 값(28pt)**을 써서 글자 높이에 맞춘다 —
    /// 아이콘·글자가 나란히 한 줄에 있으니 정답 크기가 바뀌면 이 값도 함께 바뀐다.
    private static let checkmarkSize: CGFloat = answerWordSize

    /// 이 창(체크 아이콘·정답 낱말·해설 속 정답 낱말)만 쓰는 녹색.
    ///
    /// ``AppColor/answerSheetAccent``(어두운 녹색)보다 밝은 연두 계열로, 스크린샷
    /// 지시에 맞춰 이 화면 전용으로 새로 잡았다. ``FeedbackSheet``는 13차
    /// 후속에서, ``TrueFalseSheet``는 2026-09-25부터 이 값과 **같은 색**을 쓰도록
    /// 맞췄다(각 파일의 `correctAccent`) — 세 곳 모두 값을 복제해 갖고 있으므로,
    /// 바꿀 때는 셋을 함께 바꿔야 한다.
    private static let correctAccent = Color(red: 0.396, green: 0.769, blue: 0.400)

    /// 해설 본문 글자 크기. **24pt로 지정.** 기다리는 동안의 자리표시 문장도
    /// 같은 크기를 쓴다.
    private static let commentarySize: CGFloat = 24

    /// 제목("정답 해설") 글자 크기. **24pt로 지정.** ``CommentarySheetTitle``의
    /// 기본값(``CommentaryMetrics/titleSize``, 21)을 이 창에서만 덮어쓴다.
    private static let titleSize: CGFloat = 24

    /// 「잘 맞추셨어요!」 글자 크기. 제목(``CommentaryMetrics/titleSize``)의 **1.5배**다.
    ///
    /// 이 줄은 창의 제목이 아니라 **축하 한마디**다. 창이 뜬 순간 어머니 눈에 가장
    /// 먼저 들어와야 하는 것이 "맞았다"는 사실이라, 아래 버튼 글자(21)보다 확실히
    /// 크게 뒀다.
    private static let celebrationSize: CGFloat = CommentaryMetrics.titleSize * 1.5

    init(feedback: CorrectCommentary,
         onNext: @escaping () -> Void,
         startsExpanded: Bool = false) {
        self.feedback = feedback
        self.onNext = onNext
        self.startsExpanded = startsExpanded
        _isExpanded = State(initialValue: startsExpanded)
        // 미리보기에서 처음부터 펼쳐 두는 경우, 실제로 「정답 해설 보기」를
        // 누른 것과 같은 상태로 시작해야 updateExpandedHeight 가 시트를 딱 맞는
        // 높이로 줄여준다 — 안 그러면 hasRequestedReveal 이 꺼진 채로 남아
        // .medium 에서 안 움직인다(14차 후속).
        _hasRequestedReveal = State(initialValue: startsExpanded)
        _selectedDetent = State(initialValue: startsExpanded ? .medium : .height(Self.collapsedHeight))
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        // 접힌 동안(로딩 여부와 무관하게) 화면에 안 보이는 사본(backgroundMeasurement)을
        // 겹쳐 둔다 — 해설이 창을 열기도 전에 뒤에서 다 만들어지는 경우가 흔하니,
        // 「정답 해설 보기」를 누르기 전부터 미리 높이를 재 두면 눌렀을 때 로딩
        // 없이 바로 펼 수 있다(14차 후속). 보이는 내용(collapsedContent)의
        // 크기에는 영향을 주지 않는다 — overlay 는 자기 크기를 foreground 에서만
        // 가져온다.
        .overlay(alignment: .topLeading) { backgroundMeasurement }
        // 접힘(collapsedHeight) ↔ 펼침(expandedDetent) 두 크기만 쓴다. GlossaryPanel
        // 처럼 손잡이를 직접 그려 끌 수 있게 하지 않고, 실제로는 오직
        // updateExpandedHeight 만 펼침 쪽으로 바꾼다 — 이 창은 두 버튼 중 하나를
        // 고르는 자리라, 실수로 끌려서 커지면 오히려 혼란스러울 수 있다.
        //
        // expandedDetent 는 해설 높이를 잴 때마다 바뀌는 값이라, 여기 detents 집합에
        // 매번 새 높이가 함께 들어간다 — updateExpandedHeight 가 expandedHeight 와
        // selectedDetent 를 같은 시점에 같이 바꾸므로 어긋나지 않는다.
        //
        // 배경·손잡이·스와이프 닫기 막기는 오답 해설 창과 **같은 한 벌**이다.
        // 한때 이 창을 연두, 오답 창을 주황으로 갈라 봤다(창이 뜨는 순간 색으로
        // 맞았는지 알게 하려고). 되돌린 이유는 밝은 배경이 흰 글자를 못 받쳐서다 —
        // 제목과 버튼까지 진한 녹색으로 바꿔야 했고, 그러면 앱의 다른 화면과
        // 색이 따로 놀았다.
        .commentarySheetChrome(
            detents: [.height(Self.collapsedHeight), expandedDetent],
            selection: $selectedDetent)
        // presentationDetents 의 커스텀 .height 전환은 withAnimation 만으로는
        // 가끔 스냅처럼 보인다 — 값이 바뀔 때마다 걸리는 .animation(_:value:) 을
        // 하나 더 얹어서, collapsedHeight 에서 해설에 맞는 높이로 커질 때 항상 이
        // 애니메이션을 타게 한다. 0.3초·1초로도 갑자기 바뀌는 느낌이라는 피드백을
        // 받아 3초로 늘렸다.
        .animation(.easeInOut(duration: 3.0), value: selectedDetent)
        .onChange(of: selectedDetent) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                isExpanded = (newValue != .height(Self.collapsedHeight))
            }
        }
    }

    // MARK: - 접힘: 축하 + 버튼 둘

    /// 접혔을 때 보이는 내용. "잘 맞추셨어요!"(흰 글자, 제목의 1.5배) 한 줄 아래
    /// 버튼 두 개를 세로로 둔다 —
    /// 「정답 해설 보기」(고르는 행동, 흰 알약 + 시그니처 글자)와 「다음 문제」
    /// (이 회차를 계속 진행하는 행동, 다른 화면과 같은 시그니처 채움 알약)를
    /// 색으로 구분해, 둘 중 무엇이 "그대로 진행하기"인지 한눈에 보이게 했다.
    private var collapsedContent: some View {
        VStack(spacing: 16) {
            // 보라 배경 위의 흰 글자(4.0:1)라 잘 읽힌다. 크기만 제목의 1.5배다.
            Text("잘 맞추셨어요!")
                .font(.system(size: Self.celebrationSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: .leading)

            SecondaryActionButton(title: "정답 해설 보기",
                                  isLoading: isLoadingCommentary,
                                  action: reveal)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
        .padding(.top, 22)
    }

    /// 「정답 해설 보기」를 눌렀을 때 할 일.
    ///
    /// **해설이 이미 준비돼 있으면(``backgroundMeasurement``가 눌리기 전부터
    /// 미리 재 둔 경우가 흔하다) 로딩 없이 곧장 그 높이로 편다.** 아직이면
    /// `hasRequestedReveal`만 켠다 — 버튼은 `isLoadingCommentary`를 보고 도는
    /// 인디케이터로 바뀌고, 실제로 시트를 펴는 것은 해설이 도착했을 때
    /// `updateExpandedHeight`가 맡는다(14차 후속).
    private func reveal() {
        guard !hasRequestedReveal, !isExpanded else { return }
        hasRequestedReveal = true

        if feedback.isReady, expandedHeight > 0 {
            withAnimation(.easeInOut(duration: 3.0)) {
                appliedHeight = expandedHeight
                selectedDetent = .height(expandedHeight)
            }
        }
        // 아직 준비 안 됐으면 여기서는 아무것도 안 바꾼다 — 버튼이 로딩 모습으로
        // 바뀌고, updateExpandedHeight 가 해설 도착을 기다렸다가 편다.
    }

    // MARK: - 펼침: 해설

    /// 제목("정답 해설") + notesCard. **`expandedContent`(실제로 보여줄 때)와
    /// `backgroundMeasurement`(숨은 사본)가 완전히 같은 이 뷰를 쓴다** — 둘이
    /// 폰트·줄바꿈 한 치라도 다르면, 숨어서 잰 높이와 실제로 펼쳤을 때의 높이가
    /// 어긋난다.
    private var expandedInnerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommentarySheetTitle(text: "정답 해설", size: Self.titleSize)
            notesCard
        }
        .padding(.top, 16)
    }

    /// 접혀 있는 동안(``isExpanded`` 가 `false`인 동안, 눌렸는지와 무관하게)
    /// 화면엔 안 보이게 `expandedInnerContent`를 미리 그려서 **해설이 도착하는
    /// 순간 바로 실제 높이를 알 수 있게** 해 둔다.
    ///
    /// 「정답 해설 보기」를 누르기 **전부터** 계속 재 두는 이유 — 해설은 이 창이
    /// 뜨는 순간 뒤에서 이미 만들어지고 있어서(``QuizSession/presentCorrectFeedback(for:)``),
    /// 어머니가 버튼을 누를 즈음엔 이미 다 와 있는 경우가 흔하다. 그때 `reveal()`이
    /// 로딩 한 번 거치지 않고 바로 펼 수 있으려면, 높이도 미리 재 둬야 한다.
    ///
    /// `body`에서 `.overlay(alignment: .topLeading)`로 붙인다 — overlay는 자기
    /// 크기를 foreground(보이는 collapsedContent)에서만 가져오므로, 이 사본이
    /// 아무리 크더라도 시트나 collapsedContent 크기에 영향을 주지 않는다. 다만
    /// overlay가 이 사본에게 제안하는 너비는 `body`의 가로 padding(28)이 아직
    /// 안 빠진 값이라, `expandedContent`와 같은 줄바꿈이 되도록 여기서 직접
    /// `.padding(.horizontal, 28)`을 한 번 더 준다.
    ///
    /// `updateExpandedHeight`가 `expandedHeight`는 항상 갱신하지만, 아직
    /// `hasRequestedReveal`이 꺼져 있으면 시트는 건드리지 않으므로, 누르기 전에
    /// 시트가 저절로 펴지는 일은 없다.
    ///
    /// - Note: `.hidden()` 대신 `.opacity(0)`을 쓴다. `.hidden()`은 문서상으로는
    ///   "레이아웃엔 남는다"고 하지만, 화면에 실제로 그려지지 않는 뷰라서 시스템이
    ///   레이아웃을 뒤로 미루거나 건너뛰는 경우가 있었다 — 그러면 오래 기다려도
    ///   `expandedHeight`가 0에서 안 바뀌어, 매번 로딩 화면부터 거치게 된다.
    ///   `.opacity(0)`은 여전히 "투명하게 그려지는" 뷰라 매 렌더마다 확실히 레이아웃
    ///   된다. `.id(feedback.commentary)`도 같이 줘서, 자리표시 문구에서 진짜
    ///   해설로 바뀔 때 뷰를 통째로 새로 만들어 **반드시 새 높이를 재게** 한다
    ///   (14차 후속 — "아무리 기다려도 로딩이 뜬다"는 신고를 받아 고쳤다).
    @ViewBuilder
    private var backgroundMeasurement: some View {
        if !isExpanded {
            expandedInnerContent
                .padding(.horizontal, 28)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    updateExpandedHeight(contentHeight: newHeight)
                }
                .id(feedback.commentary)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// 펼쳤을 때 실제로 보이는 내용. 제목은 항상 "정답 해설"이고, 「잘
    /// 맞추셨어요!」와 같이 흰 글자다 — 이 창에서 배경 위에 바로 올라가는 글자는
    /// 이 둘뿐이고, 둘의 색이 다르면 접었다 펼 때 색이 바뀌어 보인다.
    ///
    /// `expandedInnerContent`에도 `onGeometryChange`를 달아 높이를 계속 잰다 —
    /// 펼치기 전에 `backgroundMeasurement`가 이미 한 번(대개 여러 번) 재 뒀지만,
    /// 펼친 뒤에도 이 계측을 유지해 두면(예: 훗날 해설을 다시 만드는 기능이
    /// 생기는 등) 내용이 또 바뀌어도 시트가 따라 맞춰진다. `ScrollView`는
    /// 안전망이다 — 잰 높이가 화면을 넘어서면 시스템이 detent를 화면 안으로
    /// 알아서 줄이는데, 그때도 내용이 잘리지 않고 스크롤되게 한다.
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                expandedInnerContent
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        updateExpandedHeight(contentHeight: newHeight)
                    }
            }

            // 예전엔 Spacer(minLength: 8)로 남는 공간을 버튼 위로 밀어냈지만,
            // 이제는 시트 높이 자체를 내용에 맞추므로 남는 공간이 없다 — 고정폭
            // 8pt만 두면 된다(늘어나는 Spacer 를 쓰면 위에서 잰 높이와 실제
            // 배치가 어긋난다).
            Color.clear.frame(height: 8)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
    }

    /// `backgroundMeasurement`(숨은 사본)나 `expandedContent`(실제로 펼친 뒤)
    /// 양쪽 모두에서 부른다. 잰 내용 높이(제목+카드)에 고정 여백을 더해 시트
    /// 높이를 계산해 `expandedHeight`에 **항상** 캐시해 둔다 — 아직 눌리기
    /// 전이라도, 해설이 이미 왔다면 미리 알아 두려는 것이다.
    ///
    /// **해설이 다 도착하기 전에는 아무것도 하지 않는다** — `feedback.isReady`가
    /// `false`인 동안은(자리표시 문장 높이로 여러 번 불려도) 그냥 돌아간다.
    ///
    /// **시트는 `hasRequestedReveal`이 켜져 있을 때만 움직인다** — 어머니가
    /// 아직 「정답 해설 보기」를 누르지 않았으면, 해설이 뒤에서 다 와도 시트는
    /// `collapsedHeight` 그대로다. 눌렀는데 그때까지 해설이 없었다면, 도착하는
    /// 순간 이 함수가 시트를 `collapsedHeight`에서 딱 맞는 높이로 **한 번에**
    /// 애니메이션과 함께 연다 — `.medium`을 거쳤다가 다시 줄어드는 두 번 움직임이
    /// 없다(13·14차 후속).
    private func updateExpandedHeight(contentHeight: CGFloat) {
        guard feedback.isReady, contentHeight > 0 else { return }

        let target = (contentHeight + Self.expandedChromeHeight).rounded()
        expandedHeight = target

        guard hasRequestedReveal, target != appliedHeight else { return }

        withAnimation(.easeInOut(duration: 3.0)) {
            appliedHeight = target
            selectedDetent = .height(target)
        }
    }

    /// 정답 줄 + 설명을 감싸는 카드.
    ///
    /// 오답 해설 창의 배지 줄(``CommentaryRow``)을 그대로 쓰지 않고 이 창만의
    /// 모양을 직접 그린다 — 여기는 견줄 오답이 없어서, "여러 후보 중 하나"처럼
    /// 보이는 배지보다 SF Symbol 체크 아이콘(`checkmark.app.fill`) + 배경 없는
    /// 굵은 녹색 글자가 "이미 확정된 사실"에 더 가깝게 읽힌다(11차 후속, 스크린샷
    /// 반영). 글자색은 이 창 전용 ``correctAccent``다 — ``FeedbackSheet``의 정답
    /// 줄도 13차 후속부터, ``TrueFalseSheet``의 정답 줄도 2026-09-25부터 같은
    /// 색·같은 모양(체크 아이콘 + 배경 없는 굵은 글자)을 쓴다. 세 창 모두 같은
    /// ``correctAccent`` 값(0.396, 0.769, 0.400)을 각자 복제해 갖고 있으므로,
    /// 색을 바꿀 때는 세 곳을 함께 바꿔야 한다.
    private var notesCard: some View {
        CommentaryCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.app.fill")
                        .font(.system(size: Self.checkmarkSize))
                        .foregroundStyle(Self.correctAccent)

                    Text(feedback.correctAnswer)
                        .font(.system(size: Self.answerWordSize, weight: .heavy))
                        .foregroundStyle(Self.correctAccent)
                }

                commentary
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.** (FeedbackSheet.commentary 와 같은 이유)
    ///
    /// 글은 검정이고 **정답 낱말만 이 창 전용 녹색(``correctAccent``)**이다 —
    /// 위 정답 줄과 같은 색이라 카드 안에서 같은 낱말이 다른 색으로 보이지
    /// 않는다. 크기도 정답 줄과 마찬가지로 키운 값(``commentarySize``)을 쓴다.
    /// 창 배경(보라)과는 상관없이, 낱말은 흰 카드 위에 올라가므로 서로 부딪히지 않는다.
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            CommentaryBodyText(text: feedback.commentary,
                               word: feedback.correctAnswer,
                               color: Self.correctAccent,
                               size: Self.commentarySize)
        } else {
            Text(feedback.commentary)
                .modifier(CommentaryBodyStyle(size: Self.commentarySize))
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }
}

#Preview("접힘 — 잘 맞추셨어요") {
    CorrectAnswerSheet(
        feedback: .init(
            id: 32,
            correctAnswer: "이순신",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {})
}

#Preview("펼침 — 해설 도착") {
    CorrectAnswerSheet(
        feedback: .init(
            id: 32,
            correctAnswer: "이순신",
            commentary: "임진왜란 때 거북선으로 왜적을 물리친 장군이에요. 지금도 존경받는 대표적인 장군이에요."),
        onNext: {},
        startsExpanded: true)
}

#Preview("펼침 — 기다리는 중") {
    CorrectAnswerSheet(
        feedback: .init(
            id: 32,
            correctAnswer: "이순신",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {},
        startsExpanded: true)
}

#Preview("펼침 — 긴 정답: 고구려, 백제, 신라") {
    CorrectAnswerSheet(
        feedback: .init(
            id: 27,
            correctAnswer: "고구려, 백제, 신라",
            commentary: "고구려, 백제, 신라입니다. 이 세 나라가 있었습니다. 신라가 이 세 나라를 하나로 합쳤습니다."),
        onNext: {},
        startsExpanded: true)
}
