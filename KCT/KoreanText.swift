//
//  KoreanText.swift
//  KCT
//
//  한국어 지문을 읽기 좋게 보여주는 텍스트 뷰.
//  - 왼쪽 정렬로 왼쪽부터 읽기 편하게 한다.
//  - 한글 단어 단위로 줄바꿈한다. (Apple이 한국어 UI에 권장하는 hangulWordPriority)
//  - "2333년"처럼 숫자와 단위가 갈라지지 않게 묶는다.
//  SwiftUI Text는 한글 줄바꿈 전략을 지원하지 않아 UILabel을 감싼다.
//

import SwiftUI
import UIKit

struct KoreanText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var color: UIColor = .black
    var lineSpacing: CGFloat = 8
    /// 본문에서 강조할 부분. (예: O/X에서 판단 대상인 답)
    var highlight: String?
    var highlightColor: UIColor = UIColor(AppColor.signature)
    /// 형광펜으로 칠할 부분. (질문이 묻는 대상)
    var marker: String?
    var markerColor: UIColor = UIColor(AppColor.marker)

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left                   // 왼쪽 정렬
        paragraph.lineBreakMode = .byWordWrapping     // 단어 단위 줄바꿈
        paragraph.lineBreakStrategy = .hangulWordPriority   // 한글은 단어 중간에서 끊지 않음
        paragraph.lineSpacing = lineSpacing

        let displayed = Self.keepingNumbersWithUnits(text)
        let attributed = NSMutableAttributedString(
            string: displayed,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )

        // 묻는 대상은 형광펜(배경색)으로 칠한다.
        if let marker, !marker.isEmpty {
            let target = Self.keepingNumbersWithUnits(marker)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                attributed.addAttribute(.backgroundColor, value: markerColor, range: range)
            }
        }

        // 강조 구간은 시그니처 색 + 굵은 밑줄로 표시한다.
        // 색과 밑줄 두 가지 신호를 주어 색 구분이 어려운 분도 알아볼 수 있게 한다.
        if let highlight, !highlight.isEmpty {
            let target = Self.keepingNumbersWithUnits(highlight)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                attributed.addAttributes(
                    [
                        .foregroundColor: highlightColor,
                        .underlineStyle: NSUnderlineStyle.thick.rawValue,
                        .underlineColor: highlightColor,
                    ],
                    range: range
                )
            }
        }

        label.attributedText = attributed
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    /// 숫자와 뒤따르는 한글이 줄바꿈으로 갈라지지 않게 묶는다.
    ///
    /// `hangulWordPriority`는 한글끼리만 붙여 주기 때문에 "2333년"은 숫자와 한글의
    /// 경계에서 끊어질 수 있다. 폭이 없는 WORD JOINER(U+2060)를 끼워 넣어 이를 막는다.
    private static func keepingNumbersWithUnits(_ text: String) -> String {
        let wordJoiner: Character = "\u{2060}"
        var result = ""
        var previous: Character?

        for character in text {
            if let previous, previous.isNumber, character.isHangul {
                result.append(wordJoiner)
            }
            result.append(character)
            previous = character
        }
        return result
    }
}

private extension Character {
    /// 한글(음절·자모)인지 여부.
    var isHangul: Bool {
        unicodeScalars.allSatisfy { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)     // 한글 음절
                || (0x1100...0x11FF).contains(scalar.value)   // 한글 자모
                || (0x3130...0x318F).contains(scalar.value)   // 호환용 자모
        }
    }
}
