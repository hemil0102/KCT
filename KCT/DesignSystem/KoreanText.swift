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
//  ├─ highlight / highlightColor     낫표(「 」)로 감싸고 색 + 더 굵은 글자로 강조 (O/X 의 판단 대상, 밑줄 없음)
//  ├─ marker / markerColor           형광펜(배경색)으로 칠할 부분 (묻는 대상)
//  ├─ selectedWord / selectedWordBackgroundColor / selectedWordTextColor
//  │     하단 사전 시트가 열려 있는 낱말 — 배경은 연라벤더 배지(wordBadgeBackground),
//  │     글자는 짙은 보라(wordBadgeText). 모달 헤더의 낱말 배지와 **같은 색**이라
//  │     탭한 낱말과 모달이 이어져 보인다. 배경은 BackgroundHighlight 로 모서리를
//  │     살짝 둥글린다 — 시트가 닫히면 selectedWord 가 nil 이 되어 둘 다 함께 사라진다
//  ├─ makeUIView(context:)           UnderlineLabel 준비 (여러 줄, 세로 크기 우선)
//  ├─ updateUIView(_:context:)       문단 스타일 + 강조 두 종류를 입힌다
//  ├─ sizeThatFits(...)              폭에 맞는 높이를 SwiftUI 에 알려준다
//  ├─ preparedForLineBreaks(_:)     한글 사이엔 끊어도 되는 자리(U+200B),
//  │                                숫자+한글 사이엔 끊지 말라는 자리(U+2060)
//  ├─ fittingFont(...)               주어진 폭·최대 높이 안에 맞는 가장 큰 글꼴을 고른다
//  │                                (11차 후속 — 지문이 화면 절반을 넘지 않게 하는 데 쓴다)
//  ├─ measuredHeight(...)            fittingFont 가 후보 글꼴마다 실제 높이를 재는 데 쓰는 도구
//  └─ Coordinator                    탭이 어느 낱말에 떨어졌는지 알아내는 다리
//
//  실제로 밑줄·배경을 그리는 것은 UnderlineLabel(DesignSystem/UnderlineLabel.swift)이다 —
//  이 파일은 **무엇에 칠할지**(범위 계산)만 하고, **어떻게 그릴지**는 그쪽이 안다.
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 이 지문·강조·형광펜을 넘긴다
//    → preparedForLineBreaks() 로 끊어도 되는/안 되는 자리를 심는다
//    → NSMutableAttributedString 에 문단 스타일(양쪽 정렬 + 글자 단위 줄바꿈) 적용
//    → marker 구간에 배경색, highlight·glossary 구간은 밑줄 정보만 UnderlineLabel 에 넘긴다
//    → UILabel 의 .underlineStyle 은 안 쓴다 — 글자 아래쪽(받침)과 겹쳐서, 대신
//      UnderlineLabel 이 직접 원하는 간격만큼 띄워 그린다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (지문 표시)
//  기대는 것    : UIKit, AppColor, UnderlineLabel(그리기), KoreanTextLayout(줄바꿈 규칙)
//  건드리지 않는 것 : 무엇을 강조할지 판단 — QuizItem 이 정해서 넘겨준다.
//                    밑줄을 실제로 그리는 계산 — UnderlineLabel 의 몫이다
//

import SwiftUI
import UIKit

