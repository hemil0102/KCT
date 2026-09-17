//
//  GlossaryPanel.swift
//  KCT
//
//  역할 : 낱말 뜻을 보여주는 시트(모달) 안 내용
//  요점 : iOS 기본 시트(.sheet)에 얹으므로 손잡이·펼침 애니메이션은 직접 그리지 않는다
//
//  ── 구성 ──────────────────────────────────────────────
//  GlossaryPanel
//  ├─ word / gloss              낱말과 짧은 뜻 (뜻은 이미 다듬어져 있음). 둘의 글자
//  │                            크기는 항상 같고(wordGlossFontSize, 28pt)
//  ├─ relatedWordsText          JSON에 원래 있던 비슷한 낱말 목록 — 있으면 바로 보여준다
//  ├─ exampleState               6단계 생성 예문(Foundation Models)의 진행 상태.
//  │                            .loading/.unavailable/.ready(String) 셋으로 나눈다 —
//  │                            String? 하나로는 "만드는 중"과 "기기 미지원이라 끝내
//  │                            없음"을 구분할 수 없었다
//  └─ showsExample               위로 쓸어 올리거나(또는 눌러서) 예문을 펼쳤는지 — 펼치면
//                               로딩 중이든 준비됐든 그 상태를 그대로 보여준다
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 이 .sheet(...) 로 이 뷰를 띄운다
//    → presentationDetents 로 iOS 26 Liquid Glass 모양을 그대로 받는다
//    → 닫는 ✕ 버튼은 없앴다 — 답을 고르거나, 다시 읽기를 누르거나, 배경(지문·여백)을
//      탭하면 QuestionScreen 이 glossarySelection 을 nil 로 되돌려 닫는다(아래로
//      쓸어내리는 기본 동작도 그대로 된다)
//    → 생성 예문은 만들고 있을 때부터 안내 문구가 바로 보인다. 위로 쓸어 올리면(또는
//      문구를 누르면) 펼쳐지는데, 아직 안 끝났으면 "로딩 중" 문구가, 끝났으면 실제
//      예문이 나온다 — exampleState 가 바뀌면 펼친 자리의 내용도 그때그때 바뀐다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (.sheet 안)
//  기대는 것    : AppColor
//  건드리지 않는 것 : 예문을 만들지 여부 — 그것은 GlossaryComposer(6단계) 의 몫이다
//

import SwiftUI
import Foundation
import UIKit

/// Foundation Models 생성 예문이 지금 어느 단계인지.
///
/// `String?` 하나로는 "아직 만드는 중"과 "기기가 지원 안 해서 끝내 없음"을 구분할 수
/// 없어서 — 둘 다 nil 이니까 — 셋으로 나눴다. `GlossaryPanel`이 스와이프로 펼치는
/// 자리에서, 로딩 중인지 완성됐는지를 그때그때 다르게 보여주려면 이 구분이 필요하다.
enum GlossaryExampleState {
    /// `composeExample(...)`이 아직 응답하지 않음.
    case loading
    /// 기기가 Foundation Models 를 지원하지 않거나, 생성이 실패해 끝내 못 만듦.
    case unavailable
    /// 완성된 예문.
    case ready(String)
}

/// 시트 위쪽 손잡이 모양. "^"를 옆으로 넓게 늘린 모양이다 — 시스템 기본 알약
/// 모양 대신 이 모양을 그리려고 만들었다(`GlossaryPanel.dragHandle`).
private struct WideChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// 낱말 뜻을 보여주는 시트 안 내용.
///
/// `.presentationDetents`로 iOS 26의 Liquid Glass 모양을 그대로 받습니다. 펼침
/// 상태(커지고 줄어드는 것)는 시트 자체가 대신 해 줍니다. 다만 위쪽 손잡이 모양은
/// 시스템 기본 알약 모양 대신 `dragHandle`(넓적한 "^" 모양)을 직접 그립니다 —
/// `.presentationDragIndicator(.hidden)`로 시스템 손잡이는 숨기고, 그 자리에 우리
/// 모양을 얹은 것뿐이라 끌어서 크기를 바꾸는 동작 자체는 그대로 시스템이 맡습니다.
struct GlossaryPanel: View {
    let word: String
    let gloss: String

    /// 6단계 생성 예문의 진행 상태. 위 `GlossaryExampleState` 참고.
    let exampleState: GlossaryExampleState

