//
//  KoreanText.swift
//  KCT
//
//  역할 : 한국어 지문을 읽기 좋게 보여준다. 줄바꿈·강조·형광펜을 함께 처리
//  요점 : SwiftUI Text 는 한글 줄바꿈 전략을 지원하지 않아 UILabel 을 감싼다
//
//  ── 구성 ──────────────────────────────────────────────
//  KoreanText (UIViewRepresentable → UILabel)
//  ├─ text / font / color / lineSpacing
//  ├─ highlight / highlightColor     색 + 굵은 밑줄로 강조 (O/X 의 판단 대상)
//  ├─ marker / markerColor           형광펜(배경색)으로 칠할 부분 (묻는 대상)
//  ├─ makeUIView(context:)           UILabel 준비 (여러 줄, 세로 크기 우선)
//  ├─ updateUIView(_:context:)       문단 스타일 + 강조 두 종류를 입힌다
//  ├─ sizeThatFits(...)              폭에 맞는 높이를 SwiftUI 에 알려준다
//  └─ keepingNumbersWithUnits(_:)    "2333년" 이 갈라지지 않게 WORD JOINER 삽입
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 이 지문·강조·형광펜을 넘긴다
//    → keepingNumbersWithUnits() 로 숫자+한글을 붙여 둔다
//    → NSMutableAttributedString 에 문단 스타일(hangulWordPriority) 적용
//    → marker 구간에 배경색, highlight 구간에 색+밑줄
//    → UILabel 에 attributedText 로 넣는다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (지문 표시)
//  기대는 것    : UIKit, AppColor
//  건드리지 않는 것 : 무엇을 강조할지 판단 — QuizItem 이 정해서 넘겨준다
//

import SwiftUI
import UIKit

/// 한국어 지문을 읽기 좋게 보여주는 텍스트 뷰.
///
/// ## 왜 UILabel 을 감쌌나
///
/// SwiftUI 의 `Text` 는 **한글 줄바꿈 전략을 지원하지 않습니다.** 그대로 쓰면
/// "대한민국" 이 "대한민" / "국" 으로 갈라집니다. Apple 이 한국어 UI에 권장하는
/// `hangulWordPriority` 는 `NSParagraphStyle` 에만 있어서 UIKit 을 거쳐야 합니다.
///
/// ## 두 가지 강조
///
/// | 무엇 | 어떻게 | 언제 |
/// |---|---|---|
/// | ``marker`` | 형광펜 (배경색) | 질문이 묻는 대상. 연습 모드에서만 |
/// | ``highlight`` | 색 + 굵은 밑줄 | O/X 에서 판단 대상인 답 |
///
/// 강조를 **두 가지 신호(색과 밑줄)로** 주는 이유는 색 구분이 어려운 분도
/// 알아볼 수 있게 하기 위해서입니다.
struct KoreanText: UIViewRepresentable {
    let text: String
    var font: UIFont
    var color: UIColor = .black
    var lineSpacing: CGFloat = 8

    /// 본문에서 강조할 부분. (예: O/X 에서 판단 대상인 답)
    var highlight: String?
    var highlightColor: UIColor = UIColor(AppColor.signature)

    /// 형광펜으로 칠할 부분. (질문이 묻는 대상)
    var marker: String?
    var markerColor: UIColor = UIColor(AppColor.marker)

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0

        // 지문은 길어질 수 있다. 세로로 절대 줄어들지 않게 못을 박아 둔다.
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left                         // 왼쪽부터 읽기 편하게
        paragraph.lineBreakMode = .byWordWrapping           // 단어 단위 줄바꿈
        paragraph.lineBreakStrategy = .hangulWordPriority   // 한글 단어 중간에서 끊지 않음
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

        // 강조 구간은 시그니처 색 + 굵은 밑줄. 색과 밑줄 두 신호를 함께 준다.
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

    /// 폭이 정해지면 그 폭에서 필요한 높이를 계산해 SwiftUI 에 알려준다.
    ///
    /// 이것이 없으면 UIKit 뷰의 높이를 SwiftUI 가 몰라서 지문이 잘립니다.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    /// 숫자와 뒤따르는 한글이 줄바꿈으로 갈라지지 않게 묶는다.
    ///
    /// `hangulWordPriority` 는 **한글끼리만** 붙여 주기 때문에 "2333년" 은
    /// 숫자와 한글의 경계에서 끊어질 수 있습니다. 폭이 없는
    /// WORD JOINER(U+2060)를 끼워 넣어 그 자리에서 줄이 갈라지지 않게 합니다.
    ///
    /// - Note: 강조·형광펜 문자열도 **같은 처리를 거친 뒤** 찾아야 합니다.
    ///   본문에만 WORD JOINER 를 넣으면 글자가 달라져 구간을 못 찾습니다.
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
            (0xAC00...0xD7A3).contains(scalar.value)          // 한글 음절 (가 ~ 힣)
                || (0x1100...0x11FF).contains(scalar.value)   // 한글 자모
                || (0x3130...0x318F).contains(scalar.value)   // 호환용 자모
        }
    }
}
