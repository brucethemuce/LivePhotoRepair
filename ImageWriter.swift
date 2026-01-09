import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageWriter {

    /// Write an image as a Live Photo-compatible HEIC
    /// - Parameters:
    ///   - src: URL of the source image (JPEG, PNG, or HEIC)
    ///   - dst: Destination URL (including filename)
    ///   - assetID: Live Photo asset ID
    func write(src: URL, dst: URL, assetID: String) throws {
        let ext = src.pathExtension.lowercased()
        let fm = FileManager.default

        if ext == "jpg" || ext == "jpeg" {
            // JPEG → HEIC
            try convertToAppleHEIC(input: src, output: dst)
        } else if ext == "heic" {
            // HEIC → HEIC (copy before metadata injection)
            if fm.fileExists(atPath: dst.path) {
                try fm.removeItem(at: dst)
            }
            try fm.copyItem(at: src, to: dst)
        } else {
            throw NSError(
                domain: "ImageWrite",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported image type: \(ext)"]
            )
        }

        try injectLivePhotoMetadata(src: dst, assetID: assetID)
    }


    /// Uses libheif heif-enc CLI to convert jpeg to Apple HEVC HEIC
    private func convertToAppleHEIC(input: URL, output: URL) throws {
        let heifEncPath = "/usr/local/bin/heif-enc" // adjust if installed elsewhere
        let process = Process()
        process.executableURL = URL(fileURLWithPath: heifEncPath)
        process.arguments = [input.path, "-o", output.path, "-q", "90"] // quality 90 is a good balance, 100 is too big. icloud will compress anyway

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let outputStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "HEICConvert", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "heif-enc failed: \(outputStr)"])
        }
    }

    /// Injects Live Photo asset ID into HEIC using CGImageDestination
    private func injectLivePhotoMetadata(src: URL, assetID: String) throws {
        let data = try Data(contentsOf: src)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else {
            throw NSError(domain: "ImageWrite", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to read image \(src.path)"])
        }

        let meta = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        var makerApple = meta[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any] ?? [:]
        makerApple["17" as CFString] = assetID

        var newMeta = meta
        newMeta[kCGImagePropertyMakerAppleDictionary] = makerApple

        let dest = CGImageDestinationCreateWithURL(src as CFURL, type, 1, nil)!
        CGImageDestinationAddImageFromSource(dest, source, 0, newMeta as CFDictionary)

        if !CGImageDestinationFinalize(dest) {
            throw NSError(domain: "ImageWrite", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image \(src.path)"])
        }
    }
}
