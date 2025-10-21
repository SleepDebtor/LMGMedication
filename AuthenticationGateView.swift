//
//  AuthenticationGateView.swift
//  LMGMedication
//
//  Created by Assistant on 10/5/25.
//

import SwiftUI
import UIKit

struct AuthenticationGateView<Content: View>: View {
    @StateObject private var auth = BiometricAuth()
    @Environment(\.scenePhase) private var scenePhase
    let content: () -> Content

    // Platform-aware system colors
    private var platformSystemBackground: Color {
        Color(.systemBackground)
    }

    private var platformSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }

    var body: some View {
        Group {
            if auth.isUnlocked {
                content()
            } else {
                lockScreen
            }
        }
        .onAppear {
            // Trigger authentication on appear
            auth.authenticate()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // Re-authenticate when app becomes active if not unlocked
                if !auth.isUnlocked {
                    auth.authenticate()
                }
            case .inactive, .background:
                // Lock immediately when leaving foreground
                auth.isUnlocked = false
            @unknown default:
                break
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            // Branding image - using system icon as fallback
            VStack {
                Image(systemName: "pills.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 32)

            // Title and message
            VStack(spacing: 8) {
                Text("Welcome to LMG Medication")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Face ID or Passcode required to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let message = auth.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)

            // Unlock button
            Button {
                auth.authenticate()
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Spacer()

            // Small footer branding
            Text("Lazar Medical Group")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [platformSystemBackground, platformSecondaryBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