/// 한국어 지문을 읽기 좋게 보여주는 텍스트 뷰.
///
/// SwiftUI 의 `Text` 는 한글 줄바꿈 전략을 지원하지 않아 "대한민국" 이 갈라지는데, `hangulWordPriority` 는 `NSParagraphStyle` 에만 있어 UILabel 을 감쌌습니다.
/// ``marker`` 는 형광펜(배경색)으로 묻는 대상을, ``highlight`` 는 색과 더 굵은 글자(밑줄 없음)로 O/X 의 판단 대상을 강조합니다.
/// 두 가지 신호(색·굵기)를 함께 주는 것은 색 구분이 어려운 분도 알아볼 수 있게 하기 위해서입니다.
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

    /// 지금 하단 사전 시트가 열려 있는 낱말. 이 낱말에만 배경·글자색을 칠한다 —
    /// 다른 낱말은 안 건드린다. QuestionScreen 이 glossarySelection 을 그대로
    /// 넘겨주므로, 시트가 닫혀 그 값이 nil이 되면 둘 다 같이 사라지고 원래 모습
    /// (검정 글자, 배경 없음)으로 돌아온다.
    var selectedWord: String?
    /// 하단 사전 모달의 낱말에 쓰는 것과 같은 연라벤더 배지 배경(wordBadgeBackground).
    /// `NSAttributedString.backgroundColor` 속성이 아니라
    /// `UnderlineLabel.BackgroundHighlight`(TextKit 줄 단위 계산)로 그려서 모서리를
    /// 살짝 둥글게 뺄 수 있다 — 그 속성은 각진 사각형만 가능하다.
    var selectedWordBackgroundColor: UIColor = UIColor(AppColor.wordBadgeBackground)
    /// 하단 사전 모달에서 낱말 글자에 쓰는 것과 같은 짙은 보라(wordBadgeText).
    var selectedWordTextColor: UIColor = UIColor(AppColor.wordBadgeText)

    /// 임시 스위치 — 버그를 밑줄과 분리해서 보려고 노란 형광펜 배경을 잠시 꺼 둔다.
    /// 다시 켜려면 이 값을 true로 되돌리면 된다 (marker 자체는 그대로 넘어오고 있다).
    private let showsMarkerHighlight = false
    
    /// 점선 밑줄로 표시하고, 탭하면 뜻을 보여줄 낱말들.
    var glossary: [GlossaryEntry] = []

    /// 낱말을 탭했을 때 호출. 위치(CGRect)가 필요 없어 하단 패널 쪽이 훨씬 단순합니다.
    var onTapWord: ((GlossaryEntry) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> UnderlineLabel {
        let label = UnderlineLabel()
        
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        )
        context.coordinator.label = label
        
        label.numberOfLines = 0

        // 지문은 길어질 수 있다. 세로로 절대 줄어들지 않게 못을 박아 둔다.
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UnderlineLabel, context: Context) {
        // 줄바꿈·정렬 규칙은 해설 본문(JustifiedKoreanText)과 **같은 것을 본다** —
        // KoreanTextLayout 에 한 벌만 두었다. 규칙이 두 군데로 갈라지면 반드시 어긋난다.
        let paragraph = KoreanTextLayout.paragraphStyle(lineSpacing: lineSpacing)

        var displayed = Self.preparedForLineBreaks(text)

        // O/X 판단 대상("답")을 낫표(「 」)로 감싸 강조한다. 지문 원문에는 없는
        // 문자라 화면에 보여줄 때만 문자열에 끼워 넣는다 — 색+굵기(아래 강조 처리
        // 참고)만으로는 신호가 약할 수 있어서 기호를 더했다(10차 계획 9번 후속 요청).
        // 처음엔 큰따옴표(“ ”)였는데, 데모의 낫표가 낱말 경계가 더 또렷해 보여
        // 바꿨다(11차 4-32). 낫표와 낱말 사이에는 WORD JOINER(U+2060)를 넣어
        // 「 만 줄 끝에 남거나 」 만 다음 줄 첫머리로 떨어지지 않게 붙여 둔다.
        // 여기서 찾은 범위(낫표 포함)를
        // highlightRange 에 남겨 뒀다가 강조 처리에서 그대로 쓴다 — attributed
        // 문자열을 만들기 전에 끼워 넣어야 그 뒤 marker·glossary 검색이 이
        // 문자열 기준으로 어긋나지 않는다.
        var highlightRange: NSRange?
        if let highlight, !highlight.isEmpty {
            let target = Self.preparedForLineBreaks(highlight)
            if let swiftRange = displayed.range(of: target) {
                let quoted = "「\u{2060}\(target)\u{2060}」"
                displayed.replaceSubrange(swiftRange, with: quoted)
                highlightRange = (displayed as NSString).range(of: quoted)
            }
        }

        let attributed = NSMutableAttributedString(
            string: displayed,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )

        // 묻는 대상은 형광펜(배경색)으로 칠한다. (showsMarkerHighlight = false 인 동안은 꺼 둠)
        if showsMarkerHighlight, let marker, !marker.isEmpty {
            let target = Self.preparedForLineBreaks(marker)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                attributed.addAttribute(.backgroundColor, value: markerColor, range: range)
            }
        }

        // 밑줄은 .underlineStyle 을 안 쓴다 — 폰트가 정한 자리는 받침(글자 아래쪽)과
        // 겹칠 수 있다. 색만 여기서 입히고, 실제 선은 UnderlineLabel 이 간격을 두고 그린다.
        var underlines: [UnderlineLabel.Underline] = []

        // 강조 구간("답", 낫표 포함)은 밑줄이 아니라 색 + 더 굵은 글자로
        // 표시한다 — 10차 계획 9번, 세 시안 중 어머니가 고른 "시안 1(색상+
        // 굵기만)". 지문 글자가 이미 기본으로 굵어서(.bold), 구분되게 보이려면
        // 그보다 한 단계 더 굵은 무게(.heavy)를 줘야 한다. 범위는 위에서 낫표를
        // 끼워 넣을 때 이미 구해 둔 highlightRange 를 그대로 쓴다. 밑줄을 안
        // 그리므로 낱말의 점선 밑줄과 같은 자리에서 겹칠 일이 없다 — 그래서
        // 아래 사전 낱말 루프도 "강조와 겹치는 낱말은 건너뛴다"는 예외 없이
        // 원래대로, 모든 어려운 낱말이 항상 점선 밑줄 + 탭 가능하다.
        if let highlightRange {
            attributed.addAttribute(.foregroundColor, value: highlightColor, range: highlightRange)
            attributed.addAttribute(
                .font,
                value: UIFont.systemFont(ofSize: font.pointSize, weight: .heavy),
                range: highlightRange
            )
        }
        
        // 어려운 낱말은 점선 밑줄. 탭 판정을 위해 범위도 함께 기억해 둔다.
        var hits: [(range: NSRange, entry: GlossaryEntry)] = []

        // 지금 사전 시트가 열려 있는 낱말의 배경(둥근 모서리). NSAttributedString의
        // backgroundColor(각진 사각형만 가능) 대신 UnderlineLabel.BackgroundHighlight를
        // 쓴다 — GlossaryPanel의 해설 배경과 같은 방식이다.
        var backgroundHighlights: [UnderlineLabel.BackgroundHighlight] = []

        for entry in glossary {
            let target = Self.preparedForLineBreaks(entry.word)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                underlines.append(.init(range: range, color: UIColor(AppColor.textMuted), isDotted: true))
                hits.append((range, entry))
                
                // 지금 사전 시트가 열려 있는 낱말이면 배경(둥근 모서리)과 글자색을 칠한다.
                if entry.word == selectedWord {
                    attributed.addAttribute(.foregroundColor, value: selectedWordTextColor, range: range)
                    backgroundHighlights.append(
                        UnderlineLabel.BackgroundHighlight(
                            range: range,
                            color: selectedWordBackgroundColor,
                            cornerRadius: 6,
                            excludesUnderlineSpacing: true
                        )
                    )
                }
            }
        }
        
        context.coordinator.glossaryHits = hits
        context.coordinator.onTapWord = onTapWord

        label.attributedText = attributed
        label.underlines = underlines
        label.backgroundHighlights = backgroundHighlights
        label.setNeedsDisplay()
    }

    /// 폭이 정해지면 그 폭에서 필요한 높이를 계산해 SwiftUI 에 알려준다.
    ///
    /// 이것이 없으면 SwiftUI 가 UIKit 뷰의 높이를 몰라서 지문이 잘립니다.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UnderlineLabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }

        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // 마지막 줄 밑에 밑줄이 그려질 자리를 비워 둔다. **이걸 빼먹으면 마지막 줄에
        // 걸린 낱말의 점선만 안 보인다** — 뷰 높이가 글자 높이와 같아서 그 밑에 그린
        // 점이 통째로 잘려 나가기 때문이다. (「국경일」이 줄 끝에서 갈려 「국」은
        // 점선이 있고 「경일」은 없던 증상이 이것이었다.)
        //
        // 예전에는 여기서 lineFragmentPadding(10)을 빼고 있었다. 그건 **중간 줄**에서
        // 쓰는 보정값이라(UnderlineLabel.drawText 의 correction 참고) 여기 들어오면
        // 안 된다 — 2 - 10 + 1.5 + 2 = -4.5 가 되어 max(0,...)에 걸려 여유가 늘
        // 0이었다. 정작 잘릴 위험이 있는 마지막 줄은 그 보정을 안 쓰는데도 말이다.
        // 지금은 마지막 줄 기준 그대로 잡는다: 글자 아래로 gap(2)만큼 내려가고,
        // 점의 반지름(1.5)만큼 더 내려가며, 여유 2를 더해 5.5pt.
        //
        // max(0, ...)는 그대로 둔다 — 밑줄을 글자 위로 올리려고 underlineGap 에 음수를
        // 주면 이 값이 음수가 되어 뷰가 글자보다 작아지고, 형광펜 배경이나 글자 자체가
        // 아래에서 잘린다.
        let underlineAllowance = uiView.underlines.isEmpty
            ? 0
            : max(0, uiView.underlineGap + uiView.underlineDepthBelowLine + 2)
        return CGSize(width: width, height: fitting.height + underlineAllowance)
    }

    /// 줄바꿈 표시를 심는다. 실제 규칙은 ``KoreanTextLayout/prepared(_:)`` 에 있다.
    ///
    /// 해설 본문(``JustifiedKoreanText``)도 같은 것을 쓴다 — 지문과 해설이 같은
    /// 모양으로 보이려면 이 규칙이 한 벌이어야 한다.
    private static func preparedForLineBreaks(_ text: String) -> String {
        KoreanTextLayout.prepared(text)
    }

    /// 주어진 폭·최대 높이 안에 맞는 가장 큰 글꼴을 고른다. (11차 후속)
    ///
    /// 어머니가 정답·오답 해설 모달(화면 아래 절반, `.presentationDetents([.medium])`)을
    /// 내리지 않고도 문제를 같이 보려면, 지문이 항상 화면 위 절반 안에 다 들어와
    /// 있어야 한다. 짧은 지문은 `baseFont` 그대로 재도 이미 그 안에 들어오므로
    /// 그대로 돌려준다 — 예전 모습이 안 바뀐다. 길어서 넘치면 `minFontSize`에
    /// 닿을 때까지 1pt씩 줄여 가며 다시 재서, 절반 안에 드는 가장 큰 크기를 찾는다.
    /// 그래도 `minFontSize`에서까지 못 들어오면(아주 긴 지문) `minFontSize`를
    /// 그대로 돌려준다 — 이 경우는 지금처럼 questionArea 의 ScrollView 가 나머지를
    /// 스크롤로 보여준다.
    static func fittingFont(
        for text: String,
        baseFont: UIFont,
        minFontSize: CGFloat,
        maxHeight: CGFloat,
        width: CGFloat,
        lineSpacing: CGFloat
    ) -> UIFont {
        guard width > 0 else { return baseFont }
        guard measuredHeight(for: text, font: baseFont, width: width, lineSpacing: lineSpacing) > maxHeight else {
            return baseFont
        }

        var fontSize = baseFont.pointSize - 1
        while fontSize > minFontSize {
            let candidate = baseFont.withSize(fontSize)
            if measuredHeight(for: text, font: candidate, width: width, lineSpacing: lineSpacing) <= maxHeight {
                return candidate
            }
            fontSize -= 1
        }
        return baseFont.withSize(minFontSize)
    }

    /// 주어진 폭에서 이 지문이 실제로 차지할 높이를 잰다. `updateUIView`가 실제로
    /// 쓰는 것과 같은 문단 스타일(양쪽 정렬 + 글자 단위 줄바꿈)을 써야 실제 줄바꿈과
    /// 같은 값이 나온다 — 다만 강조 따옴표 삽입 같은 자잘한 처리는 하지 않는다(글자
    /// 두어 개 차이라 높이에 거의 영향이 없다).
    private static func measuredHeight(for text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat) -> CGFloat {
        // updateUIView 와 **같은 규칙**이어야 줄 수가 맞는다. 하나라도 다르면
        // 여기서 잰 높이와 실제로 그려지는 높이가 어긋나 글꼴 고르기가 헛돈다.
        let paragraph = KoreanTextLayout.paragraphStyle(lineSpacing: lineSpacing)

        let attributed = NSAttributedString(
            string: preparedForLineBreaks(text),
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        let bounding = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounding.height)
    }

    /// 탭 이벤트를 받아 어느 낱말이 눌렸는지 알아내는 다리 역할.
    /// `updateUIView` 가 매번 최신 범위(glossaryHits)를 여기 채워 둔다.
    final class Coordinator: NSObject {
        weak var label: UnderlineLabel?

        var glossaryHits: [(range: NSRange, entry: GlossaryEntry)] = []
        var onTapWord: ((GlossaryEntry) -> Void)?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let label, let attributedText = label.attributedText else { return }

            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage(attributedString: attributedText)
            textStorage.addLayoutManager(layoutManager)

            let textContainer = NSTextContainer(size: label.bounds.size)
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = label.numberOfLines
            layoutManager.addTextContainer(textContainer)

            let tapPoint = recognizer.location(in: label)
            let charIndex = layoutManager.characterIndex(
                for: tapPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            guard let hit = glossaryHits.first(
                where: { NSLocationInRange(charIndex, $0.range) }
            ) else {
                return
            }

            onTapWord?(hit.entry)
        }
    }
}
