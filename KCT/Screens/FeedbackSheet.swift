//
//  FeedbackSheet.swift
//  KCT
//
//  역할 : 틀렸을 때 고른 답을 먼저 짚어 주고, 눌러야 정답을 보여주는 모달
//  요점 : 「오답」·「정답」 낱말 칸(제목 박스)을 없애고, 제목 한 줄 + 낱말 배지 두 개로
//        비교 인지를 대신한다 — 해설만 나란히 있어도 비교가 되기 때문이다
//
//  ── 구성 ──────────────────────────────────────────────
//  FeedbackSheet
//  ├─ feedback         고른 답 · 고른 답 설명 · 정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext           「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ showsAnswer      「정답 보기」를 눌렀는가. 두 박자를 가른다
//  ├─ isPulsing        기다리는 동안 맥동시키는 깃발
//  ├─ title            시트 맨 위 제목 한 줄. 박자에 따라 문구가 바뀐다
//  ├─ notesCard        낱말 배지 + 설명 두 줄을 감싸는 흰 카드 하나 (완전 불투명)
//  ├─ noteRow(...)     이모지(❌/✅) + 낱말 배지 + 그 아래 설명 한 덩어리
//  ├─ commentary        기다릴 때와 도착한 뒤가 서로 다른 뷰
//  └─ highlight(_:word:color:size:)  글 속의 낱말만 칠한다 — 배지와 이중으로 표시한다
//
//  파일 안의 도우미
//  ├─ BodyStyle            두 설명이 함께 쓰는 본문 글꼴 (크기를 인자로 받는다)
//  └─ pulsingWhileWaiting  아직 안 온 글을 옅게 맥동시키는 수식어
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.feedback 이 생기면 이 창을 띄운다
//    → 1박자 : 제목 「오답 해설」 + 오답 배지·설명만. 버튼은 「정답 보기」
//    → 「정답 보기」를 누르면
//    → 2박자 : 제목이 「오답 및 정답 비교 해설」로 바뀌고 정답 배지·해설이 이어 붙는다.
//             버튼은 「다음 문제」
//    → 「다음 문제」를 누르면 onNext() 로 위에 알린다
//
//  ── 이 구조를 고른 이유 (11차, 2026-09) ───────────────
//  10차에서는 "개천절 → 추석" 처럼 두 낱말을 한 줄에 나란히 놓아 낱말 칸을
//  없앴다. 그런데 오답이 "고구려, 백제, 신라" 처럼 길어지면 한 줄 대조가
//  줄바꿈되면서 어색해졌다. 그래서 "타이틀 박스 없이 해설만 있어도 비교가
//  되지 않을까"를 데모 3개로 확인했고, **낱말을 큰 두 줄로 나란히 놓는 대신
//  줄마다 작은 배지로 앞세우는 안(시안 3)** 을 골랐다.
//
//  이 안을 고른 이유는 셋이다.
//    1. 배지가 낱말 사전 패널(GlossaryPanel)의 배지와 같은 모양(코너 반경 7,
//       굵은 글자)이라 앱 전체가 한 언어로 보인다.
//    2. 낱말이 아무리 길어도(예: "고구려, 백제, 신라") 배지 폭이 늘어날 뿐
//       줄 구조가 안 깨진다 — 지난번 "글자를 줄이거나 말줄임표로 자르는" 안보다
//       안전하다. 정답을 자르면 오답과 구분이 안 되는 경우가 생기기 때문에
//       말줄임표 안은 애초에 채택하지 않았다.
//    3. **해설 문장에 정답 낱말이 아예 안 나오는 문항이 있다** — 모델이 만든
//       문장이라 항상 낱말을 포함한다는 보장이 없다(예: 정답 "고조선", 해설
//       "고는 옛날이라는 뜻이에요. 도읍은 아사달이었어요." 에는 "고조선"이
//       한 번도 안 나온다). 배지는 문장과 별개로 낱말을 항상 보여주므로 이
//       경우에도 정답이 화면에서 사라지지 않는다. 문장 속 낱말도 여전히
//       색칠한다(`highlight`) — 낱말이 문장에 있을 때는 배지·문장 두 곳이
//       같은 색으로 보여 눈이 그 색을 그 낱말로 배우고, 없을 때는 배지가
//       혼자 그 역할을 떠맡는다. 데모에서는 보기 좋으라고 문장 앞의 낱말을
//       손으로 지웠지만, 실제 문장은 모델이 매번 다르게 쓰므로 "앞 낱말만
//       지운다" 같은 규칙은 안전하지 않아 코드에는 넣지 않았다.
//
//  오답 설명만 22 → **19pt** 로 낮추는 안(실측상 ≈46pt 절약, 3줄→2줄)으로
//  시작했지만, "정답은 크게·오답은 작게"라는 비대칭이 오히려 어색하다는
//  피드백을 받아 **정답 해설도 19pt로 맞춰 전체를 오답 기준으로 통일했다**
//  (11차 후속). 배지 글자 크기도 같이 19pt로 낮춰 배지·설명이 한 크기로
//  보이게 했다. 덕분에 393pt급 작은 기기에서의 여유도 더 늘었다 — 정답
//  해설이 길 때도 이제 19pt가 적용되기 때문이다.
//
//  ── 아직 반영 안 한 것 ─────────────────────────────────
//  이전 라운드에서 나온 "제목과 모달 사이 여백을 조금 더" · "다음 문제 버튼을
//  조금 내려서 콘텐츠 공간 확보" 요청은 이번 변경에 포함하지 않았다. 이번
//  라운드가 그 요청들을 대체하는 것인지 따로 확인이 필요해서다.
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
/// | 박자 | 제목 | 배지·설명 | 버튼 |
/// |---|---|---|---|
/// | 1 | 오답 해설 | ❌ 고른 답 배지 + 설명만 | 「정답 보기」 |
/// | 2 | 오답 및 정답 비교 해설 | 위 + ✅ 정답 배지 + 해설 | 「다음 문제」 |
///
/// 한 화면에 다 쏟지 않는 이유 — 정답이 처음부터 보이면 **고른 답을 읽지 않고**
/// 정답으로 눈이 갑니다. 한 번 누르는 사이에 「내가 무엇을 골랐더라」가 한 박자 남습니다.
///
/// - Note: 분홍·하늘색은 **이 창 안에서만** 씁니다. 목록과 결과 화면의 「다시 볼 문제」는
///   여전히 시그니처 색입니다 — 그쪽은 「틀렸다」가 아니라 「또 만날 문제」이기 때문입니다.
struct FeedbackSheet: View {
    let feedback: QuizSession.IncorrectCommentary
    let onNext: () -> Void

