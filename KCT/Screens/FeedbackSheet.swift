//
//  FeedbackSheet.swift
//  KCT
//
//  역할 : 틀렸을 때 고른 답을 먼저 짚어 주고, 눌러야 정답을 보여주는 모달
//  요점 : 「오답」·「정답」 낱말 칸(제목 박스)을 없애고, 제목 한 줄 + 낱말 배지 두 개로
//        비교 인지를 대신한다 — 해설만 나란히 있어도 비교가 되기 때문이다
//
//  ── 구성 ──────────────────────────────────────────────
//  FeedbackSheet
//  ├─ feedback         고른 답 · 고른 답 설명 · 정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext           「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ showsAnswer      「정답 보기」를 눌렀는가. 두 박자를 가른다
//  ├─ isPulsing        기다리는 동안 맥동시키는 깃발
//  ├─ hasChosenNote    고른 답 쪽에 그릴 것이 있는가 (없으면 그 줄을 통째로 뺀다)
//  ├─ notesCard        낱말 배지 + 설명 두 줄을 감싸는 흰 카드 (CommentaryCard)
//  ├─ chosenNote       고른 답 설명. 아직 안 왔으면 응원 한 줄을 맥동시킨다
//  └─ commentary       정답 해설. 기다릴 때와 도착한 뒤가 서로 다른 뷰
//
//  모양은 전부 DesignSystem/CommentarySheet.swift 에 있다 — CommentaryMetrics(크기)·
//  CommentarySheetTitle(제목)·CommentaryCard(흰 카드)·CommentaryRow(줄)·
//  CommentaryBodyText(양쪽 정렬 본문)·commentarySheetChrome(시트 외장).
//  **정답 해설 창(CorrectAnswerSheet)이 같은 부품을 쓴다.**
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuizView 가 session.feedback 이 생기면 이 창을 띄운다
//    → 1박자 : 제목 「오답 해설」 + 오답 배지·설명만. 버튼은 「정답 보기」
//    → 「정답 보기」를 누르면
//    → 2박자 : 제목이 「오답 및 정답 비교 해설」로 바뀌고 정답 배지·해설이 이어 붙는다.
//             버튼은 「다음 문제」
//    → 「다음 문제」를 누르면 onNext() 로 위에 알린다
//
//  ── 이 구조를 고른 이유 (11차, 2026-09) ───────────────
//  10차에서는 "개천절 → 추석" 처럼 두 낱말을 한 줄에 나란히 놓아 낱말 칸을
//  없앴다. 그런데 오답이 "고구려, 백제, 신라" 처럼 길어지면 한 줄 대조가
//  줄바꿈되면서 어색해졌다. 그래서 "타이틀 박스 없이 해설만 있어도 비교가
//  되지 않을까"를 데모 3개로 확인했고, **낱말을 큰 두 줄로 나란히 놓는 대신
//  줄마다 작은 배지로 앞세우는 안(시안 3)** 을 골랐다.
//
//  이 안을 고른 이유는 셋이다.
//    1. 배지가 낱말 사전 패널(GlossaryPanel)의 배지와 같은 모양(코너 반경 7,
//       굵은 글자)이라 앱 전체가 한 언어로 보인다.
//    2. 낱말이 아무리 길어도(예: "고구려, 백제, 신라") 배지 폭이 늘어날 뿐
//       줄 구조가 안 깨진다 — 지난번 "글자를 줄이거나 말줄임표로 자르는" 안보다
//       안전하다. 정답을 자르면 오답과 구분이 안 되는 경우가 생기기 때문에
//       말줄임표 안은 애초에 채택하지 않았다.
//    3. **해설 문장에 정답 낱말이 아예 안 나오는 문항이 있다** — 모델이 만든
//       문장이라 항상 낱말을 포함한다는 보장이 없다(예: 정답 "고조선", 해설
//       "고는 옛날이라는 뜻이에요. 도읍은 아사달이었어요." 에는 "고조선"이
//       한 번도 안 나온다). 배지는 문장과 별개로 낱말을 항상 보여주므로 이
//       경우에도 정답이 화면에서 사라지지 않는다. 문장 속 낱말도 여전히
//       색칠한다(CommentaryBodyText) — 낱말이 문장에 있을 때는 배지·문장 두 곳이
//       같은 색으로 보여 눈이 그 색을 그 낱말로 배우고, 없을 때는 배지가
//       혼자 그 역할을 떠맡는다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.feedback 이 있는 동안
//  기대는 것    : IncorrectCommentary, AppColor,
//                CommentarySheet.swift 의 부품들, PrimaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// 오답 직후에 올라오는 모달.
///
/// **두 박자로 나뉩니다.**
///
/// | 박자 | 제목 | 배지·설명 | 버튼 |
/// |---|---|---|---|
/// | 1 | 오답 해설 | ❌ 고른 답 배지 + 설명만 | 「정답 보기」 |
/// | 2 | 오답 및 정답 비교 해설 | 위 + ✅ 정답 배지 + 해설 | 「다음 문제」 |
///
/// 한 화면에 다 쏟지 않는 이유 — 정답이 처음부터 보이면 **고른 답을 읽지 않고**
/// 정답으로 눈이 갑니다. 한 번 누르는 사이에 「내가 무엇을 골랐더라」가 한 박자 남습니다.
///
/// - Note: 분홍·녹색은 **이 창과 정답 창 안에서만** 씁니다. 목록과 결과 화면의
///   「다시 볼 문제」는 여전히 시그니처 색입니다 — 그쪽은 「틀렸다」가 아니라
///   「또 만날 문제」이기 때문입니다.
struct FeedbackSheet: View {
    let feedback: IncorrectCommentary
    let onNext: () -> Void

