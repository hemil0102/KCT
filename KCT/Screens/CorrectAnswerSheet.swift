//
//  CorrectAnswerSheet.swift
//  KCT
//
//  역할 : 맞혔을 때 올라와 축하하고, 원하면 정답을 한 번 더 설명해 주는 모달
//  요점 : 처음엔 접힌 채로 "잘 맞추셨어요!" + 버튼 두 개만 보여준다. "정답 해설
//        보기"를 눌러야 시트가 화면 절반으로 커지며 실제 해설이 나온다 —
//        해설이 궁금하지 않으면 곧바로 "다음 문제"로 넘어갈 수 있다.
//
//  ── 구성 ──────────────────────────────────────────────
//  CorrectAnswerSheet
//  ├─ feedback              정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext                「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ startsExpanded        미리보기 전용 — 처음부터 펼친 채로 띄운다
//  ├─ isExpanded            해설을 펼쳤는가 — collapsedContent / expandedContent 를 가른다
//  ├─ selectedDetent        지금 시트 크기. 접힘(collapsedHeight) ↔ 펼침(.medium)
//  ├─ isPulsing             기다리는 동안 맥동시키는 깃발
//  ├─ collapsedContent      "잘 맞추셨어요!" + 「정답 해설 보기」·「다음 문제」 두 버튼
//  ├─ reveal()              selectedDetent 를 .medium 으로 바꾼다
//  ├─ expandedContent       제목("정답 해설") + notesCard + 「다음 문제」
//  ├─ notesCard             정답 배지 + 해설을 감싸는 흰 카드
//  └─ commentary            기다릴 때와 도착한 뒤가 서로 다른 뷰
//
//  모양은 전부 DesignSystem/CommentarySheet.swift 에 있고, **오답 해설 창
//  (FeedbackSheet)이 같은 부품을 쓴다** — 어머니가 "이건 다른 창"이라고 새로
//  배우지 않아도 되도록, 맞았을 때와 틀렸을 때가 같은 시각 언어로 보이게 하려는 것이다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.correctFeedback 이 생기면 이 창을 접힌 채로 띄운다
//    → 접힘: "잘 맞추셨어요!" + 「정답 해설 보기」+ 「다음 문제」
//        ├─ 「정답 해설 보기」를 누르면 → reveal() → 시트가 .medium 으로 커진다
//        │     (해설은 창이 뜨자마자 뒤에서 이미 준비되고 있다 — QuizSession.
//        │     presentCorrectFeedback(for:) 가 접힘 상태와 무관하게 바로 시작한다.
//        │     그래서 펼쳤을 때 이미 다 와 있는 경우가 많다.)
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다 — 해설을 안 보고 바로 넘어간다
//    → 펼침: 제목("정답 해설") + ✅ 정답 배지 + 해설 + 「다음 문제」
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다
//
//  ── FeedbackSheet 와 다른 점 ───────────────────────────
//  오답 해설은 "고른 답 → 정답"으로 넘어가는 두 박자(「정답 보기」)이지만, 여기는
//  "접힘(축하) → 펼침(해설)"으로 넘어가는 두 박자다 — 맞았을 때는 해설을 보는
//  것 자체가 **선택**이라, 안 봐도 되는 사람은 곧바로 다음 문제로 갈 수 있게
//  두 버튼을 처음부터 나란히 뒀다. 해설 문장을 만드는 방법은 오답 해설과 완전히
//  같다 — ``QuizSession/presentCorrectFeedback(for:)`` 가 ``CommentaryWriter/explain(_:length:)``(`.full`)
//  를 그대로 호출해 만든다(Foundation Model 재활용).
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
/// **접힘 → 펼침, 두 박자입니다.** 처음엔 작게 "잘 맞추셨어요!"만 보여주고,
/// 「정답 해설 보기」를 눌러야 시트가 화면 절반으로 커지며 실제 해설이 나옵니다.
/// 해설이 궁금하지 않으면 접힌 채로 바로 「다음 문제」를 눌러 넘어갈 수 있습니다.
///
/// - Note: 펼쳤을 때의 배지·카드·시트 최대 크기(화면 절반, `.medium`)는 ``FeedbackSheet``
///   와 **같은 부품**을 씁니다 — 어머니가 "이건 다른 창"이라고 새로 배우지 않아도 되도록,
///   맞았을 때와 틀렸을 때가 같은 시각 언어로 보이게 하려는 것입니다.
struct CorrectAnswerSheet: View {
    let feedback: CorrectCommentary
    let onNext: () -> Void

