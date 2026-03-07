//
//  ContentView.swift
//  KCT
//
//  Created by harryho on 2/26/26.
//

import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.orange.ignoresSafeArea()
            VStack {
                Text("KCT")
                    .font(.system(size: 60, weight: .bold))
                Text("Korea Citizenship Test")
                    .font(.system(size: 24, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}

#Preview {
    LaunchView()
}
