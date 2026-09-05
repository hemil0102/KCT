//
//  FeedbackSheet.swift
//  KCT
//
//  역할 : 틀렸을 때 정답과 해설을 보여주는 모달
//  요점 : 정답이 가장 크다. 버튼은 3초 뒤에 켜진다 - 읽기 전에 넘어가지 않도록
//
//  ── 구성 ──────────────────────────────────────────────
//  FeedbackSheet
//  ├─ feedback        고른 답 · 정답 · 해설 (QuizSession 이 만든다)
//  ├─ onNext          「다음 문제」를 눌렀을 때 위에 알린다
//  ├─ secondsLeft     남은 대기 초. 0 이 되면 버튼이 켜진다
//  └─ .task           해설이 도착한 뒤부터 3초를 센다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView - session.feedback 이 있는 동안
//  기대는 것    : QuizSession.IncorrectCommentary, AppColor, PrimaryActionButton
//  건드리지 않는 것 : 다음 문제로 넘기는 일 - onNext 로 위에 부탁한다
//

import SwiftUI

/// 오답 직후에 올라오는 모달.
///
/// 화면 순서가 곧 읽는 순서입니다 — **고른 답(작게) → 정답(가장 크게) → 해설.**
/// 고른 답을 맨 위에 작게 두는 이유는 「내가 무엇을 골랐더라」를 한 번 확인하고
/// 넘어가기 위해서지, 틀린 것을 강조하기 위해서가 아닙니다.
///
/// - Note: 버튼이 3초 뒤에 켜지는 이유 — 창이 뜨자마자 누르면 정답을 안 보고
///   넘어갑니다. 이 창의 목적은 **정답을 한 번 더 만나는 것**이므로,
///   그 시간을 화면이 확보합니다.

struct FeedbackSheet: View {
    let feedback: QuizSession.IncorrectCommentary
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("고르신 답 - \(feedback.selectedAnswer)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textMuted)
                .padding(.top, 36)
            
            Text("이 문제의 정답은")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.top, 28)
            
            Text(feedback.correctAnswer)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AppColor.answerAccent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            
            ScrollView {
                Text(commentaryText)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(feedback.isReady ? 1 : 0.4)
            }
            .padding(.top, 24)
            
            Spacer(minLength: 16)
            
            PrimaryActionButton(title: "다음 문제  →", isReady: true) {
                onNext()
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .background(Color.white)
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }
    
    /// 해설에서 정답과 같은 글자를 찾아 연두로 칠한 문장.
    ///
    /// 정답이 **세 곳**(제목·큰 글씨·해설 속)에서 같은 색으로 보이면
    /// 눈이 그 색을 「정답」으로 배웁니다. 한 곳만 칠하면 그냥 장식이 됩니다.
    ///
    /// - Note: 첫 번째만이 아니라 **나오는 곳마다** 칠합니다.
    private var commentaryText: AttributedString {
        var text = AttributedString(feedback.commentary)
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let found = text[searchStart..<text.endIndex].range(of: feedback.correctAnswer) {
            text[found].foregroundColor = AppColor.answerAccent
            text[found].font = .system(size: 24, weight: .bold)
            searchStart = found.upperBound
        }
        return text
    }
}

#Preview {
    FeedbackSheet(
        feedback: .init(
            selectedAnswer: "단군신화",
            correctAnswer: "단군왕검",
            commentary: "고조선을 세운 첫 임금은 단군왕검입니다. 단군신화는 그 이야기를 담은 옛이야기입니다."),
        onNext: {})
}
