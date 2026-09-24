//
//  TrueFalseSheet.swift
//  KCT
//
//  역할 : O/X 를 누르자마자 올라와, 무엇을 골랐는지 · 바른 문장이 무엇인지 · 왜 그런지를 보여주는 모달
//  요점 : 맞혔을 때와 틀렸을 때를 **한 창**이 맡는다. 다른 것은 제목과 첫 줄 표시뿐이다
//
//  ── 구성 ──────────────────────────────────────────────
//  TrueFalseSheet
//  ├─ feedback      누른 라벨 · 맞았나 · 바르게 고친 문장 · 해설 (QuizSession 이 만든다)
//  ├─ onNext        「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ title         틀림: 「오답 해설」(21) · 맞힘: 「잘 맞추셨어요!」(31.5 — 정답 창과 같은 크기)
//  ├─ pickRow       고르신 답 [맞아요] — 배지 색만 다르다 (틀림 분홍 / 맞힘 녹색). 이모지 없음
//  ├─ sentenceRow   ✅ + 바르게 고친 문장 (틀린 문장이었으면 그 낱말에 줄을 긋고 정답을 이어 쓴다)
//  └─ commentary    모델이 쓴 정답 해설. 기다릴 때와 도착한 뒤가 서로 다른 뷰
//
//  ── 흐름 ──────────────────────────────────────────────
//  QuestionScreen 에서 맞아요/아니에요를 누른다
//    → 누른 버튼이 곧바로 녹색 ✓ 또는 붉은색 ✕ 로 바뀐다 (QuizSession.trueFalseVerdict)
//    → 0.6초 뒤 이 창이 화면 절반으로 올라온다 — 해설은 그 사이에 뒤에서 만들기 시작한다
//    → 「다음 문제」 → onNext()
//
//  ── 이 구조를 고른 이유 (11차 4-30, 2026-09-24) ──────────
//  예전에는 O/X 도 FeedbackSheet 를 그대로 썼다. 그러면 배지가 「❌ 맞아요」로 떠서
//  **무엇에 대해 맞다고 한 것인지**가 사라졌고, 9/14 에 어머니가 「왜 틀렸지?」 하셨다.
//  리서치(Pashler 2005 — 정답을 보여줘야 남는다, Skurnik 2005 — 노년층에게 틀린 문장을
//  되풀이하면 참으로 기억될 수 있다)를 거쳐 데모 3안 중 「빨간 펜」안을 골랐다.
//  글자 크기는 카드 안 전부를 바른 문장 크기(21)에 맞췄다(사용자 결정, 9/24). 데모에서는
//  절반 창에 다 넣으려고 해설 18 · 「고르신 오답」 16 · 배지 18 로 줄였었는데, 크기가
//  제각각인 것보다 한 크기가 낫다고 정했다. 긴 문장 + 해설이면 카드가 스크롤된다.
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.trueFalseFeedback 이 있는 동안
//  기대는 것    : TrueFalseCommentary, AppColor, CorrectionText,
//                CommentarySheet.swift 의 부품들, PrimaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

struct TrueFalseSheet: View {
    let feedback: TrueFalseCommentary
    let onNext: () -> Void

    /// 해설을 기다리는 동안 글자를 맥동시킨다.
    @State private var isPulsing = false

    /// 기기에서 「동작 줄이기」를 켠 분에게는 맥동을 끈다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 「잘 맞추셨어요!」 크기. 정답 해설 창(CorrectAnswerSheet)과 같은 제목의 1.5배.
    private static let celebrationSize: CGFloat = CommentaryMetrics.titleSize * 1.5

