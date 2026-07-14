//
//  SettingView.swift
//  KCT
//
//  Created by harryho on 7/14/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("questionFontSize") private var fontSizeRaw: String = QuestionFontSize.medium.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("설정")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(KCTTheme.textDark)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("글자 크기")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KCTTheme.chipMuted)
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("문제 글자 크기")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(KCTTheme.textDark)

                        Picker("글자 크기", selection: $fontSizeRaw) {
                            ForEach(QuestionFontSize.allCases, id: \.rawValue) { size in
                                Text(size.rawValue).tag(size.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(KCTTheme.cardBorder, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("앱 정보")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(KCTTheme.chipMuted)
                        .padding(.leading, 4)

                    VStack(spacing: 0) {
                        HStack {
                            Text("버전")
                            Spacer()
                            Text("1.0.0").foregroundStyle(KCTTheme.chipMuted)
                        }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(KCTTheme.textDark)
                        .padding(16)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("만든이에게 메시지 보내기")
                            Spacer()
                        }
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(KCTTheme.textDark)
                        .padding(16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(KCTTheme.cardBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    SettingsView()
}
