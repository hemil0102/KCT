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
//  ├─ selectedWord / selectedWordColor  하단 사전 시트가 열려 있는 낱말의 배경색
//  │                                  (다시 읽기 버튼과 같은 색) — 시트가 닫히면
//  │                                  nil이 되어 배경도 함께 사라진다
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
/// ``marker`` 는 형광펜(배경색)으로 묻는 대상을, ``highlight`` 는 색과 굵은 밑줄로 O/X 의 판단 대상을 강조합니다.
/// 두 가지 신호를 함께 주는 것은 색 구분이 어려운 분도 알아볼 수 있게 하기 위해서입니다.
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

    /// 지금 하단 사전 시트가 열려 있는 낱말. 이 낱말에만 배경색을 칠한다 — 다른
    /// 낱말은 안 건드린다. QuestionScreen 이 glossarySelection 을 그대로 넘겨주므로,
    /// 시트가 닫혀 그 값이 nil이 되면 배경도 같이 사라지고 글자는 원래 검정으로
    /// 돌아온다(배경만 지웠을 뿐 글자색을 따로 바꾼 적이 없어서 자연히 그렇게 된다).
    var selectedWord: String?
    /// "다시 읽기" 버튼과 같은 배경색 — 낱말을 골랐다는 느낌을 그 버튼과 통일한다.
    var selectedWordColor: UIColor = UIColor(AppColor.secondaryBackground)

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

        let displayed = Self.keepingNumbersWithUnits(text)
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

        // 강조 구간은 시그니처 색 + 굵은 밑줄. 색과 밑줄 두 신호를 함께 준다.
        if let highlight, !highlight.isEmpty {
            let target = Self.keepingNumbersWithUnits(highlight)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                attributed.addAttribute(.foregroundColor, value: highlightColor, range: range)
                underlines.append(.init(range: range, color: highlightColor, isDotted: false))
            }
        }
        
        // 어려운 낱말은 점선 밑줄. 탭 판정을 위해 범위도 함께 기억해 둔다.
        var hits: [(range: NSRange, entry: GlossaryEntry)] = []
        
        for entry in glossary {
            let target = Self.keepingNumbersWithUnits(entry.word)
            let range = (displayed as NSString).range(of: target)
            if range.location != NSNotFound {
                underlines.append(.init(range: range, color: UIColor(AppColor.textMuted), isDotted: true))
                hits.append((range, entry))
                
                // 지금 사전 시트가 열려 있는 낱말이면 배경을 칠한다.
                if entry.word == selectedWord {
                    attributed.addAttribute(.backgroundColor, value: selectedWordColor, range: range)
                }
            }
        }
        
        context.coordinator.glossaryHits = hits
        context.coordinator.onTapWord = onTapWord

        label.attributedText = attributed
        label.underlines = underlines
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
            : max(0, uiView.underlineGap - uiView.lineFragmentPadding + uiView.underlineThickness / 2 + 2)
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
        /// true면 점선(사전), false면 굵은 실선(O/X 강조).
        let isDotted: Bool
    }

    var underlines: [Underline] = []

    /// 글자 아래쪽에서 밑줄까지 띄우는 간격. **0이 기본값이자 "받침 바로 아래"** 자리다.
    var underlineGap: CGFloat = 0

    /// 실선(강조) 두께. 점선(사전)은 이보다 얇게 고정해서 그린다.
    var underlineThickness: CGFloat = 2.5

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
        super.drawText(in: topAlignedRect)

        guard let attributedText, !underlines.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 실제 화면에 그려진 것과 같은 줄바꿈을 다시 계산해서, 낱말이 어느 줄의
        // 어디에 놓였는지(글자 범위 → 사각형)를 알아낸다. 위에서 글자를 그린 것과
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
        let gap = underlineGap
        let thickness = underlineThickness
        let padding = lineFragmentPadding

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
                context.setStrokeColor(underline.color.cgColor)
                context.setLineCap(.round)
                if underline.isDotted {
                    context.setLineWidth(1.6)
                    context.setLineDash(phase: 0, lengths: [1.2, 3.4])
                } else {
                    context.setLineWidth(thickness)
                    context.setLineDash(phase: 0, lengths: [])
                }
                context.move(to: CGPoint(x: startX, y: y))
                context.addLine(to: CGPoint(x: endX, y: y))
                context.strokePath()
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
