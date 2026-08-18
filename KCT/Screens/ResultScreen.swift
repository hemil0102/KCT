//
//  ResultScreen.swift
//  KCT
//
//  역할 : 회차가 끝난 뒤 결과를 보여주는 화면
//  요점 : "틀렸다"를 쓰지 않는다. 맞힌 것을 칭찬하고, 못 맞힌 것은 "다시 볼 문제"로 부른다
//
//  ── 구성 ──────────────────────────────────────────────
//  ResultScreen                 결과를 그리는 화면
//  ├─ progresses (@Query)       누적 통계용. 화면 표시라서 @Query 로 받는다
//  ├─ cumulativeCorrect         지금까지 맞힌 총 횟수 — 이 화면의 주인공
//  ├─ masteredCount             완전히 익힌 문제 수
//  ├─ cumulativeCard            누적 정답을 크게 보여주는 시그니처 카드
//  ├─ resultRow(for:)           문제 하나의 결과 카드
//  ├─ onRestart                 "다시 풀기" — 위쪽에 새 회차를 부탁한다
//  └─ onEraseProgress           "학습 기록 초기화" — 확인창을 거친 뒤 부탁한다
//
//  ── 흐름 ──────────────────────────────────────────────
//  session.results 로 문제별 정오답을 그린다
//    → @Query 로 읽은 진척에서 누적 정답 수와 마스터 수를 센다
//    → "다시 풀기" 탭 → onRestart()
//    → "학습 기록 초기화" 탭 → 확인창 → onEraseProgress()
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuizView — 회차가 끝나고 채점도 끝났을 때
//  기대는 것    : QuizSession(회차 결과), QuestionProgress(누적 통계), AppColor
//  건드리지 않는 것 : 기록 삭제 자체 — QuizSession.eraseAllProgress() 가 한다
//

import SwiftUI
import SwiftData

/// 회차 결과를 보여주는 화면.
///
/// 강조하는 것은 이번 회차 점수가 아니라 **지금까지 맞힌 누적 개수**입니다.
/// 매일 5문제씩 푸는 사람에게 "5문제 중 3개" 는 작아 보이지만,
/// "지금까지 412개" 는 계속할 이유가 됩니다.
///
/// - Note: 누적 통계는 `@Query` 로 읽습니다. 채점이 저장된 뒤 화면이 저절로
///   따라 바뀌어야 하기 때문입니다. 반대로 판단에 쓰는 진척은 ``QuizSession`` 이
///   직접 조회합니다 — `@Query` 는 즉시 갱신을 보장하지 않습니다.
struct ResultScreen: View {
    let session: QuizSession

    /// 새 회차를 시작해 달라는 부탁.
    let onRestart: () -> Void

    /// 학습 기록을 모두 지워 달라는 부탁.
    let onEraseProgress: () -> Void

    @Query private var progresses: [QuestionProgress]

    @State private var showsEraseConfirm = false

    /// 지금까지(모든 회차 누적) 맞힌 총 횟수.
    private var cumulativeCorrect: Int {
        progresses.reduce(0) { $0 + $1.totalCorrect }
    }

    /// 완전히 익힌(마스터한) 문제 개수.
    private var masteredCount: Int {
        progresses.filter(\.isMastered).count
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("잘하셨어요! 🎉")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.black)

            cumulativeCard

            if masteredCount > 0 {
                masteredBadge
            }

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(session.items) { item in
                        resultRow(for: item)
                    }
                }
            }

            PrimaryActionButton(title: "다시 풀기", minHeight: 60, action: onRestart)

            eraseButton
        }
        .padding(24)
    }

    // MARK: - 누적 강조

    private var cumulativeCard: some View {
        VStack(spacing: 6) {
            Text("지금까지 맞힌 문제")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("\(cumulativeCorrect)개")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(.white)
            Text("오늘 \(session.items.count)문제 중 \(session.correctCount)개 맞혔어요")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColor.signature, in: RoundedRectangle(cornerRadius: 24))
    }

    private var masteredBadge: some View {
        Label("완전히 익힌 문제 \(masteredCount)개", systemImage: "star.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppColor.mastered, in: Capsule())
    }

    // MARK: - 문제별 결과

    /// 문제 하나의 결과 카드. 맞히면 칭찬, 아니면 "다시 볼 문제"로 부드럽게.
    private func resultRow(for item: QuizItem) -> some View {
        let isCorrect = session.result(for: item.id)?.isCorrect ?? false
        let isMastered = progress(for: item.id)?.isMastered == true
        let accent = isCorrect ? AppColor.correct : AppColor.review

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
                Text(isCorrect ? "정답!" : "다시 볼 문제")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                Spacer()
                if isMastered {
                    Label("완전히 익힘", systemImage: "star.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.mastered)
                }
            }

            Text(item.displayText)
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)

            if isCorrect {
                Text("잘 맞히셨어요! 👍")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.correct)
            } else {
                Text("정답: \(item.question.answer)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                Text("곧 다시 만나요 😊")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private func progress(for questionID: Int) -> QuestionProgress? {
        progresses.first { $0.questionID == questionID }
    }

    // MARK: - 기록 초기화

    /// 되돌릴 수 없는 행동이므로 작게 두고 확인창을 반드시 거친다.
    private var eraseButton: some View {
        Button("학습 기록 초기화") {
            showsEraseConfirm = true
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppColor.textMuted)
        .confirmationDialog(
            "학습 기록을 모두 지울까요?",
            isPresented: $showsEraseConfirm,
            titleVisibility: .visible
        ) {
            Button("모두 초기화", role: .destructive, action: onEraseProgress)
            Button("취소", role: .cancel) {}
        } message: {
            Text("지금까지 맞힌 기록과 난이도가 모두 처음으로 돌아갑니다.")
        }
    }
}
