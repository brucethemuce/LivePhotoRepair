import Foundation
import AVFoundation

final class AssetScanner {

    /// Scan a folder recursively and return all image/video assets
    func scan(folder: URL) -> [AssetFile] {
        var assets: [AssetFile] = []
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .typeIdentifierKey]

        let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )!

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isDirectory != true
            else { continue }

            let typeIdentifier = values.typeIdentifier ?? ""
            let ext = url.pathExtension.lowercased()

            // ---------------- Images ----------------
            if typeIdentifier.hasPrefix("public.image") || ["jpg", "jpeg", "heic"].contains(ext) {
                let date = Self.runExifTool(
                    url: url,
                    printFormat: "$CreateDate"
                )

                assets.append(
                    AssetFile(
                        url: url,
                        type: .image,
                        duration: nil,
                        exifCreateDate: date,
                        quickTimeCreationDate: nil
                    )
                )
                continue
            }

            // ---------------- Videos ----------------
            if typeIdentifier.hasPrefix("public.movie") || ["mov", "mp4"].contains(ext) {
                let asset = AVURLAsset(url: url)
                let duration = asset.duration.isNumeric ? asset.duration.seconds : nil

                let date = Self.runExifTool(
                    url: url,
                    printFormat: "$CreationDate"
                )

                assets.append(
                    AssetFile(
                        url: url,
                        type: .video,
                        duration: duration,
                        exifCreateDate: nil,
                        quickTimeCreationDate: date
                    )
                )
            }
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
}

