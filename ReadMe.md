# LivePhotoRepair

LivePhotoRepair is a Swift-based command-line tool for macOS that scans folders of image and video files, detects split Live Photo pairs, and recombines them into proper Live Photos. 
It is designed to work with files exported from the Photos app or other sources where a still image and a short video belong together but are stored separately.


## Features

- Recursively scans input folders for images and videos.
- Detects candidate Live Photo pairs by:
  - Exact filename match (basename match)
  - Sequential numeric filename match (e.g., `IMG_0019.heic` ↔ `IMG_0020.mov`)
  - Timestamp proximity checks
  - Short video duration limits
- Outputs repaired Live Photo pairs in a specified output folder.
- Offers a dry-run mode to preview matches without writing files.

## Requirements

- Targeted for **macOS Sonoma**, but may work on other more recent macOS versions (not tested)
- Developed using quickemu on Ubuntu hostsystem
- requires brew and libheif
``` brew install libheif```

## Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/LivePhotoRepair.git
cd LivePhotoRepair
```
Build the binary:
```
swiftc -framework AVFoundation -framework ImageIO -framework CoreServices *.swift -o livephoto-repair
```
You might get deprecation errors on building but its fine.

## Usage
### Dry-Run Mode (Safe Preview)

Always start with dry-run mode to see what pairs would be processed:
```
.build/release/livephoto-repair --dry-run /path/to/input /path/to/output
```

This prints matched pairs without creating any files.

### Actual Repair Mode

If you are satisfied with the dry-run results, run without dry-run:
```
.build/release/livephoto-repair /path/to/input /path/to/output
```

This creates Live Photo files in the output directory. The input folder is never modified. You can now reimport them into the photos app and sync via iCloud.

## How It Works

Live Photos in macOS and iOS are composed of **two linked assets**:

1. **A still image** (usually HEIC)
2. **A short video** (MOV)

The Photos app determines that these two files belong together using **specific metadata fields**. 
Split Live Photos fail to appear as a single Live Photo because these references are missing or inconsistent. 
This seems to often be caused by export/import from a third party app to iOS Photos app (e.g. dropbox, google drive, some photo editing, etc.)

This tool repairs the split Live Photos by re-injecting the necessary metadata so that the Photos app can recognize the image and video as a single Live Photo for displaying.

### Metadata Operations Performed by the Tool

1. **Generate a Unique Pair Identifier**
   - A UUID is created for each detected pair.
   - This UUID is used in both the image and video files to link them.

2. **Modify the Image Metadata**
   - For HEIC/JPG images, the tool injects EXIF tags to reference the UUID in the apple specific metadata.
        - `makerApple["17" as CFString] = assetID`

3. **Modify the Video Metadata**
   - For MOV/MP4 files, the tool injects QuickTime metadata, including:
     - `com.apple.quicktime.still-image-time` — indicates the frame in the video corresponding to the still image (not recoverable with this tool but needed for reconstruction, left as 0 seconds).
     - `com.apple.quicktime.content.identifier` — matches the UUID of the image.
   - This links the video to the image, signaling Photos app to treat them as a single Live Photo.
4. **Write the updated files to the output directory**
    - .mp4 files are remuxed into a MOV container
    - .heic is passed through unchanged. jpg's and jpeg's are re-encoded as .heic
    - All other metadata is untouched and passed through with the addition of the above injections.
    - files will autorename in the output folder the case of duplicated basenames to avoid clashes and overwriting

### Matching Criteria

The tool matches assets using the following criteria:

1. **Exact filename match**
   - Same basename (ignoring extension) for image and video.
2. **Sequential numeric match**
   - Filenames with the same prefix and adjacent numbers (e.g., `IMG_0019.heic` ↔ `IMG_0020.mov`).
3. **Timestamp proximity**
   - Image and video must have similar creation dates.
4. **Video duration limits**
   - Videos must be shorter than a configured maximum (default ≤ 4.0 seconds).

Each video is only used once in a match.

## Disclaimer

**Use at your own risk.** 
Always make a backup of your files before running this tool. File corruption or data loss is possible. Use `--dry-run` first to preview matches.

The author is not responsible for any damage or data loss resulting from using this software.
