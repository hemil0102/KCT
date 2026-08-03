//
//  QuizView.swift
//  IdeaPlayground
//
//  퀴즈 진행 화면. (C단계: 5문제 출제 + 텍스트 답 입력 + 모델 채점)
//

import SwiftUI

struct QuizView: View {
    /// 이번 라운드에 출제할 5문제.
    /// B단계에서는 임시로 "쉬운 순 5개"를 사용한다. (진짜 출제 로직은 E단계에서 교체 예정)
    @State private var quiz: [Question] = Array(
        Question.all.sorted { $0.level < $1.level }.prefix(5)
    )

    /// 현재 몇 번째 문제를 풀고 있는지 (0부터 시작)
    @State private var currentIndex = 0

    /// 현재 문제에 입력 중인 답
    @State private var userAnswer = ""

    /// 사용자가 제출한 답 기록 (문제 id → 답)
    @State private var submittedAnswers: [Int: String] = [:]

    /// 채점 결과 (문제 id → 결과)
    @State private var results: [Int: GradingResult] = [:]

    /// 채점이 진행 중인지 여부
    @State private var isGrading = false

    private let grader = AnswerGrader()

    /// 모든 문제를 다 풀었는지 여부
    private var isFinished: Bool { currentIndex >= quiz.count }

    /// 맞힌 문제 개수
    private var correctCount: Int {
        results.values.filter { $0.isCorrect }.count
    }

    var body: some View {
        VStack(spacing: 24) {
            if isFinished {
                if isGrading {
                    gradingView
                } else {
                    resultView
                }
            } else {
                questionView
            }
        }
        .padding()
    }

    // MARK: - 문제 풀이 화면

    private var questionView: some View {
        let question = quiz[currentIndex]

        return VStack(spacing: 20) {
            // 진행 상황 표시
            Text("문제 \(currentIndex + 1) / \(quiz.count)")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(currentIndex), total: Double(quiz.count))

            Spacer()

            Text(question.question)
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            TextField("답을 입력하세요", text: $userAnswer)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            Button(currentIndex == quiz.count - 1 ? "제출" : "다음") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
    }

    // MARK: - 채점 중 화면

    private var gradingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("채점 중이에요...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 결과 화면

    private var resultView: some View {
        VStack(spacing: 16) {
            Text("\(quiz.count)문제 중 \(correctCount)개 정답!")
                .font(.title)
                .bold()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(quiz) { question in
                        resultRow(for: question)
                        Divider()
                    }
                }
            }

            Button("다시 풀기") {
                restart()
            }
            .buttonStyle(.bordered)
        }
    }

    /// 문제 하나에 대한 채점 결과 한 줄.
    private func resultRow(for question: Question) -> some View {
        let result = results[question.id]
        let isCorrect = result?.isCorrect ?? false

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? .green : .red)
                Text(question.question)
                    .font(.subheadline)
            }
            Text("내 답: \(submittedAnswers[question.id] ?? "")")
                .font(.footnote)
                .foregroundStyle(.blue)
            Text("정답: \(question.answer)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let reason = result?.reason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 동작

    /// 현재 답을 기록하고 다음 문제로 넘어간다. 마지막 문제면 채점을 시작한다.
    private func submit() {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let question = quiz[currentIndex]
        submittedAnswers[question.id] = trimmed
        userAnswer = ""
        currentIndex += 1

        // 마지막 문제까지 풀었으면 채점 시작
        if isFinished {
            Task { await gradeAll() }
        }
    }

    /// 제출된 답들을 문제별로 순차 채점한다.
    private func gradeAll() async {
        isGrading = true
        defer { isGrading = false }

        for question in quiz {
            let answer = submittedAnswers[question.id] ?? ""
            do {
                results[question.id] = try await grader.grade(question: question, userAnswer: answer)
            } catch {
                // 채점에 실패하면 오답으로 처리하고 사유를 남긴다.
                results[question.id] = GradingResult(
                    isCorrect: false,
                    reason: "채점 오류: \(error.localizedDescription)"
                )
            }
        }
    }

    /// 퀴즈를 처음부터 다시 시작한다.
    private func restart() {
        currentIndex = 0
        userAnswer = ""
        submittedAnswers = [:]
        results = [:]
    }
}

#Preview {
    QuizView()
}
