//
//  MyHistoryView.swift
//  KCT
//
//  역할 : "나의 이력" 탭. 지금까지 쌓인 학습 통계를 보여주고 스토리 모드로 들어가는 문
//  요점 : 통계를 세는 방식은 ResultScreen과 똑같다 — 같은 재료(QuestionProgress)를
//        같은 방식(@Query)으로 읽어 계산만 한 번 더 한다
//
//  ── 구성 ──────────────────────────────────────────────
//  MyHistoryView
//  ├─ progresses (@Query)     누적 통계용. ResultScreen과 같은 방식
//  ├─ questionCatalog          전체 문항 수 표시용 (환경에서 받음)
//  ├─ cumulativeCorrect        지금까지 맞힌 총 횟수
//  ├─ masteredCount            완전히 익힌 문제 수
//  ├─ cumulativeCard           누적 정답을 크게 보여주는 카드 (ResultScreen과 같은 모양)
//  └─ storyModeEntry           "스토리 모드 시작하기" — StoryModeView로 넘어간다
//
//  ── 흐름 ──────────────────────────────────────────────
//  RootView의 "나의 이력" 탭이 이 화면을 띄운다
//    → @Query로 진척을 읽어 누적 정답·마스터 수를 센다
//    → "스토리 모드 시작하기" 탭 → StoryModeView (지금은 "준비 중" 안내만)
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : RootView
//  기대는 것    : QuestionProgress·QuestionCatalog(환경), AppColor, StoryModeView
//  건드리지 않는 것 : 진척 수정 — 여기서는 읽기만 한다. 회차 진행은 QuizView 쪽 몫이다
//
//  11차(스토리 모드 진입) — 스토리 모드 자체(챕터·콘텐츠)는 아직 설계 전이라(참고:
//  스토리모드_구상.md) 지금은 "진입 버튼 + 지금까지의 기록"만 놓아 둔다. 기록을 아예
//  안 보여주는 안도 있었지만, 이 탭에 처음 들어왔을 때 빈 화면보다는 지금까지 쌓아온
//  것이 보이는 편이 "여기 오면 뭔가 있다"는 확신을 준다고 판단해 통계를 넣었다.
//

import SwiftUI
import SwiftData

/// "나의 이력" 탭 — 학습 통계와 스토리 모드 입구.
///
/// 강조하는 지표는 ``ResultScreen`` 과 똑같이 **지금까지 맞힌 누적 개수**입니다.
/// 회차가 끝날 때만 보이던 숫자를 언제든 다시 볼 수 있게 이 탭으로 옮겨 왔습니다.
struct MyHistoryView: View {
    @Query private var progresses: [QuestionProgress]

    @Environment(QuestionCatalog.self) private var questionCatalog

    /// 지금까지(모든 회차 누적) 맞힌 총 횟수.
    private var cumulativeCorrect: Int {
        progresses.reduce(0) { $0 + $1.totalCorrect }
    }

    /// 완전히 익힌(마스터한) 문제 개수.
    private var masteredCount: Int {
        progresses.filter(\.isMastered).count
    }

    /// 전체 문제집 크기. 마스터 수와 함께 "얼마나 남았는지" 감을 준다.
    private var totalQuestionCount: Int {
        questionCatalog.questions.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("나의 이력")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                cumulativeCard

                if masteredCount > 0 {
                    masteredBadge
                }

                Spacer()

                storyModeEntry
            }
            .padding(24)
            .background(Color.white)
        }
    }

    // MARK: - 누적 강조 (ResultScreen과 같은 모양)

    private var cumulativeCard: some View {
        VStack(spacing: 6) {
            Text("지금까지 맞힌 문제")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("\(cumulativeCorrect)개")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(.white)
            Text("전체 \(totalQuestionCount)문항 중 도전하고 있어요")
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

    // MARK: - 스토리 모드 입구

    private var storyModeEntry: some View {
        NavigationLink {
            StoryModeView()
        } label: {
            Text("스토리 모드 시작하기")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(AppColor.signature, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyHistoryView()
        .environment(QuestionCatalog.loaded())
        .modelContainer(for: [QuestionProgress.self, QuestionFocusRecord.self], inMemory: true)
}
