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
//  ├─ isExpanded            해설을 펼쳤는가 — collapsedContent / expandedContent 를 가른다
//  ├─ selectedDetent        지금 시트 크기. 접힘(collapsedHeight) ↔ 펼침(.medium)
//  ├─ isPulsing             기다리는 동안 맥동시키는 깃발
//  ├─ collapsedContent      "잘 맞추셨어요!" + 「정답 해설 보기」·「다음 문제」 두 버튼
//  ├─ revealButton          「정답 해설 보기」— 누르면 reveal() 로 시트를 펼친다
//  ├─ reveal()              selectedDetent 를 .medium 으로 바꾼다
//  ├─ expandedContent       제목("정답 해설") + notesCard + 「다음 문제」
//  ├─ title                 펼쳤을 때만 보이는 제목 한 줄 — "정답 해설" 고정
//  ├─ notesCard             정답 배지 + 해설을 감싸는 흰 카드 (FeedbackSheet.notesCard 와 같은 모양)
//  ├─ noteRow(...)          이모지(✅) + 낱말 배지 + 그 아래 설명 — FeedbackSheet 와 같은 구조
//  ├─ commentary            기다릴 때와 도착한 뒤가 서로 다른 뷰
//  └─ highlight(_:word:color:size:)  글 속의 낱말만 칠한다 — FeedbackSheet 와 같은 규칙
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
//  같다 — ``QuizSession/presentCorrectFeedback(for:)`` 가 ``CommentaryWriter/write(for:)``
//  를 그대로 호출해 만든다(Foundation Model 재활용).
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.correctFeedback 이 있는 동안
//  기대는 것    : QuizSession.CorrectCommentary, AppColor, PrimaryActionButton,
//                BodyStyle · pulsingWhileWaiting(FeedbackSheet.swift 에 있는 것을 그대로 가져다 쓴다)
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
///   와 똑같이 맞췄습니다 — 어머니가 "이건 다른 창"이라고 새로 배우지 않아도 되도록,
///   맞았을 때와 틀렸을 때가 같은 시각 언어로 보이게 하려는 것입니다.
struct CorrectAnswerSheet: View {
    let feedback: QuizSession.CorrectCommentary
    let onNext: () -> Void

    /// 처음부터 펼친 채로 보여줄지. **미리보기 전용**이다 — 실제 사용에서는
    /// QuizView 가 이 시트를 띄울 때마다 항상 접힌 채로 시작한다.
    var startsExpanded: Bool = false

    /// 해설을 펼쳤는가. collapsedContent(축하 + 버튼 둘) 와 expandedContent(해설)를 가른다.
    @State private var isExpanded: Bool

    /// 지금 시트 크기. 손잡이가 없으므로(아래 `.presentationDragIndicator(.hidden)`)
    /// 오직 `reveal()`(「정답 해설 보기」)만 이 값을 바꾼다 — GlossaryPanel 과 달리
    /// 스와이프로 펼치는 경로는 없다. 접힌 채로 남아 있으면 「다음 문제」만 누를 수 있다.
    @State private var selectedDetent: PresentationDetent

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 접혔을 때(처음 열릴 때) 시트 높이. "잘 맞추셨어요!" 한 줄 + 버튼 두 개
    /// (revealButton·다음 문제, 각 64pt) + 그 사이 간격을 어림잡은 값이다 — 실제
    /// 기기에서 위아래 여백이 어색하면 조정이 필요할 수 있다(GlossaryPanel의
    /// collapsedHeight 도 같은 방식으로 어림해 잡은 값이었다).
    private static let collapsedHeight: CGFloat = 260

    /// 버튼 높이. FeedbackSheet 와 같은 값(터치 목표 1cm 권장).
    private static let buttonHeight: CGFloat = 64

    /// 이모지(✅) 크기. FeedbackSheet 와 같은 값.
    private static let markSize: CGFloat = 20

    /// 시트 맨 위 제목 글자 크기. FeedbackSheet 와 같은 값.
    private static let titleSize: CGFloat = 21

    /// 낱말 배지 · 해설이 함께 쓰는 글자 크기. FeedbackSheet 와 같은 값.
    private static let noteSize: CGFloat = 21

