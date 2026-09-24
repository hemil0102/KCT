//
//  GlossaryExampleText.swift
//  KCT
//
//  역할 : 낱말 사전 해설 문장 한 줄을 그린다 — "낱말(뜻)" 자리만 다른 색·다른 크기로
//  요점 : 낱말이 활용형으로 바뀌어 나오므로 글자로 못 찾는다. "(" 앞 덩어리를 낱말로 본다
//
//  ── 구성 ──────────────────────────────────────────────
//  GlossaryExampleText (View)          부르는 쪽이 쓰는 유일한 입구
//  ├─ text / fontSize
//  └─ body                             아래 둘을 이어 붙인다
//
//  파일 안의 도우미
//  ├─ HighlightedExample               스타일이 다 입혀진 문자열 + 둥근 배경 구간들
//  ├─ highlighted(_:fontSize:)         그 둘을 만드는 계산 (여기가 이 파일의 핵심)
//  └─ HighlightedSentenceView          UnderlineLabel 로 실제로 그리는 얇은 다리
//
//  ── 왜 글자로 낱말을 못 찾나 ───────────────────────────
//  모델이 만든 문장에서 낱말은 **활용형으로 바뀌어** 나온다 — "기리는" 을 넘겼는데
//  문장에는 "기립니다" 로 적힌다. 원래 낱말 문자열로는 못 찾는다. 대신 모델에게
//  "낱말(뜻)" 형식을 지키라고 시켜 두었으므로, **"(" 바로 앞에서 공백 없이 이어지는
//  한 덩어리**를 낱말 자리로 본다.
//
//    "손주가 할머니를 기립니다(고맙게 생각하는) 마음으로 …"
//                      └ 낱말 ┘└──── 뜻(괄호 포함) ────┘
//
//  ── 왜 UILabel 을 거치나 ───────────────────────────────
//  SwiftUI `Text`/`AttributedString` 의 `backgroundColor` 속성은 **각진 사각형만**
//  그린다(둥근 모서리·여백을 못 준다). 그래서 지문의 밑줄과 같은 방식
//  (``UnderlineLabel`` 이 TextKit 으로 줄 단위 사각형을 직접 채우기)을 대신 쓴다 —
//  여기서는 밑줄 없이 배경만 켠다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : GlossaryPanel (펼쳤을 때의 해설 자리)
//  기대는 것    : AppColor(낱말 배지 색), UnderlineLabel(그리기)
//  건드리지 않는 것 : 문장을 만드는 일 — GlossaryExampleWriter 의 몫이다.
//                    글자 크기를 정하는 일 — GlossaryPanel 이 낱말·뜻과 같은 값으로 넘긴다
//
//  ⚠️ 2026-09-23 리팩토링에서 GlossaryPanel.swift(479줄)에서 떼어냈다. 계산은 한 줄도
//     안 바꿨고, 글자 크기만 `Self.wordGlossFontSize` 대신 인자로 받게 했다 —
//     "낱말·뜻·해설이 항상 같은 크기"라는 규칙은 여전히 GlossaryPanel 의 상수 하나가 쥔다.
//

import SwiftUI
import UIKit

/// 낱말 사전 해설 문장 한 줄.
///
/// "낱말(뜻)" 중 **낱말 자리**는 헤더의 낱말과 같은 조합(연라벤더 둥근 배경 +
/// 짙은 보라 글자)으로, **뜻 자리**는 괄호까지 포함해 배경 없이 흰 글자로 둡니다.
/// 나머지 문장은 흐린 흰색(72%)이라 두 자리가 상대적으로 도드라져 보입니다.
struct GlossaryExampleText: View {
    let text: String

    /// 글자 크기. ``GlossaryPanel`` 이 낱말·뜻과 **같은 값**을 넘긴다 —
    /// 위아래 글자 크기가 다르면 해설만 유독 작아 보였다.
    let fontSize: CGFloat

    var body: some View {
        HighlightedSentenceView(example: Self.highlighted(text, fontSize: fontSize))
    }

    // MARK: - 안에서 하는 일

    /// ``highlighted(_:fontSize:)`` 의 결과물 — 스타일이 다 입혀진 문자열과, 그 위에
    /// 둥글게 채울 배경 구간들. ``HighlightedSentenceView`` 에 그대로 넘긴다.
    private struct HighlightedExample {
        let attributedText: NSAttributedString
        let backgroundHighlights: [UnderlineLabel.BackgroundHighlight]
    }

    /// 문장에 색과 배경을 입힌다.
    ///
    /// - Note: 배경은 여백 없이 글자 폭에 딱 맞게 그려진다 — 가로로 여백을 더 주면
    ///   옆 글자와 겹친다(그 자리에 여백이 있다고 텍스트 레이아웃 자체가 미리 잡아
    ///   두지 않기 때문). 모서리만 둥글게 깎는다.
    /// - Note: "(" 는 있는데 짝이 되는 ")" 가 없으면(모델이 형식을 깼을 때) 낱말
    ///   배경·글자색만 칠하고 뜻 자리는 그대로 둔다.
    private static func highlighted(_ text: String, fontSize: CGFloat) -> HighlightedExample {
        let baseFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)

