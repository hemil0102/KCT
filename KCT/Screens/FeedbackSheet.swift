//
//  FeedbackSheet.swift
//  KCT
//
//  역할 : 틀렸을 때 고른 답을 먼저 짚어 주고, 눌러야 정답을 보여주는 모달
//  요점 : 고른 답도 어딘가의 정답이다. 그것부터 알려 주고 정답으로 넘어간다
//
//  ── 구성 ──────────────────────────────────────────────
//  FeedbackSheet
//  ├─ feedback         고른 답 · 고른 답 설명 · 정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext           「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ showsAnswer      「정답 보기」를 눌렀는가. 두 박자를 가른다
//  ├─ isPulsing        기다리는 동안 맥동시키는 깃발
//  ├─ chosenBlock      👉 고르신 답 + 그것이 무엇인지 (제목만 붉은색, 글은 검정)
//  ├─ answerBlock      ✅ 정답 + 해설 (제목만 파랑, 글은 검정)
//  ├─ commentary       기다릴 때와 도착한 뒤가 서로 다른 뷰
//  └─ highlight(_:word:color:)  글 속의 낱말만 칠한다
//
//  파일 안의 도우미
//  ├─ BodyStyle            두 칸이 함께 쓰는 본문 글꼴 (22pt · 검정)
//  └─ pulsingWhileWaiting  아직 안 온 글을 옅게 맥동시키는 수식어
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.feedback 이 생기면 이 창을 띄운다
//    → 1박자 : 고른 답과 그 설명이 먼저 보인다. 버튼은 「정답 보기」
//    → 「정답 보기」를 누르면
//    → 2박자 : 정답과 해설이 아래에 이어 붙는다. 버튼은 「다음 문제」
//    → 「다음 문제」를 누르면 onNext() 로 위에 알린다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.feedback 이 있는 동안
//  기대는 것    : QuizSession.IncorrectCommentary, AppColor, PrimaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// 오답 직후에 올라오는 모달.
///
/// **두 박자로 나뉩니다.**
///
/// | 박자 | 보이는 것 | 버튼 |
/// |---|---|---|
/// | 1 | 👉 고르신 답 + 그것이 무엇인지 | 「정답 보기」 |
/// | 2 | 위 + ✅ 정답 + 해설 | 「다음 문제」 |
///
/// 한 화면에 다 쏟지 않는 이유 — 정답이 처음부터 보이면 **고른 답을 읽지 않고**
/// 정답으로 눈이 갑니다. 한 번 누르는 사이에 「내가 무엇을 골랐더라」가 한 박자 남습니다.
///
/// - Note: 붉은색은 **이 창 안에서만** 씁니다. 목록과 결과 화면의 「다시 볼 문제」는
///   여전히 시그니처 색입니다 — 그쪽은 「틀렸다」가 아니라 「또 만날 문제」이기 때문입니다.
///
/// - Note: 표시가 ❌ 가 아니라 👉 인 이유 — 화면에 「틀렸다」를 쓰지 않기로 한 원칙과
///   「분명하게 짚어 준다」 사이의 절충입니다. **가리키기만 하고 나무라지 않습니다.**
struct FeedbackSheet: View {
    let feedback: QuizSession.IncorrectCommentary
    let onNext: () -> Void

    /// 「정답 보기」를 눌렀는가.
    @State private var showsAnswer = false

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 두 제목의 글자 크기. **고르신 답과 정답이 같은 크기여야** 나란히 읽힙니다.
    private static let titleSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("오답 해설")
                        .font(.system(size: Self.titleSize, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    chosenBlock
                    if showsAnswer { answerBlock }
                }
                .padding(.top, 32)
            }

            Spacer(minLength: 12)

