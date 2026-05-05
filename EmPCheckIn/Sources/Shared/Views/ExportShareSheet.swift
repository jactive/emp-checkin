import SwiftUI
import UIKit

struct ExportShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
