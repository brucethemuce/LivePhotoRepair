//
//  main.swift
//  LivePhotoRepair
//

import Foundation

// ---------------------
// Command-line argument parsing
// ---------------------
let args = CommandLine.arguments

// Dry-run flag
let dryRun = args.contains("--dry-run") || args.contains("-n")

// Filter out flags for positional paths
let paths = args.filter { !$0.hasPrefix("-") }

guard paths.count == 3 else {
    print("""
    Usage: livephoto-repair [--dry-run|-n] <input-folder> <output-folder>
    """)
    exit(1)
}

let inputURL = URL(fileURLWithPath: paths[1])
let outputURL = URL(fileURLWithPath: paths[2])

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

for pair in pairs {
    if dryRun {
        print("DRY-RUN: would build Live Photo for \(pair.image.url.lastPathComponent)")
    } else {
        do {
            try builder.build(pair: pair, outputDir: outputURL)
            print("✔ Built Live Photo: \(pair.image.baseName)")
        } catch {
            print("✖ Failed to build \(pair.image.baseName): \(error)")
        }
    }
}

if dryRun {
    print("Dry run complete — no files were written.")
} else {
    print("All Live Photos written to \(outputURL.path)")
}

