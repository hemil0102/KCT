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
//  ├─ highlight / highlightColor     따옴표로 감싸고 색 + 더 굵은 글자로 강조 (O/X 의 판단 대상, 밑줄 없음)
//  ├─ marker / markerColor           형광펜(배경색)으로 칠할 부분 (묻는 대상)
//  ├─ selectedWord / selectedWordBackgroundColor / selectedWordTextColor
//  │     하단 사전 시트가 열려 있는 낱말 — 배경은 모달 배경(보라), 글자는 모달
//  │     낱말 글자색(주황). 배경은 BackgroundHighlight로 모서리를 살짝 둥글린다 —
//  │     시트가 닫히면 selectedWord가 nil이 되어 둘 다 함께 사라진다
//  ├─ makeUIView(context:)           UnderlineLabel 준비 (여러 줄, 세로 크기 우선)
//  ├─ updateUIView(_:context:)       문단 스타일 + 강조 두 종류를 입힌다
//  ├─ sizeThatFits(...)              폭에 맞는 높이를 SwiftUI 에 알려준다
//  └─ keepingNumbersWithUnits(_:)    "2333년" 이 갈라지지 않게 WORD JOINER 삽입
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 이 지문·강조·형광펜을 넘긴다
//    → keepingNumbersWithUnits() 로 숫자+한글을 붙여 둔다
//    → NSMutableAttributedString 에 문단 스타일(hangulWordPriority) 적용
//    → marker 구간에 배경색, highlight·glossary 구간은 밑줄 정보만 UnderlineLabel 에 넘긴다
//    → UILabel 의 .underlineStyle 은 안 쓴다 — 글자 아래쪽(받침)과 겹쳐서, 대신
//      UnderlineLabel 이 직접 원하는 간격만큼 띄워 그린다
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
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left                         // 왼쪽부터 읽기 편하게
        paragraph.lineBreakMode = .byWordWrapping           // 단어 단위 줄바꿈
        paragraph.lineBreakStrategy = .hangulWordPriority   // 한글 단어 중간에서 끊지 않음
        paragraph.lineSpacing = lineSpacing

        var displayed = Self.keepingNumbersWithUnits(text)

        // O/X 판단 대상("답")을 여는/닫는 큰따옴표(“ ”)로 감싸 강조한다. 지문
        // 원문에는 없는 문자라 화면에 보여줄 때만 문자열에 끼워 넣는다 — 색+
        // 굵기(아래 강조 처리 참고)만으로는 신호가 약할 수 있어서 따옴표를
        // 더했다(10차 계획 9번 후속 요청). 여기서 찾은 범위(따옴표 포함)를
        // highlightRange 에 남겨 뒀다가 강조 처리에서 그대로 쓴다 — attributed
        // 문자열을 만들기 전에 끼워 넣어야 그 뒤 marker·glossary 검색이 이
        // 문자열 기준으로 어긋나지 않는다.
        var highlightRange: NSRange?
        if let highlight, !highlight.isEmpty {
            let target = Self.keepingNumbersWithUnits(highlight)
            if let swiftRange = displayed.range(of: target) {
                let quoted = "“\(target)”"
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
            let target = Self.keepingNumbersWithUnits(marker)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                attributed.addAttribute(.backgroundColor, value: markerColor, range: range)
            }
        }

        // 밑줄은 .underlineStyle 을 안 쓴다 — 폰트가 정한 자리는 받침(글자 아래쪽)과
        // 겹칠 수 있다. 색만 여기서 입히고, 실제 선은 UnderlineLabel 이 간격을 두고 그린다.
        var underlines: [UnderlineLabel.Underline] = []

        // 강조 구간("답", 따옴표 포함)은 밑줄이 아니라 색 + 더 굵은 글자로
        // 표시한다 — 10차 계획 9번, 세 시안 중 어머니가 고른 "시안 1(색상+
        // 굵기만)". 지문 글자가 이미 기본으로 굵어서(.bold), 구분되게 보이려면
        // 그보다 한 단계 더 굵은 무게(.heavy)를 줘야 한다. 범위는 위에서 따옴표를
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
            let target = Self.keepingNumbersWithUnits(entry.word)
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
        // 밑줄이 있으면 마지막 줄 밑에 여유가 더 필요할 수 있다. 그런데 underlineGap 을
        // 그대로 더하면, 사용자가 밑줄을 올리려고(음수 값) 조절할 때 이 높이가 실제
        // 글자 높이보다 작아져 버려서 — 형광펜(marker) 배경이나 글자 자체가 아래쪽에서
        // 잘려 나간다. 그래서 절대 자연스러운 높이(fitting.height) 밑으로는 안 내려가게
        // max(0, ...)로 막는다. 밑줄을 얼마로 조절하든 형광펜·글자는 항상 안전하다.
        let underlineAllowance = uiView.underlines.isEmpty
            ? 0
            : max(0, uiView.underlineGap - uiView.lineFragmentPadding + uiView.underlineDepthBelowLine + 2)
        return CGSize(width: width, height: fitting.height + underlineAllowance)
    }

    /// 숫자와 뒤따르는 한글이 줄바꿈으로 갈라지지 않게 묶는다.
    ///
    /// `hangulWordPriority` 는 한글끼리만 붙여 주므로, "2333년" 사이에 폭이 없는 WORD JOINER(U+2060)를 끼워 넣습니다.
    ///
    /// - Note: 강조·형광펜 문자열도 같은 처리를 거친 뒤 찾아야 구간을 찾을 수 있습니다.
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

