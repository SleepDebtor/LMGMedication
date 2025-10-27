//
//  NonInjectableLabelPDFGenerator.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/12/25.
//  Updated: 10/27/25 - Added QR code generation and fixed 3"x2" sizing
//

import Foundation
import PDFKit
import CoreImage.CIFilterBuiltins
import UIKit

class NonInjectableLabelPDFGenerator {
    
    static func generatePDF(for medication: DispencedMedication, overrideDispenseDate: Date? = nil) async -> Data? {
        return await withCheckedContinuation { continuation in
            nonisolated(unsafe) let med = medication
            nonisolated(unsafe) let overrideDate = overrideDispenseDate
            DispatchQueue.global(qos: .userInitiated).async {
                let pdfData = createNonInjectableLabelPDF(for: med, overrideDispenseDate: overrideDate)
                continuation.resume(returning: pdfData)
            }
        }
    }
    
    private static func createNonInjectableLabelPDF(for medication: DispencedMedication, overrideDispenseDate: Date? = nil) -> Data? {
        // 3" x 2" at 72 DPI = 216 x 144 points
        let pageRect = CGRect(x: 0, y: 0, width: 216, height: 144)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: {
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = [
                kCGPDFContextTitle as String: "Medication Label - Non-Injectable",
                kCGPDFContextAuthor as String: "Lazar Medical Group",
                kCGPDFContextSubject as String: "Prescription Label"
            ]
            return format
        }())
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Set high quality rendering
            let cgContext = context.cgContext
            cgContext.setAllowsAntialiasing(true)
            cgContext.setAllowsFontSmoothing(true)
            cgContext.setAllowsFontSubpixelPositioning(true)
            cgContext.setAllowsFontSubpixelQuantization(true)
            
