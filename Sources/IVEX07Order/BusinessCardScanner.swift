import SwiftUI
import VisionKit

/// Apple's document camera detects the card edges, corrects perspective,
/// rotates the image and improves contrast before returning a JPEG.
struct BusinessCardScanner: UIViewControllerRepresentable {
    let onScan: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onDismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScan: (Data) -> Void
        private let onDismiss: () -> Void

        init(onScan: @escaping (Data) -> Void, onDismiss: @escaping () -> Void) {
            self.onScan = onScan
            self.onDismiss = onDismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0,
                  let data = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.90) else {
                onDismiss()
                return
            }
            onScan(data)
            onDismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onDismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onDismiss()
        }
    }
}