/// 밑줄을 글자에서 살짝 띄워서 직접 그리는 라벨.
///
/// `NSAttributedString.underlineStyle`은 폰트가 정한 자리에만 그려져, 받침이 있는
/// 글자(예: "국") 아래쪽과 겹쳐 보일 수 있습니다. 그 속성은 아예 쓰지 않고, 대신 이
/// 라벨이 글자를 다 그린 뒤 원하는 만큼 아래로 띄운 자리에 선을 직접 그립니다.
final class UnderlineLabel: UILabel {
    /// 밑줄 하나. `range`는 `attributedText`의 문자 범위입니다.
    struct Underline {
        let range: NSRange
        let color: UIColor
        /// true면 점선(사전 낱말), false면 실선.
        ///
        /// 지금 지문에 그려지는 밑줄은 **전부 점선**이다 — 9차에서 O/X 의 답을
        /// 밑줄이 아니라 색·굵기·따옴표로 바꾸면서 실선을 쓰는 자리가 없어졌다.
        /// 실선 경로는 다시 필요해질 때를 위해 남겨 둔다.
        let isDotted: Bool
    }

    /// 배경을 둥글게 채워 그릴 구간 하나. `range`는 `attributedText`의 문자 범위입니다.
    /// 밑줄과 달리 **글자보다 먼저(아래에)** 그린다 — 그래야 글자가 그 위에 그대로
    /// 보인다. SwiftUI의 `Text`/`AttributedString`은 `backgroundColor` 속성을
    /// 각진 사각형으로만 그릴 수 있어서, 둥근 모서리가 필요한 자리(예: 낱말 사전
    /// 해설 속 "(뜻)")는 밑줄과 같은 방식(줄 단위로 TextKit 레이아웃을 계산)으로
    /// 직접 채워 그린다.
    struct BackgroundHighlight {
        let range: NSRange
        let color: UIColor
        let cornerRadius: CGFloat
        /// true면 배경 아래쪽을 줄 간격(lineFragmentPadding)만큼 미리 줄여서,
        /// 같은 구간에 붙는 밑줄이 배경 안에 덮이지 않고 배경 바로 아래에
        /// 그려지게 한다 — 지문의 사전 낱말처럼 밑줄과 배경이 함께 있는 자리에서만
        /// 켠다. 밑줄이 없는 자리(모달의 낱말 배경 등)에서 이 값을 켜면, 밑줄
        /// 자리를 비워 둘 필요가 없는데도 배경 아래쪽이 잘려 글자(특히 받침)를
        /// 온전히 감싸지 못하는 문제가 생긴다 — 그래서 기본값은 false다.
        var excludesUnderlineSpacing: Bool = false
    }

