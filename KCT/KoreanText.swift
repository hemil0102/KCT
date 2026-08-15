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

        label.attributedText = NSAttributedString(
            string: Self.keepingNumbersWithUnits(text),
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
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