    /// 카드 안 글자 크기 — 「고르신 답」·배지·바른 문장·해설을 **모두 바른 문장 크기(21)** 로
    /// 맞춘다. 크기가 제각각이면 어머니 눈에 「어느 게 중요한 글이지?」가 생긴다.
    /// 절반 창을 넘치면 카드가 스크롤된다.
    private static let bodySize: CGFloat = CommentaryMetrics.noteSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    title
                    card
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 8)

            PrimaryActionButton(title: "다음 문제  →",
                                minHeight: CommentaryMetrics.buttonHeight) { onNext() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        // 오답·정답 해설 창과 같은 외장 — 같은 보라, 같은 진하기, 쓸어내려 닫기 막음.
        .commentarySheetChrome(detents: [.medium])
    }

    // MARK: - 제목

    @ViewBuilder
    private var title: some View {
        if feedback.isCorrect {
            Text("잘 맞추셨어요!")
                .font(.system(size: Self.celebrationSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.96))
        } else {
            CommentarySheetTitle(text: "오답 해설")
        }
    }

    // MARK: - 카드

    private var card: some View {
        CommentaryCard {
            pickRow
            sentenceRow
            Divider()
            commentary
        }
    }

    /// 무엇을 눌렀는지. 「고르신 답」 · 누른 라벨 배지가 한 줄.
    ///
    /// 앞에 ❌/✅ 이모지를 두지 않는다 — 맞았는지는 배지 색(녹색·분홍)과 제목이 이미
    /// 알려 주고, ✅ 는 아래 「바른 문장」 한 곳에만 둬야 그 뜻이 흐려지지 않는다.
    private var pickRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("고르신 답")
                .font(.system(size: Self.bodySize, weight: .semibold))
                .foregroundStyle(AppColor.textMuted)

            WordBadge(
                word: feedback.pickedLabel,
                background: feedback.isCorrect ? AppColor.answerSheetBadge : AppColor.wrongHeader,
                foreground: feedback.isCorrect ? AppColor.answerSheetAccent : AppColor.wrongAccent,
                size: Self.bodySize)
        }
    }

    /// ✅ + 바르게 고친 문장. 이모지를 위 줄과 같은 칸에 세워 「이게 바른 문장」임을 알린다.
    private var sentenceRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✅")
                .font(.system(size: CommentaryMetrics.markSize))
                .padding(.top, 3)

            CorrectionText(
                before: feedback.sentenceBefore,
                struck: feedback.statementWasTrue ? nil : feedback.shownCandidate,
                corrected: feedback.correctAnswer,
                after: feedback.sentenceAfter,
                struckColor: UIColor(AppColor.wrongAccent),
                correctedColor: UIColor(AppColor.answerSheetAccent),
                correctedBackground: UIColor(AppColor.answerSheetBadge))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 해설 글. **기다리는 동안과 도착한 뒤가 서로 다른 뷰다.** (FeedbackSheet.commentary 와 같은 이유)
    @ViewBuilder
    private var commentary: some View {
        if feedback.isReady {
            CommentaryBodyText(text: feedback.commentary,
                               word: feedback.correctAnswer,
                               color: AppColor.answerSheetAccent,
                               size: Self.bodySize)
        } else {
            Text(feedback.commentary)
                .modifier(CommentaryBodyStyle(size: Self.bodySize))
                .pulsingWhileWaiting(reduceMotion: reduceMotion, isPulsing: $isPulsing)
        }
    }
}

#Preview("틀림 — 틀린 문장에 맞아요") {
    TrueFalseSheet(
        feedback: .init(
            id: 12, pickedLabel: "맞아요", isCorrect: false,
            statementWasTrue: false, shownCandidate: "개천절", correctAnswer: "제헌절",
            sentenceBefore: "대한민국 헌법을 만들어 공포한 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: "제헌절은 헌법을 처음 만들어 알린 날이에요. 양력 7월 17일이고, 제헌은 헌법을 만들었다는 뜻이에요."),
        onNext: {})
}

#Preview("틀림 — 맞는 문장에 아니에요") {
    TrueFalseSheet(
        feedback: .init(
            id: 2, pickedLabel: "아니에요", isCorrect: false,
            statementWasTrue: true, shownCandidate: "고조선", correctAnswer: "고조선",
            sentenceBefore: "한국의 최초 국가 이름은 ",
            sentenceAfter: "이에요.",
            commentary: CommentaryPlaceholder.waiting),
        onNext: {})
}

#Preview("맞힘 — 틀린 문장에 아니에요") {
    TrueFalseSheet(
        feedback: .init(
            id: 13, pickedLabel: "아니에요", isCorrect: true,
            statementWasTrue: false, shownCandidate: "삼일절", correctAnswer: "광복절",
            sentenceBefore: "1945년에 일본으로부터 나라를 되찾은 것을 기념하는 국경일은 ",
            sentenceAfter: "이에요.",
            commentary: "광복절은 일본에게서 나라를 되찾은 날이에요. 양력 8월 15일이고, 광복은 빛을 되찾았다는 뜻이에요."),
        onNext: {})
}