    /// 처음부터 펼친 채로 보여줄지. **미리보기 전용**이다 — 실제 사용에서는
    /// QuizView 가 이 시트를 띄울 때마다 항상 접힌 채로 시작한다.
    var startsExpanded: Bool = false

    /// 해설을 펼쳤는가. collapsedContent(축하 + 버튼 둘) 와 expandedContent(해설)를 가른다.
    @State private var isExpanded: Bool

    /// 지금 시트 크기. 손잡이가 없으므로(``commentarySheetChrome`` 이 숨긴다)
    /// 오직 `reveal()`(「정답 해설 보기」)만 이 값을 바꾼다 — GlossaryPanel 과 달리
    /// 스와이프로 펼치는 경로는 없다. 접힌 채로 남아 있으면 「다음 문제」만 누를 수 있다.
    @State private var selectedDetent: PresentationDetent

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 접혔을 때(처음 열릴 때) 시트 높이. "잘 맞추셨어요!" 한 줄 + 버튼 두 개
    /// (각 64pt) + 그 사이 간격을 어림잡은 값이다 — 실제 기기에서 위아래 여백이
    /// 어색하면 조정이 필요할 수 있다(GlossaryPanel 의 collapsedHeight 도 같은
    /// 방식으로 어림해 잡은 값이었다).
    private static let collapsedHeight: CGFloat = 260

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
        // 접힘(collapsedHeight) ↔ 펼침(.medium) 두 크기만 쓴다. GlossaryPanel 처럼
        // 손잡이를 직접 그려 끌 수 있게 하지 않고, 「정답 해설 보기」를 눌러야만
        // (reveal()) 커지게 뒀다 — 이 창은 두 버튼 중 하나를 고르는 자리라, 실수로
        // 끌려서 커지면 오히려 혼란스러울 수 있다.
        //
        // 배경·손잡이·스와이프 닫기 막기는 오답 해설 창과 **같은 한 벌**이다.
        // 한때 이 창을 연두, 오답 창을 주황으로 갈라 봤다(창이 뜨는 순간 색으로
        // 맞았는지 알게 하려고). 되돌린 이유는 밝은 배경이 흰 글자를 못 받쳐서다 —
        // 제목과 버튼까지 진한 녹색으로 바꿔야 했고, 그러면 앱의 다른 화면과
        // 색이 따로 놀았다.
        .commentarySheetChrome(
            detents: [.height(Self.collapsedHeight), .medium],
            selection: $selectedDetent)
        .onChange(of: selectedDetent) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                isExpanded = (newValue == .medium)
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

            SecondaryActionButton(title: "정답 해설 보기", action: reveal)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
        .padding(.top, 22)
    }

    /// 시트를 `.medium`으로 키운다. 실제로 내용을 펼치는 것은 `onChange(of:
    /// selectedDetent)`가 맡는다(GlossaryPanel의 `reveal()`과 같은 방식).
    private func reveal() {
        withAnimation(.easeOut(duration: 0.3)) {
            selectedDetent = .medium
        }
    }

    // MARK: - 펼침: 해설

    /// 펼쳤을 때 보이는 내용. 예전 버전(축하 없이 바로 해설만 보여주던 모습)과 같다.
    ///
    /// 제목은 항상 "정답 해설"이고, 「잘 맞추셨어요!」와 같이 흰 글자다 — 이 창에서
    /// 배경 위에 바로 올라가는 글자는 이 둘뿐이고, 둘의 색이 다르면 접었다 펼 때
    /// 색이 바뀌어 보인다.
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CommentarySheetTitle(text: "정답 해설")
                    notesCard
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 8)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
    }

    /// 정답 배지 + 설명을 감싸는 카드. 오답 해설 창과 **같은 부품**이라 모양이 같다 —
    /// 여기서는 ✅ 줄 하나만 그린다.
    private var notesCard: some View {
        CommentaryCard {
            CommentaryRow(
                mark: "✅",
                word: feedback.correctAnswer,
                badgeBackground: AppColor.answerSheetBadge,
                badgeText: AppColor.answerSheetAccent
            ) { commentary }
        }
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.** (FeedbackSheet.commentary 와 같은 이유)
    ///
    /// 글은 검정이고 **정답 낱말만 진한 녹색**이다 — 오답 창의 「정답」 줄도 같은
    /// 녹색으로, 두 창 모두 **정답 = 녹색**으로 통일했다. 창 배경(보라)과는 상관없이,
    /// 낱말은 흰 카드 위에 올라가므로 서로 부딪히지 않는다.
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            CommentaryBodyText(text: feedback.commentary,
                               word: feedback.correctAnswer,
                               color: AppColor.answerSheetAccent)
        } else {
            Text(feedback.commentary)
                .modifier(CommentaryBodyStyle())
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
