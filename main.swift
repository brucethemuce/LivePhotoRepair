//
//  main.swift
//  LivePhotoRepair
//

import Foundation

// ---------------------
// Command-line argument parsing
// ---------------------
let args = Array(CommandLine.arguments.dropFirst())

let dryRun = args.contains("--dry-run") || args.contains("-n")

let paths = args.filter { !$0.hasPrefix("-") }

guard paths.count == 2 else {
    print("""
    Usage: livephoto-repair [--dry-run|-n] <input-folder> <output-folder>
    """)
    exit(1)
}

let inputURL = URL(fileURLWithPath: paths[0])
let outputURL = URL(fileURLWithPath: paths[1])

// ---------------------
// Ensure output folder exists
// ---------------------
if !dryRun {
    try? FileManager.default.createDirectory(
        at: outputURL,
        withIntermediateDirectories: true
    )
}

// ---------------------
// Scan assets
// ---------------------
print("Scanning assets in \(inputURL.path)...")
let scanner = AssetScanner()
let assets = scanner.scan(folder: inputURL)

// ---------------------
// Split images and videos
// ---------------------
let images = assets.filter { $0.type == .image }
let videos = assets.filter { $0.type == .video }

print("Found \(images.count) images and \(videos.count) videos")

// ---------------------
// Match pairs
// ---------------------
let matcher = PairMatcher()
let pairs = matcher.match(images: images, videos: videos, dryRun: dryRun)

print("Matched \(pairs.count) potential Live Photo pairs")

// ---------------------
// Build Live Photos
// ---------------------
let builder = LivePhotoBuilder()

let total = pairs.count

for (index, pair) in pairs.enumerated() {
    let current = index + 1
    let imageName = pair.image.url.lastPathComponent

    if dryRun {
        print("[\(current)/\(total)] DRY-RUN: would build Live Photo for \(imageName)")
    } else {
        do {
            try builder.build(pair: pair, outputDir: outputURL)
            print("[\(current)/\(total)] Built Live Photo: \(imageName)")
        } catch {
            print("[\(current)/\(total)] Failed to build \(imageName): \(error)")
        }
    }
}


if dryRun {
    print("Dry run complete — no files were written.")
} else {
    print("All Live Photos written to \(outputURL.path)")
}

