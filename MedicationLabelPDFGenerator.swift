//
//  MedicationLabelPDFGenerator.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import Foundation
import PDFKit
import CoreImage.CIFilterBuiltins
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor

class MedicationLabelPDFGenerator {
    
    static func generatePDF(for medication: DispencedMedication) async -> Data? {
        return await withCheckedContinuation { continuation in
            nonisolated(unsafe) let med = medication
            DispatchQueue.global(qos: .userInitiated).async {
                let pdfData = createMedicationLabelPDF(for: med)
                continuation.resume(returning: pdfData)
            }
        }
    }
    
    private static func createMedicationLabelPDF(for medication: DispencedMedication) -> Data? {
        // Use 72 DPI as standard (1 point = 1/72 inch)
        // For a 2"x1" label at 72 DPI: 144x72 points
        // For better quality, we'll use 400x200 points (roughly 5.5"x2.8" at 72 DPI)
        let pageRect = CGRect(x: 0, y: 0, width: 400, height: 200)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: {
            let format = UIGraphicsPDFRendererFormat()
            format.documentInfo = [
                kCGPDFContextTitle as String: "Medication Label",
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
            
            drawMedicationLabel(in: pageRect, for: medication, context: cgContext)
        }
        return data
    }
    
    static func drawMedicationLabel(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        let margin: CGFloat = 6 // Scaled margin for 200 DPI
        let contentRect = rect.insetBy(dx: margin, dy: margin)
        
        // Draw border
        // context.setStrokeColor(PlatformColor.black.cgColor)
        // context.setLineWidth(2) // Slightly thicker border for higher resolution
        // context.stroke(rect.insetBy(dx: 1, dy: 1))
        
        // QR code on the left - reduced size for 200 DPI
        let qrCodeSize: CGFloat = 125 // Reduced from 166 to 120
        let qrCodeRect = CGRect(
            x: contentRect.minX + 6,
            y: contentRect.minY + 6,// qrCodeSize)+10,
            width: qrCodeSize,
            height: qrCodeSize
        )
        
        if let qrCodeImage = generateQRCode(for: medication) {
            context.draw(qrCodeImage, in: qrCodeRect)
        }
        
        // Text area on the right - more space due to smaller QR code
        let textRect = CGRect(
            x: qrCodeRect.maxX + 8,
            y: contentRect.minY,
            width: contentRect.width - qrCodeSize - 14,
            height: contentRect.height
        )
        
        drawCompactMedicationInfo(in: textRect, for: medication, context: context)
        
        // Draw practice and pharmacy info across full width at bottom
        drawFullWidthBottomInfo(in: contentRect, for: medication, context: context)
    }
    
    private static func drawCompactMedicationInfo(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        var currentY = rect.minY + 3
        
        // Patient name (compact, bold) - scaled for 200 DPI
        if let patient = medication.patient {
            let lastName = patient.lastName ?? "Unknown"
            let firstName = patient.firstName ?? "Patient"
            let patientName = "\(lastName), \(firstName)"
            currentY += drawText(
                patientName,
                font: PlatformFont.boldSystemFont(ofSize: 19), // 8 * 2.78 ≈ 22
                color: PlatformColor.black,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 28),
                context: context
            )
        }
        
        // Medication name and dose (compact, bold) - scaled for 200 DPI
        let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
        let dose = medication.dose ?? ""
        let doseUnit = medication.doseUnit ?? ""
        let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
        
        currentY += drawText(
            medicationTitle,
            font: PlatformFont.boldSystemFont(ofSize: 22), // 7 * 2.78 ≈ 19
            color: PlatformColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 25),
            context: context
        )
        
