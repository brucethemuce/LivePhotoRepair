import Foundation

final class LivePhotoBuilder {

    func build(pair: AssetPair, outputDir: URL) throws {
        let assetID = UUID().uuidString

        let imageOut = outputDir.appendingPathComponent(pair.image.baseName + "_live.heic")
        let videoOut = outputDir.appendingPathComponent(pair.image.baseName + "_live.mov")

        try writeImage(src: pair.image.url, dst: imageOut, assetID: assetID)
        try writeVideo(src: pair.video.url, dst: videoOut, assetID: assetID)
    }
}

