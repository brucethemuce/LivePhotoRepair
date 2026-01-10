//
//  Models.swift
//  LivePhotoRepair
//

import Foundation

/// Represents a single asset file (image or video)
struct AssetFile {
    let url: URL
    let type: AssetType
    let duration: TimeInterval?
    let exifCreateDate: Date?
    let quickTimeCreationDate: Date?
    var baseName: String {
        return url.deletingPathExtension().lastPathComponent
    }
}

/// Type of asset: image or video
enum AssetType {
    case image
    case video
}

/// Represents a matched image/video pair for a Live Photo
struct AssetPair {
    let image: AssetFile
    let video: AssetFile
    let priority: Int // 1 = exact name, 2 = similar name, 3 = different name
}

