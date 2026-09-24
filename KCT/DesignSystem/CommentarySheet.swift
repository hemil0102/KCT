//
//  CommentarySheet.swift
//  KCT
//
//  역할 : 해설 창(오답·정답·낱말 사전) 세 곳이 함께 쓰는 부품 한 벌
//  요점 : 세 창이 같은 언어로 보여야 한다. 그 「같음」을 주석으로 약속하지 않고
//        같은 코드를 쓰게 해서 강제한다
//
//  ── 이 파일이 생긴 이유 ────────────────────────────────
//  11차까지 FeedbackSheet(오답)와 CorrectAnswerSheet(정답)가 카드·배지·본문·
//  시트 외장·상수 네 개를 **각자 한 벌씩** 들고 있었다. CorrectAnswerSheet 의
//  주석이 "FeedbackSheet.noteRow(...) 와 똑같다"고 스스로 적고 있었는데,
//  똑같다는 것을 주석으로 적어야 하는 상태가 곧 갈라질 상태다 — 한쪽만 고치면
//  주석은 그대로 남고 화면만 어긋난다. 그래서 공통분을 여기로 모았다.
//
//  ── 구성 ──────────────────────────────────────────────
//  CommentaryMetrics (enum — 값만)   세 창이 공유하는 크기·진하기
//  ├─ titleSize 21                  시트 맨 위 제목
//  ├─ noteSize 21                   낱말 배지 · 설명 본문 (둘은 항상 같다)
//  ├─ markSize 20                   줄머리 이모지 (❌/✅)
//  ├─ buttonHeight 64               터치 목표 1cm(≈64pt) 권장
//  ├─ backgroundOpacity 0.75        시그니처 보라 배경의 진하기
//  ├─ cardCornerRadius 16           흰 카드
//  └─ badgeCornerRadius 7           낱말 배지
//
//  CommentarySheetTitle      보라 배경 위 흰 제목 한 줄
//  CommentaryCard            배지 + 설명 줄들을 감싸는 완전 불투명 흰 카드
//  CommentaryRow             이모지 + 낱말 배지가 한 줄, 그 아래 왼쪽 끝부터 설명
//  WordBadge                 낱말 하나를 감싸는 배지
//  CommentaryBodyStyle       기다리는 동안 보여줄 글의 글꼴 (SwiftUI Text 용)
//  CommentaryBodyText        도착한 글. 양쪽 정렬 + 낱말만 칠하기 (UILabel 경유)
//  View.pulsingWhileWaiting  아직 안 온 글을 옅게 맥동시킨다
//  View.commentarySheetChrome  시트 바깥 모양 한 벌 (배경·크기·손잡이·닫기 막기)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : FeedbackSheet · CorrectAnswerSheet · GlossaryPanel(외장만)
//  기대는 것    : AppColor · JustifiedKoreanText
//  건드리지 않는 것 : 무엇을 보여줄지 — 내용은 QuizSession 이 만들고, 이 파일은
//                    그 내용을 어떻게 입힐지만 안다. 도메인을 전혀 모른다
//

import SwiftUI

/// 세 해설 창이 공유하는 크기와 진하기.
///
/// 하나하나 실기기에서 눈으로 맞춰 정한 값입니다. **여기서 바꾸면 세 창이 함께 바뀝니다** —
/// 그게 이 타입이 있는 이유입니다. 한 창만 바꾸고 싶다면 그 창에서 인자로 덮어씁니다.
enum CommentaryMetrics {

    /// 시트 맨 위 제목 글자 크기.
    static let titleSize: CGFloat = 21

    /// 낱말 배지 · 설명 본문이 **함께 쓰는** 글자 크기.
    ///
    /// 처음에는 정답 해설만 22pt로 크게 뒀다("정답은 기억해야 하니 크게"라는 인지 연구
    /// 근거였다). 실제 화면에서 비대칭으로 느껴진다는 피드백을 받아 오답 크기(19pt)로
    /// 통일했고, 그 기준이 너무 작다는 피드백을 받아 **21pt로 올렸다.**
    static let noteSize: CGFloat = 21

    /// 줄머리 이모지(❌/✅) 크기.
    static let markSize: CGFloat = 20

    /// 버튼 높이. 터치 목표 1cm(≈64pt) 권장에 맞춘 값 — 기본값 56pt 보다 크다.
    static let buttonHeight: CGFloat = 64

    /// 시그니처 보라 배경의 진하기.
    ///
    /// 0.5 → 0.58 → 0.65 → **0.75**로 "조금 더 진하게"를 여러 차례 받아 올라간 값입니다.
    /// 더 올릴 때는 뒤 지문이 안 보이기 시작하는 지점인지 확인이 필요합니다.
    static let backgroundOpacity: Double = 0.75

    /// 설명을 감싸는 흰 카드의 모서리.
    static let cardCornerRadius: CGFloat = 16

