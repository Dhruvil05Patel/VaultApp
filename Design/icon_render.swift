#!/usr/bin/swift
import AppKit
import CoreGraphics
import Foundation

let size = CGSize(width: 2048, height: 2048)
let rect = CGRect(origin: .zero, size: size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create context")
}

// Background
context.saveGState()
let bgColors = [
    NSColor(calibratedRed: 0x1A/255.0, green: 0x1F/255.0, blue: 0x3A/255.0, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0x2D/255.0, green: 0x3A/255.0, blue: 0x8C/255.0, alpha: 1.0).cgColor
] as CFArray
guard let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) else { fatalError() }
// Note: AppKit context origin is bottom-left, but we can draw TL->BR by going top-left (0, 2048) to bottom-right (2048, 0)
context.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: 2048), end: CGPoint(x: 2048, y: 0), options: [])

// Radial glow
let glowColors = [
    NSColor(calibratedRed: 0x5B/255.0, green: 0x8D/255.0, blue: 0xEF/255.0, alpha: 0.5).cgColor,
    NSColor(calibratedRed: 0x5B/255.0, green: 0x8D/255.0, blue: 0xEF/255.0, alpha: 0.0).cgColor
] as CFArray
guard let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) else { fatalError() }
context.drawRadialGradient(glowGradient, startCenter: CGPoint(x: 1024, y: 1024), startRadius: 0, endCenter: CGPoint(x: 1024, y: 1024), endRadius: 1000, options: [])
context.restoreGState()

// Bottom vignette
context.saveGState()
let vigColors = [
    NSColor(calibratedWhite: 0.0, alpha: 0.0).cgColor,
    NSColor(calibratedWhite: 0.0, alpha: 0.4).cgColor
] as CFArray
guard let vigGradient = CGGradient(colorsSpace: colorSpace, colors: vigColors, locations: [0.0, 1.0]) else { fatalError() }
context.drawLinearGradient(vigGradient, start: CGPoint(x: 1024, y: 600), end: CGPoint(x: 1024, y: 0), options: [])
context.restoreGState()

// Draw Shield
// AppKit origin is bottom-left
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: NSColor.black.withAlphaComponent(0.4).cgColor)

let shieldPath = CGMutablePath()
// Center is 1024, 1024. Shield width 1200, height 1400
// Top is flat or slightly curved
shieldPath.move(to: CGPoint(x: 1024, y: 300)) // bottom tip
shieldPath.addQuadCurve(to: CGPoint(x: 1624, y: 1400), control: CGPoint(x: 1624, y: 800)) // right side
shieldPath.addLine(to: CGPoint(x: 1624, y: 1600)) // straight up a bit
shieldPath.addLine(to: CGPoint(x: 1024, y: 1700)) // top peak
shieldPath.addLine(to: CGPoint(x: 424, y: 1600)) // left side top
shieldPath.addLine(to: CGPoint(x: 424, y: 1400)) // left side straight
shieldPath.addQuadCurve(to: CGPoint(x: 1024, y: 300), control: CGPoint(x: 424, y: 800)) // left side down

context.addPath(shieldPath)
context.setFillColor(NSColor(calibratedRed: 0xF4/255.0, green: 0xF8/255.0, blue: 0xFF/255.0, alpha: 1.0).cgColor)
context.fillPath()
context.restoreGState()

// Padlock
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: NSColor.black.withAlphaComponent(0.3).cgColor)

// Shackle
context.saveGState()
context.setLineWidth(80)
context.setLineCap(.round)
context.setStrokeColor(NSColor(calibratedRed: 0x5B/255.0, green: 0x8D/255.0, blue: 0xEF/255.0, alpha: 1.0).cgColor)
context.addArc(center: CGPoint(x: 1024, y: 1100), radius: 160, startAngle: 0, endAngle: .pi, clockwise: false)
context.strokePath()
context.restoreGState()

// Lock body
context.saveGState()
let bodyRect = CGRect(x: 774, y: 600, width: 500, height: 500)
let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 80, cornerHeight: 80, transform: nil)
context.addPath(bodyPath)
let lockColors = [
    NSColor(calibratedRed: 0x7B/255.0, green: 0xAD/255.0, blue: 0xFF/255.0, alpha: 1.0).cgColor, // lighter gloss
    NSColor(calibratedRed: 0x5B/255.0, green: 0x8D/255.0, blue: 0xEF/255.0, alpha: 1.0).cgColor  // base
] as CFArray
guard let lockGradient = CGGradient(colorsSpace: colorSpace, colors: lockColors, locations: [0.0, 1.0]) else { fatalError() }
context.clip()
context.drawLinearGradient(lockGradient, start: CGPoint(x: 1024, y: 1100), end: CGPoint(x: 1024, y: 600), options: [])
context.restoreGState()

// Keyhole
context.saveGState()
context.setFillColor(NSColor(calibratedRed: 0x1A/255.0, green: 0x1F/255.0, blue: 0x3A/255.0, alpha: 1.0).cgColor) // Navy
let keyholeCircle = CGRect(x: 984, y: 850, width: 80, height: 80)
context.addEllipse(in: keyholeCircle)
let keyholeStem = CGRect(x: 1004, y: 780, width: 40, height: 90)
context.addRect(keyholeStem)
context.fillPath()
context.restoreGState()

context.restoreGState()

// Save to PNG
guard let cgImage = context.makeImage() else { fatalError() }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError() }
try pngData.write(to: URL(fileURLWithPath: "Design/icon_2048.png"))

// Create 1024 version
let size1024 = CGSize(width: 1024, height: 1024)
guard let context1024 = CGContext(data: nil, width: Int(size1024.width), height: Int(size1024.height), bitsPerComponent: 8, bytesPerRow: Int(size1024.width) * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError() }
context1024.interpolationQuality = .high
context1024.draw(cgImage, in: CGRect(origin: .zero, size: size1024))
guard let cgImage1024 = context1024.makeImage() else { fatalError() }
let rep1024 = NSBitmapImageRep(cgImage: cgImage1024)
guard let pngData1024 = rep1024.representation(using: .png, properties: [:]) else { fatalError() }
try pngData1024.write(to: URL(fileURLWithPath: "Design/icon_1024.png"))

print("Successfully generated icon_2048.png and icon_1024.png")
