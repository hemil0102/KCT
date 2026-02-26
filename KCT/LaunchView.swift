//
//  ContentView.swift
//  KCT
//
//  Created by harryho on 2/26/26.
//

import SwiftUI

struct LaunchView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
        
            Text("KCT")
            Text("(Korea Citizenship Test)")
        }
        .background()
        .padding()
    }
}

#Preview {
    LaunchView()
}