            drawNonInjectableLabel(in: pageRect, for: medication, context: cgContext, overrideDispenseDate: overrideDispenseDate)
        }
        return data
    }
    
    static func drawNonInjectableLabel(in rect: CGRect, for medication: DispencedMedication, context: CGContext, overrideDispenseDate: Date? = nil) {
        let margin: CGFloat = 4
        let contentRect = rect.insetBy(dx: margin, dy: margin)
        
        // Draw border (optional)
        // context.setStrokeColor(UIColor.black.cgColor)
        // context.setLineWidth(1)
        // context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        
        // QR code on the right side - will be positioned later to align with medication name
        let qrCodeSize: CGFloat = 50
        var qrCodeRect = CGRect(
            x: contentRect.maxX - qrCodeSize,
            y: contentRect.minY + 2, // Temporary position, will be updated
            width: qrCodeSize,
            height: qrCodeSize
        )
        // Text area - adjust for QR code
        let textRect = CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width - qrCodeSize - 6, // Leave space for QR code
            height: contentRect.height
        )
        
        var currentY = textRect.minY + 2
        
        // Practice header - centered and prominent
        currentY += drawText(
            "LAZAR MEDICAL GROUP",
            font: UIFont.boldSystemFont(ofSize: 8),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 10),
            context: context,
            alignment: .center
        )
        
        // Practice address - centered
        currentY += drawText(
            "400 Market St, Suite 5, Williamsport, PA 17701",
            font: UIFont.systemFont(ofSize: 6),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 8),
            context: context,
            alignment: .center
        )
        
        // Phone number - centered
        currentY += drawText(
            "Phone: (570) 933-5507",
            font: UIFont.systemFont(ofSize: 6),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 8),
            context: context,
            alignment: .center
        )
        
        // Add some space
        currentY += 4
        
        // Patient name - left aligned
        if let patient = medication.patient {
            let lastName = patient.lastName ?? "Unknown"
            let firstName = patient.firstName ?? "Patient"
            let patientName = "Patient: \(firstName) \(lastName)"
            
            currentY += drawText(
                patientName,
                font: UIFont.boldSystemFont(ofSize: 8),
                color: UIColor.black,
                rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 10),
                context: context
            )
        }
        
        // Date of birth (if available)
        if let patient = medication.patient, let birthdate = patient.birthdate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let dobText = "DOB: \(formatter.string(from: birthdate))"
            
            currentY += drawText(
                dobText,
                font: UIFont.systemFont(ofSize: 5),
                color: UIColor.black,
                rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 7),
                context: context
            )
        }
        
        // Prescription date
        if let dispenseDate = overrideDispenseDate ?? medication.dispenceDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let dateText = "Rx Date: \(formatter.string(from: dispenseDate))"
            
            currentY += drawText(
                dateText,
                font: UIFont.systemFont(ofSize: 5),
                color: UIColor.black,
                rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 7),
                context: context
            )
        }
        
        // Add space before medication info
        currentY += 4
        
        // Store the Y position where medication name starts for QR code alignment
        let medicationNameY = currentY
        
        // Medication name and strength - prominent
        let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
        let dose = medication.dose ?? ""
        let doseUnit = medication.doseUnit ?? ""
        let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
        
        currentY += drawText(
            medicationTitle,
            font: UIFont.boldSystemFont(ofSize: 9),
            color: UIColor.black,
            rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 11),
            context: context
        )
        
        // Update QR code position to align with medication name
        qrCodeRect = CGRect(
            x: contentRect.maxX - qrCodeSize,
            y: medicationNameY,
            width: qrCodeSize,
            height: qrCodeSize
        )
        
        // Generic name or secondary ingredient (if different)
        if let ingredient1 = medication.baseMedication?.ingredient1,
           !ingredient1.isEmpty,
           ingredient1.lowercased() != medicationName.lowercased() {
            let genericText = "Generic: \(ingredient1)"
            currentY += drawText(
                genericText,
                font: UIFont.italicSystemFont(ofSize: 7),
                color: UIColor.darkGray,
                rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 9),
                context: context
            )
        }
        
        // Quantity dispensed
        let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
        let dispenseUnit = medication.dispenceUnit ?? "tablets"
        let quantityText = "Qty: \(dispenseAmt) \(dispenseUnit)"
        
        currentY += drawText(
            quantityText,
            font: UIFont.boldSystemFont(ofSize: 7),
            color: UIColor.black,
            rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 9),
            context: context
        )
        
        //Sig
        let sig = medication.sig ?? "Take as directed."
        let additionalSig = medication.additionalSg.flatMap { $0.isEmpty ? nil : " \($0)" } ?? ""
        let dosingInstructions = sig + additionalSig
        currentY += drawText(
            dosingInstructions,
            font: UIFont.boldSystemFont(ofSize: 7),
            color: UIColor.black,
            rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 20),
            context: context
        )
        
        // Prescriber information
        if let prescriber = medication.prescriber {
            let firstName = prescriber.firstName ?? ""
            let lastName = prescriber.lastName ?? ""
            let prescriberName = "\(firstName) \(lastName), MD".trimmingCharacters(in: .whitespacesAndNewlines)
            let prescriberText = "Prescriber: \(prescriberName)"
            
            currentY += drawText(
                prescriberText,
                font: UIFont.systemFont(ofSize: 6),
                color: UIColor.black,
                rect: CGRect(x: textRect.minX, y: currentY, width: textRect.width, height: 8),
                context: context
            )
        }
        
        // Pharmacy information (if available) - moved closer to bottom
        if let pharmacy = medication.baseMedication?.pharmacy {
            drawText(
                "Pharmacy: \(pharmacy)",
                font: UIFont.systemFont(ofSize: 6),
                color: UIColor.black,
                rect: CGRect(x: textRect.minX, y: contentRect.maxY - 24, width: textRect.width, height: 8),
                context: context
            )
        }
        
        // Lot and Expiration at bottom-right (if available)
        var bottomInfoParts: [String] = []
        if let lotNum = medication.lotNum, !lotNum.isEmpty {
            bottomInfoParts.append("Lot: \(lotNum)")
        }
        if let exp = medication.expDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            bottomInfoParts.append("Exp: \(formatter.string(from: exp))")
        }
        if !bottomInfoParts.isEmpty {
            let bottomText = bottomInfoParts.joined(separator: " • ")
            let bottomWidth: CGFloat = 100
            drawText(
                bottomText,
                font: UIFont.systemFont(ofSize: 5),
                color: UIColor.darkGray,
                rect: CGRect(x: contentRect.maxX - bottomWidth, y: contentRect.maxY - 8, width: bottomWidth, height: 6),
                context: context,
                alignment: .right
            )
        }
        
        // Draw QR code at its final position (aligned with medication name)
        if let qrCodeImage = generateQRCode(for: medication, overrideDispenseDate: overrideDispenseDate) {
            context.draw(qrCodeImage, in: qrCodeRect)
        }
    }
    
    @discardableResult
    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        rect: CGRect,
        context: CGContext,
        alignment: NSTextAlignment = .left
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate actual height needed
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let adjustedRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(boundingRect.height, rect.height)
        )
        
        attributedString.draw(in: adjustedRect)
        
        return boundingRect.height + 1 // Add minimal spacing for compact format
    }
    
    private static func generateQRCode(for medication: DispencedMedication, overrideDispenseDate: Date? = nil) -> CGImage? {
        // Prefer template URL if available; otherwise fall back to fixed medications page
        let fallbackURL = "https://hushmedicalspa.com/medications"
        let qrString: String
        if let base = medication.baseMedication, let url = base.urlForQR, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Use the template-provided URL
            qrString = url
        } else {
            // No template or no URL provided: use the fixed medications page
            qrString = fallbackURL
        }
        
        guard let data = qrString.data(using: .utf8) else { return nil }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel") // Medium error correction for smaller QR codes
        
        // Create QR code by scaling up - smaller scale for compact labels
        let transform = CGAffineTransform(scaleX: 4, y: 4)
        
        if let output = filter.outputImage?.transformed(by: transform) {
            let context = CIContext()
            if let cgImage = context.createCGImage(output, from: output.extent) {
                return cgImage
            }
        }
        
        return nil
    }
}
