//
//  LegacyFeedbackSheet.swift
//  KCT
//
//  역할 : 스크린샷용으로 되살린 옛 오답 모달 (2026-09-10 이전 모습)
//  요점 : ⚠️ 임시 파일이다. 스크린샷을 찍고 나면 이 파일을 지운다
//
//  ── 왜 있나 ───────────────────────────────────────────
//  모달을 두 박자(고른 답 → 정답 보기)로 바꾸기 전 모습을 남겨 두지 못했다.
//  기록용 스크린샷 한 장을 위해 옛 코드를 그대로 되살린 것이고,
//  **앱의 어느 곳에서도 부르지 않는다.**
//
//  ── 어떻게 보나 ────────────────────────────────────────
//  isOn 이 true 이면 QuizView 가 이 창을 대신 띄운다. 앱을 빌드해 문제를 틀리면 나온다.
//  다 찍으면 ① isOn 을 false 로 두거나 ② QuizView 의 if 를 지우고 이 파일을 지운다.
//
//  ── 지금 것과 다른 점 ──────────────────────────────────
//  · 고른 답 설명이 없다        · 「정답 보기」 버튼이 없다 (한 화면에 다 보인다)
//  · 정답이 연두색이다          · 창 높이가 0.65 다
//

import SwiftUI

/// 옛 오답 모달. **스크린샷용 임시 코드다.**
struct LegacyFeedbackSheet: View {

    /// ⚠️ **이 스위치 하나로 켜고 끈다.** `false` 로 두면 지금 모달이 뜬다.
    static let isOn = true

    let selectedAnswer: String
    let correctAnswer: String
    let commentary: String

    /// 「다음 문제」를 눌렀을 때.
    let onNext: () -> Void

    /// 그때 쓰던 연두색. 지금 ``AppColor/answerAccent`` 는 파랑으로 바뀌었다.
    private static let legacyGreen = Color(red: 0.33, green: 0.61, blue: 0.16)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("고르신 답 - \(selectedAnswer)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textMuted)
                .padding(.top, 36)

            Text("이 문제의 정답은")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.top, 28)

            Text(correctAnswer)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Self.legacyGreen)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            ScrollView {
                Text(commentaryText)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 24)

            Spacer(minLength: 16)

            PrimaryActionButton(title: "다음 문제  →", isReady: true) { onNext() }
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .background(Color.white)
    }

    /// 해설 속 정답을 연두로 칠하던 그때 방식.
    private var commentaryText: AttributedString {
        var text = AttributedString(commentary)
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let found = text[searchStart..<text.endIndex].range(of: correctAnswer) {
            text[found].foregroundColor = Self.legacyGreen
            text[found].font = .system(size: 24, weight: .bold)
            searchStart = found.upperBound
        }
        return text
    }
}

// 창이 실제로 올라온 모습 그대로 보려고 시트로 띄운다. 높이도 그때의 0.65.
#Preview("옛 모달 — 스크린샷용") {
    Color(white: 0.85)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            LegacyFeedbackSheet(
                selectedAnswer: "개천절",
                correctAnswer: "추석",
                commentary: "추석은 음력 8월 15일로, 햇곡식과 햇과일로 음식을 만들어 차례를 지내는 날입니다. 송편을 먹는 한국의 가을 명절입니다.",
                onNext: {})
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.hidden)
        }
}
