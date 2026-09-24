//
//  KoreanTextLayout.swift
//  KCT
//
//  역할 : 한국어를 "양쪽 정렬 + 빽빽한 줄" 로 그리는 규칙 한 벌. 지문과 해설이 함께 쓴다
//  요점 : 줄바꿈 규칙이 두 군데로 갈라지면 반드시 어긋난다. 한 곳에만 둔다
//
//  ── 구성 ──────────────────────────────────────────────
//  KoreanTextLayout (enum — 규칙만 모아 둔 곳)
//  ├─ prepared(_:)              끊어도 되는/안 되는 자리를 글자 사이에 심는다
//  └─ paragraphStyle(lineSpacing:)  양쪽 정렬 + 낱말 단위 줄바꿈 문단 스타일
//
//  JustifiedKoreanText (UIViewRepresentable → UILabel)
//  └─ 낱말 하나만 색·굵기가 다른 한 덩어리 글을 양쪽 정렬로 그린다 (해설 본문)
//
//  Character.isHangul                한글인지 (KoreanText 도 같이 쓴다)
//
//  ── 이 파일이 생긴 이유 ────────────────────────────────
//  지문(KoreanText)만 양쪽 정렬이고 해설(SwiftUI Text)은 왼쪽 정렬이라 두 글의
//  모양이 달랐다. SwiftUI 의 `Text` 는 **양쪽 정렬을 지원하지 않는다**
//  (`multilineTextAlignment` 에 `.justified` 가 없다). 그래서 해설도 UILabel 로
//  그리게 되었고, 그러면 줄바꿈 규칙이 두 벌이 된다 — 그걸 막으려고 규칙을
//  여기로 빼서 둘이 같은 것을 보게 했다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KoreanText(지문), FeedbackSheet·CorrectAnswerSheet(해설 본문)
//  기대는 것    : UIKit 뿐
//

import SwiftUI
import UIKit

enum KoreanTextLayout {

    /// 줄을 바꿔도 되는 자리와 바꾸면 안 되는 자리를 **글자 사이에 미리 심어** 둔다.
    ///
    /// 폭이 0인 글자 두 개를 씁니다. 화면에는 아무것도 안 보이고, 줄바꿈 판단에만 쓰입니다.
    ///
    /// | 자리 | 넣는 것 | 뜻 |
    /// |---|---|---|
    /// | 한글과 한글 사이 | ZERO WIDTH SPACE (U+200B) | 여기서 끊어도 된다 |
    /// | 숫자와 뒤따르는 한글 사이 | WORD JOINER (U+2060) | 여기서는 끊지 마라 ("2333년") |
    ///
    /// 낱말 안에 끊어도 되는 자리를 심어 두면, 줄바꿈 자체는 평소대로 낱말 단위
    /// (`byWordWrapping`)로 두면서도 줄을 글자 단위처럼 빽빽하게 채울 수 있습니다.
    /// **줄 끝의 공백이 알아서 흡수되는 것**이 낱말 단위 줄바꿈을 쓰는 이유입니다 —
    /// `byCharWrapping` 은 공백도 한 글자로 보기 때문에 그 공백이 다음 줄 첫머리로
    /// 넘어가 한 칸 들여쓴 것처럼 보입니다.
    ///
    /// - Note: 강조·형광펜·낱말 문자열도 같은 처리를 거친 뒤 찾아야 구간을 찾을 수 있습니다.
    static func prepared(_ text: String) -> String {
        // 여기서 줄을 바꿔도 된다는 표시. 폭이 0이라 화면에는 안 보인다.
        let zeroWidthSpace: Character = "\u{200B}"
        // 여기서는 줄을 바꾸지 말라는 표시. 역시 폭이 0이다.
        let wordJoiner: Character = "\u{2060}"

        var result = ""
        var previous: Character?

        for character in text {
            if let previous {
                if previous.isNumber, character.isHangul {
                    // "2333년" 은 갈라지면 안 된다.
                    result.append(wordJoiner)
                } else if previous.isHangul, character.isHangul {
                    // 한글과 한글 사이는 끊어도 된다 — 줄을 빽빽하게 채우는 핵심.
                    result.append(zeroWidthSpace)
                }
            }
            result.append(character)
            previous = character
        }
        return result
    }

