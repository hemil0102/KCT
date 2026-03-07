//
//  ContentView.swift
//  KCT
//
//  Created by harryho on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isLaunch: Bool = true
    
    var body: some View {
        if isLaunch {
            LaunchView()
                .onAppear {
                    // 메인 스레드에서 1.5초 뒤에 특정 코드를 수행한다.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isLaunch = false
                    }
                }
        } else {
            MainView()
        }
    }
}
