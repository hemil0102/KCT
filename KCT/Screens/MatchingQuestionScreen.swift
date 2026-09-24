//
//  MatchingQuestionScreen.swift
//  KCT
//
//  역할 : 「맞는 짝을 연결해보세요」 화면. 왼쪽 낱말과 오른쪽 낱말을 순서대로
//         골라 짝을 맞추고, 맞으면 선으로 잇는다
//  요점 : Question 의 한 문제·한 사다리 체계와는 완전히 별개다. 이 화면은
//         한 세트(MatchingSet)를 받아 스스로 그리고 스스로 채점한다
//
//  ── 구성 ──────────────────────────────────────────────
//  MatchingQuestionScreen
//  ├─ header               X(닫기) + 이 회차 진행 막대
//  ├─ title                고정 문구 "알맞은 짝을 연결해보세요."
//  ├─ board                왼쪽 열 · 오른쪽 열 + 맞은 짝을 잇는 선
//  ├─ card(for:side:)      카드 한 장을 그리고 그 자리를 위로 올린다
//  ├─ linesOverlay         맞은 짝마다 MatchLine 하나
//  ├─ nextButton           PrimaryActionButton 재사용. 다 맞히기 전엔 눌러도
//  │                       안내만 뜨고 넘어가지 않는다
//  ├─ tapLeft / tapRight   고르기와 판정 — 이 화면의 유일한 판단
//  ├─ shake(_:)            흔들림 세 박자. 왼쪽·오른쪽·「다음」이 **같은 것을 쓴다**
//  └─ setToast(_:hideAfter:) 안내 문구 갈아 끼우기
//
//  판 부품(MatchCard · MatchLine · CardSlot · CardFrameKey)은 MatchBoard.swift 에,
//  진행 막대는 SessionProgressBar(currentIsComplete:)에, 안내 줄은 GuidanceBanner 에,
//  X 버튼은 CircleIconButton 에 있다 — 넷 다 다른 화면과 함께 쓰는 것이다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  init 에서 matchingSet.pairs 를 왼쪽·오른쪽 각각 따로 섞어 둔다
//    → 왼쪽 하나 탭 → 선택 표시, 안내가 "오른쪽에서 고르세요"로 바뀜
//    → 오른쪽 하나 탭
//        ├─ 짝이 맞으면 → 두 카드 사이에 시그니처 보라 선을 그리고(애니메이션),
//        │              matchedIDs 에 추가. 5쌍을 다 채우면 진행 막대 칸이 오른다
//        └─ 짝이 틀리면 → 두 카드 테두리·글자가 빨갛게 변하며 흔들리고, 안내가 바뀐다
//    → "다음" 은 다 맞혔을 때만 실제로 onComplete() 를 부른다. 아직이면
//      흔들리며 안내만 다시 띄운다 — 이 문제 유형엔 오답 해설이 없다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView — session.isMatchingSlot 인 칸에서
//  기대는 것    : MatchingSet(재료), MatchBoard.swift · CircleIconButton ·
//                GuidanceBanner · SessionProgressBar · PrimaryActionButton(디자인)
//  건드리지 않는 것 : QuestionScreen·QuizSession·AskingMode 사다리 — 이 화면은
//                    그 체계를 전혀 모르고, 세션 진행 막대의 총 개수·현재 위치만
//                    바깥에서 숫자로 받는다
//
//  ── 11차 이후 후속 (연결 문제 도입) ──────────────────────
//  데모 3안(웹 시안) 중 "큰 글씨 단계형"을 그대로 옮겼다. 체크 아이콘은 빼고
//  선만 남겼고, 선은 초록이 아니라 시그니처 보라다. 왼쪽·오른쪽 사이 공백을
//  넓혔고, 안내 문구는 "국경일"·"날짜" 같은 이 세트 전용 낱말 대신 어떤
//  연결 문제가 와도 쓸 수 있게 "용어"로 일반화했다. 왼쪽·오른쪽 카드 순서는
//  화면이 새로 생길 때마다(=문제가 새로 나올 때마다) 각각 따로 무작위로 섞인다 —
//  같은 자리에 같은 낱말이 반복해서 나오지 않게 하기 위해서다.
//

import SwiftUI

struct MatchingQuestionScreen: View {

