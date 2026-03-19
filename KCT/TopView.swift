//
//  TopView.swift
//  KCT
//
//  Created by harryho on 3/18/26.
//

import SwiftUI

struct TopView: View {
    var body: some View {
        ZStack {
            Color.orange.ignoresSafeArea()
            Text("우리 엄마 천천히 화이팅 :)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    TopView()
}
