//
//  BlurOverlayWindow.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 9/26/26.
//

import SwiftUI

enum BlurReason {
    case tooClose
    case cameraCovered
}

struct BlurOverlayWindow: View {
    var reason: BlurReason
    var threshold: Double

    var body: some View {
        ZStack {
            // Light, bright full-screen frosted blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

//            VStack(spacing: 16) {
            VStack(spacing: 20) {

                if reason == .cameraCovered {
                    // Original "See-No-Evil" Emoji
                    Text("🙈")
//                        .font(.system(size: 64))
                        .font(.system(size: 72))
                    
                    Text("Camera Covered")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Please uncover your MacBook camera to continue.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } else {
                    // Original Orange Warning Triangle
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .foregroundColor(.orange)
                    Text("Oops! You're Too Close!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Please sit back at least \(Int(threshold)) inches to rest your eyes.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
