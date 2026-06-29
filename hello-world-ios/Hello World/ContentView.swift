//
//  ContentView.swift
//  Hello World
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.2, green: 0.15, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Hello, World!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("made on cursor mobile")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
    }
}

#Preview {
    ContentView()
}
