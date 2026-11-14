import SwiftUI
import UIKit
import Vision
import VisionKit

// MARK: - Живой сканер штрихкодов (VisionKit, iPhone XS и новее)

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    @MainActor static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> ScannerHost {
        let host = ScannerHost()
        host.onCode = onCode
        return host
    }

    func updateUIViewController(_ host: ScannerHost, context: Context) {
        host.onCode = onCode
    }

    static func dismantleUIViewController(_ host: ScannerHost, coordinator: ()) {
        host.stop()
    }
}

final class ScannerHost: UIViewController, DataScannerViewControllerDelegate {
    var onCode: ((String) -> Void)?
    private var scanner: DataScannerViewController?
    private var last = ""
    private var lastAt = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .itf14])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = self
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
        scanner = vc
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let s = scanner, !s.isScanning { try? s.startScanning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stop()
    }

    func stop() {
        if let s = scanner, s.isScanning { s.stopScanning() }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        handle(addedItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        last = ""
        handle([item])
    }

    private func handle(_ items: [RecognizedItem]) {
        for item in items {
            guard case .barcode(let b) = item, let v = b.payloadStringValue else { continue }
            let digits = v.filter { $0.isNumber }
            guard digits.count >= 8 else { continue }
            if digits == last && Date().timeIntervalSince(lastAt) < 4 { continue }
            last = digits
            lastAt = Date()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCode?(digits)
        }
    }
}

// MARK: - Камера для одного снимка

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) } else { parent.onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Разбор фото на телефоне: штрихкоды, предметы, текст

struct PhotoFindings {
    var barcodes: [String] = []
    var labels: [(String, Float)] = []
    var text = ""
}

enum PhotoAnalyzer {
    static func analyze(_ image: UIImage, readText: Bool) async -> PhotoFindings {
        await Task.detached(priority: .userInitiated) { run(image, readText: readText) }.value
    }

    private static func run(_ image: UIImage, readText: Bool) -> PhotoFindings {
        guard let cg = image.cgImage else { return PhotoFindings() }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:])
        let barcodes = VNDetectBarcodesRequest()
        let classify = VNClassifyImageRequest()
        let ocr = VNRecognizeTextRequest()
        ocr.recognitionLevel = .accurate
        ocr.recognitionLanguages = ["en-US", "ru-RU"]
        ocr.usesLanguageCorrection = false
        var requests: [VNRequest] = [barcodes, classify]
        if readText { requests.append(ocr) }
        try? handler.perform(requests)

        var out = PhotoFindings()
        var seen = Set<String>()
        for b in barcodes.results ?? [] {
            guard let v = b.payloadStringValue else { continue }
            let d = v.filter { $0.isNumber }
            if d.count >= 8 && d.count <= 14 && seen.insert(d).inserted { out.barcodes.append(d) }
        }
        out.labels = (classify.results ?? []).filter { $0.confidence > 0.3 }.map { ($0.identifier, $0.confidence) }
        if readText {
            out.text = (ocr.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
        return out
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
