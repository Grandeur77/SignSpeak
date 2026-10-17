import SwiftUI
import AVFoundation

/// A SwiftUI representation of an AVCaptureVideoPreviewLayer for real-time camera rendering.
public struct CameraPreviewView: UIViewRepresentable {
    private let session: AVCaptureSession?
    private let isMirrored: Bool
    private let videoGravity: AVLayerVideoGravity

    public init(
        session: AVCaptureSession?,
        isMirrored: Bool = true,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill
    ) {
        self.session = session
        self.isMirrored = isMirrored
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = videoGravity
        updateMirroring(for: view.previewLayer)
        return view
    }

    public func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.previewLayer.videoGravity = videoGravity
        updateMirroring(for: uiView.previewLayer)
    }

    private func updateMirroring(for layer: AVCaptureVideoPreviewLayer) {
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    /// UIKit container view backed directly by AVCaptureVideoPreviewLayer for seamless frame autolayout.
    public final class PreviewContainerView: UIView {
        override public class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        public var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override public init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            isAccessibilityElement = true
            accessibilityLabel = "Live Camera Preview"
            accessibilityTraits = .image
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .black
        }
    }
}