    /// 양쪽 정렬 + 낱말 단위 줄바꿈 문단 스타일.
    ///
    /// 낱말 **안에서도** 끊을 수 있게, ``prepared(_:)`` 가 한글과 한글 사이에
    /// 끊어도 되는 자리를 미리 심어 둔다. 둘은 한 세트다.
    ///
    /// 왜 이렇게 도는가 —
    /// 1. 낱말 단위로만 끊으면(+`hangulWordPriority`) 줄 끝에 낱말 하나만큼
    ///    (80~130pt)이 통째로 남는다. 양쪽을 맞추려고 그 빈자리를 띄어쓰기에 몰면
    ///    낱말 사이가 쩍 벌어지고, `.justified` 에 맡기면 한글을 CJK 로 보고 글자
    ///    사이를 전부 벌려 「임진왜란」이 「임 진 왜 란」이 된다.
    /// 2. 그래서 `byCharWrapping`(아무 데서나 끊기)으로 바꿨더니 줄은 빽빽하게
    ///    찼는데, 이번엔 **띄어쓰기도 한 글자로 보기 때문에** 줄 첫머리에 공백이
    ///    남았다 — 「…나쁜 / ␣귀신을…」처럼 한 칸 들여쓴 것처럼 보인다.
    /// 3. 지금 방식은 둘 다 피한다. 줄바꿈은 평소대로 낱말 단위라 **줄 끝의 공백은
    ///    알아서 흡수되고**, 낱말 안에 심어 둔 자리 덕분에 줄은 여전히 빽빽하게
    ///    차서 벌릴 폭이 몇 pt밖에 안 남는다.
    static func paragraphStyle(lineSpacing: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineBreakMode = .byWordWrapping           // 줄 끝 공백을 흡수한다
        paragraph.lineBreakStrategy = []                    // 한글 낱말 보호는 끈다
        paragraph.lineSpacing = lineSpacing
        return paragraph
    }
}

/// 낱말 하나만 색과 굵기가 다른 한 덩어리 글을, **지문과 똑같은 규칙으로** 그린다.
///
/// 해설 본문(오답·정답 창)이 이걸 쓴다. SwiftUI 의 `Text` 로는 양쪽 정렬을 할 수
/// 없어서 UILabel 을 감쌌습니다 — 줄바꿈 규칙은 ``KoreanTextLayout`` 하나만 봅니다.
///
/// - Note: 칠할 낱말이 글 안에 **여러 번 나오면 전부** 칠합니다. 해설에서 정답
///   낱말이 두세 번 나오는 일이 흔하기 때문입니다.
struct JustifiedKoreanText: UIViewRepresentable {

    let text: String
    var font: UIFont
    var color: UIColor = .black
    var lineSpacing: CGFloat = 7

    /// 색과 굵기를 다르게 칠할 낱말. `nil` 이면 글 전체가 같은 모양이다.
    var coloredWord: String?
    var coloredWordColor: UIColor = .black
    /// 칠한 낱말에 쓸 글꼴. `nil` 이면 ``font`` 를 그대로 쓴다(색만 바뀐다).
    var coloredWordFont: UIFont?

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        // 글이 길어지면 세로로 줄어들지 않게 못을 박아 둔다. (KoreanText 와 같다)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let displayed = KoreanTextLayout.prepared(text)

        let attributed = NSMutableAttributedString(
            string: displayed,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: KoreanTextLayout.paragraphStyle(lineSpacing: lineSpacing),
            ]
        )

        if let coloredWord, !coloredWord.isEmpty {
            // 찾을 낱말도 같은 전처리를 거쳐야 한다 — 글에는 글자 사이에 폭 0인
            // 글자가 끼어 있어서, 원래 낱말 그대로는 못 찾는다.
            let target = KoreanTextLayout.prepared(coloredWord)
            let source = displayed as NSString
            var searchRange = NSRange(location: 0, length: source.length)

            while searchRange.length > 0 {
                let found = source.range(of: target, options: [], range: searchRange)
                guard found.location != NSNotFound else { break }

                attributed.addAttribute(.foregroundColor, value: coloredWordColor, range: found)
                attributed.addAttribute(.font, value: coloredWordFont ?? font, range: found)

                let next = found.location + found.length
                searchRange = NSRange(location: next, length: source.length - next)
            }
        }

        label.attributedText = attributed
    }

    /// 폭이 정해지면 그 폭에서 필요한 높이를 SwiftUI 에 알려준다.
    ///
    /// 이것이 없으면 SwiftUI 가 UIKit 뷰의 높이를 몰라 글이 잘립니다. (KoreanText 와 같다)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }
}

extension Character {
    /// 한글(음절·자모)인지 여부.
    var isHangul: Bool {
        unicodeScalars.allSatisfy { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)          // 한글 음절 (가 ~ 힣)
                || (0x1100...0x11FF).contains(scalar.value)   // 한글 자모
                || (0x3130...0x318F).contains(scalar.value)   // 호환용 자모
        }
    }
}
