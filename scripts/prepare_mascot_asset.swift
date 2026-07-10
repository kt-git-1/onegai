import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3 else {
    fputs("usage: prepare_mascot_asset.swift input.png output.png\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("failed to read input image\n", stderr)
    exit(1)
}

let width = image.width
let height = image.height
let bytesPerRow = width * 4
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("failed to create bitmap context\n", stderr)
    exit(1)
}
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

func isBackground(_ index: Int) -> Bool {
    let offset = index * 4
    let r = Int(pixels[offset])
    let g = Int(pixels[offset + 1])
    let b = Int(pixels[offset + 2])
    return min(r, g, b) >= 220 && max(r, g, b) - min(r, g, b) <= 20
}

var visited = [Bool](repeating: false, count: width * height)
var queue = [Int]()
queue.reserveCapacity(width * height / 2)
for x in 0..<width {
    queue.append(x)
    queue.append((height - 1) * width + x)
}
for y in 1..<(height - 1) {
    queue.append(y * width)
    queue.append(y * width + width - 1)
}

var cursor = 0
while cursor < queue.count {
    let index = queue[cursor]
    cursor += 1
    guard !visited[index], isBackground(index) else { continue }
    visited[index] = true
    pixels[index * 4 + 3] = 0
    let x = index % width
    let y = index / width
    if x > 0 { queue.append(index - 1) }
    if x + 1 < width { queue.append(index + 1) }
    if y > 0 { queue.append(index - width) }
    if y + 1 < height { queue.append(index + width) }
}

var minX = width
var minY = height
var maxX = 0
var maxY = 0
for y in 0..<height {
    for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
    }
}
guard minX <= maxX, minY <= maxY, let fullImage = context.makeImage() else {
    fputs("no foreground pixels found\n", stderr)
    exit(1)
}

let padding = 16
let crop = CGRect(
    x: max(minX - padding, 0),
    y: max(minY - padding, 0),
    width: min(maxX + padding, width - 1) - max(minX - padding, 0) + 1,
    height: min(maxY + padding, height - 1) - max(minY - padding, 0) + 1
)
guard let cropped = fullImage.cropping(to: crop),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
    fputs("failed to create output image\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, cropped, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("failed to write output image\n", stderr)
    exit(1)
}