    /// 이 화면이 보여줄 연결 문제 세트.
    let matchingSet: MatchingSet

    /// 이 문제가 속한 회차의 전체 칸 수. 진행 막대 칸 개수를 정한다.
    let sessionTotal: Int

    /// 이 문제가 회차에서 몇 번째 칸인가(0부터). 이 칸은 "다 맞혀야" 채워진다.
    let sessionCurrentIndex: Int

    /// 닫기(X)를 눌렀을 때 부탁할 일. 실제로 화면을 내리는 건 부르는 쪽의 몫이다.
    let onClose: () -> Void

    /// 5쌍을 다 맞히고 "다음"을 눌렀을 때 부탁할 일. 이 문제 유형엔 오답 해설이
    /// 없으므로, 곧바로 다음 문제로 넘어가 달라는 뜻이다.
    let onComplete: () -> Void

    /// 카드 한 장의 내용. `id` 는 원래 쌍의 순번이라, 왼쪽·오른쪽에서 같은 `id` 를
    /// 가진 카드끼리가 정답이다 — 글자를 서로 비교할 필요가 없다.
    private struct Slot: Identifiable {
        let id: Int
        let text: String
    }

    @State private var leftSlots: [Slot]
    @State private var rightSlots: [Slot]

    @State private var selectedLeftID: Int?
    @State private var matchedIDs: Set<Int> = []

    /// 방금 오답으로 흔들려야 하는 카드. 짝이 틀렸을 때만 두 값이 함께 채워진다.
    @State private var wrongLeftID: Int?
    @State private var wrongRightID: Int?

    /// 카드 흔들림에 쓰는 가로 오프셋. 키는 카드 자리(왼쪽/오른쪽 + 순번).
    @State private var cardOffsetX: [CardSlot: CGFloat] = [:]

    /// 맞은 짝을 잇는 선의 그려지는 정도(0→1). 키는 쌍의 `id`.
    @State private var lineProgress: [Int: CGFloat] = [:]

    /// 카드들의 화면 자리. 선을 그리려면 두 카드의 실제 자리를 알아야 한다.
    @State private var cardFrames: [CardSlot: CGRect] = [:]

    @State private var toastText: String = Guide.pickLeft
    @State private var toastVisible: Bool = true

    /// "다음"을 흔들어야 하는지 — 아직 다 맞히지 않았는데 눌렀을 때만 켠다.
    @State private var nextShakeOffset: CGFloat = 0

    private enum Guide {
        static let pickLeft = "왼쪽에서 용어를 골라주세요."
        static let pickRight = "알맞은 오른쪽 용어를 골라 연결하세요."
        static let wrong = "짝이 맞지 않아요. 다시 골라볼까요?"
        static let correct = "정답이에요! 계속해서 짝을 지어보세요."
        static let allDone = "모두 연결했어요!"
        static let notReady = "아직 연결하지 않은 짝이 있어요."
    }

    /// 짝이 틀렸을 때의 빨강. **이 화면에서만** 쓰는 색이라 AppColor 에 두지 않는다 —
    /// 앱의 다른 화면은 「틀렸다」를 빨강으로 말하지 않는다(AppColor.review 참고).
    private static let wrongColor = Color(red: 0.84, green: 0.22, blue: 0.18)

    /// 판 좌표를 재는 이름. 선을 그릴 때 이 공간 기준으로 카드 자리를 읽는다.
    private static let boardSpace = "matchBoard"

    init(
        matchingSet: MatchingSet,
        sessionTotal: Int,
        sessionCurrentIndex: Int,
        onClose: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.matchingSet = matchingSet
        self.sessionTotal = sessionTotal
        self.sessionCurrentIndex = sessionCurrentIndex
        self.onClose = onClose
        self.onComplete = onComplete

        let indexed = Array(matchingSet.pairs.enumerated())
        // 화면이 새로 생길 때(=이 문제가 새로 나올 때)마다 왼쪽·오른쪽을 각각
        // 따로 섞는다. 두 열을 같은 순서로 섞으면 "항상 같은 줄끼리"가 되어
        // 자리만 외워도 풀리므로, 독립적으로 섞어야 한다.
        _leftSlots = State(initialValue: indexed.map { Slot(id: $0.offset, text: $0.element.left) }.shuffled())
        _rightSlots = State(initialValue: indexed.map { Slot(id: $0.offset, text: $0.element.right) }.shuffled())
    }

