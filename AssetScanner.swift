//
//  AssetScanner.swift
//  LivePhotoRepair
//

import Foundation
import ImageIO
import AVFoundation

final class AssetScanner {

    /// Scan a folder recursively and return all image/video assets
    func scan(folder: URL) -> [AssetFile] {
        var assets: [AssetFile] = []
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .creationDateKey,
            .typeIdentifierKey
        ]

        let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )!

        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)) else {
                continue
            }

            if resourceValues.isDirectory == true { continue }

            let typeIdentifier = resourceValues.typeIdentifier ?? ""
            let creationDate = resourceValues.creationDate

            if typeIdentifier.hasPrefix("public.image")
                || url.pathExtension.lowercased() == "heic" {

                assets.append(
                    AssetFile(
                        url: url,
                        type: .image,
                        creationDate: creationDate,
                        duration: nil
                    )
                )

            } else if typeIdentifier.hasPrefix("public.movie")
                || ["mov","mp4"].contains(url.pathExtension.lowercased()) {

                let asset = AVURLAsset(
                    url: url,
                    options: [
                        "AVURLAssetPreferPreciseDurationKey": false
                    ]
                )

                let duration = asset.duration.isNumeric
                    ? asset.duration.seconds
                    : nil

                assets.append(
                    AssetFile(
                        url: url,
                        type: .video,
                        creationDate: creationDate,
                        duration: duration
                    )
                )
            }
        }

        return assets
    }
}
