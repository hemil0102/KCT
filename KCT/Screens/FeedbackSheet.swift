//
//  FeedbackSheet.swift
//  KCT
//
//  역할 : 틀렸을 때 뜨는 모달. **정답만** 보여준다 — 무엇을 잘못 골랐는지는
//        보여주지 않는다(2026-09-25, "오답은 이제 안 보여줘도 된다").
//  요점 : ``CorrectAnswerSheet``와 완전히 같은 접힘 → 펼침 두 박자다. 처음엔
//        접힌 채로 큰 "정답 해설" 글자 + 버튼 두 개만 보여준다. 해설은 이 창이
//        뜨기 훨씬 전, 문제가 화면에 뜨는 순간부터 이미 뒤에서 만들어지고
//        있으므로(``QuizSession/prefetchExplanation(for:)``), 「정답 해설 보기」를
//        눌렀을 때 이미 다 와 있으면 **로딩 없이 곧장** 그 높이로 펼쳐지고,
//        아직이면 버튼이 도는 인디케이터로 바뀌었다가 해설이 도착하는 순간
//        **딱 한 번에** 그 높이로 펼쳐진다.
//
//  ── 구성 ──────────────────────────────────────────────
//  FeedbackSheet
//  ├─ feedback              고른 답 · 정답 · 해설 (QuizSession 이 만든다 — 고른 답 쪽
//  │                        필드는 이제 이 화면에서 안 쓰지만, 데이터 모델
//  │                        (IncorrectCommentary)은 그대로 둔다)
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
//  ├─ collapsedContent      큰 "정답 해설" 글자 + 「정답 해설 보기」(로딩 중엔
//  │                        인디케이터)·「다음 문제」 두 버튼
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
//  └─ commentary            해설 글. 기다릴 때와 도착한 뒤가 서로 다른 뷰(해설이
//                           끝내 실패하면 ``CommentaryPlaceholder/failed`` 문구가
//                           이 자리에 그대로 온다)
//
//  모양은 전부 DesignSystem/CommentarySheet.swift 에 있다 — CommentaryMetrics(크기)·
//  CommentarySheetTitle(제목)·CommentaryCard(흰 카드)·CommentaryRow(줄)·
//  CommentaryBodyText(양쪽 정렬 본문)·commentarySheetChrome(시트 외장).
//  **정답 해설 창(CorrectAnswerSheet)이 같은 부품을 쓴다 — 구조 자체도 이제
//  똑같다.**
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.feedback 이 생기면 이 창을 접힌 채로 띄운다
//    → 접힘: 큰 "정답 해설" 글자 + 「정답 해설 보기」+ 「다음 문제」
//        ├─ 이 순간부터 이미 해설이 뒤에서 만들어지고 있고, backgroundMeasurement
//        │     가 화면 밖에서 그 결과의 높이를 계속 잰다 — 버튼을 누르기 훨씬 전부터다
//        ├─ 「정답 해설 보기」를 누르면 → reveal()
//        │     ├─ 해설이 **이미 준비돼 있으면** → 로딩 없이 selectedDetent 를
//        │     │     바로 그 높이로 바꾼다 → 시트가 collapsedHeight 에서 곧장 커진다
//        │     └─ 아직이면 → hasRequestedReveal 만 켠다 → 버튼 글자가 도는
//        │           인디케이터로 바뀐다. 시트는 아직 collapsedHeight 그대로다 —
//        │           「다음 문제」는 로딩 중에도 계속 누를 수 있다
//        ├─ (로딩 중이었다면) 해설이 도착하면 updateExpandedHeight 가 진짜 높이를
//        │     계산해 딱 한 번 selectedDetent 를 그 높이로 바꾼다 → 시트가 그
//        │     높이로 곧장 애니메이션과 함께 커진다
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다 — 해설을 안 보고 바로 넘어간다
//    → 펼침: 제목("정답 해설") + ✅ 체크 아이콘 + 정답 낱말 + 해설 + 「다음 문제」
//        └─ 「다음 문제」를 누르면 → onNext() 로 위에 알린다
//
//  ── 다시 손본 이유 (2026-09-25 갱신) ──────────────────
//  "2지선다·4지선다·입력형 모두 오답일 때 정답만 보여주자, 오답은 이제 안
//  보여줘도 된다"는 요청으로, 「정답 보기」를 눌러야 나오던 2박자 구조와
//  고른 답(❌) 줄을 통째로 없앴다. 제목도 「오답 해설」/「오답 및 정답 비교
//  해설」 대신 항상 「정답 해설」이다.
//
//  ── 두 번째로 손본 이유 (2026-09-25 재갱신, 접힘/펼침 추가) ─
//  "모든 문제의 모달 해설창은 접으면 접히고 해설이 있다면 정답 해설 보기
//  버튼을 보여줄 것"이라는 요청으로 ``CorrectAnswerSheet``와 같은 접힘(축하
//  문구+버튼) ↔ 펼침(해설) 두 박자 구조를 넣었다.
//
//  ── 세 번째로 손본 이유 (2026-09-25 삼차 갱신, 접힘/펼침 되돌림) ─
//  "오답을 골랐을 때는 버튼을 눌러서 보는 게 아니라 바로 해설이 보이는
//  모달로 올라왔으면 한다"는 요청으로 접힘/펼침 두 박자를 걷어내고, 뜨자마자
//  곧바로 다 보여주는 구조로 한동안 바꿔 두었었다.
//
//  ── 네 번째로 손본 이유 (2026-09-25 사차 갱신, 되돌림의 되돌림) ─
//  "오답 해설도 다시 접혀야 한다"는 요청으로 세 번째 손질을 다시 걷어내고,
//  ``CorrectAnswerSheet``와 완전히 같은 접힘(headline+버튼 둘) → 펼침(해설)
//  구조로 되돌렸다. 다만 맞았을 때(CorrectAnswerSheet)의 "잘 맞추셨어요!"에
//  해당하는 축하 문구가 이 창엔 없으므로, 접힘 headline 자리엔 "정답 해설"
//  이라는 글자를 celebration 크기(제목의 1.5배)로 크게 보여주는 것으로
//  대신했다 — 어머니가 창이 뜨는 순간 "이건 정답 해설 창이구나"를 바로 알 수
//  있게 하려는 것이다. estimatedHeight 로 불렀던 어림값은 이제 다른 두 해설
//  창과 같은 이름(``collapsedHeight``)으로 되돌렸다.
//
//  ── 4지선다는 원래도 이 창을 쓰지 않는다 ──────────────
//  4지선다는 오답을 눌러도 그 자리에서 흔들리다 소거될 뿐(QuestionScreen),
//  submitCurrent() 자체가 불리지 않아 이 창(session.feedback)이 뜬 적이 없다.
//  정답을 고른 순간에만 채점되어 CorrectAnswerSheet 로 간다.
//
//  ── 다섯 번째로 손본 이유 (2026-09-25 오차 갱신) ─────────
//  정답: 접힌 채로 뜬다 → 「정답 해설 보기」 → 펼침.
//  오답: **펼친 채로** 뜬다(해설이 바로 보인다) → 「접기」나 아래로 내리면 접힌다
//        → 접힌 화면의 「정답 해설 보기」로 다시 펼 수 있다.
//  펼친 화면 제목 옆에 「접기」를 달았고, 접히면 hasRequestedReveal 을 되돌려
//  몇 번이든 다시 펼 수 있게 했다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.feedback 이 있는 동안
//  기대는 것    : IncorrectCommentary,
//                CommentarySheet.swift 의 부품들, PrimaryActionButton · SecondaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// 오답 직후에 올라오는 모달. **정답만 보여준다.**
///
/// ``CorrectAnswerSheet``와 같은 **접힘(headline + 버튼 둘) → 펼침(해설)** 두
/// 박자입니다. 해설은 이 창이 뜨는 순간부터 뒤에서 이미 만들어지고 있습니다.
/// 「정답 해설 보기」를 눌렀을 때 이미 다 와 있으면 **로딩 없이 곧장** 그
/// 높이로 펼쳐지고, 아직이면 버튼이 도는 인디케이터로 바뀌었다가 해설이
/// 도착하는 순간 **한 번에** 그 높이로 펼쳐집니다. 해설이 궁금하지 않으면
/// 로딩 중이라도 바로 「다음 문제」를 눌러 넘어갈 수 있습니다.
///
/// - Note: 녹색은 **이 창과 정답 창 안에서만** 씁니다. 목록과 결과 화면의
///   「다시 볼 문제」는 여전히 시그니처 색입니다 — 그쪽은 「틀렸다」가 아니라
///   「또 만날 문제」이기 때문입니다.
struct FeedbackSheet: View {
    let feedback: IncorrectCommentary
    let onNext: () -> Void