    private var allMatched: Bool { matchedIDs.count == matchingSet.pairs.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            title
            board
            Spacer(minLength: 0)
            toastBanner
            nextButton
        }
        .padding(24)
    }

    // MARK: - 상단 (닫기 + 회차 진행 막대)

    /// 진행 막대는 **세 단계**로 그린다 — 이 문제는 다 맞혀야 칸이 오르기 때문이다.
    /// 「아직(회색) · 지금 푸는 중(옅은 보라) · 다 맞힘(진한 보라)」.
    private var header: some View {
        HStack(spacing: 16) {
            CircleIconButton(systemName: "xmark", action: onClose)

            SessionProgressBar(
                total: sessionTotal,
                currentIndex: sessionCurrentIndex,
                currentIsComplete: allMatched,
                upcomingFill: AppColor.disabledBackground)
        }
    }

    // MARK: - 제목

    /// 글자색을 `.black` 으로 **못 박아 둔다.** 이걸 빼면 기본값(`.primary`)이라
    /// 기기가 다크 모드일 때 흰 글자가 되는데, 이 앱은 배경을 전부 흰색으로
    /// 고정해 두었기 때문에(QuizView 의 `.background(Color.white)`) 흰 배경 위
    /// 흰 글자가 되어 **글자만 안 보인다.** 앱의 다른 글자들(ChoiceButton ·
    /// KoreanText · ResultScreen …)이 모두 `.black` 을 직접 쓰는 것과 같은 이유다.
    private var title: some View {
        Text("알맞은 짝을 연결해보세요.")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
    }

    // MARK: - 판 (왼쪽 열 · 오른쪽 열 · 선)

    private var board: some View {
        // 가로 76 : 왼쪽 낱말과 오른쪽 낱말 사이에 선이 지나갈 자리를 넉넉히 둔다.
        // 세로 18 : 줄끼리도 조금 더 띄워 어느 줄을 고르는지 헷갈리지 않게 한다.
        HStack(spacing: 76) {
            VStack(spacing: 18) {
                ForEach(leftSlots) { slot in
                    card(for: slot, side: .left)
                }
            }
            VStack(spacing: 18) {
                ForEach(rightSlots) { slot in
                    card(for: slot, side: .right)
                }
            }
        }
        .padding(.top, 28)
        .coordinateSpace(name: Self.boardSpace)
        .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
        .overlay(linesOverlay)
    }

    private func card(for slot: Slot, side: MatchSide) -> some View {
        let key = CardSlot(side: side, id: slot.id)
        let isMatched = matchedIDs.contains(slot.id)
        let isSelected = side == .left && selectedLeftID == slot.id
        let isWrong = (side == .left && wrongLeftID == slot.id)
            || (side == .right && wrongRightID == slot.id)

        return MatchCard(
            text: slot.text,
            isSelected: isSelected,
            isMatched: isMatched,
            isWrong: isWrong,
            wrongColor: Self.wrongColor
        ) {
            switch side {
            case .left: tapLeft(slot.id)
            case .right: tapRight(slot.id)
            }
        }
        .disabled(isMatched)
        .offset(x: cardOffsetX[key] ?? 0)
        // 카드의 화면 자리를 위로 올린다. 왼쪽·오른쪽을 **타입이 아니라 키의 값**으로
        // 가르므로(CardSlot.side) PreferenceKey 가 하나뿐이고, if/else 로 갈라 쓸 일도 없다.
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CardFrameKey.self,
                    value: [key: proxy.frame(in: .named(Self.boardSpace))]
                )
            }
        )
    }

    private var linesOverlay: some View {
        ZStack {
            ForEach(Array(matchedIDs), id: \.self) { id in
                if let left = cardFrames[CardSlot(side: .left, id: id)],
                   let right = cardFrames[CardSlot(side: .right, id: id)] {
                    MatchLine(
                        start: CGPoint(x: left.maxX, y: left.midY),
                        end: CGPoint(x: right.minX, y: right.midY)
                    )
                    .trim(from: 0, to: lineProgress[id] ?? 0)
                    .stroke(AppColor.signature, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 하단 (안내 토스트 + 다음)

    /// 안내 줄. 문제 화면(``QuestionScreen``)의 안내와 **같은 부품**이지만, 이 화면은
    /// 자리에 있는 채로 흐려지고(opacity) 문제 화면은 아래에서 밀려 올라온다 —
    /// 그래서 나타나는 방식만 여기서 붙인다.
    private var toastBanner: some View {
        GuidanceBanner(text: toastText,
                       fontSize: 17,
                       verticalPadding: 13,
                       bottomPadding: 14)
            .opacity(toastVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: toastVisible)
    }

    private var nextButton: some View {
        PrimaryActionButton(title: "다음  →", isReady: allMatched) {
            if allMatched {
                onComplete()
            } else {
                shake { nextShakeOffset = $0 }
                setToast(Guide.notReady, hideAfter: 1.4)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .offset(x: nextShakeOffset)
    }

    // MARK: - 동작

    private func tapLeft(_ id: Int) {
        guard !matchedIDs.contains(id) else { return }
        if selectedLeftID == id {
            selectedLeftID = nil
            setToast(Guide.pickLeft)
            return
        }
        selectedLeftID = id
        setToast(Guide.pickRight)
    }

    private func tapRight(_ id: Int) {
        guard let leftID = selectedLeftID else {
            shake { cardOffsetX[CardSlot(side: .right, id: id)] = $0 }
            setToast(Guide.pickLeft)
            return
        }

        if id == leftID {
            selectedLeftID = nil
            matchedIDs.insert(id)
            lineProgress[id] = 0
            withAnimation(.easeOut(duration: 0.35)) { lineProgress[id] = 1 }

            if allMatched {
                setToast(Guide.allDone, hideAfter: 1.1)
            } else {
                setToast(Guide.correct)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if selectedLeftID == nil && !allMatched { setToast(Guide.pickLeft) }
                }
            }
        } else {
            wrongLeftID = leftID
            wrongRightID = id
            selectedLeftID = nil
            shake { cardOffsetX[CardSlot(side: .left, id: leftID)] = $0 }
            shake { cardOffsetX[CardSlot(side: .right, id: id)] = $0 }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                wrongLeftID = nil
                wrongRightID = nil
            }
            setToast(Guide.wrong)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                if selectedLeftID == nil && !allMatched { setToast(Guide.pickLeft) }
            }
        }
    }

    /// 흔들림 세 박자. CSS 의 `25% -6px · 75% +6px` 을 그대로 옮긴 것이다.
    ///
    /// 예전에는 `shakeLeft`·`shakeRight`·`shakeNext` 세 함수가 **글자까지 똑같이**
    /// 있었다. 다른 것은 "어디에 값을 넣는가" 하나뿐이라, 그 한 가지만 클로저로
    /// 받으면 세 자리가 같은 코드를 쓴다 — 흔들림 박자를 고칠 때 한 곳만 본다.
    ///
    /// - Parameter apply: 오프셋 값을 받아 제 자리에 넣어 주는 클로저.
    ///   (`shake { cardOffsetX[key] = $0 }` 처럼 쓴다)
    private func shake(_ apply: @escaping (CGFloat) -> Void) {
        withAnimation(.easeInOut(duration: 0.08)) { apply(-6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.16)) { apply(6) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.08)) { apply(0) }
        }
    }

    private func setToast(_ text: String, hideAfter: Double? = nil) {
        toastText = text
        toastVisible = true
        if let hideAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter) {
                if toastText == text { toastVisible = false }
            }
        }
    }
}

#Preview {
    MatchingQuestionScreen(
        matchingSet: MatchingSet(
            id: 1,
            category: "대한민국",
            unit: "국경일",
            pairs: [
                MatchingPair(left: "삼일절", right: "3월 1일"),
                MatchingPair(left: "제헌절", right: "7월 17일"),
                MatchingPair(left: "광복절", right: "8월 15일"),
                MatchingPair(left: "개천절", right: "10월 3일"),
                MatchingPair(left: "한글날", right: "10월 9일"),
            ]
        ),
        sessionTotal: 7,
        sessionCurrentIndex: 2,
        onClose: {},
        onComplete: {}
    )
}
