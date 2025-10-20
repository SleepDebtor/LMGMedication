//
//  BiometricAuth.swift
//  LMGMedication
//
//  Created by Assistant on 10/5/25.
//

import Foundation
import LocalAuthentication
import SwiftUI
import Combine

@MainActor
final class BiometricAuth: ObservableObject {
    @Published var isUnlocked: Bool = false
    @Published var lastErrorMessage: String?
    @Published var biometryType: LABiometryType = .none
    
    /// If true, only biometrics are allowed. If false, falls back to device passcode when biometrics are unavailable.
    var biometricsOnly: Bool = false
    
    /// Time in seconds after which the app will lock automatically
    var lockTimeoutInterval: TimeInterval = 300 // 5 minutes default
    
    private var lockTimer: Timer?
    private var lastActiveTime: Date = Date()
    private var appStateSubscription: AnyCancellable?
    
    init() {
        setupAppStateMonitoring()
    }
    
    deinit {
        lockTimer?.invalidate()
        appStateSubscription?.cancel()
    }
    
    /// Setup monitoring for app state changes and user activity
    private func setupAppStateMonitoring() {
        // Monitor app state changes
        appStateSubscription = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
        
        // Also monitor when app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppForeground()
        }
    }
    
    /// Call this method whenever user interacts with the app
    func recordUserActivity() {
        lastActiveTime = Date()
        resetLockTimer()
    }
    
    /// Start or reset the lock timer
    private func resetLockTimer() {
        lockTimer?.invalidate()
        
        guard isUnlocked else { return }
        
        lockTimer = Timer.scheduledTimer(withTimeInterval: lockTimeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lockApp()
            }
        }
    }
    
    /// Handle app going to background
    private func handleAppBackground() {
        // Optionally lock immediately when app goes to background
        // Comment out the next line if you want to keep the timer running in background
        lockApp()
    }
    
    /// Handle app coming to foreground
    private func handleAppForeground() {
        // Check if we should lock based on time elapsed
        let timeElapsed = Date().timeIntervalSince(lastActiveTime)
        if timeElapsed > lockTimeoutInterval && isUnlocked {
            lockApp()
        } else if isUnlocked {
            // Reset timer for remaining time
            resetLockTimer()
        }
    }
    
    /// Lock the app
    func lockApp() {
        isUnlocked = false
        lockTimer?.invalidate()
        lastErrorMessage = nil
    }
    
    /// Authenticate with biometrics
    func authenticate(reason: String = "Unlock to access LMGMedication") {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        biometryType = context.biometryType // Will be `.none` initially; set again after canEvaluatePolicy.

        let policy: LAPolicy = biometricsOnly ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        if context.canEvaluatePolicy(policy, error: &error) {
            // Update biometry type after evaluation
            biometryType = context.biometryType
            context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, evalError in
                DispatchQueue.main.async {
                    if success {
                        self?.isUnlocked = true
                        self?.lastErrorMessage = nil
                        self?.recordUserActivity() // Start the timer
                    } else {
                        self?.isUnlocked = false
                        self?.lastErrorMessage = evalError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            // Cannot evaluate policy
            DispatchQueue.main.async { [weak self] in
                self?.isUnlocked = false
                let message = error?.localizedDescription ?? "Biometric authentication is not available on this device."
                self?.lastErrorMessage = message
                self?.biometryType = context.biometryType
            }
        }
    }
    
    /// Set custom lock timeout (in seconds)
    func setLockTimeout(_ seconds: TimeInterval) {
        lockTimeoutInterval = seconds
        if isUnlocked {
            resetLockTimer()
        }
    }
}

