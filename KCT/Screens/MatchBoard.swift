//
//  MatchBoard.swift
//  KCT
//
//  역할 : 연결 문제의 「판」 부품 — 카드 한 장, 두 카드를 잇는 선, 카드 자리 모으기
//  요점 : 카드는 자기가 맞았는지 모른다. 겉모습 셋(선택·맞음·오답)을 받아 그릴 뿐이다
//
//  ── 구성 ──────────────────────────────────────────────
//  MatchSide (enum)      왼쪽 / 오른쪽
//  CardSlot              카드 한 장을 가리키는 키 (side + 쌍의 순번)
//  CardFrameKey          카드들의 화면 자리를 위로 모으는 PreferenceKey
//  MatchCard             카드 한 장 (선택 / 맞음 / 오답 세 가지 겉모습)
//  MatchLine             맞은 두 카드 사이를 잇는 직선
//
//  ── PreferenceKey 가 하나인 이유 ───────────────────────
//  예전에는 LeftFrameKey · RightFrameKey 두 타입이 **글자까지 똑같이** 있었다.
//  PreferenceKey 는 타입 하나가 키 하나라서 왼쪽·오른쪽을 가르려면 둘이 필요했던 것인데,
//  가르는 것을 **타입이 아니라 값**(CardSlot 의 side)으로 옮기면 하나로 충분하다.
//  그래서 카드 쪽 GeometryReader 에서 if/else 로 갈라 쓸 일도 없어졌다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : MatchingQuestionScreen
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 짝이 맞는지 판정 — MatchingQuestionScreen 이 한다
//

import SwiftUI

/// 판의 어느 열인가.
enum MatchSide {
    case left
    case right
}

/// 카드 한 장을 가리키는 키.
///
/// `id` 는 **원래 쌍의 순번**이라, 왼쪽·오른쪽에서 같은 `id` 를 가진 카드끼리가
/// 정답입니다 — 글자를 서로 비교할 필요가 없습니다.
struct CardSlot: Hashable {
    let side: MatchSide
    let id: Int
}

/// 카드들의 화면 자리를 위로 모으는 키. 선을 그리려면 두 카드의 실제 자리를 알아야 한다.
struct CardFrameKey: PreferenceKey {
    static var defaultValue: [CardSlot: CGRect] = [:]

    static func reduce(value: inout [CardSlot: CGRect], nextValue: () -> [CardSlot: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// 카드 한 장. 겉모습이 셋이다 — 고른 것 · 맞은 것 · 방금 틀린 것.
///
/// 이 카드는 **자기가 정답인지 모릅니다.** 세 깃발을 받아 그릴 뿐이고, 판정은
/// ``MatchingQuestionScreen`` 이 합니다.
struct MatchCard: View {
    let text: String
    let isSelected: Bool
    let isMatched: Bool
    let isWrong: Bool

    /// 틀렸을 때의 빨강. 이 화면에서만 쓰는 색이라 ``AppColor`` 가 아니라 인자로 받는다.
    let wrongColor: Color

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isWrong ? wrongColor : .black)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(.horizontal, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .buttonStyle(.plain)
        .opacity(isMatched ? 0.92 : 1)
        .animation(.easeOut(duration: 0.2), value: isMatched)
    }

    // 맞힌 짝은 녹색이다 — 4지선다·O/X 에서 정답 버튼이 녹색 ✓ 로 바뀌는 것과
    // 같은 색(AppColor.answerSheetAccent / answerSheetBadge)을 써서, "맞았다"를
    // 앱 전체가 같은 색으로 말하게 한다. 선을 긋는 쪽(MatchingQuestionScreen)도
    // 같은 answerSheetAccent 를 쓴다.
    private var background: Color {
        if isWrong { return .white }
        if isMatched { return AppColor.answerSheetBadge }
        if isSelected { return AppColor.softBackground }
        return .white
    }

    private var borderColor: Color {
        if isWrong { return wrongColor }
        if isMatched { return AppColor.answerSheetAccent }
        if isSelected { return AppColor.signature }
        return Color.black.opacity(0.35)
    }

    private var borderWidth: CGFloat {
        (isSelected || isMatched) ? 3 : 1.5
    }
}

/// 맞은 두 카드 사이를 잇는 직선. `.trim(from:to:)` 으로 그려지는 애니메이션을 준다.
struct MatchLine: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

#Preview {
    VStack(spacing: 18) {
        MatchCard(text: "삼일절", isSelected: false, isMatched: false,
                  isWrong: false, wrongColor: .red) {}
        MatchCard(text: "삼일절", isSelected: true, isMatched: false,
                  isWrong: false, wrongColor: .red) {}
        MatchCard(text: "삼일절", isSelected: false, isMatched: true,
                  isWrong: false, wrongColor: .red) {}
        MatchCard(text: "삼일절", isSelected: false, isMatched: false,
                  isWrong: true, wrongColor: Color(red: 0.84, green: 0.22, blue: 0.18)) {}
    }
    .padding(24)
}
