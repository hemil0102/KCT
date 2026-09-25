//
//  TrueFalseSheet.swift
//  KCT
//
//  역할 : O/X 를 누르자마자 올라와, 바른 문장이 무엇인지 · 왜 그런지를 보여주는 모달
//  요점 : 맞혔든 틀렸든 **바른 문장만** 보여준다. 무엇을 틀렸는지는 문제 화면의
//        버튼 색(``QuizSession/immediateVerdict``)이 이미 말해 준다. **맞았을
//        때와 틀렸을 때가 ``CorrectAnswerSheet``와 같은 접힘 → 펼침 두 박자를
//        똑같이 쓴다** — 다른 점은 접혔을 때 headline 글자 한 줄뿐이다.
//
//  ── 구성 ──────────────────────────────────────────────
//  TrueFalseSheet
//  ├─ feedback              O/X 판정 · 바른 문장 · 해설 (QuizSession 이 만든다)
//  ├─ onNext                「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ startsExpanded        미리보기 전용 — 처음부터 펼친 채로 띄운다
//  ├─ isExpanded            해설을 펼쳤는가 — collapsedContent / expandedContent 를 가른다
//  ├─ hasRequestedReveal    「정답 해설 보기」를 눌렀는가 (한 번 켜지면 계속 켜져 있다)
//  ├─ isLoadingCommentary   지금 로딩 인디케이터를 보여줄지
//  ├─ selectedDetent        지금 시트 크기. 접힘(collapsedHeight) ↔ 펼침(expandedDetent)
//  ├─ expandedHeight        해설 내용에 딱 맞춘 높이 — 누르기 전부터 계속 캐시된다
//  ├─ appliedHeight         시트를 실제로 옮긴 적 있는 높이
//  ├─ expandedDetent        펼침 시트가 쓸 크기
//  ├─ isPulsing             기다리는 동안 맥동시키는 깃발
//  ├─ collapsedContent      headline(맞았으면 "잘 맞추셨어요!", 틀렸으면 "정답
//  │                        해설") + 「정답 해설 보기」(로딩 중엔 인디케이터)·
//  │                        「다음 문제」 두 버튼
//  ├─ reveal()              이미 준비돼 있으면 곧장 펴고, 아니면 hasRequestedReveal 만 켠다
//  ├─ expandedInnerContent  제목("정답 해설") + card
//  ├─ backgroundMeasurement 접힌 동안 화면 밖(숨김)으로 계속 그려 두는
//  │                        expandedInnerContent 사본
//  ├─ expandedContent       expandedInnerContent + 「다음 문제」
//  ├─ updateExpandedHeight  잰 내용 높이 + 여백으로 expandedHeight 를 항상 캐시하고,
//  │                        hasRequestedReveal 이 켜져 있을 때만 selectedDetent 도 바꾼다
//  ├─ card                  sentenceRow + Divider + commentary 를 감싸는 흰 카드
//  ├─ sentenceRow           ✓ + 바르게 고친 문장 — 맞혔든 틀렸든 이 한 줄만 보여준다
//  └─ commentary            모델이 쓴 정답 해설. 기다릴 때와 도착한 뒤가 서로 다른 뷰
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 에서 맞아요/아니에요를 누른다
//    → 누른 버튼이 곧바로 녹색 ✓ 또는 붉은색 ✕ 로 바뀐다 (QuizSession.immediateVerdict)
//    → 0.6초 뒤 이 창이 접힌 채로 올라온다 — 해설은 그 사이에도 뒤에서 계속
//      만들어지고 있다
//    → 접힘: headline(맞았으면 "잘 맞추셨어요!", 틀렸으면 "정답 해설") +
//      「정답 해설 보기」+ 「다음 문제」
//        ├─ 「정답 해설 보기」를 누르면 → reveal() — 해설이 이미 준비돼 있으면
//        │     로딩 없이 곧장 펴지고, 아직이면 버튼이 도는 인디케이터로 바뀐다
//        └─ 「다음 문제」를 누르면 → onNext() — 해설을 안 보고 바로 넘어간다
//    → 펼침: 제목("정답 해설") + ✓ 바르게 고친 문장 + 해설 + 「다음 문제」
//
//  ── 이 구조를 고른 이유 (11차 4-30, 2026-09-24) ──────────
//  예전에는 O/X 도 FeedbackSheet 를 그대로 썼다. 그러면 배지가 「❌ 맞아요」로 떠서
//  **무엇에 대해 맞다고 한 것인지**가 사라졌고, 9/14 에 어머니가 「왜 틀렸지?」 하셨다.
//  리서치(Pashler 2005 — 정답을 보여줘야 남는다, Skurnik 2005 — 노년층에게 틀린 문장을
//  되풀이하면 참으로 기억될 수 있다)를 거쳐 데모 3안 중 「빨간 펜」안을 골랐다.
//
//  ── 다시 손본 이유 (2026-09-25 갱신) ──────────────────
//  「고르신 답」 배지 줄을 없앴다 — 맞았는지는 문제 화면의 버튼 색이 이미 말해 준다.
//  처음엔 틀렸을 때 본 문장(✕)과 바른 문장(✓)을 두 줄로 같이 보여줬지만, 곧바로
//  "오답일 때도 정답만 보여주자"로 다시 정리했다 — 바른 문장 한 줄이면 충분하다.
//  제목도 틀렸을 때 「오답 해설」 대신 「정답 해설」로 바꿨다. 아이콘은 이모지
//  (✅/❌) 대신 다른 두 해설 창과 같은 SF Symbol(`checkmark.app.fill`)로, 글자
//  크기는 21 → 24로 올렸다. 정답 색도 ``CorrectAnswerSheet``·``FeedbackSheet``와
//  같은 전용 ``correctAccent``로 바꿨다 — 세 해설 창의 정답 녹색이 모두 같다.
//
//  ── 두 번째로 손본 이유 (2026-09-25 재갱신) ───────────
//  "모든 문제의 모달 해설창은 접으면 접히고 정답 해설 보기 버튼을 보여줄 것"
//  이라는 요청으로, 맞혔든 틀렸든 ``CorrectAnswerSheet``와 같은 접힘 ↔ 펼침
//  두 박자를 한 벌로 넣었다.
//
//  ── 세 번째로 손본 이유 (2026-09-25 삼차 갱신, 갈림) ─────
//  "OX 문제도 오답을 골랐을 때는 바로 해설이 보이는 모달로 올라왔으면 좋겠고,
//  맞혔을 때 뜨는 해설 모달은 지금처럼 접혔다가 정답 해설 보기 버튼으로
//  펼쳐지는 채로 남겨 달라"는 요청으로, 맞았을 때와 틀렸을 때의 구조를 한동안
//  두 개의 하위 뷰(``CorrectTrueFalseContent``·``DirectTrueFalseContent``)로 갈라
//  뒀었다 — 틀렸을 때는 버튼 없이 바로 열리는 구조였다.
//
//  ── 네 번째로 손본 이유 (2026-09-25 사차 갱신, 되돌림) ────
//  "오답 해설도 다시 접혀야 한다"는 요청으로 세 번째 갈림을 다시 합쳤다.
//  맞았을 때와 틀렸을 때가 이제 다시 **완전히 같은 접힘 → 펼침 구조**를
//  쓰므로, 두 하위 뷰로 가를 이유가 없어져 하나의 `TrueFalseSheet` 구조체로
//  되돌렸다(2026-09-25 재갱신 때의 구조와 같다). 남은 차이는 접혔을 때
//  headline 한 줄뿐이다 — 맞았으면 "잘 맞추셨어요!"(축하), 틀렸으면 "정답
//  해설"(``FeedbackSheet``와 같은 방식 — 이 창엔 축하할 일이 없으니 대신 창의
//  정체를 크게 보여준다).
//
//  ── 다섯 번째로 손본 이유 (2026-09-25 오차 갱신) ─────────
//  정답: 접힌 채로 뜬다 → 「정답 해설 보기」 → 펼침.
//  오답: **펼친 채로** 뜬다(해설이 바로 보인다) → 「접기」나 아래로 내리면 접힌다
//        → 접힌 화면의 「정답 해설 보기」로 다시 펼 수 있다.
//  펼친 화면 제목 옆에 「접기」를 달았고, 접히면 hasRequestedReveal 을 되돌려
//  몇 번이든 다시 펼 수 있게 했다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.trueFalseFeedback 이 있는 동안
//  기대는 것    : TrueFalseCommentary, AppColor, CorrectionText,
//                CommentarySheet.swift 의 부품들, PrimaryActionButton · SecondaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// O/X 해설 창. ``CorrectAnswerSheet``와 같은 접힘 → 펼침 두 박자를 맞았을 때·
/// 틀렸을 때 모두에 쓴다 — 다른 점은 접혔을 때 headline 한 줄뿐이다(맞았으면
/// "잘 맞추셨어요!", 틀렸으면 "정답 해설").
struct TrueFalseSheet: View {
    let feedback: TrueFalseCommentary
    let onNext: () -> Void

