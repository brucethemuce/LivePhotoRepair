import Foundation
import AVFoundation

func writeVideo(src: URL, dst: URL, assetID: String) throws {
    // let asset = AVAsset(url: src)
            // Video writing requires AVAsset, but we do NOT request precise duration
    let asset = AVURLAsset(
        url: src,
        options: [
            "AVURLAssetPreferPreciseDurationKey": false
        ]
    )

    let exporter = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetPassthrough
    )!

    // Use raw strings for Monterey compatibility
    // the secret sauce in the video that makes it a Live Photo pair
    let idMeta = AVMutableMetadataItem()
    idMeta.keySpace = .quickTimeMetadata
    idMeta.key = "com.apple.quicktime.content.identifier" as NSString
    idMeta.value = assetID as NSString

    let stillMeta = AVMutableMetadataItem()
    stillMeta.keySpace = .quickTimeMetadata
    stillMeta.key = "com.apple.quicktime.still-image-time" as NSString
    stillMeta.value = 0 as NSNumber // the time is unrecoverable but must be set to something to re-pair, you could do some frame matching with a hash but thats alot of work for little gain

    exporter.outputURL = dst
    exporter.outputFileType = .mov
    exporter.metadata = [idMeta, stillMeta]

    let group = DispatchGroup()
    group.enter()

    exporter.exportAsynchronously {
        group.leave()
    }
    group.wait()

    if exporter.status != .completed {
        throw exporter.error ?? NSError(domain: "VideoWrite", code: 1)
    }
}