    /// JSON에 원래 있던 비슷한 낱말 목록. 없으면 빈 배열.
    let relatedWords: [String]

    /// 접혔을 때(처음 열릴 때) 시트 높이. 손잡이(24) + 위아래 같은 여백(20씩, 아래
    /// .padding(20)) + 낱말·뜻 두 줄 높이 — 손잡이를 뺀 나머지에서 낱말·뜻 묶음
    /// 위아래 여백이 같아지도록 다시 150으로 되돌렸다. 해설을 펼치기 전까지는
    /// 접힌 모습이 "손잡이 / 낱말 / 뜻"만 보이는 딱 그만큼이다.
    private static let collapsedHeight: CGFloat = 150

    /// 낱말 이름표와 뜻(gloss) 글자 크기 — 둘은 항상 같아야 하므로 상수 하나로 묶는다.
    /// 28pt로 직접 지정했다(선다 보기 버튼 22pt보다 크게 키운 값).
    private static let wordGlossFontSize: CGFloat = 28

    /// 낱말과 뜻 사이 간격. 접혔을 때나 펼쳤을 때나 이 값 하나만 쓰므로 두 상태에서
    /// 항상 같다.
    private static let wordGlossSpacing: CGFloat = 12

    /// 낱말(뜻) 묶음과 그 아래 해설(펼치면 나오는 자리) 사이 간격. wordGlossSpacing
    /// 보다 넉넉히 넓게 둬서, 낱말·뜻은 한 덩어리로 붙어 보이고 해설은 확실히
    /// 떨어진 구역으로 보이게 한다. 접혔을 때는 해설 자리가 아예 없으므로(showsExample
    /// 이 false면 아래 exampleContent 를 그리지 않는다) 이 간격이 쓰이지 않는다.
    private static let sectionSpacing: CGFloat = 28

    /// 생성 예문을 펼쳤는지. 낱말이 바뀌면(아래 onChange(of: word)), 또는 시트를
    /// 다시 접으면(아래 onChange(of: selectedDetent)) 다시 접어 둔다.
    @State private var showsExample = false

    /// 지금 시트 크기. 처음엔 작게(collapsedHeight) 떠 있다. 이 값이 `.medium`이 되는 경로는
    /// 여러 가지다 — 손잡이를 직접 끌거나, 내용이 짧아 스크롤할 게 없을 때 시트
    /// 위에서 그냥 위로 쓸어 올리거나(둘 다 iOS 가 알아서 처리), 안내 문구를
    /// 누르거나 그 위에서 쓸어 올리는 것(우리 코드, `reveal()`). **어느 경로로
    /// 커지든** 아래 `onChange(of: selectedDetent)`가 그 순간을 잡아 해설을 편다 —
    /// "시트가 커진다"와 "해설이 나온다"를 하나로 묶어 둔 것이다. 거꾸로 손잡이를
    /// 내리거나 아래로 스와이프해 다시 collapsedHeight 로 돌아오면, 같은 onChange 가
    /// 해설을 도로 접는다 — 펼친 해설이 접힌 뒤에도 남아 있지 않게 하기 위해서다.
    @State private var selectedDetent: PresentationDetent = .height(Self.collapsedHeight)