    /// 처음부터 펼친 채로 보여줄지. **미리보기 전용**이다 — 실제 사용에서는
    /// QuizView 가 이 시트를 띄울 때마다 항상 접힌 채로 시작한다.
    var startsExpanded: Bool = true

    /// 해설을 펼쳤는가. collapsedContent(headline + 버튼 둘) 와 expandedContent(해설)를 가른다.
    @State private var isExpanded: Bool

    /// 「정답 해설 보기」를 눌렀는가. **한 번 켜지면 계속 켜져 있다.**
    @State private var hasRequestedReveal = false

    /// 지금 로딩 인디케이터를 보여줘야 하는가 — 눌렀는데(`hasRequestedReveal`)
    /// 아직 해설이 안 왔을 때(`!feedback.isReady`)뿐이다. (``CorrectAnswerSheet``와 같은 이유)
    private var isLoadingCommentary: Bool {
        hasRequestedReveal && !feedback.isReady
    }

    /// 지금 시트 크기. `reveal()`과 `updateExpandedHeight`만 이 값을 바꾼다.
    @State private var selectedDetent: PresentationDetent

    /// 펼쳤을 때 해설 내용에 딱 맞춘 시트 높이. **눌리기 전부터** 계속 최신값으로
    /// 캐시된다.
    @State private var expandedHeight: CGFloat = 0

