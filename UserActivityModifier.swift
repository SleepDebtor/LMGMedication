//
//  UserActivityModifier.swift
//  LMGMedication
//
//  Created by Assistant on 10/19/25.
//

import SwiftUI

/// A view modifier that tracks user activity and resets the authentication timer
struct UserActivityModifier: ViewModifier {
    @EnvironmentObject private var biometricAuth: BiometricAuth
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                biometricAuth.recordUserActivity()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        biometricAuth.recordUserActivity()
                    }
            )
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                biometricAuth.recordUserActivity()
            }
    }
}

extension View {
    /// Tracks user activity to reset the authentication timer
    func trackUserActivity() -> some View {
        self.modifier(UserActivityModifier())
    }
}