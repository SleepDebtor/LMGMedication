//
//  MedicationPrintManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import Foundation
import PDFKit
import CoreGraphics
import UIKit

@MainActor
class MedicationPrintManager {
    static let shared = MedicationPrintManager()
    
    private init() {}
    
    /// Print a single medication label
    func printLabel(for medication: DispencedMedication) async {
        // Update nextDoseDue based on medication type and dispensed amount when printing
        medication.updateNextDoseDueOnPrint()
        
        let pdfData: Data?
        
        // Use different PDF generators based on whether medication is injectable
        if medication.baseMedication?.injectable == true {
            pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication)
        } else {
            pdfData = await NonInjectableLabelPDFGenerator.generatePDF(for: medication)
        }
        
        guard let finalPdfData = pdfData else {
            print("Failed to generate PDF for medication: \(medication.displayName)")
            return
        }
        
        await presentPrintInterface(
            with: finalPdfData,
            jobName: "Medication Label - \(medication.displayName)"
        )
    }
    
    /// Print multiple medication labels
    func printLabels(for medications: [DispencedMedication]) async {
        guard !medications.isEmpty else { return }
        
        if medications.count == 1 {
            await printLabel(for: medications[0])
            return
        }
        
        // Generate combined PDF for multiple labels
        guard let combinedPDF = await generateCombinedPDF(for: medications) else {
            print("Failed to generate combined PDF for medications")
            return
        }
        
        let jobName = medications.count == 1 
            ? "Medication Label - \(medications[0].displayName)"
            : "Medication Labels - \(medications.count) labels"
        
        await presentPrintInterface(
            with: combinedPDF,
            jobName: jobName
        )
    }
    
    /// Generate a PDF containing multiple medication labels
    private func generateCombinedPDF(for medications: [DispencedMedication]) async -> Data? {
        // Update nextDoseDue for all medications before generating combined PDF
        for med in medications {
            med.updateNextDoseDueOnPrint()
        }

        return await withCheckedContinuation { continuation in
            Task {
                // Check if we have mixed types of medications (injectable and non-injectable)
                let injectableMeds = medications.filter { $0.baseMedication?.injectable == true }
                let nonInjectableMeds = medications.filter { $0.baseMedication?.injectable != true }
                
                // For now, if we have mixed types, we'll create separate pages for each type
                // You could modify this to handle them differently if needed
                
                let renderer = UIGraphicsPDFRenderer(bounds: CGRect.zero, format: {
                    let format = UIGraphicsPDFRendererFormat()
                    format.documentInfo = [
                        kCGPDFContextTitle as String: "Medication Labels",
                        kCGPDFContextAuthor as String: "Lazar Medical Group",
                        kCGPDFContextSubject as String: "Prescription Labels"
                    ]
                    return format
                }())
                
                let data = renderer.pdfData { context in
                    // Draw injectable medication labels first
                    for medication in injectableMeds {
                        let pageRect = CGRect(x: 0, y: 0, width: 400, height: 200)
                        context.beginPage(withBounds: pageRect, pageInfo: [:])
                        MedicationLabelPDFGenerator.drawMedicationLabel(
                            in: pageRect,
                            for: medication,
                            context: context.cgContext
                        )
                    }
                    
                    // Draw non-injectable medication labels
                    for medication in nonInjectableMeds {
                        let pageRect = CGRect(x: 0, y: 0, width: 216, height: 144)
                        context.beginPage(withBounds: pageRect, pageInfo: [:])
                        NonInjectableLabelPDFGenerator.drawNonInjectableLabel(
                            in: pageRect,
                            for: medication,
                            context: context.cgContext
                        )
                    }
                }
                continuation.resume(returning: data)
            }
        }
    }
    
    /// Present the iOS print interface
    private func presentPrintInterface(with pdfData: Data, jobName: String) async {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()

        printInfo.outputType = .general
        printInfo.jobName = jobName
        printInfo.duplex = .none

        printController.printInfo = printInfo
        printController.printingItem = pdfData

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("Could not find root view controller for printing")
            return
        }

        printController.present(animated: true) { (controller, completed, error) in
            if let error = error {
                print("Printing error: \(error.localizedDescription)")
            } else if completed {
                print("Print job completed successfully")
            } else {
                print("Print job was cancelled")
            }
        }
    }
    
    /// Share medication label as PDF
    func sharePDF(for medication: DispencedMedication) async {
        let pdfData: Data?
        
        // Use different PDF generators based on whether medication is injectable
        if medication.baseMedication?.injectable == true {
            pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication)
        } else {
            pdfData = await NonInjectableLabelPDFGenerator.generatePDF(for: medication)
        }
        
        guard let finalPdfData = pdfData else {
            print("Failed to generate PDF for sharing")
            return
        }

        let fileName = "Medication_Label_\(medication.displayName.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try finalPdfData.write(to: tempURL)
            let activityController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("Could not find root view controller for sharing")
                return
            }
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        } catch {
            print("Failed to save PDF for sharing: \(error.localizedDescription)")
        }
    }
    
    /// Share multiple medication labels as a single PDF
    func shareCombinedPDF(for medications: [DispencedMedication]) async {
        guard !medications.isEmpty else { return }
        if medications.count == 1 {
            await sharePDF(for: medications[0])
            return
        }

        guard let combinedPDF = await generateCombinedPDF(for: medications) else {
            print("Failed to generate combined PDF for sharing")
            return
        }

        let fileName = "Medication_Labels_\(medications.count)_labels_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try combinedPDF.write(to: tempURL)
            let activityController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("Could not find root view controller for sharing")
                return
            }
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityController, animated: true)
        } catch {
            print("Failed to save combined PDF for sharing: \(error.localizedDescription)")
        }
    }
}

