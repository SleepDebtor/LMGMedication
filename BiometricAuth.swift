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
}