    var underlines: [Underline] = []
    var backgroundHighlights: [BackgroundHighlight] = []

    /// 글자 아래쪽에서 밑줄 중심까지 띄우는 간격. **0이 "받침 바로 아래"** 자리다.
    ///
    /// 기본값을 2로 둔 것은, 0일 때 점선이 받침("국"·"웅" 같은 글자 아래)에 바짝
    /// 붙어 글자와 섞여 보였기 때문이다 (10차 계획 10번).
    var underlineGap: CGFloat = 2

    /// 실선 두께. 지금은 쓰는 곳이 없다 (``Underline/isDotted`` 참고).
    var underlineThickness: CGFloat = 2.5

    /// 점선의 점 하나 지름.
    ///
    /// 1.6pt 짜리 얇은 점선이 어머니 눈에 잘 안 띈다는 요청으로 키운 값이다
    /// (10차 계획 10번, 시안 1 "또렷한 동그란 점").
    var dottedDotDiameter: CGFloat = 3

    /// 점과 점 사이에 두고 싶은 간격.
    ///
    /// **실제 간격은 낱말마다 조금씩 다르다.** 이 값은 "이 정도면 좋겠다"는 기준일
    /// 뿐이고, 낱말 너비에 점이 몇 개 들어가는지 센 뒤 고르게 다시 나눈다 —
    /// 그래야 낱말 양 끝에서 점이 잘리지 않는다. ``drawText(in:)`` 참고.
    var dottedDotSpacing: CGFloat = 3

    /// 밑줄이 `underlineGap` 이 가리키는 자리보다 아래로 내려가는 깊이.
    ///
    /// 점선은 점의 반지름만큼, 실선은 두께의 절반만큼 내려간다. 뷰 높이를 잡는
    /// `sizeThatFits` 가 이 값을 봐야, 점을 키웠을 때 마지막 줄 밑에서 점이
    /// 잘리지 않는다.
    var underlineDepthBelowLine: CGFloat {
        max(dottedDotDiameter / 2, underlineThickness / 2)
    }

    /// `NSLayoutManager.boundingRect(forGlyphRange:in:)`가 돌려주는 사각형은 글자가
    /// 놓인 "줄 한 칸 전체"(line fragment)라서, 문단 스타일의 줄 간격(`lineSpacing`,
    /// 8pt)만큼 실제 글자 아래쪽보다 더 아래까지 내려가 있다. `underlineGap`을 "글자에서부터
    /// 띈 거리"로 쓰려면 이 여분을 먼저 빼야 한다. TextKit이 이 값을 공개 API로 알려주지
    /// 않아서, 실측으로 정한 값이다 — `underlineGap = 0`일 때 밑줄이 훨씬 아래로 내려가
    /// 보였고, `-10`을 줘야 원하는 자리(받침 바로 아래)가 나왔다. 그래서 이 보정값을 먼저
    /// 빼서 `underlineGap = 0`이 바로 그 자리가 되게 한다.
    let lineFragmentPadding: CGFloat = 10

    override func drawText(in rect: CGRect) {
        // UILabel 은 rect 가 실제 글자 높이보다 크면 그 안에서 세로 가운데 정렬을 해
        // 버린다. sizeThatFits(...)가 밑줄 여유만큼 rect 를 키워 주므로, 그대로
        // super.drawText(in: rect) 를 부르면 글자가 살짝 아래로 밀려서 그려지고,
        // 아래에서 같은 rect 로 계산하는 밑줄 위치와 어긋난다. 그래서 "글자만 필요한
        // 높이"를 다시 구해 **항상 위쪽에 붙여** 그리고, 밑줄도 같은 사각형 기준으로
        // 계산한다 — 그래야 글자와 밑줄이 같은 좌표계를 본다.
        let textHeight = super.sizeThatFits(CGSize(width: rect.width, height: .greatestFiniteMagnitude)).height
        let topAlignedRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: textHeight)