        // Secondary ingredient (compact) - scaled for 200 DPI
        if let ingredient2 = medication.baseMedication?.ingredient2,
           let concentration2 = medication.baseMedication?.concentration2,
           !ingredient2.isEmpty, concentration2 > 0 {
            var amt2Text: String = ""
            if medication.fillAmount > 0.0 {
                amt2Text = " \(String(format: "%.1f", medication.fillAmount*concentration2))mg"
            }
            let secondaryInfo = "  \(ingredient2) \(amt2Text)"
            currentY += drawText(
                secondaryInfo,
                font: PlatformFont.italicSystemFont(ofSize: 15), // 6 * 2.78 ≈ 17
                color: PlatformColor.darkGray,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 22),
                context: context
            )
        }
        
        // Dispense information (compact) - scaled for 200 DPI
        let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
        let dispenseUnit = medication.dispenceUnit ?? "units"
        let dispenseInfo = "Disp: \(dispenseAmt) \(dispenseUnit)"
        currentY += drawText(
            dispenseInfo,
            font: PlatformFont.boldSystemFont(ofSize: 17), // 6 * 2.78 ≈ 17
            color: PlatformColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 22),
            context: context
        )
        
        // Dosing instructions (compact) - scaled for 200 DPI
        let unitSingular = dispenseUnit.hasSuffix("s") ? String(dispenseUnit.dropLast()) : dispenseUnit
        let dosingInstructions = "1 \(unitSingular) sq weekly"
        currentY += drawText(
            dosingInstructions,
            font: PlatformFont.systemFont(ofSize: 14), // 5 * 2.78 ≈ 14
            color: PlatformColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 19),
            context: context
        )
    }
    
    private static func drawFullWidthBottomInfo(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        // Calculate bottom area for practice and pharmacy info
        let bottomHeight: CGFloat = 54 // Space for three lines at bottom
        let bottomRect = CGRect(
            x: rect.minX + 6,
            y: rect.maxY - bottomHeight,
            width: rect.width,
            height: bottomHeight
        )
        
        var currentY = bottomRect.minY
        
        
        // Prescriber information (compact) - scaled for 200 DPI
        if let prescriber = medication.prescriber {
            let firstName = prescriber.firstName ?? ""
            let lastName = prescriber.lastName ?? ""
            let prescriberName = "\(firstName) \(lastName), MD (570) 933-5507".trimmingCharacters(in: .whitespacesAndNewlines)
            
            currentY += drawText(
                "Prescriber: \(prescriberName)",
                font: PlatformFont.boldSystemFont(ofSize: 14), // 5 * 2.78 ≈ 14
                color: PlatformColor.black,
                rect: CGRect(x: bottomRect.minX, y: currentY, width: bottomRect.width, height: 17),
                context: context
            )
        }
        
        // Practice information (full width) - scaled for 200 DPI
        let practiceInfo = "Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA"
        currentY += drawText(
            practiceInfo,
            font: PlatformFont.systemFont(ofSize: 11), // 4 * 2.78 ≈ 11
            color: PlatformColor.black,
            rect: CGRect(x: bottomRect.minX, y: currentY, width: bottomRect.width, height: 17),
            context: context
        )
        
        // Pharmacy info with fill volume (full width) - scaled for 200 DPI
        if let pharmacy = medication.baseMedication?.pharmacy {
            let fillAmount = medication.fillAmount
            let fillText = String(format: "%.2f", fillAmount)
            let fillTextUnits = String(format: "%.0f", fillAmount * 100)
            let pharmacyText = "\(pharmacy) \(fillText)mL (\(fillTextUnits)U)"
            
            currentY += drawText(
                pharmacyText,
                font: PlatformFont.boldSystemFont(ofSize: 11), // 4 * 2.78 ≈ 11
                color: PlatformColor.black,
                rect: CGRect(x: bottomRect.minX, y: currentY, width: bottomRect.width, height: 17),
                context: context
            )
        }
    }
    
    @discardableResult
    private static func drawText(
        _ text: String,
        font: PlatformFont,
        color: PlatformColor,
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
        let textRect = rect
        
        // Calculate actual height needed
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let adjustedRect = CGRect(
            x: textRect.minX,
            y: textRect.minY,
            width: textRect.width,
            height: min(boundingRect.height, textRect.height)
        )
        
        attributedString.draw(in: adjustedRect)
        
        return boundingRect.height + 5 // Add some spacing
    }
    
    private static func generateQRCode(for medication: DispencedMedication) -> CGImage? {
        // Create QR code data - you can customize this based on your needs
        var qrData = ""
        
        if let patient = medication.patient {
            qrData += "Patient: \(patient.displayName)\n"
        }
        
        if let medName = medication.baseMedication?.name {
            qrData += "Medication: \(medName)\n"
        }
        
        if let dose = medication.dose {
            qrData += "Dose: \(dose)\(medication.doseUnit ?? "")\n"
        }
        
        qrData += "Dispense: \(medication.dispenceAmt) \(medication.dispenceUnit ?? "")\n"
        
        if let dispenseDate = medication.dispenceDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            qrData += "Date: \(formatter.string(from: dispenseDate))\n"
        }
        
        if let lotNum = medication.lotNum {
            qrData += "Lot: \(lotNum)"
        }
        
        // If the medication has a URL for QR, use that instead
        if let qrURL = medication.baseMedication?.urlForQR {
            qrData = qrURL
        }
        
        let data = qrData.data(using: String.Encoding.utf8)
        
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction
        
        // Create high-resolution QR code by scaling up significantly
        let transform = CGAffineTransform(scaleX: 8, y: 8) // Higher scale for better quality
        
        if let output = filter.outputImage?.transformed(by: transform) {
            let context = CIContext()
            // Render with better quality settings
            if let cgImage = context.createCGImage(output, from: output.extent) {
                return cgImage
            }
        }
        
        return nil
    }
}

