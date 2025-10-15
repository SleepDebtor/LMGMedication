import Foundation
import SwiftUI

enum AppEnvironment: String {
    case development = "Development"
    case testFlight = "TestFlight"
    case appStore = "App Store"
}

struct EnvironmentInfo {
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        // Detect TestFlight via sandbox receipt
        if let url = Bundle.main.appStoreReceiptURL?.lastPathComponent, url == "sandboxReceipt" {
            return .testFlight
        } else {
            return .appStore
        }
        #endif
    }
    
    static var label: String { current.rawValue }
    
    static var color: Color {
        switch current {
        case .development: return .orange
        case .testFlight: return .blue
        case .appStore: return .green
        }
    }
}

struct EnvironmentBadgeView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.caption2)
            Text(EnvironmentInfo.label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(EnvironmentInfo.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(EnvironmentInfo.color.opacity(0.12))
        .cornerRadius(8)
        .accessibilityLabel("Environment: \(EnvironmentInfo.label)")
    }
}