        // 배경(backgroundHighlights)도 밑줄(underlines)도 없으면 예전과 똑같이
        // 그냥 글자만 그린다 — TextKit 스택을 새로 만드는 비용도 안 든다.
        guard let attributedText, !(underlines.isEmpty && backgroundHighlights.isEmpty) else {
            super.drawText(in: topAlignedRect)
            return
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            super.drawText(in: topAlignedRect)
            return
        }

        // 실제 화면에 그려진 것과 같은 줄바꿈을 다시 계산해서, 구간이 어느 줄의
        // 어디에 놓였는지(글자 범위 → 사각형)를 알아낸다. 아래에서 글자를 그릴 때와
        // 같은 topAlignedRect 크기를 써야 좌표가 맞는다.
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: topAlignedRect.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        layoutManager.addTextContainer(textContainer)

        let originX = topAlignedRect.minX
        let originY = topAlignedRect.minY

        // 배경을 먼저 채운다 — 글자를 그 위에 그려야 글자가 가려지지 않는다. 밑줄과
        // 달리 여백 없이 글자 폭에 딱 맞는 사각형에 모서리만 둥글게 깎는다(가로로
        // 여유를 더 주면, 옆 글자는 이미 그 여유가 없다고 가정하고 배치돼 있어서
        // 겹쳐 보인다 — 세로도 줄 칸(line fragment) 그대로 써서 같은 문제를 피한다).
        for highlight in backgroundHighlights {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: highlight.range, actualCharacterRange: nil)

            // 구간이 줄 끝에 걸려 두 줄에 나뉘어도, 줄마다 따로 둥근 사각형을 채운다.
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, container, effectiveGlyphRange, _ in
                let intersection = NSIntersectionRange(glyphRange, effectiveGlyphRange)
                guard intersection.length > 0 else { return }

