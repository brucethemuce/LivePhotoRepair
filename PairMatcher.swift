import Foundation
import AVFoundation

final class PairMatcher {

    /// Maximum video duration (seconds)
    var maxVideoDuration: TimeInterval = 4.0 // its usually less than 3 but can be a bit more sometimes found a few cases that are 3.1s

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

        // Group assets by normalized parent folder
        let folders = Dictionary(
            grouping: images + videos,
            by: { $0.url.deletingLastPathComponent().standardizedFileURL }
        )

        for (_, assetsInFolder) in folders {
            let folderImages = assetsInFolder.filter { $0.type == .image }
            let folderVideos = assetsInFolder.filter { $0.type == .video }
            var usedVideos = Set<URL>()

            for image in folderImages {
                let imageName = image.url.lastPathComponent
                let imageBase = image.url.deletingPathExtension().lastPathComponent
                let imageFolder = image.url.deletingLastPathComponent().standardizedFileURL

                for video in folderVideos where !usedVideos.contains(video.url) {
                    let videoName = video.url.lastPathComponent
                    let videoBase = video.url.deletingPathExtension().lastPathComponent
                    let videoFolder = video.url.deletingLastPathComponent().standardizedFileURL

                    // Enforce same directory
                    guard imageFolder == videoFolder else { continue }
                    // Exact filename match
                    guard imageBase == videoBase else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    pairs.append(
                        AssetPair(
                            image: image,
                            video: video,
                            priority: 1
                        )
                    )

                    usedVideos.insert(video.url)

                    if dryRun {
                        print(
                            "DRY-RUN [MATCH]: \(imageName) ↔ \(videoName) " +
                            "[\(String(format: "%.2f", duration))s]"
                        )
                    }

                    break
                }
            }
        }

        return pairs
    }
}
