//
//  MedicationPrintManager.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import Foundation
import PDFKit
import CoreGraphics
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

@MainActor
class MedicationPrintManager {
    static let shared = MedicationPrintManager()
    
    private init() {}
    
    /// Print a single medication label
    func printLabel(for medication: DispencedMedication) async {
        guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
            print("Failed to generate PDF for medication: \(medication.displayName)")
            return
        }
        
        await presentPrintInterface(
            with: pdfData,
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
        return await withCheckedContinuation { continuation in
            Task {
                // Create a PDF renderer for multiple pages - 2x1 inch labels at 200 DPI
                let pageRect = CGRect(x: 0, y: 0, width: 400, height: 200) // Same size as MedicationLabelPDFGenerator
                #if os(iOS)
                let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                let data = renderer.pdfData { context in
                    for medication in medications {
                        context.beginPage()
                        // Draw each medication label on its own page using the existing generator's method
                        MedicationLabelPDFGenerator.drawMedicationLabel(
                            in: pageRect,
                            for: medication,
                            context: context.cgContext
                        )
                    }
                }
                continuation.resume(returning: data)
                #elseif os(macOS)
                let mutableData = NSMutableData()
                var mediaBox = pageRect
                if let consumer = CGDataConsumer(data: mutableData as CFMutableData),
                   let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
                    for medication in medications {
                        cgContext.beginPDFPage(nil)
                        // Draw each medication label on its own page using the existing generator's method
                        MedicationLabelPDFGenerator.drawMedicationLabel(
                            in: pageRect,
                            for: medication,
                            context: cgContext
                        )
                        cgContext.endPDFPage()
                    }
                    cgContext.closePDF()
                    continuation.resume(returning: mutableData as Data)
                } else {
                    continuation.resume(returning: nil)
                }
                #else
                continuation.resume(returning: nil)
                #endif
            }
        }
    }
    
    /// Present the iOS print interface
    private func presentPrintInterface(with pdfData: Data, jobName: String) async {
        #if os(iOS)
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
        #elseif os(macOS)
        guard let document = PDFDocument(data: pdfData) else {
            print("Failed to create PDFDocument for printing")
            return
        }
        let pdfView = PDFView(frame: .zero)
        pdfView.document = document
        let printInfo = NSPrintInfo()
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true
        let operation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        operation.jobTitle = jobName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
        #endif
    }
    
    /// Share medication label as PDF
    func sharePDF(for medication: DispencedMedication) async {
        #if os(iOS)
        guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
            print("Failed to generate PDF for sharing")
            return
        }

        let fileName = "Medication_Label_\(medication.displayName.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: tempURL)
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
        #elseif os(macOS)
        guard let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) else {
            print("Failed to generate PDF for sharing")
            return
        }
        let fileName = "Medication_Label_\(medication.displayName.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
        } catch {
            print("Failed to save or open PDF for sharing: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Share multiple medication labels as a single PDF
    func shareCombinedPDF(for medications: [DispencedMedication]) async {
        guard !medications.isEmpty else { return }
        #if os(iOS)
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
        #elseif os(macOS)
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
            NSWorkspace.shared.open(tempURL)
        } catch {
            print("Failed to save or open combined PDF for sharing: \(error.localizedDescription)")
        }
        #endif
    }
}

