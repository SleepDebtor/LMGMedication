//
//  MedicationLabelPDFGenerator.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import Foundation
import UIKit
import PDFKit
import CoreImage.CIFilterBuiltins

class MedicationLabelPDFGenerator {
    
    static func generatePDF(for medication: DispencedMedication) async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let pdfData = createMedicationLabelPDF(for: medication)
                continuation.resume(returning: pdfData)
            }
        }
    }
    
    private static func createMedicationLabelPDF(for medication: DispencedMedication) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 400, height: 200) // 2x1 inch label size at 200 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            drawMedicationLabel(in: pageRect, for: medication, context: context.cgContext)
        }
        
        return data
    }
    
    static func drawMedicationLabel(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        let margin: CGFloat = 6 // Scaled margin for 200 DPI
        let contentRect = rect.insetBy(dx: margin, dy: margin)
        
        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2) // Slightly thicker border for higher resolution
        context.stroke(rect.insetBy(dx: 1, dy: 1))
        
        // QR code on the left - scaled for 200 DPI
        let qrCodeSize: CGFloat = 166 // Scaled QR code size (60 * 200/72)
        let qrCodeRect = CGRect(
            x: contentRect.minX + 6, 
            y: contentRect.minY + (contentRect.height - qrCodeSize) / 2, // Center vertically
            width: qrCodeSize, 
            height: qrCodeSize
        )
        
        if let qrCodeImage = generateQRCode(for: medication) {
            context.draw(qrCodeImage, in: qrCodeRect)
        }
        
        // Text area on the right - remaining space
        let textRect = CGRect(
            x: qrCodeRect.maxX + 11,
            y: contentRect.minY,
            width: contentRect.width - qrCodeSize - 17,
            height: contentRect.height
        )
        
        drawCompactMedicationInfo(in: textRect, for: medication, context: context)
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
                font: UIFont.boldSystemFont(ofSize: 22), // 8 * 2.78 ≈ 22
                color: UIColor.black,
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
            font: UIFont.boldSystemFont(ofSize: 19), // 7 * 2.78 ≈ 19
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 25),
            context: context
        )
        
        // Secondary ingredient (compact) - scaled for 200 DPI
        if let ingredient2 = medication.baseMedication?.ingredient2,
           let concentration2 = medication.baseMedication?.concentration2,
           !ingredient2.isEmpty, concentration2 > 0 {
            let secondaryInfo = "\(ingredient2) \(String(format: "%.1f", concentration2))mg"
            currentY += drawText(
                secondaryInfo,
                font: UIFont.italicSystemFont(ofSize: 17), // 6 * 2.78 ≈ 17
                color: UIColor.darkGray,
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
            font: UIFont.boldSystemFont(ofSize: 17), // 6 * 2.78 ≈ 17
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 22),
            context: context
        )
        
        // Dosing instructions (compact) - scaled for 200 DPI
        let unitSingular = dispenseUnit.hasSuffix("s") ? String(dispenseUnit.dropLast()) : dispenseUnit
        let dosingInstructions = "1 \(unitSingular) sq weekly"
        currentY += drawText(
            dosingInstructions,
            font: UIFont.systemFont(ofSize: 14), // 5 * 2.78 ≈ 14
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 19),
            context: context
        )
        
        // Prescriber information (compact) - scaled for 200 DPI
        if let prescriber = medication.prescriber {
            let firstName = prescriber.firstName ?? ""
            let lastName = prescriber.lastName ?? ""
            let prescriberName = "\(firstName) \(lastName), MD".trimmingCharacters(in: .whitespacesAndNewlines)
            
            currentY += drawText(
                "Prescriber: \(prescriberName)",
                font: UIFont.boldSystemFont(ofSize: 14), // 5 * 2.78 ≈ 14
                color: UIColor.black,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 19),
                context: context
            )
        }
        
        // Practice and pharmacy information (very compact, at bottom) - scaled for 200 DPI
        let practiceInfo = "Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA"
        currentY += drawText(
            practiceInfo,
            font: UIFont.systemFont(ofSize: 11), // 4 * 2.78 ≈ 11
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 17),
            context: context
        )
        
        // Pharmacy info with fill volume (compact) - scaled for 200 DPI
        if let pharmacy = medication.baseMedication?.pharmacy {
            let fillAmount = medication.fillAmount
            let fillText = String(format: "%.2f", fillAmount)
            let fillTextUnits = String(format: "%.0f", fillAmount * 100)
            let pharmacyText = "\(pharmacy) \(fillText)mL (\(fillTextUnits)U)"
            
            currentY += drawText(
                pharmacyText,
                font: UIFont.boldSystemFont(ofSize: 11), // 4 * 2.78 ≈ 11
                color: UIColor.black,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 17),
                context: context
            )
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
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        let transform = CGAffineTransform(scaleX: 3, y: 3)
        
        if let output = filter.outputImage?.transformed(by: transform) {
            let context = CIContext()
            return context.createCGImage(output, from: output.extent)
        }
        
        return nil
    }
}
