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

    /// 접혔을 때(처음 열릴 때) 시트 높이.
    private static let collapsedHeight: CGFloat = 150

    /// 낱말 이름표와 뜻(gloss) 글자 크기 — 둘은 항상 같아야 하므로 상수 하나로 묶는다.
    /// 28pt로 직접 지정했다(선다 보기 버튼 22pt보다 크게 키운 값).
    private static let wordGlossFontSize: CGFloat = 28

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
                VStack(alignment: .leading, spacing: 12) {
                    // 낱말 이름표도 뜻(gloss)과 같은 크기·굵기로 맞췄다 — 색만 시그니처로
                    // 구분한다. 닫는 버튼은 없앴다 — 배경을 탭하거나 답을 고르면
                    // QuestionScreen 이 시트를 닫는다. 비슷한 낱말은 이 낱말칸 바로
                    // 오른쪽에 붙인다 — Spacer 를 낱말과 비슷한 낱말 "사이"가 아니라
                    // 그 뒤에 둬서, 모달 오른쪽 끝이 아니라 낱말칸에 바짝 붙어 보이게 한다.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(word).font(.system(size: Self.wordGlossFontSize, weight: .bold)).foregroundStyle(AppColor.signature)
                        if let relatedWordsText {
                            Text(relatedWordsText)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(AppColor.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    // 낱말 이름표와 같은 크기(wordGlossFontSize) — 둘은 항상 같아야 한다.
                    Text(gloss)
                        .font(.system(size: Self.wordGlossFontSize, weight: .bold))
                        .foregroundStyle(.black)

                    // exampleState 가 .unavailable 이어도 안내는 그대로 보여준다. 예전엔
                    // 여기서 EmptyView() 로 통째로 숨겼는데, 그러면 기기가 Foundation Models 를
                    // 지원 안 하는 순간(대개 즉시 판가름난다) 안내 문구가 뜰 새도 없이 사라져
                    // "안내가 아예 안 보인다"는 버그로 보였다. 이제 펼쳤을 때만 상태에 맞는
                    // 내용(로딩 중 / 완성된 해설 / 지원 안 함 안내)을 다르게 보여준다.
                    Divider()
                    if showsExample {
                        exampleContent
                    } else {
                        revealExampleHint
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // 가독성 때문에 안은 다시 흰 배경으로 고정한다. 겉 테두리(모서리 둥글기·손잡이 자리)는
        // .presentationBackground 를 안 쓰므로 iOS 26에서 여전히 Liquid Glass 로 보인다 —
        // 유리 느낌은 "안이 비치는 것"이 아니라 "시트 자체가 떠 있는 모양"에서 온다.
        .background(Color.white)
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
            .stroke(AppColor.textMuted.opacity(0.4), style: StrokeStyle(lineWidth: 4.8, lineCap: .round, lineJoin: .round))
            .frame(width: 48, height: 10)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
    }

    /// 위로 쓸어 올리면(또는 탭하면) 해설을 펼치는 자리. 아무것도 그리지 않는
    /// 투명한 자리다 — 안내 문장에 이어, 여기 있던 화살표(^) 아이콘도 없앴다. 맨 위
    /// `dragHandle`(넓적한 "^")만으로 "여기서 더 나온다"는 힌트를 준다. 탭·스와이프
    /// 영역 자체는 그대로 남겨 뒀다(아래 위/아래 padding 만큼의 높이).
    ///
    /// 이 뷰는 `ScrollView` 안에 있다. `.gesture(...)`로만 달면 스와이프가 대개
    /// **ScrollView 자신의 스크롤 제스처에 져서** 안 먹힌다 — 조상 뷰의 제스처가 우선권을
    /// 가져가는 SwiftUI 의 기본 동작이다(실기기에서 확인된 증상: 문구를 눌러야만
    /// 펼쳐지고 쓸어 올리는 건 그냥 스크롤로 흡수됨). `.highPriorityGesture(...)`로 달아야
    /// 이 작은 영역에서 시작된 드래그를 ScrollView 보다 먼저 가져올 수 있다. 그래도
    /// 혹시 몰라 탭도 함께 받는다.
    private var revealExampleHint: some View {
        Color.clear
            .frame(height: 0)
            .frame(maxWidth: .infinity)
        // 위(구분선)와는 넉넉히, 아래는 그보다 좁게 둬서 탭/스와이프 영역을 확보한다.
        .padding(.top, 16)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
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

    /// 시트를 `.medium`으로 키운다. 실제로 해설을 펴는 것은 `onChange(of:
    /// selectedDetent)`가 맡는다 — 그래야 손잡이로 직접 끌어서 커진 경우도 똑같이
    /// 해설이 나온다.
    private func reveal() {
        withAnimation(.easeOut(duration: 0.3)) {
            selectedDetent = .medium
        }
    }

    /// 펼친 자리에 보일 실제 내용. `exampleState`가 바뀌면(로딩 → 완성) 이미 펼쳐 놓은
    /// 채로도 자동으로 갱신된다 — 사용자가 다시 스와이프할 필요가 없다.
    @ViewBuilder
    private var exampleContent: some View {
        switch exampleState {
        case .ready(let text):
            // GlossaryComposer 가 "1. ...\n\n2. ..." 모양으로 두 문장(낱말을 그대로
            // 넣은 문장 · 확정된 뜻을 넣은 문장)을 한 문자열에 담아 보낸다 — 빈 줄
            // 기준으로 나눠 각각 따로 된 문단으로 보여주면, 어디만 다른지 줄 단위로
            // 비교하며 읽기 쉬워진다("1."/"2." 번호는 텍스트 자체에 이미 들어 있다).
            let sentences = text.components(separatedBy: "\n\n")
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                    Text(sentence)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppColor.textMuted)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("해설 준비 중입니다.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.textMuted)
            }
            .transition(.opacity)
        case .unavailable:
            Text("이 기기에서는 해설을 만들 수 없어요.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.textMuted)
                .transition(.opacity)
        }
    }
}