    /// 처음부터 펼친 채로 보여줄지. **미리보기 전용**이다.
    var startsExpanded: Bool = false

    @State private var isExpanded: Bool
    @State private var hasRequestedReveal = false

    private var isLoadingCommentary: Bool {
        hasRequestedReveal && !feedback.isReady
    }

    @State private var selectedDetent: PresentationDetent
    @State private var expandedHeight: CGFloat = 0
    @State private var appliedHeight: CGFloat = 0

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let collapsedHeight: CGFloat = 260

    private var expandedDetent: PresentationDetent {
        expandedHeight > 0 ? .height(expandedHeight) : .medium
    }

    private static let expandedChromeHeight: CGFloat = 8 + CommentaryMetrics.buttonHeight + 14

    private static let titleSize: CGFloat = 24
    private static let headlineSize: CGFloat = CommentaryMetrics.titleSize * 1.5
    private static let bodySize: CGFloat = 24
    private static let markSize: CGFloat = bodySize
    private static let correctAccent = Color(red: 0.396, green: 0.769, blue: 0.400)

    init(feedback: TrueFalseCommentary,
         onNext: @escaping () -> Void,
         startsExpanded: Bool? = nil) {
        // 따로 정하지 않으면(실제 사용) 틀렸을 때 펼친 채로, 맞았을 때 접힌 채로 시작한다.
        let expanded = startsExpanded ?? !feedback.isCorrect
        self.feedback = feedback
        self.onNext = onNext
        self.startsExpanded = expanded
        _isExpanded = State(initialValue: expanded)
        _hasRequestedReveal = State(initialValue: expanded)
        _selectedDetent = State(initialValue: expanded ? .medium : .height(Self.collapsedHeight))
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
        .overlay(alignment: .topLeading) { backgroundMeasurement }
        .commentarySheetChrome(
            detents: [.height(Self.collapsedHeight), expandedDetent],
            selection: $selectedDetent)
        .animation(.easeInOut(duration: 3.0), value: selectedDetent)
        .onChange(of: selectedDetent) { _, newValue in
            let collapsed = (newValue == .height(Self.collapsedHeight))
            if collapsed {
                // 접히면 다시 「정답 해설 보기」로 펼 수 있게 되돌려 둔다.
                hasRequestedReveal = false
                appliedHeight = Self.collapsedHeight
            }
            withAnimation(.easeOut(duration: 0.25)) {
                isExpanded = !collapsed
            }
        }
    }