    /// 「정답 보기」를 눌렀는가.
    @State private var showsAnswer = false

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    CommentarySheetTitle(
                        text: showsAnswer ? "오답 및 정답 비교 해설" : "오답 해설")
                    notesCard
                }
                .padding(.top, 16)
            }

            // 버튼을 시트 바닥 쪽으로 살짝 내렸다 — 아래 여백(24 → 14)과 최소
            // 간격(12 → 8)을 함께 줄여, 그만큼 위 콘텐츠가 쓸 공간을 넓혔다.
            Spacer(minLength: 8)

            if showsAnswer {
                PrimaryActionButton(title: "다음 문제  →",
                                    minHeight: CommentaryMetrics.buttonHeight) { onNext() }
            } else {
                PrimaryActionButton(title: "정답 보기",
                                    minHeight: CommentaryMetrics.buttonHeight) {
                    withAnimation(.easeOut(duration: 0.25)) { showsAnswer = true }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        // 배경·크기·손잡이·스와이프 닫기 막기 한 벌. 정답 해설 창과 같은 것을 쓴다 —
        // 맞았을 때와 틀렸을 때가 같은 시각 언어로 보여야 어머니가 "이건 다른 창"이라고
        // 새로 배우지 않는다. 세 창(오답·정답·낱말 사전)이 모두 같은 보라 · 같은 진하기다.
        //
        // 한때 이 창을 주황, 정답 창을 연두로 갈라 봤다가 되돌렸다 — 밝은 배경이 흰
        // 글자를 못 받쳐서, 제목과 버튼까지 그 계열의 진한 색으로 바꿔야 했고 앱의 다른
        // 화면과 따로 놀았다. 맞았는지 틀렸는지는 창 색이 아니라 **줄머리 배지**가
        // 알려 준다 — 고르신 답은 ❌ 분홍, 정답은 ✅ 녹색이다.
        .commentarySheetChrome(detents: [.medium])
    }

    // MARK: - 해설 카드

    /// 낱말 배지 + 설명 줄들을 감싸는 카드 하나.
    ///
    /// 10차의 "낱말 대조 줄"(제목 칸)을 없애고, 그 자리에 있던 낱말을 각 설명
    /// 줄 머리의 배지로 옮겼다 — 칸을 하나 더 그리는 게 아니라 **줄의 머리를
    /// 낱말로 바꾸는 것**이라 높이가 거의 늘지 않는다.
    private var notesCard: some View {
        CommentaryCard {
            // 쓸 설명이 하나도 없으면 오답 줄 자체를 그리지 않는다 — 안 그리면
            // 빈 줄만 남아 고장난 것처럼 보인다.
            if hasChosenNote {
                CommentaryRow(
                    mark: "❌",
                    word: feedback.selectedAnswer,
                    badgeBackground: AppColor.wrongHeader,
                    badgeText: AppColor.wrongAccent
                ) { chosenNote }
            }

            if showsAnswer {
                CommentaryRow(
                    mark: "✅",
                    word: feedback.correctAnswer,
                    badgeBackground: AppColor.answerSheetBadge,
                    badgeText: AppColor.answerSheetAccent
                ) { commentary }
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 설명 두 줄

    /// 고른 답 쪽에 그릴 것이 있는가. 설명이 이미 왔거나, 올 예정이거나.
    ///
    /// 둘 다 아니면(오타·O/X 라벨처럼 어느 문항의 정답도 아닐 때) 고른 답 줄은
    /// 통째로 없다 — 막대만 남기지 않기 위해 이 판단을 바깥으로 뺐다.
    private var hasChosenNote: Bool {
        feedback.selectedNote != nil || feedback.expectsNote
    }

    /// 고른 답 설명. 아직 안 왔으면 올 예정인 자리를 비워 두고 기다린다.
    @ViewBuilder
    private var chosenNote: some View {
        if let note = feedback.selectedNote {
            CommentaryBodyText(text: note,
                               word: feedback.selectedAnswer,
                               color: AppColor.wrongAccent)
        } else {
            Text(feedback.waitingLine)
                .modifier(CommentaryBodyStyle())
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.**
    ///
    /// 같은 뷰에 두고 애니메이션만 끄는 방법은 통하지 않습니다 —
    /// `repeatForever` 는 한 번 걸리면 애니메이션을 `nil` 로 바꿔도 계속 돕니다.
    /// **뷰를 통째로 갈아 끼우면** 맥동하던 뷰가 사라지므로 확실히 멈춥니다.
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            CommentaryBodyText(text: feedback.commentary,
                               word: feedback.correctAnswer,
                               color: AppColor.answerSheetAccent)
        } else {
            Text(feedback.commentary)
                .modifier(CommentaryBodyStyle())
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }
}

#Preview("정답 보기 전") {
    FeedbackSheet(
        feedback: .init(
            id: 11,
            selectedAnswer: "개천절",
            selectedNote: "개천절은 고조선이 세워진 것을 기리는 국경일이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "추석",
            commentary: "추석은 가을 저녁이라는 뜻이에요. 음력 8월 15일에 지내는 명절이에요. 한가위라고도 불러요."),
        onNext: {})
}

#Preview("설명이 없을 때") {
    FeedbackSheet(
        feedback: .init(
            id: 4,
            selectedAnswer: "고죠선",
            selectedNote: nil,
            waitingLine: "천천히 보면 돼요. 같이 살펴볼게요. 🍀",
            expectsNote: false,
            correctAnswer: "고조선",
            commentary: "고는 옛날이라는 뜻이에요. 도읍은 아사달이었어요."),
        onNext: {})
}

#Preview("긴 정답 — 고구려, 백제, 신라") {
    FeedbackSheet(
        feedback: .init(
            id: 27,
            selectedAnswer: "동지",
            selectedNote: "동지는 팥죽을 먹는 날이고 양력 12월 22일쯤이며 절기 이름이 있으며 겨울에 이르렀다는 뜻이에요.",
            waitingLine: "괜찮아요. 저와 함께 오답을 알아봐요. 😆",
            expectsNote: true,
            correctAnswer: "고구려, 백제, 신라",
            commentary: "고구려, 백제, 신라입니다. 이 세 나라가 있었습니다. 신라가 이 세 나라를 하나로 합쳤습니다."),
        onNext: {})
}
