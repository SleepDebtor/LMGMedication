//
//  MedicationLabelPreviewView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import SwiftUI
import PDFKit
import CoreData

struct MedicationLabelPreviewView: View {
    let medication: DispencedMedication
    @State private var pdfDocument: PDFDocument?
    @State private var isGenerating = false
    @State private var generationError: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generating PDF...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pdfDocument = pdfDocument {
                    PDFKitView(document: pdfDocument)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = generationError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to generate PDF")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            generatePDF()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No PDF available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Label Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLabelButton(medication: medication)
                }
            }
        }
        .onAppear {
            generatePDF()
        }
    }
    
    private func generatePDF() {
        isGenerating = true
        generationError = nil
        
        Task {
            if let pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication) {
                let document = PDFDocument(data: pdfData)
                await MainActor.run {
                    pdfDocument = document
                    isGenerating = false
                }
            } else {
                await MainActor.run {
                    generationError = "Failed to generate PDF"
                    isGenerating = false
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let medication = DispencedMedication(context: context)
    
    return MedicationLabelPreviewView(medication: medication)
}