            if showsAnswer {
                PrimaryActionButton(title: "다음 문제  →") { onNext() }
            } else {
                PrimaryActionButton(title: "정답 보기") {
                    withAnimation(.easeOut(duration: 0.25)) { showsAnswer = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .background(Color.white)
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    // MARK: - 1박자 — 고르신 답

    /// 고른 답과 **그것이 무엇인지.**
    ///
    /// 설명이 `nil` 이면(오타·O/X 라벨처럼 어느 문항의 정답도 아닐 때) 고른 답만 보입니다.
    private var chosenBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👉 고르신 답 - \(feedback.selectedAnswer)")
                .font(.system(size: Self.titleSize, weight: .bold))
                .foregroundStyle(AppColor.wrongAccent)
                .fixedSize(horizontal: false, vertical: true)

            if feedback.selectedNote != nil {
                Text(noteText).modifier(BodyStyle())
            } else if feedback.expectsNote {
                // 올 예정이라 자리를 비워 두고 기다린다.
                body(feedback.waitingLine)
                    .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.wrongBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 2박자 — 정답

    /// 정답과 해설.
    private var answerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✅ 정답 - \(feedback.correctAnswer)")
                .font(.system(size: Self.titleSize, weight: .bold))
                .foregroundStyle(AppColor.answerAccent)
                .fixedSize(horizontal: false, vertical: true)

            commentary
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.answerBackground, in: RoundedRectangle(cornerRadius: 16))
        .transition(.opacity)
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.**
    ///
    /// 같은 뷰에 두고 애니메이션만 끄는 방법은 통하지 않습니다 —
    /// `repeatForever` 는 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 계속 돕니다.
    /// **뷰를 통째로 갈아 끼우면** 맥동하던 뷰가 사라지므로 확실히 멈춥니다.
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            Text(commentaryText).modifier(BodyStyle())
        } else {
            body(feedback.commentary)
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }

    /// 본문 한 줄. **글은 검정이고, 칠하는 것은 낱말뿐입니다.**
    private func body(_ text: String) -> some View {
        Text(text).modifier(BodyStyle())
    }

    /// 정답 해설. 글은 검정이고 **정답 낱말만 파랑**이다.
    private var commentaryText: AttributedString {
        highlight(feedback.commentary,
                  word: feedback.correctAnswer,
                  color: AppColor.answerAccent)
    }

    /// 고른 답 설명. 글은 검정이고 **고른 낱말만 붉은색**이다.
    private var noteText: AttributedString {
        highlight(feedback.selectedNote ?? "",
                  word: feedback.selectedAnswer,
                  color: AppColor.wrongAccent)
    }

    /// 글 속의 낱말을 찾아 칠한다.
    ///
    /// 같은 낱말이 **제목과 글 속 두 곳**에서 같은 색으로 보이면 눈이 그 색을 그 낱말로
    /// 배웁니다. 한 곳만 칠하면 그냥 장식이 됩니다.
    ///
    /// - Note: 첫 번째만이 아니라 **나오는 곳마다** 칠합니다. 낱말이 비어 있으면 그냥 둡니다.
    private func highlight(_ sentence: String, word: String, color: Color) -> AttributedString {
        var text = AttributedString(sentence)
        guard !word.isEmpty else { return text }

        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let found = text[searchStart..<text.endIndex].range(of: word) {
            text[found].foregroundColor = color
            text[found].font = .system(size: 22, weight: .bold)
            searchStart = found.upperBound
        }
        return text
    }
}

#Preview("정답 보기 전") {
    FeedbackSheet(
        feedback: .init(
            selectedAnswer: "개천절",
            selectedNote: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "추석",
            commentary: "추석은 가을 저녁이라는 뜻이에요. 한가위라고도 불러요."),
        onNext: {})
}

#Preview("설명이 없을 때") {
    FeedbackSheet(
        feedback: .init(
            selectedAnswer: "고죠선",
            selectedNote: nil,
            waitingLine: "천천히 보면 돼요. 같이 살펴볼게요. 🍀",
            expectsNote: false,
            correctAnswer: "고조선",
            commentary: "고는 옛날이라는 뜻이에요. 도읍은 아사달이었어요."),
        onNext: {})
}

// MARK: - 두 칸이 함께 쓰는 것

/// 모달 본문의 글꼴. 고른 답 설명과 정답 해설이 **같은 모양**이어야 합니다.
private struct BodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.black)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// 아직 안 온 글을 **옅게 맥동시킨다.**
    ///
    /// 글이 도착하면 부르는 쪽에서 **다른 뷰로 갈아 끼웁니다** — `repeatForever` 는
    /// 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 멈추지 않기 때문입니다.
    func pulsingWhileWaiting(reduceMotion: Bool, isPulsing: Binding<Bool>) -> some View {
        opacity(reduceMotion ? 0.45 : (isPulsing.wrappedValue ? 0.6 : 0.25))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isPulsing.wrappedValue)
            .onAppear { isPulsing.wrappedValue = true }
    }
}
