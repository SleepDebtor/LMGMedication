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
    @State private var showActualSize = false
    
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
                    VStack(spacing: 0) {
                        // Size information
                        HStack {
                            let isInjectable = medication.baseMedication?.injectable == true
                            Text("Label Size: \(isInjectable ? "400×200" : "216×144") points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(showActualSize ? "Fit to Screen" : "Actual Size") {
                                showActualSize.toggle()
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGroupedBackground))
                        
                        // PDF Preview
                        ScrollView([.horizontal, .vertical]) {
                            let isInjectable = medication.baseMedication?.injectable == true
                            let aspectRatio = isInjectable ? 2.0 : (216.0/144.0) // Injectable is 2:1, Non-injectable is 3:2
                            let width = isInjectable ? 400.0 : 216.0
                            let height = isInjectable ? 200.0 : 144.0
                            
                            PDFKitView(document: pdfDocument, showActualSize: showActualSize)
                                .frame(
                                    width: showActualSize ? width : nil,
                                    height: showActualSize ? height : nil
                                )
                                .aspectRatio(aspectRatio, contentMode: showActualSize ? .fill : .fit)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Regenerate") {
                        generatePDF()
                    }
                    .disabled(isGenerating)
                }
                
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
            let pdfData: Data?
            
            // Use appropriate generator based on medication type
            if medication.baseMedication?.injectable == true {
                pdfData = await MedicationLabelPDFGenerator.generatePDF(for: medication)
            } else {
                pdfData = await NonInjectableLabelPDFGenerator.generatePDF(for: medication)
            }
            
            if let data = pdfData {
                let document = PDFDocument(data: data)
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
    let showActualSize: Bool
    
    init(document: PDFDocument, showActualSize: Bool = false) {
        self.document = document
        self.showActualSize = showActualSize
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        
        // Configure for better label preview
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        
        if showActualSize {
            // Show at actual size (72 DPI = 1 point per pixel)
            pdfView.autoScales = false
            pdfView.scaleFactor = 1.0
        } else {
            // Fit to view
            pdfView.autoScales = true
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
        
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 5.0
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        
        if showActualSize {
            uiView.autoScales = false
            uiView.scaleFactor = 1.0
        } else {
            uiView.autoScales = true
            uiView.scaleFactor = uiView.scaleFactorForSizeToFit
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let medication = DispencedMedication(context: context)
    
    return MedicationLabelPreviewView(medication: medication)
}
