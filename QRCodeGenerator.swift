//
//  QRCodeGenerator.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import Foundation
import CoreImage.CIFilterBuiltins

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Utility class for generating QR codes from URLs or text strings
class QRCodeGenerator {
    
    /// Generates a QR code image from a given string
    /// - Parameters:
    ///   - from: The string to encode (URL or text)
    ///   - size: The desired size of the QR code image
    /// - Returns: UIImage containing the QR code, or nil if generation fails
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> PlatformImage? {
        guard !string.isEmpty else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else { return nil }
        filter.message = data
        filter.correctionLevel = "M" // Medium error correction
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale the image to the desired size
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        #if os(iOS)
        return UIImage(cgImage: cgImage)
        #else
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }
    
    /// Generates QR code image data (PNG) from a given string
    /// - Parameters:
    ///   - from: The string to encode (URL or text)
    ///   - size: The desired size of the QR code image
    /// - Returns: Data containing the PNG image, or nil if generation fails
    static func generateQRCodeData(from string: String, size: CGSize = CGSize(width: 200, height: 200)) -> Data? {
        #if os(iOS)
        guard let image = generateQRCode(from: string, size: size) else { return nil }
        return image.pngData()
        #else
        guard let image = generateQRCode(from: string, size: size),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
        #endif
    }
    
    /// Updates a medication's QR code image based on its urlForQR property
    /// - Parameter medication: The medication to update
    /// - Returns: True if the QR code was successfully generated and saved, false otherwise
    @discardableResult
    static func updateMedicationQRCode(_ medication: Medication) -> Bool {
        let urlString = medication.urlForQR ?? "https://hushmedicalspa.com/medications"
        
        guard let qrData = generateQRCodeData(from: urlString) else {
            print("❌ Failed to generate QR code for medication: \(medication.name ?? "Unknown")")
            return false
        }
        
        medication.qrImage = qrData
        print("✅ Generated QR code for medication: \(medication.name ?? "Unknown") with URL: \(urlString)")
        return true
    }
    
    /// Validates if a string is a valid URL
    /// - Parameter string: The string to validate
    /// - Returns: True if the string is a valid URL, false otherwise
    static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    /// Formats a URL string by adding https:// if no scheme is provided
    /// - Parameter urlString: The URL string to format
    /// - Returns: A properly formatted URL string
    static func formatURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "https://hushmedicalspa.com/medications" }
        
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        } else {
            return "https://" + trimmed
        }
    }
}