    // MARK: - 접힘: headline + 버튼 둘

    /// 접혔을 때 보이는 내용. headline 한 줄(맞았으면 "잘 맞추셨어요!", 틀렸으면
    /// "정답 해설") 아래 버튼 두 개를 세로로 둔다.
    private var collapsedContent: some View {
        VStack(spacing: 16) {
            Text(feedback.isCorrect ? "잘 맞추셨어요!" : "정답 해설")
                .font(.system(size: Self.headlineSize, weight: .bold))
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

    private func reveal() {
        guard !isExpanded else { return }
        hasRequestedReveal = true

        if feedback.isReady, expandedHeight > 0 {
            withAnimation(.easeInOut(duration: 3.0)) {
                appliedHeight = expandedHeight
                selectedDetent = .height(expandedHeight)
            }
        }
    }

    /// 펼친 화면의 「접기」. 시트를 접힘 높이로 내리면 onChange 가 나머지를 한다.
    private func collapse() {
        guard isExpanded else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            selectedDetent = .height(Self.collapsedHeight)
        }
    }

    // MARK: - 펼침: 해설

    /// 제목("정답 해설") + 오른쪽 「접기」. 숨은 측정 사본도 같은 줄을 그리므로
    /// 잰 높이와 실제 높이가 어긋나지 않는다.
    private var titleRow: some View {
        HStack(alignment: .center) {
            CommentarySheetTitle(text: "정답 해설", size: Self.titleSize)
            Spacer(minLength: 8)
            Button(action: collapse) {
                Label("접기", systemImage: "chevron.down")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
            }
            .buttonStyle(.plain)
        }
    }

    private var expandedInnerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            card
        }
        .padding(.top, 16)
    }

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

            Color.clear.frame(height: 8)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
    }

    private func updateExpandedHeight(contentHeight: CGFloat) {
        // 접혀 있을 땐 해설이 다 와야 재고, 이미 펼쳐져 있으면(오답은 펼친 채로
        // 시작한다) 기다리는 문구 높이에도 맞춘다.
        guard contentHeight > 0, feedback.isReady || isExpanded else { return }

        let target = (contentHeight + Self.expandedChromeHeight).rounded()
        expandedHeight = target

        guard hasRequestedReveal, target != appliedHeight else { return }

        withAnimation(.easeInOut(duration: 3.0)) {
            appliedHeight = target
            selectedDetent = .height(target)
        }
    }

    // MARK: - 해설 카드

    private var card: some View {
        CommentaryCard {
            sentenceRow
            Divider()
            commentary
        }
    }

    private var sentenceRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.app.fill")
                .font(.system(size: Self.markSize))
                .foregroundStyle(Self.correctAccent)
                .padding(.top, 2)

            CorrectionText(
                before: feedback.sentenceBefore,
                struck: nil,
                corrected: feedback.correctAnswer,
                after: feedback.sentenceAfter,
                font: .systemFont(ofSize: Self.bodySize, weight: .semibold),
                lineSpacing: CommentaryMetrics.lineSpacing(for: Self.bodySize),
                struckColor: UIColor(AppColor.wrongAccent),
                correctedColor: UIColor(Self.correctAccent),
                correctedBackground: .clear)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            CommentaryBodyText(text: feedback.commentary,
                               word: feedback.correctAnswer,
                               color: Self.correctAccent,
                               size: Self.bodySize)
        } else {
            Text(feedback.commentary)
                .modifier(CommentaryBodyStyle(size: Self.bodySize))
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }
}

