//
//  LabelPreviewView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/12/25.
//

import SwiftUI
import PDFKit

struct LabelPreviewView: View {
    let medication: DispencedMedication
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Generating Preview...")
                    .padding()
            } else if let document = pdfDocument {
                PDFKitView(document: document, showActualSize: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else {
                Text("Failed to generate preview")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Label Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreview()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Print") {
                    Task {
                        await MedicationPrintManager.shared.printLabel(for: medication)
                    }
                }
            }
        }
    }
    
    private func loadPreview() async {
        isLoading = true
        defer { isLoading = false }
        
        let pdfData: Data?
        
        // Use appropriate generator based on medication type
        if medication.baseMedication?.injectable == true {
            pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication)
        } else {
            pdfData = await NonInjectableLabelPDFGenerator.generatePDF(for: medication)
        }
        
        if let data = pdfData {
            await MainActor.run {
                self.pdfDocument = PDFDocument(data: data)
            }
        }
    }
}

#Preview {
    NavigationView {
        // This preview won't work without a real medication object,
        // but it shows the structure
        Text("Label Preview")
    }
}