        // KoreanText.swift(지문)와 달리 이 문장에는 문단 스타일이 없었다 —
        // 그래서 한글 낱말 중간에서 줄이 갈릴 수 있었다("아사달"이 "아사" /
        // "달"로 잘려 다음 줄로 넘어가는 식). 배경 하이라이트는 줄마다 따로
        // 그리기 때문에(UnderlineLabel.drawText 참고) 그 자체는 안 깨지지만,
        // 낱말 하나가 두 줄에 걸쳐 반씩 잘려 보이니 "배경이 어긋난 것"처럼
        // 보였다 — 다급한 타이밍 문제가 아니라, 줄바꿈 규칙이 안 걸려 있던
        // 것이었다. 지문과 똑같이 hangulWordPriority 를 걸어서 한글 낱말이
        // 통째로만 다음 줄로 넘어가게 한다.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = .hangulWordPriority

        // 문장 전체를 기본값으로 살짝 흐린 흰색(72%)으로 깔아 둔다 — 데모에서
        // 고른 것과 같은 발상이다. 낱말·뜻 자리만 아래에서 또렷한 색(낱말은
        // 배지 글자색, 뜻은 100% 흰색)으로 다시 덮어써서, 나머지 문장보다
        // 두 자리가 상대적으로 더 도드라져 보이게 한다.
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.72),
                .paragraphStyle: paragraph,
            ]
        )
        var backgroundHighlights: [UnderlineLabel.BackgroundHighlight] = []

        guard let openParen = text.firstIndex(of: "(") else {
            return HighlightedExample(attributedText: attributed,
                                      backgroundHighlights: backgroundHighlights)
        }

        var wordStart = openParen
        while wordStart > text.startIndex {
            let before = text.index(before: wordStart)
            if text[before].isWhitespace { break }
            wordStart = before
        }
        let wordRange = NSRange(wordStart..<openParen, in: text)
        attributed.addAttribute(.foregroundColor, value: UIColor(AppColor.wordBadgeText), range: wordRange)
        backgroundHighlights.append(
            UnderlineLabel.BackgroundHighlight(
                range: wordRange,
                color: UIColor(AppColor.wordBadgeBackground),
                cornerRadius: 6
            )
        )

        let afterOpenParen = text.index(after: openParen)
        if afterOpenParen < text.endIndex,
           let closeParen = text[afterOpenParen...].firstIndex(of: ")") {
            // 괄호 자체("(", ")")까지 포함해서 뜻 구간으로 본다. 전용 색을 새로
            // 만들지 않고 100% 흰색을 명시적으로 입힌다 — 위에서 문장 전체를
            // 72%로 흐려 뒀으므로, 여기서 다시 덮어쓰지 않으면 뜻도 같이 흐려져
            // 버린다. 글자 크기는 2pt 작게 유지한다.
            let closeParenEnd = text.index(after: closeParen)
            let glossRange = NSRange(openParen..<closeParenEnd, in: text)
            let glossFont = UIFont.systemFont(ofSize: fontSize - 2, weight: .medium)
            attributed.addAttribute(.font, value: glossFont, range: glossRange)
            attributed.addAttribute(.foregroundColor, value: UIColor.white, range: glossRange)
        }

        return HighlightedExample(attributedText: attributed,
                                  backgroundHighlights: backgroundHighlights)
    }

    /// 해설 문장을 그리는 얇은 UIKit 다리. ``highlighted(_:fontSize:)`` 가 만든
    /// 낱말 색·뜻 글자 크기가 이미 입혀진 문자열을, 낱말 자리에 둥근 배경까지 얹어
    /// 그린다 — 실제로 배경을 그리는 계산·코드는 전부 ``UnderlineLabel`` 에 있고
    /// (밑줄 그리는 것과 같은 TextKit 방식), 여기선 밑줄 없이 배경만 켜서 쓴다.
    private struct HighlightedSentenceView: UIViewRepresentable {
        let example: HighlightedExample

        func makeUIView(context: Context) -> UnderlineLabel {
            let label = UnderlineLabel()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.setContentHuggingPriority(.required, for: .vertical)
            return label
        }

        func updateUIView(_ label: UnderlineLabel, context: Context) {
            label.attributedText = example.attributedText
            label.backgroundHighlights = example.backgroundHighlights
            label.setNeedsDisplay()
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UnderlineLabel, context: Context) -> CGSize? {
            guard let width = proposal.width, width > 0 else { return nil }
            return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        }
    }
}

/// 시트 위쪽 손잡이 모양. "^"를 옆으로 넓게 늘린 모양이다 — 시스템 기본 알약
/// 모양 대신 이 모양을 그리려고 만들었다(``GlossaryPanel`` 의 `dragHandle`).
struct WideChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        GlossaryExampleText(
            text: "손주가 할머니를 기립니다(고맙게 생각하는) 마음으로 편지를 썼어요.",
            fontSize: 28)

        // 괄호가 없을 때 — 낱말 자리를 못 찾으므로 전체가 흐린 흰색으로만 남는다.
        GlossaryExampleText(
            text: "모델이 형식을 깨서 괄호가 없는 문장입니다.",
            fontSize: 28)

        WideChevronShape()
            .stroke(Color.white.opacity(0.4),
                    style: StrokeStyle(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
            .frame(width: 48, height: 10)
    }
    .padding(20)
    .background(AppColor.signature.opacity(CommentaryMetrics.backgroundOpacity))
}
