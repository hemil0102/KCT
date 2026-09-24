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
//  ├─ showsExample               위로 쓸어 올리거나(또는 눌러서) 예문을 펼쳤는지 — 펼치면
//  │                            로딩 중이든 준비됐든 그 상태를 그대로 보여준다
//  ├─ onClose                    시트를 닫아야 할 때 위(QuestionScreen)에 부탁한다 —
//  │                            배경 탭·답 선택·아래로 스와이프·(펼쳤을 때) 하단
//  │                            「닫기」버튼, 네 경로가 모두 이 하나로 모인다
//  ├─ dragHandle                 시트 위쪽 손잡이 — 시스템 알약 대신 넓적한 "^"
//  ├─ wordGlossHeader            낱말 배지 + 비슷한 낱말 + 뜻
//  ├─ reveal()                   시트를 .medium 으로 키운다
//  └─ exampleContent             펼친 자리의 내용 (로딩 / 완성 / 불가)
//
//  해설 문장을 실제로 그리는 것은 GlossaryExampleText(DesignSystem/GlossaryExampleText.swift)
//  이고, 시트 바깥 모양은 CommentarySheet.swift 의 commentarySheetChrome 이다 —
//  오답·정답 해설 창과 같은 한 벌을 쓴다. 하단 「닫기」는 SecondaryActionButton.
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 이 .sheet(...) 로 이 뷰를 띄운다
//    → presentationDetents 로 iOS 26 Liquid Glass 모양을 그대로 받는다
//    → 답을 고르거나, 다시 읽기를 누르거나, 배경(지문·여백)을 탭하거나, 아래로
//      쓸어내리면 QuestionScreen 이 glossarySelection 을 nil 로 되돌려 닫는다
//    → 펼치면(showsExample) 시트 맨 아래에 「닫기」버튼이 하나 더 생긴다 — 접힌
//      채로 있던 "안내 문구를 눌러 펼치는" 자리가 펼친 뒤에는 스크롤 제스처로
//      바뀌므로, 명시적으로 닫을 방법이 하나 필요해서다
//    → 생성 예문은 만들고 있을 때부터 안내 문구가 바로 보인다. 위로 쓸어 올리면(또는
//      문구를 누르면) 펼쳐지는데, 아직 안 끝났으면 "로딩 중" 문구가, 끝났으면 실제
//      예문이 나온다 — exampleState 가 바뀌면 펼친 자리의 내용도 그때그때 바뀐다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (.sheet 안)
//  기대는 것    : AppColor · GlossaryExampleText(해설 그리기) ·
//                CommentarySheet.swift(시트 외장) · SecondaryActionButton(닫기)
//  건드리지 않는 것 : 예문을 만들지 여부 — 그것은 GlossaryExampleWriter 의 몫이다
//
//  11차 후속 — 닫는 ✕ 버튼을 오른쪽 위에 넣었다가, 이후 ✕는 없애고 대신 펼쳤을
//  때만 시트 맨 아래에 「닫기」버튼을 두는 것으로 바꿨다. 접힌 채로는 이미 안내
//  문구 탭/스와이프로 펼치거나 배경·답 선택으로 닫을 수 있어 ✕가 굳이 필요
//  없었고, 펼친 뒤에만 명시적 닫기 방법이 아쉬웠기 때문이다(오답·정답 해설
//  모달은 여전히 진행을 강제하는 고정 모달이라 이런 버튼을 넣지 않는다).
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
    /// ``GlossaryExampleWriter/write(word:gloss:relatedWords:referenceSentence:questionID:)`` 가 아직 응답하지 않음.
    case loading
    /// 기기가 Foundation Models 를 지원하지 않거나, 생성이 실패해 끝내 못 만듦.
    case unavailable
    /// 완성된 예문.
    case ready(String)
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

    /// 시트를 닫아야 할 때(배경 탭·답 선택·아래로 스와이프·펼쳤을 때의 하단
    /// 「닫기」버튼) 부탁할 일. 실제로 시트를 닫는 것은 위쪽(``QuestionScreen``)이
    /// ``glossarySelection`` 을 nil 로 되돌리는 방식으로 한다 — 모든 경로가 같은
    /// 곳에서만 상태를 바꾼다.
    let onClose: () -> Void

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
            // 펼쳤을 때만 보이는 하단 「닫기」— 접힌 채로는 안내 문구 탭/스와이프로
            // 펼치거나 배경·답 선택으로 닫을 수 있어 필요 없고, 펼친 뒤에만
            // 명시적으로 닫을 방법이 아쉬워서 이 자리에만 둔다. showsExample 이
            // onChange(of: selectedDetent) 안 withAnimation 으로 바뀌므로, 이
            // 버튼이 나타나고 사라지는 것도 같은 애니메이션을 그대로 탄다.
            if showsExample {
                // 흰 알약 + 시그니처 글자 — 정답 해설 모달의 「정답 해설 보기」와
                // **같은 부품**이라 같은 무게로 보인다. 이 시트의 유일한 명시적
                // 버튼이라 눈에 잘 띄어야 하지만, "다음 문제"처럼 반드시 눌러야
                // 진행되는 자리는 아니라서(배경을 눌러도 답을 골라도 똑같이 닫힌다)
                // 시그니처 채움 버튼만큼 무겁게 두지는 않았다.
                SecondaryActionButton(title: "닫기", action: onClose)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            }
        }
        // 시트 바깥 모양은 오답·정답 해설 창과 **같은 한 벌**(commentarySheetChrome)이다 —
        // 세 창이 같은 보라(시그니처) · 같은 진하기(0.75) · 같은 「손잡이 숨김」을 쓴다.
        // 지문에서 낱말을 강조할 때 쓰는 색을 모달 배경에도 그대로 써서, 탭한 낱말과
        // 모달이 한 덩어리로 이어져 보이게 한 것이다.
        //
        // 다만 **아래로 쓸어내려 닫는 것은 막지 않는다**(blocksInteractiveDismiss: false) —
        // 이 시트는 뜻만 확인하고 닫는 자리라, 오답·정답 해설처럼 "정답을 다 보기
        // 전엔 못 넘어감"을 지킬 이유가 없다.
        //
        // 작게 열렸다가 .medium 까지 커진다. selection 을 바인딩해서, 손잡이를 직접
        // 끌든 안내를 쓸어 올리든 — 어느 쪽으로 커졌든 — 아래 onChange 가 똑같이 반응한다.
        .commentarySheetChrome(
            detents: [.height(Self.collapsedHeight), .medium],
            selection: $selectedDetent,
            blocksInteractiveDismiss: false)
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
    /// 항상 같다. 닫는 버튼(펼쳤을 때만 나오는 하단 「닫기」)은 이 헤더가 아니라
    /// body 에서 조건부로 따로 그린다.
    /// 비슷한 낱말은 이 낱말칸 바로 오른쪽에 붙인다 — Spacer 를
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
            // GlossaryExampleWriter 가 "낱말(뜻)"이 문장 안에 자연스럽게 녹아든 한
            // 문장을 통째로 보낸다 — 더 이상 두 문장으로 나눠 비교할 게 없으니
            // 그대로 한 문단으로 보여준다. 그 "낱말" 부분(괄호 바로 앞, 활용형일
            // 수도 있다 — GlossaryExampleText 참고)만 낱말과 같은 색으로 칠해서,
            // 문장 속에서도 어디가 낱말 자리인지 한눈에 보이게 한다.
            // 펼쳐진 해설도 낱말·뜻과 같은 크기(wordGlossFontSize)로 맞춘다 — 위아래
            // 글자 크기가 서로 다르면 해설만 유독 작아 보였다. **그 규칙을 지키는
            // 상수는 여기 하나뿐**이라, 크기를 인자로 넘겨 준다.
            GlossaryExampleText(text: text, fontSize: Self.wordGlossFontSize)
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
