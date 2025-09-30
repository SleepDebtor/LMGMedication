//
//  MedicationLabelView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 9/29/25.
//

import SwiftUI
import PDFKit
import CoreData

struct MedicationLabelView: View {
    let medication: DispencedMedication
    
    @State private var showingPrintPreview = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Preview of the label
                MedicationLabelPreview(medication: medication)
                    .frame(width: 288, height: 144) // 1x2 inch at 144 DPI
                    .border(Color.gray, width: 1)
                
                VStack(spacing: 12) {
                    Button("Print Label") {
                        showingPrintPreview = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Share PDF") {
                        Task {
                            await sharePDF()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Medication Label")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPrintPreview) {
            PrintPreviewView(medication: medication)
        }
    }
    
    private func sharePDF() async {
        guard let pdfData = await generatePDFData() else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [pdfData],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func generatePDFData() async -> Data? {
        return await MedicationLabelPDFGenerator.generatePDF(for: medication)
    }
}

struct MedicationLabelPreview: View {
    let medication: DispencedMedication
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
            
            HStack(spacing: 8) {
                // QR Code placeholder (left side)
                VStack {
                    if let qrData = medication.baseMedication?.qrImage, !qrData.isEmpty {
                        if let uiImage = UIImage(data: qrData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 100, height: 100)
                        } else {
                            qrCodePlaceholder
                        }
                    } else {
                        qrCodePlaceholder
                    }
                }
                .frame(width: 100, height: 100)
                
                // Medication information (right side)
                VStack(alignment: .leading, spacing: 2) {
                    // Patient name
                    if let patient = medication.patient {
                        Text(patient.fullName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    // Medication name and dosage
                    Text(medication.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Concentration info (e.g., vitamin B6)
                    if !medication.concentrationInfo.isEmpty {
                        Text(medication.concentrationInfo)
                            .font(.system(size: 11))
                            .foregroundColor(.black)
                            .italic()
                    }
                    
                    // Dispensed quantity
                    if !medication.dispensedQuantityText.isEmpty {
                        Text("Disp: \(medication.dispensedQuantityText)")
                            .font(.system(size: 11))
                            .foregroundColor(.black)
                    }
                    
                    // Instructions placeholder (you can add this field to your model if needed)
                    if medication.baseMedication?.injectable == true {
                        Text("1 syringe sq weekly")
                            .font(.system(size: 11))
                            .foregroundColor(.black)
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Prescriber info
                    VStack(alignment: .leading, spacing: 1) {
                        if !medication.prescriberName.isEmpty {
                            Text("Prescriber: \(medication.prescriberName)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        // Practice info (hardcoded for now, could be made configurable)
                        Text("Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA")
                            .font(.system(size: 7))
                            .foregroundColor(.black)
                        
                        // Pharmacy info
                        if !medication.pharmacyInfo.isEmpty {
                            Text("\(medication.pharmacyInfo): 0.5mL (50U) fill on each syringe")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(8)
        }
        .frame(width: 288, height: 144)
    }
    
    private var qrCodePlaceholder: some View {
        Image(systemName: "qrcode")
            .font(.system(size: 80))
            .foregroundColor(.black)
    }
}

class MedicationLabelPDFGenerator {
    static func generatePDF(for medication: DispencedMedication) async -> Data? {
        return await withCheckedContinuation { continuation in
            // Create a PDF renderer with 1x2 inch size at 72 DPI (standard PDF resolution)
            let pageRect = CGRect(x: 0, y: 0, width: 72, height: 144) // 1x2 inches
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            
            let data = renderer.pdfData { context in
                context.beginPage()
                
                // Draw the label content
                drawMedicationLabel(medication: medication, in: pageRect, context: context.cgContext)
            }
            
            continuation.resume(returning: data)
        }
    }
    
    private static func drawMedicationLabel(medication: DispencedMedication, in rect: CGRect, context: CGContext) {
        // Set up drawing context
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        
        // White background
        UIColor.white.setFill()
        context.fill(rect)
        
        // Draw border
        UIColor.black.setStroke()
        context.setLineWidth(0.5)
        context.stroke(rect)
        
        let padding: CGFloat = 4
        let contentRect = rect.insetBy(dx: padding, dy: padding)
        
        // QR Code area (left side)
        let qrRect = CGRect(x: contentRect.minX, y: contentRect.minY, width: 50, height: 50)
        drawQRCode(for: medication, in: qrRect, context: context)
        
        // Text area (right side)
        let textRect = CGRect(
            x: qrRect.maxX + 4,
            y: contentRect.minY,
            width: contentRect.width - qrRect.width - 4,
            height: contentRect.height
        )
        
        drawMedicationText(medication: medication, in: textRect)
    }
    
    private static func drawQRCode(for medication: DispencedMedication, in rect: CGRect, context: CGContext) {
        // Try to use actual QR code data if available
        if let qrData = medication.baseMedication?.qrImage,
           let qrImage = UIImage(data: qrData) {
            qrImage.draw(in: rect)
        } else {
            // Draw a simple QR code pattern as placeholder
            drawQRCodePlaceholder(in: rect, context: context)
        }
    }
    
    private static func drawQRCodePlaceholder(in rect: CGRect, context: CGContext) {
        UIColor.black.setFill()
        
        let cellSize: CGFloat = 2
        let rows = Int(rect.height / cellSize)
        let cols = Int(rect.width / cellSize)
        
        // Simple pattern for QR code appearance
        for row in 0..<rows {
            for col in 0..<cols {
                if (row + col) % 3 == 0 || (row == 0 || row == rows-1 || col == 0 || col == cols-1) {
                    let cellRect = CGRect(
                        x: rect.minX + CGFloat(col) * cellSize,
                        y: rect.minY + CGFloat(row) * cellSize,
                        width: cellSize,
                        height: cellSize
                    )
                    context.fill(cellRect)
                }
            }
        }
    }
    
    private static func drawMedicationText(medication: DispencedMedication, in rect: CGRect) {
        var currentY = rect.minY
        
        // Patient name
        if let patient = medication.patient {
            let patientName = patient.fullName
            currentY += drawText(patientName, at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.boldSystemFont(ofSize: 8), maxWidth: rect.width)
        }
        
        // Medication name
        let medName = medication.displayName
        currentY += drawText(medName, at: CGPoint(x: rect.minX, y: currentY), 
                           font: UIFont.systemFont(ofSize: 7), maxWidth: rect.width)
        
        // Concentration info
        if !medication.concentrationInfo.isEmpty {
            currentY += drawText(medication.concentrationInfo, at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.italicSystemFont(ofSize: 6), maxWidth: rect.width)
        }
        
        // Dispensed quantity
        if !medication.dispensedQuantityText.isEmpty {
            currentY += drawText("Disp: \(medication.dispensedQuantityText)", at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.systemFont(ofSize: 6), maxWidth: rect.width)
        }
        
        // Instructions (placeholder)
        if medication.baseMedication?.injectable == true {
            currentY += drawText("1 syringe sq weekly", at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.systemFont(ofSize: 6), maxWidth: rect.width)
        }
        
        currentY += 8 // Add some space
        
        // Prescriber info
        if !medication.prescriberName.isEmpty {
            currentY += drawText("Prescriber: \(medication.prescriberName)", at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.boldSystemFont(ofSize: 5), maxWidth: rect.width)
        }
        
        // Practice info
        currentY += drawText("Lazar Medical Group, 400 Market St, Suite 5, Williamsport, PA", 
                           at: CGPoint(x: rect.minX, y: currentY), 
                           font: UIFont.systemFont(ofSize: 4), maxWidth: rect.width)
        
        // Pharmacy info
        if !medication.pharmacyInfo.isEmpty {
            currentY += drawText("\(medication.pharmacyInfo): 0.5mL (50U) fill on each syringe", 
                               at: CGPoint(x: rect.minX, y: currentY), 
                               font: UIFont.boldSystemFont(ofSize: 4), maxWidth: rect.width)
        }
    }
    
    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, maxWidth: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude), 
                                                   options: .usesLineFragmentOrigin, 
                                                   context: nil)
        
        attributedString.draw(at: point)
        
        return textSize.height + 2 // Add small spacing
    }
}

struct PrintPreviewView: View {
    let medication: DispencedMedication
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Print Preview")
                    .font(.title2)
                    .padding()
                
                MedicationLabelPreview(medication: medication)
                    .scaleEffect(2.0) // Scale up for better visibility
                    .padding()
                
                Spacer()
                
                Button("Print") {
                    Task {
                        await printLabel()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func printLabel() async {
        guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else { return }
        
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Medication Label - \(medication.displayName)"
        
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            printController.present(animated: true) { (controller, completed, error) in
                if completed {
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let patient = Patient(context: context)
    patient.firstName = "Brittany"
    patient.lastName = "Kratzer"
    
    let medication = Medication(context: context)
    medication.name = "Tirzepatide"
    medication.ingredient1 = "vitamin B6"
    medication.concentration1 = 25.0
    medication.pharmacy = "Beaker Pharmacy"
    medication.injectable = true
    
    let provider = Provider(context: context)
    provider.firstName = "Krista"
    provider.lastName = "Lazar"
    
    let dispensedMedication = DispencedMedication(context: context)
    dispensedMedication.dose = "10"
    dispensedMedication.doseUnit = "mg"
    dispensedMedication.dispenceAmt = 4
    dispensedMedication.dispenceUnit = "syringes"
    dispensedMedication.baseMedication = medication
    dispensedMedication.patient = patient
    dispensedMedication.prescriber = provider
    dispensedMedication.dispenceDate = Date()
    
    return NavigationView {
        MedicationLabelView(medication: dispensedMedication)
    }
    .environment(\.managedObjectContext, context)
}