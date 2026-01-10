import Foundation
import AVFoundation

final class AssetScanner {

    /// Max number of files per ExifTool invocation
    private static let exifToolBatchSize = 500 //slightly faster than 250

    /// Scan a folder recursively and return all image/video assets
    func scan(folder: URL) -> [AssetFile] {
        var assets: [AssetFile] = []
        let fileManager = FileManager.default

        var imageURLs: [URL] = []
        var videoURLs: [URL] = []

        let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .typeIdentifierKey],
            options: [.skipsHiddenFiles]
        )!

        for case let url as URL in enumerator {
            guard
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .typeIdentifierKey]),
                values.isDirectory != true
            else { continue }

            let ext = url.pathExtension.lowercased()
            let type = values.typeIdentifier ?? ""

            if type.hasPrefix("public.image") || ["jpg", "jpeg", "heic"].contains(ext) {
                imageURLs.append(url)
            } else if type.hasPrefix("public.movie") || ["mov", "mp4"].contains(ext) {
                videoURLs.append(url)
            }
        }

        // ---- Batch metadata extraction (FAST) ----

        let imageDates = Self.runExifToolBatch(
            urls: imageURLs,
            printFormat: "$FileName|$CreateDate"
        )

        let videoDates = Self.runExifToolBatch(
            urls: videoURLs,
            printFormat: "$FileName|$CreationDate"
        )

        // ---- Build AssetFile objects ----

        for url in imageURLs {
            assets.append(
                AssetFile(
                    url: url,
                    type: .image,
                    duration: nil,
                    exifCreateDate: imageDates[url.lastPathComponent],
                    quickTimeCreationDate: nil
                )
            )
        }

        for url in videoURLs {
            let asset = AVURLAsset(url: url)
            let duration = asset.duration.isNumeric ? asset.duration.seconds : nil //slow but need to check all the videos

            assets.append(
                AssetFile(
                    url: url,
                    type: .video,
                    duration: duration,
                    exifCreateDate: nil,
                    quickTimeCreationDate: videoDates[url.lastPathComponent]
                )
            )
        }

        return assets
    }

    // MARK: - ExifTool batching, much faster than per file or doing all at once.

    private static func runExifToolBatch(
        urls: [URL],
        printFormat: String
    ) -> [String: Date] {

        guard !urls.isEmpty else { return [:] }

        var results: [String: Date] = [:]

        for chunk in urls.chunked(into: exifToolBatchSize) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "exiftool",
                "-m",
                "-p",
                printFormat
            ] + chunk.map { $0.path }

            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("ExifTool batch failed: \(error)")
                continue
            }

            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { continue }

            for line in output.split(separator: "\n") {
                let parts = line.split(separator: "|", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let filename = String(parts[0])
                let dateString = String(parts[1])

                if let date = parseExifToolDate(dateString) {
                    results[filename] = date
                }
            }
        }

        return results
    }

    // MARK: - Date normalization (formatter reuse)

    private static let exifDateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy:MM:dd HH:mm:ss.SSSZ",
            "yyyy:MM:dd HH:mm:ssZ",
            "yyyy:MM:dd HH:mm:ss.SSS",
            "yyyy:MM:dd HH:mm:ss"
        ]

        return formats.map {
            let formatter = DateFormatter()
            formatter.dateFormat = $0
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    private static func parseExifToolDate(_ string: String) -> Date? {
        for formatter in exifDateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