    /// 낱말 배지의 모서리. 낱말 사전 패널의 배지와 같은 값이라 앱 전체가 한 언어로 보인다.
    static let badgeCornerRadius: CGFloat = 7

    /// 줄 간격. 본문 글자 크기에 따라 두 값만 씁니다.
    ///
    /// CSS 데모에서 19pt·22pt 두 값만 실측해 둔 것이라, 그 사이 크기는 19pt쪽(7)을
    /// 그대로 쓰는 근사값입니다.
    static func lineSpacing(for size: CGFloat) -> CGFloat {
        size >= 22 ? 8 : 7
    }
}

// MARK: - 제목

/// 시트 맨 위 제목 한 줄. 보라 배경 위의 흰 글자.
///
/// 두 창이 **같은 자리에 같은 무게의 글자**를 둬야 내용만 바뀐 것처럼 보입니다.
struct CommentarySheetTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: CommentaryMetrics.titleSize, weight: .bold))
            .foregroundStyle(.white.opacity(0.96))
    }
}

// MARK: - 흰 카드와 그 안의 줄

/// 낱말 배지 + 설명 줄들을 감싸는 카드 하나.
///
/// 배경이 **완전한 흰색**입니다. 한때 `Color.white.opacity(0.92)`로 8% 투명했는데,
/// 뒤 보라가 비쳐 배지와 글이 흐릿해 보인다는 피드백을 받아 불투명으로 바꿨습니다.
struct CommentaryCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            content
        }
        .padding(.horizontal, 15)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CommentaryMetrics.cardCornerRadius,
                                    style: .continuous))
    }
}

/// 이모지 + 낱말 배지 + 그 아래 설명 한 덩어리.
///
/// 이모지와 배지는 한 줄에 나란히, **설명은 그 아래 왼쪽 끝부터** 시작합니다.
///
/// 예전에는 이모지가 한 칸을 차지하고 배지와 설명이 같이 오른쪽 칸에 들어가서,
/// 설명 글이 이모지 폭(20 + 사이 10 = 30pt)만큼 들여쓰였습니다. 설명이 서너 줄이라
/// 그 들여쓰기가 줄마다 쌓여 카드가 좁아 보였고, 양쪽 정렬로 오른쪽 끝을 맞춘
/// 뒤로는 왼쪽만 들어가 있어 더 눈에 띄었습니다.
struct CommentaryRow<Content: View>: View {
    /// 줄머리 이모지. 맞았는지 틀렸는지는 창 색이 아니라 **이 배지**가 알려 준다.
    let mark: String

    let word: String
    let badgeBackground: Color
    let badgeText: Color

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 10) {
                Text(mark)
                    .font(.system(size: CommentaryMetrics.markSize))

                WordBadge(word: word, background: badgeBackground, foreground: badgeText)
            }

            content
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 낱말 하나를 감싸는 배지.
///
/// 낱말이 아무리 길어도(예: "고구려, 백제, 신라") **배지 폭이 늘어날 뿐 줄 구조가
/// 안 깨집니다.** 말줄임표로 자르는 안을 채택하지 않은 이유 — 정답을 자르면
/// 오답과 구분이 안 되는 경우가 생깁니다.
struct WordBadge: View {
    let word: String
    let background: Color
    let foreground: Color

    /// 글자 크기. 기본은 해설 본문과 같은 크기다.
    var size: CGFloat = CommentaryMetrics.noteSize

    var body: some View {
        Text(word)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(foreground)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.top, 1)
            .padding(.bottom, 3)
            .background(background,
                        in: RoundedRectangle(cornerRadius: CommentaryMetrics.badgeCornerRadius,
                                             style: .continuous))
    }
}

// MARK: - 본문 두 모습

/// 기다리는 동안 보여줄 글의 글꼴. **글은 검정이고, 칠하는 것은 낱말뿐입니다.**
///
/// 도착한 글은 ``CommentaryBodyText``(양쪽 정렬)로 그립니다 — 두 값이 어긋나면
/// 글이 도착하는 순간 글자 모양이 튀므로, 글꼴·색·줄간격을 같은 곳에서 가져옵니다.
struct CommentaryBodyStyle: ViewModifier {
    var size: CGFloat = CommentaryMetrics.noteSize

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.black)
            .lineSpacing(CommentaryMetrics.lineSpacing(for: size))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 도착한 해설 본문. 지문과 **같은 규칙(양쪽 정렬)** 으로 그리고, 글 속의 낱말만 칠한다.
///
/// SwiftUI 의 `Text` 는 양쪽 정렬을 못 해서(`multilineTextAlignment` 에 `.justified` 가
/// 없다) UILabel 을 감싼 ``JustifiedKoreanText`` 를 씁니다. 배지와 문장 두 곳이 같은
/// 색으로 보여 **눈이 그 색을 그 낱말로 배웁니다.**
///
/// - Note: 해설 문장에 낱말이 아예 안 나오는 문항도 있습니다(정답 "고조선", 해설
///   "고는 옛날이라는 뜻이에요…"). 그때는 배지가 혼자 그 역할을 떠맡습니다.
struct CommentaryBodyText: View {
    let text: String

