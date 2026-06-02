import Foundation
import AppKit

func createIcon() {
    let size = CGSize(width: 1024, height: 1024)
    // Standard macOS 11+ icon padding
    let margin: CGFloat = 100
    let rect = CGRect(x: margin, y: margin, width: size.width - (margin * 2), height: size.height - (margin * 2))
    
    let image = NSImage(size: size)
    image.lockFocus()
    
    // Background gradient (Dark modern theme)
    let context = NSGraphicsContext.current!.cgContext
    
    // Add subtle drop shadow to match macOS standard
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 30, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    
    let colors = [
        NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    
    // macOS Big Sur standard corner radius is roughly 22.5% of the width
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()
    
    // Remove shadow for inner drawing
    context.setShadow(offset: .zero, blur: 0, color: nil)
    
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    
    // Outer glow / border
    path.lineWidth = 16
    NSColor(white: 1.0, alpha: 0.15).setStroke()
    path.stroke()
    
    // Draw the stylized weave / terminal icon (Scaled and centered for new rect)
    let weavePath = NSBezierPath()
    
    // Terminal prompt >
    weavePath.move(to: NSPoint(x: rect.minX + 150, y: rect.maxY - 200))
    weavePath.line(to: NSPoint(x: rect.minX + 350, y: rect.minY + 412))
    weavePath.line(to: NSPoint(x: rect.minX + 150, y: rect.minY + 224))
    
    // Cursor _
    weavePath.move(to: NSPoint(x: rect.minX + 400, y: rect.minY + 224))
    weavePath.line(to: NSPoint(x: rect.minX + 650, y: rect.minY + 224))
    
    // Connective 'weave' lines
    weavePath.move(to: NSPoint(x: rect.minX + 650, y: rect.maxY - 200))
    weavePath.curve(to: NSPoint(x: rect.minX + 350, y: rect.minY + 412), controlPoint1: NSPoint(x: rect.minX + 450, y: rect.maxY - 200), controlPoint2: NSPoint(x: rect.minX + 550, y: rect.minY + 412))
    
    weavePath.lineWidth = 50
    weavePath.lineCapStyle = .round
    weavePath.lineJoinStyle = .round
    
    NSColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0).setStroke()
    weavePath.stroke()
    
    // Gloss effect
    let glossPath = NSBezierPath()
    glossPath.move(to: NSPoint(x: rect.minX, y: rect.maxY))
    glossPath.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
    glossPath.line(to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.4))
    glossPath.curve(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.6), controlPoint1: NSPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.4), controlPoint2: NSPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.7))
    glossPath.close()
    
    NSColor(white: 1.0, alpha: 0.05).setFill()
    glossPath.fill()
    
    image.unlockFocus()
    
    // Save to file
    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        return
    }
    
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DotWeaverIcon")
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    
    let pngURL = tempDir.appendingPathComponent("icon_1024x1024.png")
    try? pngData.write(to: pngURL)
    
    // Create iconset
    let iconsetDir = tempDir.appendingPathComponent("AppIcon.iconset")
    try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
    
    // Generate sizes using sips
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in sizes {
        for scale in [1, 2] {
            let actualSize = size * scale
            let scaleSuffix = scale == 2 ? "@2x" : ""
            let fileName = "icon_\(size)x\(size)\(scaleSuffix).png"
            let outPath = iconsetDir.appendingPathComponent(fileName).path
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
            process.arguments = ["-z", "\(actualSize)", "\(actualSize)", pngURL.path, "--out", outPath]
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    // Convert to icns
    let icnsProcess = Process()
    icnsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    icnsProcess.arguments = ["-c", "icns", iconsetDir.path, "-o", "AppIcon.icns"]
    try? icnsProcess.run()
    icnsProcess.waitUntilExit()
    
    print("AppIcon.icns generated successfully.")
}

createIcon()
