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
//  └─ action       눌렀을 때 할 일 — 무엇을 고를지는 부르는 쪽이 정한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (선다형 보기 목록, O/X 두 버튼)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 정답 여부 — 이 버튼은 무엇이 정답인지 모른다. 채점은 QuizSession 이 한다
//

import SwiftUI

/// 탭하면 선택되는 큰 보기 버튼.
///
/// 채움은 주 행동(``PrimaryActionButton``)에만 쓰고, 여기서는 옅은 배경 + 굵은 테두리 + 체크로 표시합니다.
/// 체크 아이콘과 테두리 굵기가 함께 바뀌므로 색 구분이 어려운 분도 선택 여부를 알 수 있습니다.
struct ChoiceButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppColor.signature : Color.black.opacity(0.3))

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
            .background(isSelected ? AppColor.softBackground : Color.white,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColor.signature : Color.black.opacity(0.35),
                            lineWidth: isSelected ? 3 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChoiceButton(label: "고조선", isSelected: true) {}
        ChoiceButton(label: "고구려", isSelected: false) {}
    }
    .padding(24)
}
