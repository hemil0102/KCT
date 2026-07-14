//
//  TopView.swift
//  KCT
//
//  Created by harryho on 3/18/26.
//

import SwiftUI

struct TopView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KCT · 귀화 면접 문제집")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Text("우리 엄마 천천히 화이팅 :)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(KCTTheme.orangeGradient)
        .clipShape(.rect(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

#Preview {
    TopView()
}