    /// 비슷한 낱말 목록 문구. `exampleState`(생성 예문)와 달리 감추지 않고 바로 보여준다 —
    /// "위로 쓸어 올려야 나오는 것"은 모델이 만든 해설(생성 예문)만이다.
    private var relatedWordsText: String? {
        guard !relatedWords.isEmpty else { return nil }
        return "비슷한 낱말 — " + relatedWords.joined(separator: "・")
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            ScrollView {
                // 접혔을 때는 낱말(뜻) 묶음 하나만 그린다 — 그래야 손잡이를 뺀 위(낱말 위)·
                // 아래(뜻 아래) 여백이 이 VStack의 .padding(20)만으로 정확히 똑같아진다.
                // 펼쳤을 때만 그 아래 해설을 sectionSpacing 간격으로 이어 붙인다. 위로
                // 쓸어 올려 펼치는 제스처는 접혔을 때만 낱말(뜻) 묶음에 붙인다 — 펼친
                // 뒤에는 이 제스처가 없어야 해설이 길어졌을 때 ScrollView 로 정상적으로
                // 스크롤된다.
                VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                    if showsExample {
                        wordGlossHeader
                        exampleContent
                    } else {
                        wordGlossHeader
                            .contentShape(Rectangle())
                            // `.gesture(...)`로만 달면 스와이프가 대개 **ScrollView 자신의
                            // 스크롤 제스처에 져서** 안 먹힌다 — 조상 뷰의 제스처가 우선권을
                            // 가져가는 SwiftUI 의 기본 동작이다(실기기에서 확인된 증상: 문구를
                            // 눌러야만 펼쳐지고 쓸어 올리는 건 그냥 스크롤로 흡수됨).
                            // `.highPriorityGesture(...)`로 달아야 이 영역에서 시작된 드래그를
                            // ScrollView 보다 먼저 가져올 수 있다. 그래도 혹시 몰라 탭도 함께 받는다.
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 12)
                                    .onEnded { value in
                                        guard value.translation.height < -12 else { return }
                                        reveal()
                                    }
                            )
                            .onTapGesture {
                                reveal()
                            }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 지문에서 낱말을 강조할 때 쓰는 색(시그니처 보라, KoreanText.highlightColor)을
        // 모달 배경에도 그대로 써서, 탭한 낱말과 모달이 한 덩어리로 이어져 보이게 한다.
        // 배경이 진한 색이 되었으니 안의 글자는 낱말(주황)만 빼고 전부 흰색으로 바꿨다.
        //
        // 처음엔 이 자리에 `.background(AppColor.signature.opacity(0.8))`로 안쪽
        // 내용에만 색을 칠했는데, 시트 자체의 배경(테두리·모서리까지 포함한 진짜
        // 배경)은 그와 별개로 iOS 시스템이 정한 재질이 따로 깔려 있어서 투명도를
        // 낮춰도 뒤 지문이 비치지 않았다. `.presentationBackground(...)`로 시트의
        // 진짜 배경 자체를 바꿔서 이 문제는 해결했다 — `.presentationBackgroundInteraction`
        // 과 맞물려 뒤 지문이 비쳐 보인다. 투명도 값은 0.8 → 0.1 → .clear(진단용) 를
        // 거쳐 지금 0.5로 자리 잡았다.
        .presentationBackground(AppColor.signature.opacity(0.5))
        // 작게 열렸다가 .medium 까지 커진다. selection 을 바인딩해서, 손잡이를 직접
        // 끌든 안내를 쓸어 올리든 — 어느 쪽으로 커졌든 — 아래 onChange 가 똑같이 반응한다.
        .presentationDetents([.height(Self.collapsedHeight), .medium], selection: $selectedDetent)
        // 시스템 기본 알약 모양 대신 dragHandle(넓적한 "^")을 직접 그리므로, 시스템
        // 손잡이 자체는 숨긴다. 끌어서 크기를 바꾸는 동작은 이 표시와 무관하게 계속 된다.
        .presentationDragIndicator(.hidden)
        // 뒤 화면(문제 지문)을 계속 보면서 뜻만 확인하는 용도라, 어둡게 가리지 않고
        // 뒤도 계속 탭할 수 있게 둔다. iOS 는 "안 어둡게"와 "뒤도 탭 가능"을 한 세트로만
        // 제공한다 — 어둡기만 따로 줄이는 공식 방법은 없다.
        .presentationBackgroundInteraction(.enabled)
        // 낱말이 바뀌면(사전 시트가 열린 채로 다른 낱말을 탭했을 때) 펼침 상태를 되돌린다.
        // id 가 고정값이라 뷰가 새로 만들어지지 않고 @State 가 그대로 남기 때문에 필요하다.
        .onChange(of: word) { _, _ in
            showsExample = false
            selectedDetent = .height(Self.collapsedHeight)
        }
        // 시트가 커지는 방법도, 다시 접히는 방법도 여러 갈래(손잡이, 빈 스크롤 위
        // 스와이프, 안내 탭/스와이프 / 손잡이를 반대로 끌기, 아래로 스와이프)라 그
        // 갈래를 하나하나 다 처리하는 대신 "결과"인 selectedDetent 하나만 지켜본다.
        // .medium 이 되면 해설을 펴고, 다시 collapsedHeight 로 돌아오면 접어 둔다 —
        // 그래야 한 번 만든 해설이 다음에 펼칠 때도 그대로 남아 있지 않고, 매번 새로
        // 펼치는 동작(탭/스와이프)을 거쳐야 보인다.
        .onChange(of: selectedDetent) { _, newValue in
            withAnimation(.easeOut(duration: 0.25)) {
                showsExample = (newValue == .medium)
            }
        }
    }

