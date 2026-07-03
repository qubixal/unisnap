//
//  WallpaperColors.swift
//  unisnap
//
//  Extracts dominant colors from the user's desktop wallpaper
//  and exposes them for use in SwiftUI gradients.
//

import Cocoa
import SwiftUI
import Combine

final class WallpaperColors: ObservableObject {
    @Published var colors: [Color] = [.gray, .gray]

    private var timer: Timer?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public

    func refresh() {
        if let result = dominantColorsRaw(count: 2) {
            colors = result.map { Color(red: Double($0.r / 255.0), green: Double($0.g / 255.0), blue: Double($0.b / 255.0)) }
        } else {
            colors = [.gray, .gray]
        }
    }

    // MARK: - Wallpaper Change Detection

    private func startObserving() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Dominant Color Extraction

    private func dominantColorsRaw(count: Int) -> [(r: CGFloat, g: CGFloat, b: CGFloat)]? {
        guard let screen = NSScreen.main,
              let imageURL = NSWorkspace.shared.desktopImageURL(for: screen),
              let ciImage = CIImage(contentsOf: imageURL) else {
            return nil
        }

        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        let sampleSize = 64
        let scaleX = CGFloat(sampleSize) / extent.width
        let scaleY = CGFloat(sampleSize) / extent.height

        let scaledImage = ciImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .clampedToExtent()

        let context = CIContext(options: [.useSoftwareRenderer: false])
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)

        context.render(
            scaledImage,
            toBitmap: &pixelData,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var pixels: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                let offset = (y * sampleSize + x) * 4
                let r = CGFloat(pixelData[offset])
                let g = CGFloat(pixelData[offset + 1])
                let b = CGFloat(pixelData[offset + 2])
                let a = CGFloat(pixelData[offset + 3])
                if a > 128 {
                    pixels.append((r, g, b))
                }
            }
        }

        guard !pixels.isEmpty else { return nil }

        let dominant = kMeansDominantColors(pixels: pixels, k: count, iterations: 20)

        return dominant
    }

    // MARK: - K-Means Clustering

    private func kMeansDominantColors(pixels: [(r: CGFloat, g: CGFloat, b: CGFloat)], k: Int, iterations: Int) -> [(r: CGFloat, g: CGFloat, b: CGFloat)] {
        guard pixels.count >= k else {
            return Array(pixels.prefix(k))
        }

        var centroids = pixels.shuffled().prefix(k).map { $0 }

        for _ in 0..<iterations {
            var clusters = [[(r: CGFloat, g: CGFloat, b: CGFloat)]](repeating: [], count: k)

            for pixel in pixels {
                var minDist = CGFloat.greatestFiniteMagnitude
                var closest = 0
                for (i, centroid) in centroids.enumerated() {
                    let dist = colorDistance(pixel, centroid)
                    if dist < minDist {
                        minDist = dist
                        closest = i
                    }
                }
                clusters[closest].append(pixel)
            }

            for i in 0..<k {
                guard !clusters[i].isEmpty else { continue }
                let avgR = clusters[i].reduce(0) { $0 + $1.r } / CGFloat(clusters[i].count)
                let avgG = clusters[i].reduce(0) { $0 + $1.g } / CGFloat(clusters[i].count)
                let avgB = clusters[i].reduce(0) { $0 + $1.b } / CGFloat(clusters[i].count)
                centroids[i] = (avgR, avgG, avgB)
            }
        }

        let sorted = centroids.sorted { a, b in
            saturation(a) > saturation(b)
        }

        return Array(sorted.prefix(k))
    }

    private func colorDistance(_ a: (r: CGFloat, g: CGFloat, b: CGFloat), _ b: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }

    private func saturation(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        let maxC = max(c.r, c.g, c.b)
        let minC = min(c.r, c.g, c.b)
        guard maxC > 0 else { return 0 }
        return (maxC - minC) / maxC
    }
}
