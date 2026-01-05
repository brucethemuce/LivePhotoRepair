import Foundation

final class LivePhotoBuilder {

    func build(pair: AssetPair, outputDir: URL) throws {
        let assetID = UUID().uuidString

        // Build initial output URLs
        let imageOut = outputDir.appendingPathComponent(pair.image.baseName + "_live.heic")
        let videoOut = outputDir.appendingPathComponent(pair.image.baseName + "_live.mov")

        // Ensure unique filenames
        let uniqueImageOut = uniqueFileURL(original: imageOut)
        let uniqueVideoOut = uniqueFileURL(original: videoOut)

        // Write files
        let imageWriter = ImageWriter()
        try imageWriter.write(src: pair.image.url, dst: uniqueImageOut, assetID: assetID)
        try writeVideo(src: pair.video.url, dst: uniqueVideoOut, assetID: assetID)
    }

    // MARK: - Private helper

    /// Returns a URL that does not exist by appending a sequential number
    private func uniqueFileURL(original: URL) -> URL {
        var candidate = original
        var counter = 1
        let fileManager = FileManager.default

        while fileManager.fileExists(atPath: candidate.path) {
            let baseName = original.deletingPathExtension().lastPathComponent
            let ext = original.pathExtension
            candidate = original.deletingLastPathComponent()
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }

        return candidate
    }
}
