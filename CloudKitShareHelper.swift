//
//  CloudKitShareHelper.swift
//  LMGMedication
//
//  Created by Assistant on 11/9/25.
//

import Foundation
import CloudKit

/// Helper class to handle CloudKit share URLs with sandbox extension issues
class CloudKitShareHelper {
    
    /// Attempts to handle sandbox extension issues when opening CloudKit share URLs
    static func handleShareURL(_ url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔗 CloudKitShareHelper: Processing URL: \(url.absoluteString)")
        
        // Check if this is an iCloud share URL
        guard url.host?.contains("icloud.com") == true else {
            print("❌ Not an iCloud share URL")
            completion(.failure(CloudKitShareError.invalidURL))
            return
        }
        
        Task {
            do {
                // Try to access the security-scoped resource
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                if hasAccess {
                    print("✅ Successfully accessed security-scoped resource")
                } else {
                    print("⚠️ Could not access security-scoped resource, proceeding anyway...")
                }
                
                // Handle the URL through the ShareURLHandler
                await ShareURLHandler.shared.handleIncomingURL(url)
                completion(.success(()))
                
            } catch {
                print("❌ Failed to handle share URL: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Creates a custom URL scheme version of an iCloud share URL to avoid sandbox issues
    static func convertToCustomScheme(_ iCloudURL: URL) -> URL? {
        guard let urlComponents = URLComponents(url: iCloudURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // Extract the share token from the path
        let path = urlComponents.path
        let shareID = path.replacingOccurrences(of: "/share/", with: "")
        
        // Create a custom scheme URL
        let customURLString = "lmgmedication://share/\(shareID)"
        return URL(string: customURLString)
    }
    
    /// Extracts the share token from an iCloud share URL
    static func extractShareToken(from url: URL) -> String? {
        if url.absoluteString.contains("/share/") {
            let components = url.absoluteString.components(separatedBy: "/share/")
            return components.last
        }
        return nil
    }
}

enum CloudKitShareError: LocalizedError {
    case invalidURL
    case sandboxExtensionFailed
    case shareTokenNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid CloudKit share URL"
        case .sandboxExtensionFailed:
            return "Cannot access share URL due to security restrictions"
        case .shareTokenNotFound:
            return "Could not extract share information from URL"
        }
    }
}