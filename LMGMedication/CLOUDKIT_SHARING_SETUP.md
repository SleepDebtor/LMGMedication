# CloudKit Sharing Setup Guide

## Overview
This guide covers the complete setup needed for CloudKit sharing functionality in your LMGMedication app. The sharing system allows healthcare providers to securely share patient data via CloudKit.

## 🔧 Required Changes

### 1. Info.plist Configuration

**CRITICAL**: You must add URL scheme support to handle CloudKit share invitations.

Add the following to your `Info.plist` file (see `Info.plist.example` for complete configuration):

```xml
<!-- CloudKit Sharing URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>CloudKit Share</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lmgmedication</string> <!-- Replace with your preferred scheme -->
        </array>
    </dict>
</array>

<!-- Enable CloudKit Sharing -->
<key>CKSharingSupported</key>
<true/>

<!-- Privacy Description -->
<key>NSCloudKitSharingDescription</key>
<string>This app uses CloudKit to share patient medication data securely between healthcare providers.</string>
```

### 2. App Delegate Updates

Add URL handling to your main App file or App Delegate:

```swift
// In your main App.swift file:
import SwiftUI

@main
struct LMGMedicationApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var sharingManager = SharingManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    Task {
                        await handleIncomingURL(url)
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) async {
        // Handle CloudKit share URLs
        if url.scheme == "lmgmedication" || url.absoluteString.contains("cloudkit") {
            do {
                try await sharingManager.acceptShare(from: url)
                print("Successfully accepted share from URL: \(url)")
            } catch {
                print("Failed to accept share: \(error)")
            }
        }
    }
}
```

### 3. CloudKit Container Configuration

**Ensure your CloudKit container is properly configured:**

1. Go to [CloudKit Console](https://icloud.developer.apple.com/dashboard)
2. Select your `iCloud.LMGMedications` container
3. Enable sharing for the following record types:
   - `Patient`
   - `DispencedMedication` 
   - `MedicationTemplate`

### 4. Entitlements File

Verify your `YourApp.entitlements` file includes:

```xml
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.LMGMedications</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <!-- Enable CloudKit sharing -->
    <key>com.apple.developer.cloudkit-sharing</key>
    <true/>
</dict>
```

## 🚀 Testing Your Setup

### 1. Test Share Creation
```swift
// In your view or test:
let patient = // your patient object
let sharingManager = SharingManager.shared

Task {
    do {
        let shareURL = try await sharingManager.generatePatientShareLink(
            patient, 
            with: ["colleague@example.com"]
        )
        print("Share URL created: \(shareURL)")
    } catch {
        print("Share creation failed: \(error)")
    }
}
```

### 2. Test Share Acceptance

1. Create a share URL in your app
2. Send it to another device with your app installed
3. Tap the URL - it should open your app and accept the share
4. Verify the shared patient appears in the "Shared Patients" view

## 🔒 Security Considerations

### CloudKit Sharing Security Features:
- **Encrypted in transit and at rest**
- **User authentication via iCloud**
- **Participant permission control**
- **Audit trail via CloudKit Console**

### Best Practices:
- Always validate participant email addresses
- Implement proper error handling for share failures
- Test with real iCloud accounts before production
- Monitor CloudKit usage in the Console

## 📱 User Experience Enhancements

### Share Button Integration

Use the provided SwiftUI components:

```swift
// For patient sharing:
SharePatientButton(patient: myPatient)

// For medication label sharing:
ShareLabelButton(medication: myMedication)

// For viewing shared content:
SharedPatientsView()

// For share invitations:
ShareInvitationView(shareURL: invitationURL)
```

### Status Indicators

The sharing system provides visual feedback:
- Progress indicators during sharing operations
- Error alerts with actionable messages
- Success confirmations
- Sync status indicators

## 🐛 Troubleshooting

### Common Issues:

**"URL scheme not recognized"**
- Verify Info.plist URL scheme configuration
- Ensure app is installed on the receiving device
- Check that URL scheme matches your configuration

**"CloudKit sharing not available"**
- Verify user is signed in to iCloud
- Check CloudKit container configuration
- Ensure entitlements are correct

**"Participant not found"**
- Verify email addresses are exact matches for iCloud accounts
- Test with known iCloud users first
- Check CloudKit Console for participant resolution errors

### Debug Commands:

```swift
// Check CloudKit status
print("iCloud signed in: \(CloudKitManager.shared.isSignedInToiCloud)")
print("Account status: \(CloudKitManager.shared.accountStatus)")

// Monitor sharing operations
SharingManager.shared.$isSharing.sink { isSharing in
    print("Sharing in progress: \(isSharing)")
}
```

## ✅ Verification Checklist

Before deploying:

- [ ] Info.plist includes CFBundleURLTypes for CloudKit sharing
- [ ] CKSharingSupported is set to true
- [ ] CloudKit container has sharing enabled for all record types
- [ ] Entitlements file includes cloudkit-sharing permission
- [ ] URL handling is implemented in your main App
- [ ] Tested share creation and acceptance
- [ ] Error handling displays user-friendly messages
- [ ] Privacy description explains CloudKit usage

## 🎯 Next Steps

Once setup is complete:

1. **Test thoroughly** with multiple iCloud accounts
2. **Deploy to TestFlight** for broader testing
3. **Monitor CloudKit Console** for usage and errors
4. **Gather user feedback** on the sharing experience
5. **Consider additional features** like:
   - Batch patient sharing
   - Sharing groups management
   - Share expiration controls
   - Advanced permission management

---

Your CloudKit sharing implementation is now ready for healthcare collaboration! 🏥✨