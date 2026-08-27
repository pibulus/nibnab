import Cocoa
@preconcurrency import Vision
import UniformTypeIdentifiers

enum VisionOCR {
    /// Recognizes text from an NSImage using Apple's Vision framework.
    /// Runs locally on the Neural Engine / GPU with zero network dependencies.
    static func recognizeText(from image: NSImage) async -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmapImage.cgImage else {
            return ""
        }
        return await recognizeText(from: cgImage)
    }

    /// Recognizes text from raw image data (PNG, JPEG, TIFF, HEIC, etc.).
    static func recognizeText(from data: Data) async -> String {
        guard let image = NSImage(data: data) else { return "" }
        return await recognizeText(from: image)
    }

    /// Performs the Vision text recognition request on a CGImage.
    static func recognizeText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: "")
                        return
                    }

                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }

                    let joined = recognizedStrings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: joined)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                if #available(macOS 13.0, *) {
                    request.automaticallyDetectsLanguage = true
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