                let box = layoutManager.boundingRect(forGlyphRange: intersection, in: container)
                // boundingRect가 돌려주는 높이는 밑줄 계산과 똑같이 줄 간격(lineSpacing)
                // 만큼 글자 아래쪽보다 더 내려가 있다(아래 밑줄 루프의 lineFragmentPadding
                // 설명 참고). excludesUnderlineSpacing이 켜진 배경(지문의 사전 낱말처럼
                // 같은 구간에 점선 밑줄이 함께 붙는 경우)만 마지막 줄이 아닐 때 그만큼
                // 미리 빼서, 밑줄이 배경 안에 덮이지 않고 배경 바로 아래에 그려지게
                // 한다. 밑줄이 없는 배경(모달의 낱말 배경 등)은 이 보정을 하지 않고
                // 줄 칸 높이를 그대로 써서 글자(받침 포함)를 잘리지 않게 다 감싼다.
                let isLastLine = effectiveGlyphRange.location + effectiveGlyphRange.length >= layoutManager.numberOfGlyphs
                let bottomTrim = (highlight.excludesUnderlineSpacing && !isLastLine) ? self.lineFragmentPadding : 0
                let fillRect = CGRect(
                    x: originX + box.minX,
                    y: originY + box.minY,
                    width: box.width,
                    height: box.height - bottomTrim
                )
                let path = UIBezierPath(roundedRect: fillRect, cornerRadius: highlight.cornerRadius)
                context.saveGState()
                context.setFillColor(highlight.color.cgColor)
                path.fill()
                context.restoreGState()
            }
        }

        super.drawText(in: topAlignedRect)

        guard !underlines.isEmpty else { return }

        let gap = underlineGap
        let thickness = underlineThickness
        let padding = lineFragmentPadding
        let dotDiameter = dottedDotDiameter
        let dotSpacing = dottedDotSpacing

        for underline in underlines {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: underline.range, actualCharacterRange: nil)

            // 낱말이 줄 끝에 걸려 두 줄에 나뉘어도, 줄마다 따로 선을 긋는다.
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, container, effectiveGlyphRange, _ in
                let intersection = NSIntersectionRange(glyphRange, effectiveGlyphRange)
                guard intersection.length > 0 else { return }

                let box = layoutManager.boundingRect(forGlyphRange: intersection, in: container)
                // box.maxY 는 줄 전체 칸의 아래쪽이라 lineFragmentPadding 만큼 이미 더
                // 내려가 있다 — 그걸 먼저 빼서 "받침 바로 아래"를 0으로 맞춘 뒤 gap 을 더한다.
                // (이 클로저는 escaping 이라 self 프로퍼티는 미리 지역 상수로 꺼내 둔다 — padding)
                //
                // 그런데 이 여분(lineSpacing)은 "다음 줄과의 사이"에만 들어간다 — 뒤에
                // 이어지는 줄이 없는 마지막 줄의 line fragment 에는 애초에 안 붙어 있다.
                // 그 마지막 줄에서까지 padding 을 빼면 오히려 그만큼 위로 더 올라가
                // 글자와 겹친다(현충일처럼 지문의 실제 마지막 줄에 걸린 낱말에서 확인된
                // 증상). 그래서 지금 줄이 전체 글자의 마지막 줄인지 먼저 확인한다.
                let isLastLine = effectiveGlyphRange.location + effectiveGlyphRange.length >= layoutManager.numberOfGlyphs
                let correction = isLastLine ? 0 : padding
                let y = originY + box.maxY - correction + gap
                let startX = originX + box.minX
                let endX = originX + box.maxX

                context.saveGState()
                if underline.isDotted {
                    // 점선을 `setLineDash` 로 그리지 않는 이유 — 그 방식은 낱말 왼쪽
                    // 끝에서 패턴을 시작해 일정 주기로 반복할 뿐이라, 낱말 너비가 그
                    // 주기로 나눠떨어지지 않으면 오른쪽 끝에서 점이 반쯤 잘린 채
                    // 끝난다. 그래서 낱말 너비에 점이 몇 개 들어가는지 먼저 세고,
                    // 양 끝에 점이 온전히 놓이도록 고르게 배분해 하나씩 찍는다.
                    // 그 대가로 점 간격은 낱말마다 조금씩 달라진다 — 잘리지 않는
                    // 쪽이 더 중요하다고 봤다 (10차 계획 10번).
                    let width = endX - startX
                    // 줄 끝에 점 하나보다 좁은 조각만 걸리는 극단적인 경우에도 점이
                    // 그 조각 밖으로 삐져나가지 않게, 지름을 너비 안쪽으로 줄인다.
                    let diameter = min(dotDiameter, width)
                    let radius = diameter / 2
                    context.setFillColor(underline.color.cgColor)

                    // 점 "중심"이 놓일 수 있는 구간. 양 끝에서 반지름만큼 안으로
                    // 들어와야 점이 낱말 밖으로 삐져나가지 않는다. 줄 끝에 한 글자만
                    // 걸린 경우처럼 점 하나보다 좁으면 0이 된다.
                    let centerSpan = max(0, width - diameter)
                    let count = max(1, Int((centerSpan / (diameter + dotSpacing)).rounded()) + 1)
                    // 점이 하나뿐이면 낱말 한가운데에 놓는다.
                    let step = count > 1 ? centerSpan / CGFloat(count - 1) : 0
                    let firstCenterX = count > 1 ? startX + radius : startX + width / 2

                    for index in 0 ..< count {
                        let centerX = firstCenterX + step * CGFloat(index)
                        context.fillEllipse(
                            in: CGRect(
                                x: centerX - radius,
                                y: y - radius,
                                width: diameter,
                                height: diameter
                            )
                        )
                    }
                } else {
                    context.setStrokeColor(underline.color.cgColor)
                    context.setLineCap(.round)
                    context.setLineWidth(thickness)
                    context.setLineDash(phase: 0, lengths: [])
                    context.move(to: CGPoint(x: startX, y: y))
                    context.addLine(to: CGPoint(x: endX, y: y))
                    context.strokePath()
                }
                context.restoreGState()
            }
        }
    }
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