    /// 색을 입힐 낱말. 글 안에 여러 번 나오면 전부 칠한다.
    let word: String

    let color: Color

    var size: CGFloat = CommentaryMetrics.noteSize

    var body: some View {
        JustifiedKoreanText(
            text: text,
            font: .systemFont(ofSize: size, weight: .medium),
            lineSpacing: CommentaryMetrics.lineSpacing(for: size),
            coloredWord: word,
            coloredWordColor: UIColor(color),
            coloredWordFont: .systemFont(ofSize: size, weight: .bold)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 기다림과 시트 외장

extension View {
    /// 아직 안 온 글을 **옅게 맥동시킨다.**
    ///
    /// 글이 도착하면 부르는 쪽에서 **다른 뷰로 갈아 끼웁니다** — `repeatForever` 는
    /// 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 멈추지 않기 때문입니다.
    func pulsingWhileWaiting(reduceMotion: Bool, isPulsing: Binding<Bool>) -> some View {
        opacity(reduceMotion ? 0.45 : (isPulsing.wrappedValue ? 0.6 : 0.25))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isPulsing.wrappedValue)
            .onAppear { isPulsing.wrappedValue = true }
    }

    /// 해설 창의 **바깥 모양 한 벌.** 세 창(오답·정답·낱말 사전)이 같은 것을 쓴다.
    ///
    /// - `presentationBackground` — 시트의 **진짜 배경**(테두리·모서리 포함)을 바꾼다.
    ///   `.background(...)` 로는 안 된다. 시스템이 정한 재질이 따로 깔려 있어서
    ///   투명도를 낮춰도 뒤 지문이 비치지 않는다.
    /// - `presentationBackgroundInteraction(.enabled)` — iOS 는 「안 어둡게」와
    ///   「뒤도 탭 가능」을 **한 세트로만** 제공한다. 어둡기만 따로 줄이는 공식
    ///   방법이 없어, 뒤 지문이 밝게 비치게 하려면 이걸 켜야 한다.
    /// - `presentationDragIndicator(.hidden)` — 시스템 알약 손잡이를 숨긴다.
    ///   끌어서 크기를 바꾸는 **동작 자체는 그대로** 시스템이 맡는다.
    ///
    /// - Parameter blocksInteractiveDismiss: 아래로 쓸어내려 닫는 것을 막을지.
    ///   오답·정답 해설은 「정답을 다 보기 전엔 못 넘어감」이라 `true`,
    ///   낱말 사전은 뜻만 확인하고 닫는 자리라 `false` 다.
    func commentarySheetChrome(
        detents: Set<PresentationDetent>,
        blocksInteractiveDismiss: Bool = true
    ) -> some View {
        presentationBackground(AppColor.signature.opacity(CommentaryMetrics.backgroundOpacity))
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents(detents)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(blocksInteractiveDismiss)
    }

    /// 시트 크기를 `@State` 에 묶는 판(``commentarySheetChrome(detents:blocksInteractiveDismiss:)``).
    ///
    /// 크기가 바뀌는 길이 여러 갈래(손잡이를 직접 끌기 · 빈 자리 스와이프 · 버튼 탭)일 때,
    /// 갈래마다 따로 처리하지 않고 **「결과」인 이 값 하나만 지켜보기** 위해 필요합니다.
    func commentarySheetChrome(
        detents: Set<PresentationDetent>,
        selection: Binding<PresentationDetent>,
        blocksInteractiveDismiss: Bool = true
    ) -> some View {
        presentationBackground(AppColor.signature.opacity(CommentaryMetrics.backgroundOpacity))
            .presentationBackgroundInteraction(.enabled)
            .presentationDetents(detents, selection: selection)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(blocksInteractiveDismiss)
    }
}

#Preview("카드 한 장") {
    CommentaryCard {
        CommentaryRow(
            mark: "❌",
            word: "개천절",
            badgeBackground: AppColor.wrongHeader,
            badgeText: AppColor.wrongAccent
        ) {
            CommentaryBodyText(
                text: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
                word: "개천절",
                color: AppColor.wrongAccent)
        }

        CommentaryRow(
            mark: "✅",
            word: "고구려, 백제, 신라",
            badgeBackground: AppColor.answerSheetBadge,
            badgeText: AppColor.answerSheetAccent
        ) {
            CommentaryBodyText(
                text: "고구려, 백제, 신라입니다. 이 세 나라가 있었습니다. 신라가 이 세 나라를 하나로 합쳤습니다.",
                word: "고구려, 백제, 신라",
                color: AppColor.answerSheetAccent)
        }
    }
    .padding(28)
    .background(AppColor.signature.opacity(CommentaryMetrics.backgroundOpacity))
}
