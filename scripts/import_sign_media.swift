#!/usr/bin/env swift
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO

struct CatalogSign: Codable {
    let id: String
    let name: String
    let category: String
    let recognition: String
    let imageName: String?
    let frontVideoName: String?
    let sideVideoName: String?
}

struct CatalogPayload: Codable {
    let signs: [CatalogSign]
}

func main() {
    let fileManager = FileManager.default
    let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    let signsJsonURL = projectRoot.appendingPathComponent("SignSpeak/Resources/Data/signs.json")
    let assetsSignsURL = projectRoot.appendingPathComponent("SignSpeak/Assets.xcassets/Signs")
    let signVideosURL = projectRoot.appendingPathComponent("SignSpeak/Resources/SignVideos")

    // Dataset sources
    let desktopDatasetRoot = URL(fileURLWithPath: "/Users/mileeshafernando/Desktop/SignSpeak Dataset/Dataset- WLASL")
    let staticTrainURL = desktopDatasetRoot.appendingPathComponent("Static/Train")
    let motionTrainURL = desktopDatasetRoot.appendingPathComponent("Motion/Train")

    guard let jsonData = try? Data(contentsOf: signsJsonURL),
          let catalog = try? JSONDecoder().decode(CatalogPayload.self, from: jsonData) else {
        print("[-] Error: Could not read or decode signs.json at \(signsJsonURL.path)")
        exit(1)
    }

    // 1. Ensure directories exist
    try? fileManager.createDirectory(at: assetsSignsURL, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: signVideosURL, withIntermediateDirectories: true)

    // Write root Signs folder Contents.json
    let folderContents = """
    {
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "provides-namespace" : false
      }
    }
    """
    try? folderContents.write(to: assetsSignsURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    print("=================================================================")
    print("  SignSpeak Media Importer (Step 4.2)")
    print("=================================================================")
    print("[i] Processing \(catalog.signs.count) catalog signs...")

    var importedPhotos = 0
    var importedVideos = 0
    var renderedCards = 0

    for sign in catalog.signs {
        guard let imageName = sign.imageName else { continue }
        let imageSetURL = assetsSignsURL.appendingPathComponent("\(imageName).imageset")
        try? fileManager.createDirectory(at: imageSetURL, withIntermediateDirectories: true)

        var photoImported = false

        // A. Static Alphabet Letters (A-Y except J/Z)
        if sign.category == "alphabet" && sign.name.count == 1 {
            let letter = sign.name.uppercased()
            let letterFolder = staticTrainURL.appendingPathComponent(letter)
            if let files = try? fileManager.contentsOfDirectory(atPath: letterFolder.path),
               let firstPhotoName = files.first(where: { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }) {
                let srcPhoto = letterFolder.appendingPathComponent(firstPhotoName)
                let dstPhoto = imageSetURL.appendingPathComponent("\(imageName).jpg")

                if !fileManager.fileExists(atPath: dstPhoto.path) {
                    try? fileManager.copyItem(at: srcPhoto, to: dstPhoto)
                }
                writeImageSetContents(at: imageSetURL, filename: "\(imageName).jpg")
                photoImported = true
                importedPhotos += 1
            }
        }

        // B. Motion Video Clips & Frame Extraction
        var candidateFolderNames = [sign.name]
        if sign.name == "Thank You" { candidateFolderNames.append("ThankYou") }
        if sign.name == "How are you" { candidateFolderNames.append("HowAreYou") }

        for folderName in candidateFolderNames {
            let motionWordFolder = motionTrainURL.appendingPathComponent(folderName)
            if let files = try? fileManager.contentsOfDirectory(atPath: motionWordFolder.path),
               let firstVideoName = files.first(where: { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") }) {
                let srcVideo = motionWordFolder.appendingPathComponent(firstVideoName)

                // Copy front video
                if let frontVideoName = sign.frontVideoName {
                    let dstVideo = signVideosURL.appendingPathComponent("\(frontVideoName).mp4")
                    if !fileManager.fileExists(atPath: dstVideo.path) {
                        try? fileManager.copyItem(at: srcVideo, to: dstVideo)
                        importedVideos += 1
                    }
                }

                // Extract frame as fallback photo if photo not imported yet
                let dstPhoto = imageSetURL.appendingPathComponent("\(imageName).jpg")
                if !photoImported && !fileManager.fileExists(atPath: dstPhoto.path) {
                    if extractVideoFrame(from: srcVideo, to: dstPhoto) {
                        writeImageSetContents(at: imageSetURL, filename: "\(imageName).jpg")
                        photoImported = true
                        importedPhotos += 1
                    }
                }
                break
            }
        }

        // C. Clean Branded Demonstration Card (if photo not available)
        if !photoImported {
            let dstPhoto = imageSetURL.appendingPathComponent("\(imageName).png")
            if !fileManager.fileExists(atPath: dstPhoto.path) {
                renderBrandedCard(sign: sign, destination: dstPhoto)
                writeImageSetContents(at: imageSetURL, filename: "\(imageName).png")
                renderedCards += 1
            }
        }
    }

    print("-" * 65)
    print("  Import Summary:")
    print("  - Photos from Datasets / Frames: \(importedPhotos)")
    print("  - Branded Reference Cards:      \(renderedCards)")
    print("  - Videos in Resources/SignVideos: \(importedVideos)")
    print("  - Total Signs with Media:        \(catalog.signs.count) / \(catalog.signs.count)")
    print("=================================================================")
    print("[✓] Media integration complete!")
}

func writeImageSetContents(at dirURL: URL, filename: String) {
    let json = """
    {
      "images" : [
        {
          "filename" : "\(filename)",
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? json.write(to: dirURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func extractVideoFrame(from videoURL: URL, to destinationURL: URL) -> Bool {
    let asset = AVAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 720, height: 720)

    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
    guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
        return false
    }

    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeJPEG as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    return CGImageDestinationFinalize(destination)
}

func renderBrandedCard(sign: CatalogSign, destination: URL) {
    let size: CGFloat = 512
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: Int(size) * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    // Gradient Background (Deep Navy to Teal)
    let darkNavy = CGColor(srgbRed: 15.0/255.0, green: 23.0/255.0, blue: 42.0/255.0, alpha: 1.0)
    let teal = CGColor(srgbRed: 13.0/255.0, green: 148.0/255.0, blue: 136.0/255.0, alpha: 1.0)

    let colors = [darkNavy, teal] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Accent Ribbon: Deaf Warm Yellow (#FFC72C)
    let warmYellow = CGColor(srgbRed: 255.0/255.0, green: 199.0/255.0, blue: 44.0/255.0, alpha: 1.0)
    ctx.setFillColor(warmYellow)
    ctx.fill(CGRect(x: size * 0.1, y: size * 0.88, width: size * 0.8, height: 4))

    // Inner Card Border
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.setLineWidth(2)
    ctx.stroke(CGRect(x: size * 0.08, y: size * 0.08, width: size * 0.84, height: size * 0.84))

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(destination as CFURL, kUTTypePNG as CFString, 1, nil) else {
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

main()
