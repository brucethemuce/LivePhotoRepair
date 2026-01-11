import Foundation
import AVFoundation

final class PairMatcher {

    /// Maximum allowed numeric difference for sequential filenames
    /// 1 is ideal (IMG_0019 ↔ IMG_0020)
    var maxNumericDelta: Int = 1

    /// Maximum video duration (seconds)
    var maxVideoDuration = 4.0 // limit is 3s, but in practice sometimes (~5%) its a bit more, 3.1s or 3.2s
    
    /// Maximum date interval between video and photo assets (seconds)
    var TimeInterval = 4 // idea being that the still might be first during or last, so match the video duration

    /// Matches images and videos into Live Photo pairs
    func match(
        images: [AssetFile],
        videos: [AssetFile],
        dryRun: Bool = false
    ) -> [AssetPair] {

        var pairs: [AssetPair] = []

        // Use precomputed durations from AssetScanner
        var videoDurations: [URL: TimeInterval] = [:]
        for video in videos {
            videoDurations[video.url] = video.duration ?? 0
        }

        // Prepare file URL for P2 matches
        let p2FileURL = URL(fileURLWithPath: "P2matches.txt")
        try? "".write(to: p2FileURL, atomically: true, encoding: .utf8)

        // Open file handle once
        guard let p2FileHandle = try? FileHandle(forWritingTo: p2FileURL) else {
            print("Failed to open P2matches.txt for writing.")
            return pairs
        }
        defer { p2FileHandle.closeFile() }

        let p3FileURL = URL(fileURLWithPath: "P3matches.txt")
        try? "".write(to: p3FileURL, atomically: true, encoding: .utf8)
        guard let p3FileHandle = try? FileHandle(forWritingTo: p3FileURL) else { 
            print("Failed to open P3matches.txt for writing.")
            return pairs }
        defer { p3FileHandle.closeFile() }

        // Group assets by folder
        let folders = Dictionary(
            grouping: images + videos,
            by: { $0.url.deletingLastPathComponent().standardizedFileURL }
        )

        for (_, assetsInFolder) in folders {
            let folderImages = assetsInFolder.filter { $0.type == .image }
            let folderVideos = assetsInFolder.filter { $0.type == .video }
            var usedVideos = Set<URL>()
            var usedImages = Set<URL>()

            // =====================================================
            // PASS 1: P1 + P2
            // =====================================================
            for image in folderImages where !usedImages.contains(image.url) {
                let imageBase = image.url.deletingPathExtension().lastPathComponent
                let imageFolder = image.url.deletingLastPathComponent().standardizedFileURL
                let imageFullName = image.url.lastPathComponent

                // -----------------------
                // P1: exact basename match
                // -----------------------
                var matched = false
                for video in folderVideos where !usedVideos.contains(video.url) {
                    let videoBase = video.url.deletingPathExtension().lastPathComponent
                    let videoFolder = video.url.deletingLastPathComponent().standardizedFileURL
                    let videoFullName = video.url.lastPathComponent

                    guard imageFolder == videoFolder else { continue }
                    guard imageBase == videoBase else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    pairs.append(AssetPair(image: image, video: video, priority: 1))
                    usedVideos.insert(video.url)
                    usedImages.insert(image.url)
                    matched = true

                    if dryRun {
                        print("DRY-RUN [P1]: \(imageFullName) ↔ \(videoFullName)")
                    }
                    break
                }

                if matched { continue }

                // -----------------------
                // P2: sequential numeric filename match
                // -----------------------
                guard let (imagePrefix, imageNum) = parseNumericSuffix(imageBase) else { continue }

                for video in folderVideos where !usedVideos.contains(video.url) {
                    let videoBase = video.url.deletingPathExtension().lastPathComponent
                    let videoFolder = video.url.deletingLastPathComponent().standardizedFileURL
                    let videoFullName = video.url.lastPathComponent

                    guard imageFolder == videoFolder else { continue }
                    guard let (videoPrefix, videoNum) = parseNumericSuffix(videoBase) else { continue }
                    guard imagePrefix == videoPrefix else { continue }

                    let delta = abs(imageNum - videoNum)
                    guard delta > 0 && delta <= maxNumericDelta else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    pairs.append(AssetPair(image: image, video: video, priority: 2))
                    usedVideos.insert(video.url)
                    usedImages.insert(image.url)

                    let matchLine = "\(imageFullName) \(videoFullName)\n"
                    if let data = matchLine.data(using: .utf8) {
                        p2FileHandle.seekToEndOfFile()
                        p2FileHandle.write(data)
                    }

                    if dryRun {
                        print("DRY-RUN [P2]: \(imageFullName) ↔ \(videoFullName)")
                    }
                    break
                }
            }

            // =====================================================
            // PASS 2: P3 (date-based, after P1+P2 exhausted)
            // =====================================================
            for image in folderImages where !usedImages.contains(image.url) {
                let imageFolder = image.url.deletingLastPathComponent().standardizedFileURL
                let imageFullName = image.url.lastPathComponent

                for video in folderVideos where !usedVideos.contains(video.url) {
                    let videoFolder = video.url.deletingLastPathComponent().standardizedFileURL
                    let videoFullName = video.url.lastPathComponent

                    guard imageFolder == videoFolder else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    if let imageDate = image.exifCreateDate,
                    let videoDate = video.quickTimeCreationDate {

                        let deltaSeconds = abs(imageDate.timeIntervalSince(videoDate))
                        guard deltaSeconds <= 4 else { continue }

                        pairs.append(AssetPair(image: image, video: video, priority: 3))
                        usedVideos.insert(video.url)
                        usedImages.insert(image.url)

                        let matchLine = "\(imageFullName) \(videoFullName)\n"
                        if let data = matchLine.data(using: .utf8) {
                            p3FileHandle.seekToEndOfFile()
                            p3FileHandle.write(data)
                        }

                        if dryRun {
                            print("DRY-RUN [P3]: \(imageFullName) ↔ \(videoFullName)")
                        }
                        break
                    }
                }
            }
        }

        return pairs
    }


    // MARK: - Helpers

    /// Parses a filename into a (prefix, number) pair
    /// Example: IMG_0019 -> ("IMG_", 19)
    private func parseNumericSuffix(_ name: String) -> (prefix: String, number: Int)? {
        let digits = name.reversed().prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        let numberStr = String(digits.reversed())
        guard let number = Int(numberStr) else { return nil }

        let prefix = String(name.dropLast(numberStr.count))
        return (prefix, number)
    }
}
