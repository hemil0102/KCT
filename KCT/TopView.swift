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
            Text("한걸음씩 천천히, 느려도 괜찮아요 :)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    TopView()
}