    /// 시트를 실제로 그 높이로 옮긴 적이 있다면 그 값 — 같은 높이로 또
    /// 애니메이션을 걸지 않도록 막는 용도다.
    @State private var appliedHeight: CGFloat = 0

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 접혔을 때(처음 열릴 때) 시트 높이. ``CorrectAnswerSheet/collapsedHeight``와
    /// 같은 값(260)을 그대로 쓴다 — "headline 한 줄 + 버튼 두 개" 구성이 똑같다.
    private static let collapsedHeight: CGFloat = 260

    /// 펼침 시트가 쓸 크기. (``CorrectAnswerSheet/expandedDetent``와 같은 이유)
    private var expandedDetent: PresentationDetent {
        expandedHeight > 0 ? .height(expandedHeight) : .medium
    }

    /// `expandedContent` 안에서 실제로 재는 것은 제목+카드 내용 높이뿐이다.
    /// 시트 전체 높이가 되려면 그 아래 고정된 부분들을 더해야 한다.
    private static let expandedChromeHeight: CGFloat = 8 + CommentaryMetrics.buttonHeight + 14

    /// 제목("정답 해설") 글자 크기. ``CorrectAnswerSheet``와 똑같이 24pt.
    private static let titleSize: CGFloat = 24

    /// 접혔을 때 headline("정답 해설") 글자 크기. 제목의 **1.5배**다 —
    /// ``CorrectAnswerSheet``의 「잘 맞추셨어요!」와 같은 자리를 차지하지만,
    /// 이 창엔 축하할 일이 없으므로 대신 이 창의 정체("정답 해설")를 크게 보여준다.
    private static let headlineSize: CGFloat = CommentaryMetrics.titleSize * 1.5

    /// 정답 마크·낱말 색. ``CorrectAnswerSheet``의 `correctAccent`와 **같은 값**이다.
    /// 저 창의 색을 바꾸면 여기도 같이 바꿔야 한다.
    private static let correctAccent = Color(red: 0.396, green: 0.769, blue: 0.400)

    /// 마크 아이콘·낱말 글자 크기. ``CorrectAnswerSheet``와 같은 28pt.
    private static let markAndWordSize: CGFloat = 28

    /// 해설 본문 글자 크기. 24pt.
    private static let bodySize: CGFloat = 24