    /// 「정답 보기」를 눌렀는가.
    @State private var showsAnswer = false

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 버튼 높이. 터치 목표 1cm(≈64pt) 권장에 맞춘 값 — 기본값 56pt 보다 크다.
    private static let buttonHeight: CGFloat = 64

    /// 이모지(❌/✅) 크기.
    private static let markSize: CGFloat = 20

    /// 시트 맨 위 제목 글자 크기.
    private static let titleSize: CGFloat = 21

    /// 낱말 배지 · 오답 설명 · 정답 해설이 함께 쓰는 글자 크기.
    ///
    /// 처음에는 정답 해설만 22pt로 더 크게 뒀다("정답은 기억해야 하니 크게,
    /// 오답은 인식만 되면 되니 작게"라는 인지 연구 근거였다). 그런데 실제
    /// 화면에서 보니 정답·오답 글자 크기가 다른 것이 비대칭으로 느껴진다는
    /// 피드백을 받아 오답 크기(19pt)를 기준으로 전체를 맞췄고, 그 직후 그
    /// 기준 자체가 너무 작다는 피드백을 받아 **21pt로 2pt 올렸다.** 배지도
    /// 같은 크기라 배지·설명이 한 몸처럼 보인다.
    ///
    /// - Note: 아래 `BodyStyle`의 줄간격(`lineSpacing`)은 19pt·22pt 두 값만
    ///   CSS 데모로 실측해 둔 것이라, 21pt는 19pt쪽 줄간격(7)을 그대로 쓴
    ///   근사값이다. 22pt에 더 가까워졌으니 작은 기기에서의 여유는 19pt일
    ///   때보다 다시 줄어든다 — 정확한 pt는 컴파일 환경이 없어 못 쟀다.
    private static let noteSize: CGFloat = 21

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    title
                    notesCard
                }
                .padding(.top, 16)
            }

            // 버튼을 시트 바닥 쪽으로 살짝 내렸다 — 아래 여백(24 → 14)과 최소
            // 간격(12 → 8)을 함께 줄여, 그만큼 위 콘텐츠가 쓸 공간을 넓혔다.
            Spacer(minLength: 8)

            if showsAnswer {
                PrimaryActionButton(title: "다음 문제  →", minHeight: Self.buttonHeight) { onNext() }
            } else {
                PrimaryActionButton(title: "정답 보기", minHeight: Self.buttonHeight) {
                    withAnimation(.easeOut(duration: 0.25)) { showsAnswer = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        // 원래 낱말 해설(GlossaryPanel)과 정확히 같은 값(0.5)이었다. 카드를 완전
        // 불투명한 흰색으로 바꾸고 배지 색도 옅게 만들면서 보라가 상대적으로 연하게
        // 느껴진다는 피드백을 받아 0.5 → 0.58 → 0.65 → **0.75**로 계속 올렸다.
        // GlossaryPanel과 항상 같은 값을 쓴다 — 낱말 해설 쪽도 매번 같이 올렸다.
        // 시트의 진짜 배경 자체를 바꾸는 것이라 .background(...) 가 아니라
        // .presentationBackground(...) 를 쓴다.
        .presentationBackground(AppColor.signature.opacity(0.75))
        // 글로서리 패널과 같은 이유로 켠다 — GlossaryPanel.swift 의 주석대로,
        // iOS는 "안 어둡게"와 "뒤도 탭 가능"을 한 세트로만 제공해서 어둡기만
        // 따로 줄이는 공식 방법이 없다. 이걸 켜야 뒤 문제 화면이 어둡게
        // 음영지지 않고 밝게 비친다.
        .presentationBackgroundInteraction(.enabled)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }

    // MARK: - 제목

    /// 시트 맨 위 제목 한 줄. 1박자에는 아직 정답이 없으므로 "오답 해설",
    /// 「정답 보기」를 누르면 "오답 및 정답 비교 해설"로 바뀐다.
    private var title: some View {
        Text(showsAnswer ? "오답 및 정답 비교 해설" : "오답 해설")
            .font(.system(size: Self.titleSize, weight: .bold))
            .foregroundStyle(.white.opacity(0.96))
    }

    // MARK: - 해설 카드

    /// 낱말 배지 + 설명 줄들을 감싸는 카드 하나.
    ///
    /// 10차의 "낱말 대조 줄"(제목 칸)을 없애고, 그 자리에 있던 낱말을 각 설명
    /// 줄 머리의 배지로 옮겼다 — 칸을 하나 더 그리는 게 아니라 **줄의 머리를
    /// 낱말로 바꾸는 것**이라 높이가 거의 늘지 않는다.
    ///
    /// 카드 배경은 원래 `Color.white.opacity(0.92)`로 8% 투명했다(뒤 보라
    /// 배경이 살짝 비쳐 보임). 낱말 배지·오답 해설 모두 그 비침 때문에
    /// 흐릿해 보인다는 피드백을 받아 **완전한 흰색으로 바꿨다** — 배지 색을
    /// 옅게(60% 밝게) 바꾼 지 얼마 안 됐는데, 옅어진 배지가 비치는 카드
    /// 위에서는 더 흐릿하게 보였을 것이다.
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            // 쓸 설명이 하나도 없으면 오답 줄 자체를 그리지 않는다 — 안 그리면
            // 빈 줄만 남아 고장난 것처럼 보인다.
            if hasChosenNote {
                noteRow(mark: "❌",
                        badgeBackground: AppColor.wrongHeader,
                        badgeText: AppColor.wrongAccent,
                        word: feedback.selectedAnswer) { chosenNote }
            }

            if showsAnswer {
                noteRow(mark: "✅",
                        badgeBackground: AppColor.answerHeader,
                        badgeText: AppColor.answerAccent,
                        word: feedback.correctAnswer) { commentary }
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 이모지 + 낱말 배지 + 그 아래 설명 한 덩어리.
    ///
    /// 배지는 낱말 사전 패널(GlossaryPanel)의 배지와 같은 코너 반경(7)·굵은
    /// 글자를 써서 같은 시각 언어로 보이게 했다. 색만 여기 맥락(오답 분홍 ·
    /// 정답 하늘)에 맞게 다르다.
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

    // MARK: - 설명 두 줄

    /// 고른 답 쪽에 그릴 것이 있는가. 설명이 이미 왔거나, 올 예정이거나.
    ///
    /// 둘 다 아니면(오타·O/X 라벨처럼 어느 문항의 정답도 아닐 때) 고른 답 줄은
    /// 통째로 없다 — 막대만 남기지 않기 위해 이 판단을 바깥으로 뺐다.
    private var hasChosenNote: Bool {
        feedback.selectedNote != nil || feedback.expectsNote
    }

    /// 고른 답 설명. 아직 안 왔으면 올 예정인 자리를 비워 두고 기다린다.
    @ViewBuilder
    private var chosenNote: some View {
        if feedback.selectedNote != nil {
            Text(noteText).modifier(BodyStyle(size: Self.noteSize))
        } else {
            body(feedback.waitingLine, size: Self.noteSize)
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.**
    ///
    /// 같은 뷰에 두고 애니메이션만 끄는 방법은 통하지 않습니다 —
    /// `repeatForever` 는 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 계속 돕니다.
    /// **뷰를 통째로 갈아 끼우면** 맥동하던 뷰가 사라지므로 확실히 멈춥니다.
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            Text(commentaryText).modifier(BodyStyle(size: Self.noteSize))
        } else {
            body(feedback.commentary)
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }

    /// 본문 한 줄. **글은 검정이고, 칠하는 것은 낱말뿐입니다.**
    private func body(_ text: String, size: CGFloat = Self.noteSize) -> some View {
        Text(text).modifier(BodyStyle(size: size))
    }

    /// 정답 해설. 글은 검정이고 **정답 낱말만 하늘색**이다.
    private var commentaryText: AttributedString {
        highlight(feedback.commentary,
                  word: feedback.correctAnswer,
                  color: AppColor.answerAccent,
                  size: Self.noteSize)
    }

    /// 고른 답 설명. 글은 검정이고 **고른 낱말만 분홍**이다.
    private var noteText: AttributedString {
        highlight(feedback.selectedNote ?? "",
                  word: feedback.selectedAnswer,
                  color: AppColor.wrongAccent,
                  size: Self.noteSize)
    }

    /// 글 속의 낱말을 찾아 칠한다.
    ///
    /// 같은 낱말이 **낱말 배지와 글 속 두 곳**에서 같은 색으로 보이면 눈이 그 색을 그
    /// 낱말로 배웁니다. 한 곳만 칠하면 그냥 장식이 됩니다. 문장에 낱말이 아예 없는
    /// 경우(모델이 쓴 문장이라 보장이 없다)에는 이 함수가 아무것도 칠하지 않지만,
    /// 배지가 낱말을 대신 보여주므로 정답 자체가 사라지지는 않습니다.
    ///
    /// - Note: 첫 번째만이 아니라 **나오는 곳마다** 칠합니다. 낱말이 비어 있으면 그냥 둡니다.
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

#Preview("정답 보기 전") {
    FeedbackSheet(
        feedback: .init(
            id: 11,
            selectedAnswer: "개천절",
            selectedNote: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "추석",
            commentary: "추석은 가을 저녁이라는 뜻이에요. 음력 8월 15일에 지내는 명절이에요. 한가위라고도 불러요."),
        onNext: {})
}

#Preview("설명이 없을 때") {
    FeedbackSheet(
        feedback: .init(
            id: 4,
            selectedAnswer: "고죠선",
            selectedNote: nil,
            waitingLine: "천천히 보면 돼요. 같이 살펴볼게요. 🍀",
            expectsNote: false,
            correctAnswer: "고조선",
            commentary: "고는 옛날이라는 뜻이에요. 도읍은 아사달이었어요."),
        onNext: {})
}

#Preview("긴 정답 — 고구려, 백제, 신라") {
    FeedbackSheet(
        feedback: .init(
            id: 27,
            selectedAnswer: "동지",
            selectedNote: "동지는 팥죽을 먹는 날이고 양력 12월 22일쯤이며 절기 이름이 있으며 겨울에 이르렀다는 뜻이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "고구려, 백제, 신라",
            commentary: "고구려, 백제, 신라입니다. 이 세 나라가 있었습니다. 신라가 이 세 나라를 하나로 합쳤습니다."),
        onNext: {})
}

// MARK: - 두 설명이 함께 쓰는 것

/// 모달 본문의 글꼴. 고른 답 설명과 정답 해설이 **같은 모양·같은 크기**를 쓴다 —
/// 11차 후속에서 오답(19pt)·정답(22pt) 크기를 다르게 뒀던 비대칭을 걷어내고
/// 오답 크기로 통일했다. `size` 인자는 남겨 뒀다 — 다시 갈라야 할 때를 위해서다.
///
/// `lineSpacing(7)` 은 CSS 데모에서 실측한 19pt 줄간격(1.5824배)을 SwiftUI의
/// "줄 사이 추가 간격" 값으로 환산한 것이다. 22pt 로 다시 쓸 일이 생기면 8로
/// 돌아가야 한다 — 그때 쓰던 값도 함께 남겨 둔다.
///
/// - Note: `private` 이 아니다. 11차 후속(정답 해설 모달)에서 ``CorrectAnswerSheet`` 가
///   "디자인을 오답 해설과 똑같이" 맞추려고 이 스타일을 그대로 가져다 쓴다.
struct BodyStyle: ViewModifier {
    var size: CGFloat = 21

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.black)
            .lineSpacing(size >= 22 ? 8 : 7)
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