    init(feedback: QuizSession.CorrectCommentary, onNext: @escaping () -> Void, startsExpanded: Bool = false) {
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
        // FeedbackSheet 와 같은 값 — 두 창이 같은 무게로 보이게 한다.
        .presentationBackground(AppColor.signature.opacity(0.75))
        .presentationBackgroundInteraction(.enabled)
        // 접힘(collapsedHeight) ↔ 펼침(.medium) 두 크기만 쓴다. GlossaryPanel 처럼
        // 손잡이를 직접 그려 끌 수 있게 하지 않고, 「정답 해설 보기」를 눌러야만
        // (reveal()) 커지게 뒀다 — 이 창은 두 버튼 중 하나를 고르는 자리라, 실수로
        // 끌려서 커지면 오히려 혼란스러울 수 있다.
        .presentationDetents([.height(Self.collapsedHeight), .medium], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .onChange(of: selectedDetent) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                isExpanded = (newValue == .medium)
            }
        }
    }

    // MARK: - 접힘: 축하 + 버튼 둘

    /// 접혔을 때 보이는 내용. "잘 맞추셨어요!" 한 줄 아래 버튼 두 개를 세로로 둔다 —
    /// 「정답 해설 보기」(고르는 행동, 흰 알약 + 시그니처 글자)와 「다음 문제」
    /// (이 회차를 계속 진행하는 행동, 다른 화면과 같은 시그니처 채움 알약)를
    /// 색으로 구분해, 둘 중 무엇이 "그대로 진행하기"인지 한눈에 보이게 했다.
    private var collapsedContent: some View {
        VStack(spacing: 16) {
            Text("잘 맞추셨어요!")
                .font(.system(size: Self.titleSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.96))
                .frame(maxWidth: .infinity, alignment: .leading)

            revealButton
            PrimaryActionButton(title: "다음 문제  →", minHeight: Self.buttonHeight) { onNext() }
        }
        .padding(.top, 22)
    }

    /// 「정답 해설 보기」. 흰 알약 + 시그니처 글자로, 아래 「다음 문제」(시그니처
    /// 채움)보다 한 단계 가벼운 무게로 둔다 — 이 창의 기본 동작은 "계속 진행"이고
    /// 해설을 보는 것은 원하면 고르는 부가 행동이기 때문이다.
    private var revealButton: some View {
        Button(action: reveal) {
            Text("정답 해설 보기")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppColor.signature)
                .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
                .background(Color.white, in: Capsule())
        }
        .buttonStyle(.plain)
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
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    title
                    notesCard
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 8)

            PrimaryActionButton(title: "다음 문제  →", minHeight: Self.buttonHeight) { onNext() }
        }
    }

    /// 시트 맨 위 제목. 펼쳤을 때만 보이고, 항상 "정답 해설"이다.
    private var title: some View {
        Text("정답 해설")
            .font(.system(size: Self.titleSize, weight: .bold))
            .foregroundStyle(.white.opacity(0.96))
    }

    /// 정답 배지 + 설명을 감싸는 카드. FeedbackSheet.notesCard 와 같은 모양(완전 불투명 흰색,
    /// 코너 반경 16)이다 — 여기서는 ✅ 줄 하나만 그린다.
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            noteRow(mark: "✅",
                    badgeBackground: AppColor.answerHeader,
                    badgeText: AppColor.answerAccent,
                    word: feedback.correctAnswer) { commentary }
        }
        .padding(.horizontal, 15)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 이모지 + 낱말 배지 + 그 아래 설명 한 덩어리. FeedbackSheet.noteRow(...) 와 똑같다.
    private func noteRow<Content: View>(
        mark: String,
        badgeBackground: Color,
        badgeText: Color,
        word: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(mark)
                .font(.system(size: Self.markSize))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(word)
                    .font(.system(size: Self.noteSize, weight: .black))
                    .foregroundStyle(badgeText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 9)
                    .padding(.top, 1)
                    .padding(.bottom, 3)
                    .background(badgeBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                content()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 해설

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.** (FeedbackSheet.commentary 와 같은 이유)
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            Text(commentaryText).modifier(BodyStyle(size: Self.noteSize))
        } else {
            Text(feedback.commentary)
                .modifier(BodyStyle(size: Self.noteSize))
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }

    /// 정답 해설. 글은 검정이고 **정답 낱말만 하늘색**이다. (FeedbackSheet.commentaryText 와 같다)
    private var commentaryText: AttributedString {
        highlight(feedback.commentary,
                  word: feedback.correctAnswer,
                  color: AppColor.answerAccent,
                  size: Self.noteSize)
    }

    /// 글 속의 낱말을 찾아 칠한다. FeedbackSheet.highlight(_:word:color:size:) 와 똑같다.
    private func highlight(_ sentence: String, word: String, color: Color, size: CGFloat) -> AttributedString {
        var text = AttributedString(sentence)
        guard !word.isEmpty else { return text }

        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text[searchStart..<text.endIndex].range(of: word) {
            text[found].foregroundColor = color
            text[found].font = .system(size: size, weight: .bold)
            searchStart = found.upperBound
        }
        return text
    }
}

#Preview("접힘 — 잘 맞추셨어요") {
    CorrectAnswerSheet(
        feedback: .init(
            id: 32,
            correctAnswer: "이순신",
            commentary: QuizSession.CorrectCommentary.placeholder),
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
            commentary: QuizSession.CorrectCommentary.placeholder),
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
