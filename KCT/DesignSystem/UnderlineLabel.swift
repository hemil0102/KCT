//
//  UnderlineLabel.swift
//  KCT
//
//  역할 : 글자 아래 밑줄과 글자 뒤 둥근 배경을 TextKit 으로 직접 그리는 UILabel
//  요점 : UILabel 이 주는 밑줄은 자리를 못 고른다. 받침과 겹치므로 직접 그린다
//
//  ── 구성 ──────────────────────────────────────────────
//  UnderlineLabel (UILabel 하위 클래스)
//  ├─ Underline                  밑줄 하나 (범위 · 색 · 점선인가)
//  ├─ BackgroundHighlight        둥근 배경 하나 (범위 · 색 · 모서리 · 밑줄 자리 비우기)
//  ├─ underlines / backgroundHighlights   그릴 것들. 부르는 쪽이 채운다
//  ├─ underlineGap 2             글자 아래에서 밑줄까지 띄우는 간격. **0이 「받침 바로 아래」**
//  ├─ underlineThickness 2.5     실선 두께 (지금 실선을 쓰는 곳은 없다)
//  ├─ dottedDotDiameter 3        점선의 점 하나 지름
//  ├─ dottedDotSpacing 3         점 사이 간격의 **기준값** (낱말마다 다시 고르게 나눈다)
//  ├─ underlineDepthBelowLine    밑줄이 underlineGap 자리보다 아래로 내려가는 깊이
//  ├─ lineFragmentPadding 10     줄 칸(line fragment)에 이미 들어 있는 줄 간격 보정값
//  ├─ sizeThatFits(_:)           **그릴 때와 같은 엔진으로** 높이를 잰다
//  └─ drawText(in:)              배경 → 글자 → 밑줄 순으로 직접 그린다
//
//  ── 왜 직접 그리나 ─────────────────────────────────────
//  ① `NSAttributedString.underlineStyle` 은 폰트가 정한 자리에만 그려져, 받침이 있는
//     글자("국"·"웅") 아래쪽과 겹쳐 보인다. 간격을 조절할 방법이 없다.
//  ② `.backgroundColor` 속성은 **각진 사각형만** 그린다. 모서리를 둥글게 깎을 수 없다.
//
//  ── 세 가지가 같은 좌표계를 봐야 한다 ──────────────────
//  배경·글자·밑줄을 **한 layoutManager 로** 그린다. 밑줄만 여기서 재고 글자는 UILabel
//  에게 맡기면 두 엔진이 줄을 다르게 끊어, 밑줄이 「팥죽」 대신 「죽을」 밑에 찍힌다.
//  (한글 사이에 끊어도 되는 자리(U+200B)를 심고 양쪽 정렬까지 켜면 끊을 수 있는
//  자리가 촘촘해져서 두 엔진이 서로 다른 자리를 고른다 — 실제로 겪은 버그다.)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : KoreanText(지문 — 밑줄 + 배경), GlossaryExampleText(해설 — 배경만)
//  기대는 것    : UIKit·TextKit 뿐. 색도 도메인도 모른다 — 전부 인자로 받는다
//  건드리지 않는 것 : 무엇에 밑줄을 칠지 — KoreanText 가 범위를 계산해 넘긴다
//
//  ⚠️ 2026-09-23 리팩토링에서 KoreanText.swift(613줄)에서 떼어냈다. 코드는 한 줄도
//     안 바꿨다 — 실기기 실측으로 맞춘 상수(underlineGap 0의 기준, lineFragmentPadding
//     10, 마지막 줄 보정)가 들어 있어 손대면 밑줄 자리가 어긋난다.
//

import UIKit

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

    /// 높이도 **글자를 그리는 것과 같은 엔진으로** 잰다.
    ///
    /// ``drawText(in:)`` 이 직접 글자를 그리게 된 뒤로는, UILabel 이 잰 높이를 그대로
    /// 쓰면 위험하다 — 두 엔진이 줄을 다르게 끊으면 줄 수가 하나 달라질 수 있고,
    /// 그러면 뷰가 한 줄만큼 짧아져 마지막 줄이 잘린다. 그릴 때와 같은 TextKit
    /// 스택으로 재서 둘이 항상 같은 값을 보게 한다.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // 덧그릴 것이 없으면 예전대로 UILabel 에게 맡긴다 — 그때는 UILabel 이
        // 그리기도 하므로(아래 조기 반환) 엔진이 갈릴 일이 없다.
        guard let attributedText,
              !(underlines.isEmpty && backgroundHighlights.isEmpty),
              size.width > 0 else {
            return super.sizeThatFits(size)
        }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            size: CGSize(width: size.width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = numberOfLines
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)

        let used = layoutManager.usedRect(for: textContainer)
        return CGSize(width: size.width, height: ceil(used.height))
    }

    override func drawText(in rect: CGRect) {
        // UILabel 은 rect 가 실제 글자 높이보다 크면 그 안에서 세로 가운데 정렬을 해
        // 버린다. sizeThatFits(...)가 밑줄 여유만큼 rect 를 키워 주므로, 그대로
        // super.drawText(in: rect) 를 부르면 글자가 살짝 아래로 밀려서 그려지고,
        // 아래에서 같은 rect 로 계산하는 밑줄 위치와 어긋난다. 그래서 "글자만 필요한
        // 높이"를 다시 구해 **항상 위쪽에 붙여** 그리고, 밑줄도 같은 사각형 기준으로
        // 계산한다 — 그래야 글자와 밑줄이 같은 좌표계를 본다.
        let textHeight = sizeThatFits(CGSize(width: rect.width, height: .greatestFiniteMagnitude)).height
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

        // 줄바꿈을 직접 계산한다. **글자도 이 계산대로 그린다**(아래 drawGlyphs) —
        // 밑줄만 여기서 재고 글자는 UILabel 에게 맡기면, 둘이 서로 다른 엔진이라
        // 줄 끊는 자리가 한 글자쯤 어긋날 수 있다. 실제로 그렇게 어긋났다:
        // 한글 사이에 끊어도 되는 자리(U+200B)를 심고 양쪽 정렬까지 켜면 끊을 수
        // 있는 자리가 촘촘해져서, 두 엔진이 서로 다른 자리를 골랐다 — 밑줄이 「팥죽」
        // 대신 「죽을」 밑에 찍히는 식이었다.
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        // 높이는 무제한으로 둔다. UILabel 이 잰 높이(topAlignedRect.height)를 그대로
        // 주면, 이 엔진이 한 줄 더 필요하다고 판단했을 때 그 줄이 통 밖으로 밀려
        // 잘린다 — 두 엔진이 줄을 다르게 끊을 수 있으므로 아예 매이지 않게 한다.
        let textContainer = NSTextContainer(
            size: CGSize(width: topAlignedRect.width, height: .greatestFiniteMagnitude))
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

        // 글자를 **이 layoutManager 로 직접** 그린다. super.drawText(in:)를 쓰면
        // UILabel 의 엔진이 자기 방식대로 줄을 끊어 그리므로, 위아래에서 계산한
        // 배경·밑줄과 어긋난다. 같은 스택으로 그려야 셋이 항상 같은 자리를 본다.
        let fullGlyphRange = layoutManager.glyphRange(for: textContainer)
        let origin = CGPoint(x: originX, y: originY)
        // .backgroundColor 속성(형광펜)을 쓰는 자리를 위해 배경도 같이 그린다.
        layoutManager.drawBackground(forGlyphRange: fullGlyphRange, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: fullGlyphRange, at: origin)

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