#Preview("맞힘 — 접힘") {
    TrueFalseSheet(
        feedback: .init(
            id: 13, pickedLabel: "아니에요", isCorrect: true,
            statementWasTrue: false, shownCandidate: "삼일절", correctAnswer: "광복절",
            sentenceBefore: "1945년에 일본으로부터 나라를 되찾은 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {})
}

#Preview("맞힘 — 펼침") {
    TrueFalseSheet(
        feedback: .init(
            id: 13, pickedLabel: "아니에요", isCorrect: true,
            statementWasTrue: false, shownCandidate: "삼일절", correctAnswer: "광복절",
            sentenceBefore: "1945년에 일본으로부터 나라를 되찾은 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: "광복절은 일본에게서 나라를 되찾은 날이에요. 양력 8월 15일이고, 광복은 빛을 되찾았다는 뜻이에요."),
        onNext: {},
        startsExpanded: true)
}

#Preview("틀림 — 접힘") {
    TrueFalseSheet(
        feedback: .init(
            id: 12, pickedLabel: "맞아요", isCorrect: false,
            statementWasTrue: false, shownCandidate: "개천절", correctAnswer: "제헌절",
            sentenceBefore: "대한민국 헌법을 만들어 공포한 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {},
        startsExpanded: false)
}

#Preview("틀림 — 펼침") {
    TrueFalseSheet(
        feedback: .init(
            id: 12, pickedLabel: "맞아요", isCorrect: false,
            statementWasTrue: false, shownCandidate: "개천절", correctAnswer: "제헌절",
            sentenceBefore: "대한민국 헌법을 만들어 공포한 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: "제헌절은 헌법을 처음 만들어 알린 날이에요. 양력 7월 17일이고, 제헌은 헌법을 만들었다는 뜻이에요."),
        onNext: {},
        startsExpanded: true)
}