    init(feedback: IncorrectCommentary,
         onNext: @escaping () -> Void,
         startsExpanded: Bool = true) {
        self.feedback = feedback
        self.onNext = onNext
        self.startsExpanded = startsExpanded
        _isExpanded = State(initialValue: startsExpanded)
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
        // 접힌 동안(로딩 여부와 무관하게) 화면에 안 보이는 사본을 겹쳐 둔다 —
        // 해설이 창을 열기도 전에 뒤에서 다 만들어지는 경우가 흔하니, 「정답
        // 해설 보기」를 누르기 전부터 미리 높이를 재 두면 눌렀을 때 로딩 없이
        // 바로 펼 수 있다. (``CorrectAnswerSheet``와 같은 이유)
        .overlay(alignment: .topLeading) { backgroundMeasurement }
        .commentarySheetChrome(
            detents: [.height(Self.collapsedHeight), expandedDetent],
            selection: $selectedDetent)
        // .presentationDetents 의 커스텀 .height 전환은 withAnimation 만으로는
        // 가끔 스냅처럼 보인다 — 값이 바뀔 때마다 걸리는 이 modifier를 하나 더
        // 얹는다(``CorrectAnswerSheet``와 같은 이유).
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

    /// 접혔을 때 보이는 내용. 큰 "정답 해설" 글자(흰 글자, 제목의 1.5배) 한 줄
    /// 아래 버튼 두 개를 세로로 둔다.
    private var collapsedContent: some View {
        VStack(spacing: 16) {
            Text("정답 해설")
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

    /// 「정답 해설 보기」를 눌렀을 때 할 일. (``CorrectAnswerSheet/reveal()``과 같은 이유)
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

    /// 제목("정답 해설") + notesCard. **`expandedContent`(실제로 보여줄 때)와
    /// `backgroundMeasurement`(숨은 사본)가 완전히 같은 이 뷰를 쓴다.**
    private var expandedInnerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            notesCard
        }
        .padding(.top, 16)
    }

    /// 접혀 있는 동안 화면엔 안 보이게 `expandedInnerContent`를 미리 그려서
    /// 해설이 도착하는 순간 바로 실제 높이를 알 수 있게 해 둔다.
    /// (``CorrectAnswerSheet/backgroundMeasurement``와 같은 이유 —
    /// `.hidden()` 대신 `.opacity(0)`을 쓰는 이유도 같다)
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

    /// 펼쳤을 때 실제로 보이는 내용.
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

    /// `backgroundMeasurement`나 `expandedContent` 양쪽 모두에서 부른다.
    /// (``CorrectAnswerSheet/updateExpandedHeight(contentHeight:)``와 같은 이유)
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

    /// 체크 아이콘 + 정답 낱말 + 해설을 감싸는 카드 하나. ``CorrectAnswerSheet``의
    /// notesCard 와 같은 모양이다.
    private var notesCard: some View {
        CommentaryCard {
            CommentaryRow(
                mark: "checkmark.app.fill",
                markColor: Self.correctAccent,
                markSize: Self.markAndWordSize,
                word: feedback.correctAnswer,
                badgeBackground: nil,
                badgeText: Self.correctAccent,
                wordSize: Self.markAndWordSize,
                wordWeight: .heavy
            ) { commentary }
        }
    }

    // MARK: - 해설 글

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.**
    ///
    /// 같은 뷰에 두고 애니메이션만 끄는 방법은 통하지 않습니다 —
    /// `repeatForever` 는 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 계속 돕니다.
    /// **뷰를 통째로 갈아 끼우면** 맥동하던 뷰가 사라지므로 확실히 멈춥니다.
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

#Preview("접힘") {
    FeedbackSheet(
        feedback: .init(
            id: 11,
            selectedAnswer: "개천절",
            selectedNote: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "추석",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {},
        startsExpanded: false)
}

#Preview("펼침 — 해설 도착") {
    FeedbackSheet(
        feedback: .init(
            id: 11,
            selectedAnswer: "개천절",
            selectedNote: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "추석",
            commentary: "추석은 가을 저녁이라는 뜻이에요. 음력 8월 15일에 지내는 명절이에요. 한가위라고도 불러요."),
        onNext: {},
        startsExpanded: true)
}

#Preview("펼침 — 기다리는 중") {
    FeedbackSheet(
        feedback: .init(
            id: 4,
            selectedAnswer: "고죠선",
            selectedNote: nil,
            waitingLine: "천천히 보면 돼요. 같이 살펴볼게요. 🍀",
            expectsNote: false,
            correctAnswer: "고조선",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {},
        startsExpanded: true)
}

#Preview("펼침 — 긴 정답: 고구려, 백제, 신라") {
    FeedbackSheet(
        feedback: .init(
            id: 27,
            selectedAnswer: "동지",
            selectedNote: "동지는 팥죽을 먹는 날이고 양력 12월 22일쯤이며 절기 이름이 있으며 겨울에 이르렀다는 뜻이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "고구려, 백제, 신라",
            commentary: "고구려, 백제, 신라입니다. 이 세 나라가 있었습니다. 신라가 이 세 나라를 하나로 합쳤습니다."),
        onNext: {},
        startsExpanded: true)
}
