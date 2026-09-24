//
//  CorrectionText.swift
//  KCT
//
//  역할 : 한 문장 안에서 틀린 낱말에 줄을 긋고, 바로 뒤에 고친 낱말을 칠해 보여주는 글
//  요점 : 공책을 빨간 펜으로 고쳐 주는 모양. 지문·해설과 같은 양쪽 정렬 규칙을 쓴다
//
//  ── 구성 ──────────────────────────────────────────────
//  CorrectionText (UIViewRepresentable)
//  ├─ before / after     고친 낱말 앞·뒤 글
//  ├─ struck             줄을 그을 낱말. nil 이면 긋지 않는다(문장이 원래 맞았다)
//  ├─ corrected          고쳐 넣은 낱말 — 굵게, 글자색 + 옅은 배경
//  └─ append(...)        조각을 이어 붙이며 조각 사이에도 끊어도 되는 자리를 심는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : TrueFalseSheet (O/X 해설 창의 ✅ 줄)
//  기대는 것    : KoreanTextLayout(줄바꿈·양쪽 정렬 규칙), CommentaryMetrics(기본 크기)
//  건드리지 않는 것 : 무엇이 틀렸는지 판단 — 부르는 쪽이 낱말을 정해서 넘긴다
//
//  ── 왜 JustifiedKoreanText 를 안 쓰나 ────────────────────
//  JustifiedKoreanText 는 **낱말 하나**만 칠한다. 여기는 줄 그은 낱말과 고친 낱말
//  **두 가지 모양**이 한 문장에 있어야 해서 조각을 따로 이어 붙인다. 줄바꿈 규칙은
//  같은 KoreanTextLayout 을 써서 지문·해설과 똑같이 끊긴다.
//

import SwiftUI
import UIKit

struct CorrectionText: UIViewRepresentable {

    let before: String

    /// 줄을 그을 낱말. `nil` 이면 줄 그을 것이 없다.
    let struck: String?

    let corrected: String
    let after: String

    var font: UIFont = .systemFont(ofSize: CommentaryMetrics.noteSize, weight: .semibold)
    var lineSpacing: CGFloat = CommentaryMetrics.lineSpacing(for: CommentaryMetrics.noteSize)

    var struckColor: UIColor
    var correctedColor: UIColor
    var correctedBackground: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: KoreanTextLayout.paragraphStyle(lineSpacing: lineSpacing),
        ]

        let result = NSMutableAttributedString()
        var previous: Character?

        /// 조각 하나를 붙인다. 조각끼리 맞닿는 자리도 한 문장일 때와 똑같이 끊기도록,
        /// ``KoreanTextLayout/prepared(_:)`` 가 조각 **안에서** 하는 일을 경계에서도 한다.
        func append(_ piece: String, _ extra: [NSAttributedString.Key: Any] = [:]) {
            guard !piece.isEmpty else { return }

            if let previous, let first = piece.first {
                if previous.isHangul, first.isHangul {
                    result.append(NSAttributedString(string: "\u{200B}", attributes: base))
                } else if previous.isNumber, first.isHangul {
                    result.append(NSAttributedString(string: "\u{2060}", attributes: base))
                }
            }

            let attributes = base.merging(extra) { _, new in new }
            result.append(NSAttributedString(string: KoreanTextLayout.prepared(piece),
                                             attributes: attributes))
            previous = piece.last
        }

        append(before)

        if let struck, !struck.isEmpty {
            append(struck, [
                .foregroundColor: struckColor.withAlphaComponent(0.6),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: struckColor,
            ])
            append(" ")
        }

        append(corrected, [
            .foregroundColor: correctedColor,
            .backgroundColor: correctedBackground,
            .font: UIFont.systemFont(ofSize: font.pointSize, weight: .black),
        ])

        append(after)

        label.attributedText = result
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        CorrectionText(
            before: "대한민국 헌법을 만들어 공포한 것을 기념하는 국경일은 ",
            struck: "개천절",
            corrected: "제헌절",
            after: "이에요.",
            struckColor: UIColor(AppColor.wrongAccent),
            correctedColor: UIColor(AppColor.answerSheetAccent),
            correctedBackground: UIColor(AppColor.answerSheetBadge))

        CorrectionText(
            before: "한국의 최초 국가 이름은 ",
            struck: nil,
            corrected: "고조선",
            after: "이에요.",
            struckColor: UIColor(AppColor.wrongAccent),
            correctedColor: UIColor(AppColor.answerSheetAccent),
            correctedBackground: UIColor(AppColor.answerSheetBadge))
    }
    .padding(28)
}
