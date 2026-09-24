//
//  ChoiceButton.swift
//  KCT
//
//  역할 : 탭하면 선택되는 큰 보기 버튼. 선다형과 O/X 가 함께 쓴다
//  요점 : 선택은 "상태"다. 그래서 꽉 채우지 않고 테두리와 체크로 표시한다
//
//  ── 구성 ──────────────────────────────────────────────
//  ChoiceButton
//  ├─ label        버튼에 쓸 글자 (보기 내용 또는 "맞아요"/"아니에요")
//  ├─ isSelected   지금 골라져 있는가
//  ├─ verdict      골라진 답의 판정 (nil = 아직 모름). O/X 만 넘긴다 — 녹색 ✓ / 붉은색 ✕
//  └─ action       눌렀을 때 할 일 — 무엇을 고를지는 부르는 쪽이 정한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (선다형 보기 목록, O/X 두 버튼)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 정답 여부 — 이 버튼은 무엇이 정답인지 모른다. 채점은 QuizSession 이 하고,
//                    결과(verdict)만 받아 색을 칠한다
//

import SwiftUI

/// 탭하면 선택되는 큰 보기 버튼.
///
/// 채움은 주 행동(``PrimaryActionButton``)에만 쓰고, 여기서는 옅은 배경 + 굵은 테두리 + 체크로 표시합니다.
/// 체크 아이콘과 테두리 굵기가 함께 바뀌므로 색 구분이 어려운 분도 선택 여부를 알 수 있습니다.
struct ChoiceButton: View {
    let label: String
    let isSelected: Bool

    /// 골라진 답의 판정. `nil` 이면 아직 모른다(보라로 칠한다).
    ///
    /// O/X 는 누르는 순간 채점되므로 이 값을 넘긴다 — 맞으면 녹색 ✓, 틀리면 붉은색 ✕.
    /// 해설 창이 올라온 뒤에도 창 위로 이 버튼이 보여 「내가 뭘 골랐는지」가 남는다.
    /// 선다형은 넘기지 않는다(「다음」을 눌러야 채점되는 흐름 그대로).
    var verdict: Bool? = nil

    let action: () -> Void

    /// 지금 칠할 색. 안 골랐으면 회색 테두리, 골랐으면 판정에 따라 보라·녹색·분홍.
    private var tint: Color {
        guard isSelected else { return Color.black.opacity(0.35) }
        switch verdict {
        case .some(true):  return AppColor.answerSheetAccent
        case .some(false): return AppColor.wrongAccent
        case .none:        return AppColor.signature
        }
    }

    private var fill: Color {
        guard isSelected else { return Color.white }
        switch verdict {
        case .some(true):  return AppColor.answerSheetBadge
        case .some(false): return AppColor.wrongHeader
        case .none:        return AppColor.softBackground
        }
    }

    private var iconName: String {
        guard isSelected else { return "circle" }
        return verdict == false ? "xmark.circle.fill" : "checkmark.circle.fill"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? tint : Color.black.opacity(0.3))

                Text(label)
                    .font(.system(size: 22, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            // 어르신 터치 타깃 확보 — 58pt
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(fill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint, lineWidth: isSelected ? 3 : 1.5)
            )
            .animation(.easeOut(duration: 0.2), value: verdict)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChoiceButton(label: "고조선", isSelected: true) {}
        ChoiceButton(label: "고구려", isSelected: false) {}
        HStack(spacing: 14) {
            ChoiceButton(label: "맞아요", isSelected: true, verdict: true) {}
            ChoiceButton(label: "아니에요", isSelected: false) {}
        }
        HStack(spacing: 14) {
            ChoiceButton(label: "맞아요", isSelected: true, verdict: false) {}
            ChoiceButton(label: "아니에요", isSelected: false) {}
        }
    }
    .padding(24)
}
