//
//  iCloudStatusView.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import SwiftUI
import CloudKit

struct iCloudStatusView: View {
    @StateObject private var cloudManager = CloudKitManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: cloudIcon)
                .font(.system(size: 60))
                .foregroundColor(statusColor)
            
            Text(statusTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(statusMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if cloudManager.accountStatus != .available {
                Button(actionButtonTitle) {
                    handleAction()
                }
                .buttonStyle(.borderedProminent)
                
                if cloudManager.accountStatus == .temporarilyUnavailable {
                    Button("Retry Now") {
                        cloudManager.checkAccountStatus()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onAppear {
            cloudManager.checkAccountStatus()
        }
    }
    
    private var cloudIcon: String {
        switch cloudManager.accountStatus {
        case .available:
            return "icloud.fill"
        case .noAccount:
            return "icloud.slash.fill"
        case .restricted:
            return "icloud.and.arrow.down.fill"
        case .temporarilyUnavailable:
            return "icloud.slash"
        case .couldNotDetermine:
            return "questionmark.circle.fill"
        @unknown default:
            return "exclamationmark.icloud.fill"
        }
    }
    
    private var statusColor: Color {
        switch cloudManager.accountStatus {
        case .available:
            return .green
        case .temporarilyUnavailable:
            return .orange
        default:
            return .red
        }
    }
    
    private var statusTitle: String {
        switch cloudManager.accountStatus {
        case .available:
            return "iCloud Connected"
        case .noAccount:
            return "iCloud Required"
        case .restricted:
            return "iCloud Restricted"
        case .temporarilyUnavailable:
            return "iCloud Unavailable"
        case .couldNotDetermine:
            return "iCloud Status Unknown"
        @unknown default:
            return "iCloud Issue"
        }
    }
    
    private var statusMessage: String {
        switch cloudManager.accountStatus {
        case .available:
            return "Your data is syncing with iCloud and sharing is available."
        case .noAccount:
            return "Sign in to iCloud in Settings to sync your patient data across devices and enable sharing."
        case .restricted:
            return "iCloud access is restricted. Check Screen Time settings or parental controls."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. This usually resolves automatically. Try again in a few minutes."
        case .couldNotDetermine:
            return "Unable to determine iCloud status. Check your internet connection and try again."
        @unknown default:
            return "There's an issue with iCloud connectivity. Please check your settings."
        }
    }
    
    private var actionButtonTitle: String {
        switch cloudManager.accountStatus {
        case .noAccount, .restricted:
            return "Open Settings"
        default:
            return "Retry"
        }
    }
    
    private func handleAction() {
        switch cloudManager.accountStatus {
        case .noAccount, .restricted:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        default:
            cloudManager.checkAccountStatus()
        }
    }
}

#Preview {
    iCloudStatusView()
}