    /// 시트 위쪽 손잡이. 시스템 기본 알약 대신 넓적한 "^" 모양(`WideChevronShape`)을
    /// 직접 그린다. `.presentationDragIndicator(.hidden)`로 시스템 손잡이는 숨겼지만,
    /// 끌어서 크기를 바꾸는 동작은 이 표시와 무관하게(시스템이) 계속 처리한다 — 이건
    /// 순전히 보이는 모양만 바꾼 것이다.
    private var dragHandle: some View {
        WideChevronShape()
            .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
            .frame(width: 48, height: 10)
            // 펼쳐지면(showsExample) 180도 뒤집어 "^"가 "v"처럼 보이게 한다 —
            // 접을 수 있다는 뜻을 손잡이 모양으로도 알려준다.
            .rotationEffect(.degrees(showsExample ? 180 : 0))
            .animation(.easeOut(duration: 0.25), value: showsExample)
            // 위쪽 padding을 10 → 16으로 살짝 늘려 "^"를 조금 아래로 내렸다.
            .padding(.top, 16)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
    }

    /// 낱말 이름표(비슷한 낱말 포함)와 뜻(gloss). 접혔을 때·펼쳤을 때 모두 똑같이
    /// 이 한 뷰를 그린다 — 그래야 낱말·뜻 사이 간격(wordGlossSpacing)이 두 상태에서
    /// 항상 같다. 닫는 버튼은 없앴다 — 배경을 탭하거나 답을 고르면 QuestionScreen 이
    /// 시트를 닫는다. 비슷한 낱말은 이 낱말칸 바로 오른쪽에 붙인다 — Spacer 를
    /// 낱말과 비슷한 낱말 "사이"가 아니라 그 뒤에 둬서, 모달 오른쪽 끝이 아니라
    /// 낱말칸에 바짝 붙어 보이게 한다.
    ///
    /// 여러 차례 주황으로 조정해 봤지만 균형을 못 찾아서, 보라 모노크롬 포함
    /// 데모 3개를 만들어 보여드리고 "보라 톤 모노크롬"안으로 최종 정했다 —
    /// 낱말에 연라벤더 배지(wordBadgeBackground) + 짙은 보라 글자(wordBadgeText)를,
    /// 뜻에는 배경 없이 흰 글자만 남겨 시그니처 보라 배경 위에서 한 단계
    /// 조용하게 보이도록 했다. 색상 하나(보라)의 명도 차이만으로 위계를 만든다.
    private var wordGlossHeader: some View {
        VStack(alignment: .leading, spacing: Self.wordGlossSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word)
                    .font(.system(size: Self.wordGlossFontSize, weight: .bold))
                    .foregroundStyle(AppColor.wordBadgeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColor.wordBadgeBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                if let relatedWordsText {
                    Text(relatedWordsText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            // 낱말 이름표와 같은 크기(wordGlossFontSize) — 둘은 항상 같아야 한다. 뜻은
            // 배경도, 전용 색도 없이 시그니처 보라 배경 위에 흰 글자로만 보여준다 —
            // 보라 모노크롬안에서는 뜻에까지 새 색을 만들지 않는 것이 핵심이다.
            Text(gloss)
                .font(.system(size: Self.wordGlossFontSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    /// 시트를 `.medium`으로 키운다. 실제로 해설을 펴는 것은 `onChange(of:
    /// selectedDetent)`가 맡는다 — 그래야 손잡이로 직접 끌어서 커진 경우도 똑같이
    /// 해설이 나온다.
    private func reveal() {
        withAnimation(.easeOut(duration: 0.3)) {
            selectedDetent = .medium
        }
    }

    /// `highlightedExample(_:)`의 결과물 — 스타일이 다 입혀진 문자열과, 그 위에
    /// 둥글게 채울 배경 구간들. `HighlightedSentenceView`에 그대로 넘긴다.
    private struct HighlightedExample {
        let attributedText: NSAttributedString
        let backgroundHighlights: [UnderlineLabel.BackgroundHighlight]
    }

    /// 생성된 해설 문장에서 "낱말(뜻)" 중 "낱말" 자리는 헤더의 낱말과 같은
    /// 조합 — 연라벤더(wordBadgeBackground) 둥근 배경 + 짙은 보라 글자
    /// (wordBadgeText) — 로, "(뜻)" 자리는 **괄호까지 포함해서** 배경도 전용
    /// 색도 없이 흰 글자로만 둔다(2pt 작은 글자는 그대로 유지) — 기본 속성이
    /// 이미 흰색이라 별도로 색을 입히지 않는다. 낱말이 문장 안에서 활용형으로
    /// 바뀌어 나올 수 있어(예: "기리는"이 "기립니다"로) 원래 낱말 문자열을
    /// 그대로 찾을 순 없다 — 대신 "(" 바로 앞, 공백 없이 이어지는 한 덩어리를
    /// 낱말 자리로 본다. "손주가 ... 기립니다(고맙게 생각하는), ..." 라면
    /// "기립니다"가 그 덩어리, "(고맙게 생각하는)"(괄호 포함) 전체가 뜻 자리다.
    ///
    /// - Note: SwiftUI `Text`/`AttributedString`의 `backgroundColor` 속성은 각진
    ///   사각형만 그릴 수 있어서(둥근 모서리·여백을 못 준다) `KoreanText.swift`의
    ///   `UnderlineLabel`이 밑줄을 그리는 것과 같은 방식(TextKit으로 줄 단위 사각형을
    ///   직접 계산해서 채우기)을 대신 쓴다 — 그래서 `Text`가 아니라 `NSAttributedString`
    ///   + `UnderlineLabel.BackgroundHighlight`를 돌려주고, `HighlightedSentenceView`
    ///   (아래)가 그 둘을 받아 그린다.
    /// - Note: 배경도 여백 없이 글자 폭에 딱 맞게 그려진다 — 가로로 여백을 더 주면
    ///   옆 글자와 겹친다(그 자리에 여백이 있다고 텍스트 레이아웃 자체가 미리 잡아
    ///   두지 않기 때문). 모서리만 둥글게 깎는다.
    /// - Note: "(" 는 있는데 짝이 되는 ")" 가 없으면(모델이 형식을 깼을 때) 낱말
    ///   배경·글자색만 칠하고 뜻 자리는 그대로 둔다.
    private func highlightedExample(_ text: String) -> HighlightedExample {
        let baseFont = UIFont.systemFont(ofSize: Self.wordGlossFontSize, weight: .medium)

        // KoreanText.swift(지문)와 달리 이 문장에는 문단 스타일이 없었다 —
        // 그래서 한글 낱말 중간에서 줄이 갈릴 수 있었다("아사달"이 "아사" /
        // "달"로 잘려 다음 줄로 넘어가는 식). 배경 하이라이트는 줄마다 따로
        // 그리기 때문에(UnderlineLabel.drawText 참고) 그 자체는 안 깨지지만,
        // 낱말 하나가 두 줄에 걸쳐 반씩 잘려 보이니 "배경이 어긋난 것"처럼
        // 보였다 — 다급한 타이밍 문제가 아니라, 줄바꿈 규칙이 안 걸려 있던
        // 것이었다. 지문과 똑같이 hangulWordPriority 를 걸어서 한글 낱말이
        // 통째로만 다음 줄로 넘어가게 한다.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = .hangulWordPriority

        // 문장 전체를 기본값으로 살짝 흐린 흰색(72%)으로 깔아 둔다 — 데모에서
        // 고른 것과 같은 발상이다. 낱말·뜻 자리만 아래에서 또렷한 색(낱말은
        // 배지 글자색, 뜻은 100% 흰색)으로 다시 덮어써서, 나머지 문장보다
        // 두 자리가 상대적으로 더 도드라져 보이게 한다.
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.72),
                .paragraphStyle: paragraph,
            ]
        )
        var backgroundHighlights: [UnderlineLabel.BackgroundHighlight] = []

        guard let openParen = text.firstIndex(of: "(") else {
            return HighlightedExample(attributedText: attributed, backgroundHighlights: backgroundHighlights)
        }

        var wordStart = openParen
        while wordStart > text.startIndex {
            let before = text.index(before: wordStart)
            if text[before].isWhitespace { break }
            wordStart = before
        }
        let wordRange = NSRange(wordStart..<openParen, in: text)
        attributed.addAttribute(.foregroundColor, value: UIColor(AppColor.wordBadgeText), range: wordRange)
        backgroundHighlights.append(
            UnderlineLabel.BackgroundHighlight(
                range: wordRange,
                color: UIColor(AppColor.wordBadgeBackground),
                cornerRadius: 6
            )
        )

        let afterOpenParen = text.index(after: openParen)
        if afterOpenParen < text.endIndex,
           let closeParen = text[afterOpenParen...].firstIndex(of: ")") {
            // 괄호 자체("(", ")")까지 포함해서 뜻 구간으로 본다. 전용 색을 새로
            // 만들지 않고 100% 흰색을 명시적으로 입힌다 — 위에서 문장 전체를
            // 72%로 흐려 뒀으므로, 여기서 다시 덮어쓰지 않으면 뜻도 같이 흐려져
            // 버린다. 글자 크기는 2pt 작게 유지한다.
            let closeParenEnd = text.index(after: closeParen)
            let glossRange = NSRange(openParen..<closeParenEnd, in: text)
            let glossFont = UIFont.systemFont(ofSize: Self.wordGlossFontSize - 2, weight: .medium)
            attributed.addAttribute(.font, value: glossFont, range: glossRange)
            attributed.addAttribute(.foregroundColor, value: UIColor.white, range: glossRange)
        }

        return HighlightedExample(attributedText: attributed, backgroundHighlights: backgroundHighlights)
    }

    /// 해설 문장을 그리는 얇은 UIKit 다리. `highlightedExample(_:)`가 만든 낱말 색·
    /// 뜻 글자 크기가 이미 입혀진 문자열을, 뜻 자리에 둥근 배경까지 얹어 그린다 —
    /// 실제로 배경을 그리는 계산·코드는 전부 `KoreanText.swift`의 `UnderlineLabel`에
    /// 있고(밑줄 그리는 것과 같은 TextKit 방식), 여기선 밑줄 없이 배경만 켜서 쓴다.
    private struct HighlightedSentenceView: UIViewRepresentable {
        let example: HighlightedExample

        func makeUIView(context: Context) -> UnderlineLabel {
            let label = UnderlineLabel()
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.setContentHuggingPriority(.required, for: .vertical)
            return label
        }

        func updateUIView(_ label: UnderlineLabel, context: Context) {
            label.attributedText = example.attributedText
            label.backgroundHighlights = example.backgroundHighlights
            label.setNeedsDisplay()
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UnderlineLabel, context: Context) -> CGSize? {
            guard let width = proposal.width, width > 0 else { return nil }
            return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        }
    }

    /// 펼친 자리에 보일 실제 내용. `exampleState`가 바뀌면(로딩 → 완성) 이미 펼쳐 놓은
    /// 채로도 자동으로 갱신된다 — 사용자가 다시 스와이프할 필요가 없다. `exampleState`가
    /// `.unavailable`이어도 안내는 그대로 보여준다 — 예전엔 여기서 EmptyView() 로
    /// 통째로 숨겼는데, 그러면 기기가 Foundation Models 를 지원 안 하는 순간(대개
    /// 즉시 판가름난다) 안내 문구가 뜰 새도 없이 사라져 "안내가 아예 안 보인다"는
    /// 버그로 보였다.
    @ViewBuilder
    private var exampleContent: some View {
        switch exampleState {
        case .ready(let text):
            // GlossaryComposer 가 "낱말(뜻)"이 문장 안에 자연스럽게 녹아든 한
            // 문장을 통째로 보낸다 — 더 이상 두 문장으로 나눠 비교할 게 없으니
            // 그대로 한 문단으로 보여준다. 그 "낱말" 부분(괄호 바로 앞, 활용형일
            // 수도 있다 — highlightedExample(_:) 참고)만 낱말과 같은 주황으로
            // 칠해서, 문장 속에서도 어디가 낱말 자리인지 한눈에 보이게 한다.
            // 펼쳐진 해설도 낱말·뜻과 같은 크기(wordGlossFontSize)로 맞췄다 — 위아래
            // 글자 크기가 서로 다르면 해설만 유독 작아 보였다.
            HighlightedSentenceView(example: highlightedExample(text))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("해설 준비 중입니다.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            .transition(.opacity)
        case .unavailable:
            Text("이 낱말은 해설을 준비 중입니다. 감사합니다.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .transition(.opacity)
        }
    }
}
