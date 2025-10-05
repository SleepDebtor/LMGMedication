//
//  QRCodeTestView.swift
//  LMGMedication
//
//  Created by Michael Lazar on 10/5/25.
//

import SwiftUI

struct QRCodeTestView: View {
    @State private var urlText = "https://hushmedicalspa.com/medications"
    @State private var qrImage: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("QR Code Generator Test")
                .font(.title)
                .fontWeight(.bold)
            
            TextField("Enter URL", text: $urlText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: urlText) { _, newValue in
                    generateQRCode()
                }
            
            if let qrImage = qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .border(Color.gray, width: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "qrcode")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("QR Code will appear here")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            Button("Generate QR Code") {
                generateQRCode()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .onAppear {
            generateQRCode()
        }
    }
    
    private func generateQRCode() {
        let formattedURL = QRCodeGenerator.formatURL(urlText)
        qrImage = QRCodeGenerator.generateQRCode(from: formattedURL, size: CGSize(width: 200, height: 200))
    }
}

#Preview {
    QRCodeTestView()
}