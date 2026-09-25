//
//  ChoiceButton.swift
//  KCT
//
//  역할 : 탭하면 선택되는 큰 보기 버튼. 선다형과 O/X 가 함께 쓴다
//  요점 : 선택은 "상태"다. 그래서 꽉 채우지 않고 테두리와 체크로 표시한다
//
//  ── 구성 ──────────────────────────────────────────────
//  ChoiceButton
//  ├─ label         버튼에 쓸 글자 (보기 내용 또는 "맞아요"/"아니에요")
//  ├─ isSelected    지금 골라져 있는가
//  ├─ verdict       골라진 답의 판정 (nil = 아직 모름). O/X · 2지선다만 넘긴다 —
//  │                녹색 ✓ / 붉은색 ✕ (13차 후속 — 2지선다도 O/X처럼 즉시 채점된다)
//  ├─ isWrongFlash  4지선다 전용: 방금 오답을 눌러 붉게 표시할 짧은 순간인가
//  ├─ isEliminated  4지선다 전용: 오답으로 확인돼 소거됐는가 (흐리게, 다시 못 고른다)
//  └─ action        눌렀을 때 할 일 — 무엇을 고를지는 부르는 쪽이 정한다
//
//  ── 연결 ──────────────────────────────────────────────
//  불러 쓰는 곳 : QuestionScreen (선다형 보기 목록, O/X 두 버튼)
//  기대는 것    : AppColor 뿐
//  건드리지 않는 것 : 정답 여부 — 이 버튼은 무엇이 정답인지 모른다. 채점은 QuizSession 이 하고,
//                    결과(verdict)만 받아 색을 칠한다. 4지선다의 소거도 QuestionScreen 이
//                    스스로 판단해(``ModePayload/choices(options:correct:)``의 정답과
//                    비교) isWrongFlash·isEliminated 로 넘겨줄 뿐, 이 버튼은 여전히
//                    아무것도 판단하지 않는다
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
    /// O/X · 2지선다는 누르는 순간 채점되므로 이 값을 넘긴다 — 맞으면 녹색 ✓, 틀리면
    /// 붉은색 ✕. 해설 창이 올라온 뒤에도 창 위로 이 버튼이 보여 「내가 뭘 골랐는지」가
    /// 남는다. 4지선다는 이 값 대신 ``isWrongFlash``·``isEliminated`` 를 쓴다.
    var verdict: Bool? = nil

    /// 4지선다 전용. 방금 오답을 눌러 **흔들리는 한 박자** 동안만 `true` 다 —
    /// 이 순간엔 테두리·아이콘이 붉게 뜬다. 흔들림이 끝나면 ``isEliminated`` 로 넘어간다.
    var isWrongFlash: Bool = false

    /// 4지선다 전용. 오답으로 확인돼 **소거**됐는가. 흐리게 보이고, 부르는 쪽이
    /// 다시 탭해도 무시한다(``QuestionScreen``이 그 판단을 한다 — 이 버튼은
    /// 눌린 것 자체는 그대로 알린다).
    var isEliminated: Bool = false

    let action: () -> Void

    /// 지금 칠할 색. 안 골랐으면 회색 테두리, 골랐으면(또는 오답 플래시면) 보라·녹색·분홍.
    private var tint: Color {
        if isWrongFlash { return AppColor.wrongAccent }
        guard isSelected else { return Color.black.opacity(0.35) }
        switch verdict {
        case .some(true):  return AppColor.answerSheetAccent
        case .some(false): return AppColor.wrongAccent
        case .none:        return AppColor.signature
        }
    }

    private var fill: Color {
        if isWrongFlash { return AppColor.wrongHeader }
        guard isSelected else { return Color.white }
        switch verdict {
        case .some(true):  return AppColor.answerSheetBadge
        case .some(false): return AppColor.wrongHeader
        case .none:        return AppColor.softBackground
        }
    }

    private var iconName: String {
        if isWrongFlash { return "xmark.circle.fill" }
        guard isSelected else { return "circle" }
        return verdict == false ? "xmark.circle.fill" : "checkmark.circle.fill"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isWrongFlash || isSelected ? tint : Color.black.opacity(0.3))

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
                    .stroke(tint, lineWidth: (isSelected || isWrongFlash) ? 3 : 1.5)
            )
            // 소거된 보기는 흐리게 — "다시 골라도 소용없다"는 것을 색으로도 알려준다.
            .opacity(isEliminated ? 0.35 : 1)
            .animation(.easeOut(duration: 0.2), value: verdict)
            .animation(.easeOut(duration: 0.2), value: isWrongFlash)
            .animation(.easeOut(duration: 0.25), value: isEliminated)
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
        HStack(spacing: 14) {
            ChoiceButton(label: "신라", isSelected: false, isWrongFlash: true) {}
            ChoiceButton(label: "백제", isSelected: false, isEliminated: true) {}
        }
    }
    .padding(24)
}
