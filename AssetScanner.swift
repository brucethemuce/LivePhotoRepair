import Foundation
import AVFoundation

final class AssetScanner {

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

        // ---- Batch metadata extraction ----

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
            let duration = asset.duration.isNumeric ? asset.duration.seconds : nil

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


    // MARK: - ExifTool stuff

    private static func runExifTool(url: URL, printFormat: String) -> Date? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "exiftool",
            "-m",
            "-p",
            printFormat,
            url.path
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr // equivalent to 2>/dev/null

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("ExifTool failed: \(error)")
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty
        else {
            return nil
        }

        return parseExifToolDate(output)
    }

    // MARK: - Date normalization

    private static func parseExifToolDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current

        let formats = [
            "yyyy:MM:dd HH:mm:ss.SSSZ",
            "yyyy:MM:dd HH:mm:ssZ",
            "yyyy:MM:dd HH:mm:ss.SSS",
            "yyyy:MM:dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        print("Failed to parse ExifTool date: \(string)")
        return nil
    }

    private static func runExifToolBatch(
        urls: [URL],
        printFormat: String
    ) -> [String: Date] {

        guard !urls.isEmpty else { return [:] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "exiftool",
            "-m",
            "-p",
            printFormat
        ] + urls.map { $0.path }

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("ExifTool batch failed: \(error)")
            return [:]
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var results: [String: Date] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let filename = String(parts[0])
            let dateString = String(parts[1])

            if let date = parseExifToolDate(dateString) {
                results[filename] = date
            }
        }

        return results
    }
}

