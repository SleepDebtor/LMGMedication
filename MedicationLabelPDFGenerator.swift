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
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 400) // Landscape label size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            drawMedicationLabel(in: pageRect, for: medication, context: context.cgContext)
        }
        
        return data
    }
    
    private static func drawMedicationLabel(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        let margin: CGFloat = 20
        let contentRect = rect.insetBy(dx: margin, dy: margin)
        
        // Draw border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2)
        context.stroke(rect.insetBy(dx: 1, dy: 1))
        
        // Generate and draw QR code on the left
        let qrCodeRect = CGRect(x: contentRect.minX, y: contentRect.minY + 20, width: 120, height: 120)
        if let qrCodeImage = generateQRCode(for: medication) {
            context.draw(qrCodeImage, in: qrCodeRect)
        }
        
        // Patient information area
        let patientInfoRect = CGRect(
            x: qrCodeRect.maxX + 20,
            y: contentRect.minY,
            width: contentRect.width - qrCodeRect.width - 20,
            height: contentRect.height
        )
        
        drawPatientAndMedicationInfo(in: patientInfoRect, for: medication, context: context)
        
        // Draw pharmacy info at bottom
        drawPharmacyInfo(in: contentRect, for: medication, context: context)
    }
    
    private static func drawPatientAndMedicationInfo(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        var currentY = rect.minY + 10
        
        // Patient name (large, bold)
        if let patient = medication.patient {
            let lastName = patient.lastName ?? "Unknown"
            let firstName = patient.firstName ?? "Patient"
            let patientName = "\(lastName), \(firstName)"
            currentY += drawText(
                patientName,
                font: UIFont.boldSystemFont(ofSize: 28),
                color: UIColor.black,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 40),
                context: context
            )
        }
        
        currentY += 10
        
        // Medication name and dose (large, bold)
        let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
        let dose = medication.dose ?? ""
        let doseUnit = medication.doseUnit ?? ""
        let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
        
        currentY += drawText(
            medicationTitle,
            font: UIFont.boldSystemFont(ofSize: 24),
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 35),
            context: context
        )
        
        currentY += 5
        
        // Secondary ingredient if exists (matching the image format)
        if let ingredient2 = medication.baseMedication?.ingredient2,
           let concentration2 = medication.baseMedication?.concentration2,
           !ingredient2.isEmpty, concentration2 > 0 {
            let secondaryInfo = "\(ingredient2) \(String(format: "%.1f", concentration2))mg"
            currentY += drawText(
                secondaryInfo,
                font: UIFont.italicSystemFont(ofSize: 18),
                color: UIColor.darkGray,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 25),
                context: context
            )
        }
        
        currentY += 15
        
        // Dispense information (bold, matching image)
        let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
        let dispenseUnit = medication.dispenceUnit ?? "units"
        let dispenseInfo = "Dispense: \(dispenseAmt) \(dispenseUnit)"
        currentY += drawText(
            dispenseInfo,
            font: UIFont.boldSystemFont(ofSize: 20),
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 30),
            context: context
        )
        
        // Dosing instructions (matching the "1 syringe sq weekly" format)
        let unitSingular = dispenseUnit.hasSuffix("s") ? String(dispenseUnit.dropLast()) : dispenseUnit
        let dosingInstructions = "1 \(unitSingular) sq weekly"
        currentY += drawText(
            dosingInstructions,
            font: UIFont.systemFont(ofSize: 18),
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 25),
            context: context
        )
        
        currentY += 20
        
        // Prescriber information (bold, matching image format)
        if let prescriber = medication.prescriber {
            let firstName = prescriber.firstName ?? ""
            let lastName = prescriber.lastName ?? ""
            let prescriberName = "\(firstName) \(lastName), MD".trimmingCharacters(in: .whitespacesAndNewlines)
            
            currentY += drawText(
                "Prescriber: \(prescriberName)",
                font: UIFont.boldSystemFont(ofSize: 16),
                color: UIColor.black,
                rect: CGRect(x: rect.minX, y: currentY, width: rect.width - 120, height: 22),
                context: context
            )
            
            // Add prescriber contact info (matching the image)
            drawText(
                "(570) 993-5507",
                font: UIFont.systemFont(ofSize: 14),
                color: UIColor.black,
                rect: CGRect(x: rect.width - 120, y: currentY - 22, width: 120, height: 20),
                context: context,
                alignment: .right
            )
        }
        
        // Practice information (matching the image)
        currentY += drawText(
            "Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA",
            font: UIFont.systemFont(ofSize: 14),
            color: UIColor.black,
            rect: CGRect(x: rect.minX, y: currentY, width: rect.width, height: 20),
            context: context
        )
    }
    
    private static func drawPharmacyInfo(in rect: CGRect, for medication: DispencedMedication, context: CGContext) {
        let bottomY = rect.maxY - 35
        
        // Pharmacy info with fill volume (matching "Empower Pharmacy 0.15mL (15U) fill on each syringe")
        if let pharmacy = medication.baseMedication?.pharmacy {
            let fillAmount = medication.fillAmount
            let fillText = String(format: "%.2f", fillAmount)
            let pharmacyText = "\(pharmacy) \(fillText)mL (15U) fill on each syringe"
            
            drawText(
                pharmacyText,
                font: UIFont.boldSystemFont(ofSize: 14),
                color: UIColor.black,
                rect: CGRect(x: rect.minX, y: bottomY, width: rect.width, height: 20),
                context: context
            )
        }
        
        // Date information
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        var dateInfo: [String] = []
        
        if let dispenseDate = medication.dispenceDate {
            dateInfo.append("Dispensed: \(dateFormatter.string(from: dispenseDate))")
        }
        
        if let expDate = medication.expDate {
            let expFormatter = DateFormatter()
            expFormatter.dateFormat = "MMMMyyyy" // Matching "June2025" format from image
            dateInfo.append("Exp: \(expFormatter.string(from: expDate))")
        }
        
        if let lotNum = medication.lotNum {
            dateInfo.append("Lot: \(lotNum)")
        }
        
        if !dateInfo.isEmpty {
            let dateString = dateInfo.joined(separator: " | ")
            drawText(
                dateString,
                font: UIFont.systemFont(ofSize: 12),
                color: UIColor.darkGray,
                rect: CGRect(x: rect.minX, y: bottomY + 18, width: rect.width, height: 18),
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
