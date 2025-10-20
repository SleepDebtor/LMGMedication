//
//  AuthenticationGateView.swift
//  LMGMedication
//
//  Created by Assistant on 10/19/25.
//

import SwiftUI
import LocalAuthentication

struct AuthenticationGateView<Content: View>: View {
    @EnvironmentObject private var biometricAuth: BiometricAuth
    @State private var showingTimeoutSettings = false
    
    let content: () -> Content
    
    // Custom colors matching the app theme
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if biometricAuth.isUnlocked {
                content()
                    .onTapGesture {
                        // Record user activity on any tap
                        biometricAuth.recordUserActivity()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                // Record user activity on any drag/scroll
                                biometricAuth.recordUserActivity()
                            }
                    )
            } else {
                lockScreen
            }
        }
    }
    
    private var lockScreen: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [lightBackgroundColor, goldColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon/logo area
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [goldColor.opacity(0.2), darkGoldColor.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "pills.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [goldColor, darkGoldColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: goldColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("LMG Medication")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [goldColor, darkGoldColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Authentication section
                VStack(spacing: 20) {
                    Text("App Locked")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(darkGoldColor)
                    
                    if let errorMessage = biometricAuth.lastErrorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Unlock button
                    Button(action: {
                        biometricAuth.authenticate()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIconName)
                                .font(.title2)
                            
                            Text("Unlock with \(biometricText)")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [goldColor, darkGoldColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: goldColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)
                    
                    // Settings button
                    Button(action: {
                        showingTimeoutSettings = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.caption)
                            Text("Lock Settings")
                                .font(.caption)
                        }
                        .foregroundColor(goldColor.opacity(0.8))
                    }
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingTimeoutSettings) {
            TimeoutSettingsView(biometricAuth: biometricAuth)
        }
        .onAppear {
            // Auto-prompt for authentication when lock screen appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                biometricAuth.authenticate()
            }
        }
    }
    
    private var biometricIconName: String {
        switch biometricAuth.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }
    
    private var biometricText: String {
        switch biometricAuth.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Passcode"
        }
    }
}

struct TimeoutSettingsView: View {
    @ObservedObject var biometricAuth: BiometricAuth
    @Environment(\.dismiss) private var dismiss
    
    private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let darkGoldColor = Color(red: 0.45, green: 0.3, blue: 0.15)
    private let lightBackgroundColor = Color(red: 0.99, green: 0.985, blue: 0.97)
    
    private let timeoutOptions: [(title: String, seconds: TimeInterval)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("Never", .infinity)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                lightBackgroundColor
                    .ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(timeoutOptions, id: \.seconds) { option in
                            HStack {
                                Text(option.title)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if abs(biometricAuth.lockTimeoutInterval - option.seconds) < 1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(goldColor)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                biometricAuth.setLockTimeout(option.seconds)
                            }
                        }
                    } header: {
                        Text("Auto-Lock Timer")
                            .foregroundColor(goldColor)
                    } footer: {
                        Text("Choose how long the app stays unlocked when not in use. The app will also lock when it goes to the background.")
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Toggle("Require Biometrics Only", isOn: Binding(
                            get: { biometricAuth.biometricsOnly },
                            set: { biometricAuth.biometricsOnly = $0 }
                        ))
                        .tint(goldColor)
                    } header: {
                        Text("Authentication Method")
                            .foregroundColor(goldColor)
                    } footer: {
                        Text("When enabled, only Face ID/Touch ID will be accepted. When disabled, you can fall back to your device passcode if biometrics fail.")
                            .foregroundColor(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Security Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
    }
}

#Preview {
    AuthenticationGateView {
        Text("Protected Content")
            .font(.largeTitle)
            .padding()
    }
}

