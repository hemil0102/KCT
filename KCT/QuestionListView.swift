//
//  QuestionListView.swift
//  KCT
//
//  Created by harryho on 3/12/26.
//

import SwiftUI

struct QuestionListView: View {
    @State private var text: String = "여기에 내용을 입력하세요"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .topLeading) {
                    // 외곽 영역 라운드를 지정하는 라운드 네모
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                    Text("문제 목록")
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .foregroundStyle(.primary)
                        .font(.body)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
    }
}

#Preview {
    QuestionListView()
}
