//
//  NonInjectableLabelPDFGenerator.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/12/25.
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
        let margin: CGFloat = 6
        let contentRect = rect.insetBy(dx: margin, dy: margin)
        
        // Draw border (optional)
        // context.setStrokeColor(UIColor.black.cgColor)
        // context.setLineWidth(1)
        // context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        
        var currentY = contentRect.minY + 2
        
        // Practice header - centered and prominent
        currentY += drawText(
            "LAZAR MEDICAL GROUP",
            font: UIFont.boldSystemFont(ofSize: 11),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 14),
            context: context,
            alignment: .center
        )
        
        // Practice address
        currentY += drawText(
            "400 Market St, Suite 5, Williamsport, PA 17701",
            font: UIFont.systemFont(ofSize: 8),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
            context: context,
            alignment: .center
        )
        
        // Phone number
        currentY += drawText(
            "Phone: (570) 933-5507",
            font: UIFont.systemFont(ofSize: 8),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
            context: context,
            alignment: .center
        )
        
        // Add some space
        currentY += 8
        
        // Patient name - left aligned
        if let patient = medication.patient {
            let lastName = patient.lastName ?? "Unknown"
            let firstName = patient.firstName ?? "Patient"
            let patientName = "Patient: \(firstName) \(lastName)"
            
            currentY += drawText(
                patientName,
                font: UIFont.boldSystemFont(ofSize: 10),
                color: UIColor.black,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 14),
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
                font: UIFont.systemFont(ofSize: 6),
                color: UIColor.black,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
                context: context
            )
        }
        
        // Prescription date
        if let dispenseDate = overrideDispenseDate ?? medication.dispenceDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let dateText = "Date: \(formatter.string(from: dispenseDate))"
            
            currentY += drawText(
                dateText,
                font: UIFont.systemFont(ofSize: 6),
                color: UIColor.black,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
                context: context
            )
        }
        
        // Add space before medication info
        currentY += 6
        
        // Medication name and strength - prominent
        let medicationName = medication.baseMedication?.name ?? "Unknown Medication"
        let dose = medication.dose ?? ""
        let doseUnit = medication.doseUnit ?? ""
        let medicationTitle = "\(medicationName) \(dose)\(doseUnit)"
        
        currentY += drawText(
            medicationTitle,
            font: UIFont.boldSystemFont(ofSize: 12),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 16),
            context: context
        )
        
        // Generic name or secondary ingredient (if different)
        if let ingredient1 = medication.baseMedication?.ingredient1,
           !ingredient1.isEmpty,
           ingredient1.lowercased() != medicationName.lowercased() {
            let genericText = "Generic: \(ingredient1)"
            currentY += drawText(
                genericText,
                font: UIFont.italicSystemFont(ofSize: 9),
                color: UIColor.darkGray,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
                context: context
            )
        }
        
        // Quantity dispensed
        let dispenseAmt = medication.dispenceAmt > 0 ? Int(medication.dispenceAmt) : 1
        let dispenseUnit = medication.dispenceUnit ?? "tablets"
        let quantityText = "Qty: \(dispenseAmt) \(dispenseUnit)"
        
        currentY += drawText(
            quantityText,
            font: UIFont.boldSystemFont(ofSize: 10),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 14),
            context: context
        )
        
        //Sig
        let sig = medication.sig ?? "Take as directed."
        let additionalSig = medication.additionalSg.flatMap { $0.isEmpty ? nil : " \($0)" } ?? ""
        let dosingInstructions = sig + additionalSig
        currentY += drawText(
            dosingInstructions,
            font: UIFont.boldSystemFont(ofSize: 10),
            color: UIColor.black,
            rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 14),
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
                font: UIFont.systemFont(ofSize: 9),
                color: UIColor.black,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
                context: context
            )
        }
        
        // Pharmacy information (if available)
        if let pharmacy = medication.baseMedication?.pharmacy {
            currentY += drawText(
                "Pharmacy: \(pharmacy)",
                font: UIFont.systemFont(ofSize: 8),
                color: UIColor.black,
                rect: CGRect(x: contentRect.minX, y: currentY, width: contentRect.width, height: 12),
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
            let bottomWidth: CGFloat = 130
            drawText(
                bottomText,
                font: UIFont.systemFont(ofSize: 7),
                color: UIColor.darkGray,
                rect: CGRect(x: contentRect.maxX - bottomWidth, y: contentRect.maxY - 12, width: bottomWidth, height: 10),
                context: context,
                alignment: .right
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
        
        return boundingRect.height + 2 // Add some spacing
    }
}
