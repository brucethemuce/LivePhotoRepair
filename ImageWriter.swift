import Foundation
import ImageIO
import UniformTypeIdentifiers

func writeImage(src: URL, dst: URL, assetID: String) throws {
    let data = try Data(contentsOf: src)
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    let type = CGImageSourceGetType(source)!

    let meta = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    // the secret sauce that makes it a Live Photo
    var makerApple = meta[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any] ?? [:]
    makerApple["17" as CFString] = assetID

    var newMeta = meta
    newMeta[kCGImagePropertyMakerAppleDictionary] = makerApple

    let dest = CGImageDestinationCreateWithURL(dst as CFURL, type, 1, nil)!
    CGImageDestinationAddImageFromSource(dest, source, 0, newMeta as CFDictionary)

    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "ImageWrite", code: 1)
    }
}

