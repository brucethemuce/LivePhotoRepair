//
//  PairMatcher.swift
//  LivePhotoRepair
//

import Foundation
import AVFoundation

final class PairMatcher {

    /// Timestamp tolerance for matching (seconds)
    var maxTimeDiff: TimeInterval = 2.5

    /// Maximum allowed numeric difference for sequential filenames
    /// 1 is ideal (IMG_0019 ↔ IMG_0020)
    var maxNumericDelta: Int = 1

    /// Maximum video duration (seconds)
    var maxVideoDuration: TimeInterval = 4.0

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


        // Group assets by parent folder
        let folders = Dictionary(
            grouping: images + videos,
            by: { $0.url.deletingLastPathComponent() }
        )

        for (_, assetsInFolder) in folders {

            let folderImages = assetsInFolder.filter { $0.type == .image }
            let folderVideos = assetsInFolder.filter { $0.type == .video }
            var usedVideos = Set<URL>()

            for image in folderImages {

                guard let imageDate = image.creationDate else { continue }
                let imageBase = image.url.deletingPathExtension().lastPathComponent

                // -------------------------------------------------
                // P1: exact basename match + timestamp
                // -------------------------------------------------
                var matched = false

                for video in folderVideos where !usedVideos.contains(video.url) {

                    guard let videoDate = video.creationDate else { continue }
                    let videoBase = video.url.deletingPathExtension().lastPathComponent

                    guard imageBase == videoBase else { continue }
                    guard abs(imageDate.timeIntervalSince(videoDate)) <= maxTimeDiff else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    pairs.append(
                        AssetPair(image: image, video: video, priority: 1)
                    )
                    usedVideos.insert(video.url)
                    matched = true

                    if dryRun {
                        print(
                            "DRY-RUN [P1]: \(imageBase) ↔ \(videoBase) " +
                            "[\(String(format: "%.2f", duration))s]"
                        )
                    }
                    break
                }

                if matched { continue }

                // -------------------------------------------------
                // P2: sequential numeric filename match
                // -------------------------------------------------
                guard let (imagePrefix, imageNum) = parseNumericSuffix(imageBase) else {
                    continue
                }

                for video in folderVideos where !usedVideos.contains(video.url) {

                    guard let videoDate = video.creationDate else { continue }
                    let videoBase = video.url.deletingPathExtension().lastPathComponent

                    guard let (videoPrefix, videoNum) = parseNumericSuffix(videoBase) else {
                        continue
                    }

                    guard imagePrefix == videoPrefix else { continue }

                    let delta = abs(imageNum - videoNum)
                    guard delta > 0 && delta <= maxNumericDelta else { continue }
                    guard abs(imageDate.timeIntervalSince(videoDate)) <= maxTimeDiff else { continue }

                    let duration = videoDurations[video.url] ?? 0
                    guard duration <= maxVideoDuration else { continue }

                    pairs.append(
                        AssetPair(image: image, video: video, priority: 2)
                    )
                    usedVideos.insert(video.url)

                    if dryRun {
                        print(
                            "DRY-RUN [P2]: \(imageBase) ↔ \(videoBase) " +
                            "[Δnum: \(delta), \(String(format: "%.2f", duration))s]"
                        )
                    }
                    break
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
