# LivePhotoRepair

LivePhotoRepair is a Swift-based command-line tool for macOS that detects split Live Photo pairs, and recombines them into proper Live Photos for viewing. 
It is designed to work with files exported from the Photos app or other sources where a still image and a short video belong together but are shown separately in the camera roll or iCloud.


## Features

- Recursively scans input folders for images and videos.
- Detects candidate Live Photo pairs by:
  - Timestamp proximity checks
  - Short video duration limits
  - Exact filename match (basename match)
  - Sequential numeric filename match (e.g., `IMG_0019.heic` ↔ `IMG_0020.mov`)
  - Anticollision rename match (e.g. `IMG_001.jpg` ↔ `IMG_001(1).mov` and other common ones )
  - After the above, only timestamp match, with mixed file names
- Outputs repaired Live Photo pairs in a specified output folder. Those files can be reimported into the macOS Photos app and then synced via iCloud. Both items must be imported at the same time for the app to recognize the newly minted single Live Photo asset.
- Offers a dry-run mode to preview matches without writing files.
- Generates list of identified matches in a txt file for review

## Requirements

- A filesystem folder containing the original videos and images, this approach cannot work reliably by interfacing with the Photos app directly
- Access to a mac or emulator. Runs in **macOS Sonoma**, and may work on other more recent macOS versions (not tested)
- Developed using quickemu Monterey on Ubuntu hostsystem, hence the old mac versions
- Requires brew, libheif, and exiftool

   - ``` brew install libheif```
      - if you dont have jpg matches you dont need libheif (in which case this does run on macOS Monterey)
   - ``` brew install exiftool```
   - if its a fresh install of macOS via quickemu these will take 30-40 minutes to install all dependencies


## Installation
Get the requirements above.

Clone the repository:

```bash
git clone https://github.com/brucethemuce/LivePhotoRepair.git
cd LivePhotoRepair
```
Build the binary:
```
swiftc -framework AVFoundation -framework ImageIO -framework CoreServices *.swift -o livephoto-repair
```
You might get deprecation warnings on building but its fine.

## Usage
### Dry-Run Mode (Safe Preview)

Always start with dry-run mode to see what pairs would be processed:
```
livephoto-repair --dry-run /path/to/input /path/to/output
```

This prints matched pairs without creating any files. Also check the generated text files and spot check some of the P3 matches (date only) to be sure. 

### Actual Repair Mode

If you are satisfied with the dry-run results, run without dry-run:
```
livephoto-repair /path/to/input /path/to/output
```

This creates repaired Live Photo files in the output directory. The input folder is never modified. The pair consists of the metadata injected video and image, converted (if needed) to mov and heic respectively.

You can now reimport them into the macOS Photos app and then synced via iCloud. Both items must be imported at the same time for the app to recognize the newly minted single Live Photo asset.

Run time is about 30-120 mins per 1000 pairs, re-encoding jpg files is the bottleneck, with mostly heic files expect faster times.

## How It Works

Live Photos in macOS and iOS are composed of **two linked assets**:

1. **A still image** (usually HEIC)
2. **A short video** (MOV)

The Photos app determines that these two files belong together using **specific metadata fields**. 
Split Live Photos fail to appear as a single Live Photo because these references are missing or inconsistent. 
This seems to often be caused by export/import from a third party app to iOS Photos app (e.g. dropbox, google drive, snapchat, sms, some photo editing, etc.)

This tool repairs the split Live Photos by re-injecting the necessary metadata so that the Photos app can recognize the image and video as a single Live Photo for displaying.

### Metadata Operations Performed by the Tool

1. **Generate a Unique Pair Identifier**
   - A new UUID is created for each detected pair.
   - This UUID is used in both the image and video files to link them.

2. **Modify the Image Metadata**
   - For HEIC/JPG images, the tool injects EXIF tags to reference the UUID in the apple specific metadata.
        - `makerApple["17" as CFString] = assetID`

3. **Modify the Video Metadata**
   - For MOV/MP4 files, the tool injects QuickTime metadata, including:
     - `com.apple.quicktime.content.identifier` — matches the UUID of the image.
     - `com.apple.quicktime.still-image-time` — indicates the frame in the video corresponding to the still image (not recoverable with this tool but needed for reconstruction, left as 0 seconds).

4. **Write the updated files to the output directory**
    - .mp4 files are remuxed into a MOV container
    - .heic is passed through unchanged. jpg's and jpeg's are re-encoded as .heic with quality 90
    - All other metadata is untouched and passed through with the addition of the above injections.
    - files will autorename in the output folder in the case of duplicated basenames to avoid clashes and overwriting
    - output files will have _live appended to them

### Matching Criteria

The tool matches assets using the below criteria. On all possible matches, image and video must have similar creation dates within a tolerance.

1. **Exact filename match**
   - Same basename (ignoring extension) for image and video.
2. **Sequential numeric match**
   - Filenames with the same prefix and adjacent numbers (e.g., `IMG_0019.heic` ↔ `IMG_0020.mov`).
   - iOS *sometimes* will generate sequential filenames for Live Photos usually theyre identical as in case 1
3. **Basename subset match**
   - Mutations from an OS's anti-fileCollision or human batch renaming from moving files around (e.g. `IMG_001.jpg`  ↔ `IMG_001(1).mov` and other common ones)
4. **Timestamp proximity**
   - last ditch effort after exhausting the above criteria, match by date only regardless of filenames
   - for files that got REALLY messed up, recommend spot checking these hits in P3matches.txt
5. **Video duration limits**
   - Videos must be shorter than a configured maximum (default ≤ 4.0 seconds).

Each video and image is only used once through the matching process.

## Future Features (maybe)
- video deduplication from iOS/macOS photos. the image dupes can be reliably removed using the builtin tool, but videos will not be recognized
- more match candidates/verification by image/frame hashing (would be suuuuuper slow as its unknown what video frame the still is from, could make a similarity threshold but currently works very well via filenames and metadata)
- you *could* do all this metadata injection on windows or linux but then you need to reimport them into the Photos app on macOS anyway... iCloud for windows *might* work for reimport but hasnt been tested. iCloud via web browser is hilariously limited and only supports jpeg uploads.

## Disclaimer

**Use at your own risk.** 

Always make a backup of your files before running this tool. File corruption or data loss is possible. Use `--dry-run` first to preview matches.

I am not responsible for any damage or data loss resulting from using this software.
This was developed for my needs and may not fit your *exact* use case. Feel free to fork and modify the match logic as you need.
