#!/usr/bin/env swift
// Generates README preview screenshots.
// Run: swift Tools/generate_screenshots.swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO

// MARK: - INI parser

func parseINI(at url: URL) -> [String: String] {
    guard let text = try? String(contentsOf: url, encoding: .windowsCP1252) else { return [:] }
    var result: [String: String] = [:]
    for raw in text.components(separatedBy: .newlines) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.hasPrefix(";"), !line.hasPrefix("["), !line.isEmpty else { continue }
        let noComment = line.components(separatedBy: ";").first ?? line
        let parts = noComment.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }
        result[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
               String(parts[1]).trimmingCharacters(in: .whitespaces)
    }
    return result
}

func parseBGR(_ s: String) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
    let t = s.trimmingCharacters(in: .whitespaces)
    var raw: UInt64 = 0
    if t.hasPrefix("0x") || t.hasPrefix("0X") {
        guard let v = UInt64(t.dropFirst(2), radix: 16) else { return nil }
        raw = v
    } else if let v = UInt64(t) { raw = v } else { return nil }
    return (CGFloat(raw & 0xFF) / 255,
            CGFloat((raw >> 8) & 0xFF) / 255,
            CGFloat((raw >> 16) & 0xFF) / 255)
}

// MARK: - Text rendering

func drawText(_ text: String, cx: CGFloat, cy: CGFloat,
              fontSize: CGFloat, color: CGColor, in ctx: CGContext, canvasH: Int) {
    let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color
    ]
    let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, [])
    let x = cx - bounds.width / 2
    let y = CGFloat(canvasH) - cy - bounds.height / 2 - bounds.origin.y
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - Render one skin

let OUTPUT_SIZE: Int = 300
let PAD: CGFloat = 10

// Fixed preview time: 10:10:30 AM, Jun 22
let PREVIEW_HOUR = 10, PREVIEW_MIN = 10, PREVIEW_SEC = 30
let PREVIEW_AMPM = "AM"
let PREVIEW_DATE = "Jun 22"

func renderSkin(skinName: String, skinsDir: URL, outputDir: URL,
                bgR: CGFloat, bgG: CGFloat, bgB: CGFloat,
                showAmPm: Bool = false, showDate: Bool = false) {
    // Try PNG first, then BMP
    var imageURL = skinsDir.appendingPathComponent("\(skinName).png")
    if !FileManager.default.fileExists(atPath: imageURL.path) {
        imageURL = skinsDir.appendingPathComponent("\(skinName).bmp")
    }
    let iniURL = skinsDir.appendingPathComponent("\(skinName).ini")
    guard let src = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let faceImg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        print("  ✗ could not load \(skinName)"); return
    }

    let ini = parseINI(at: iniURL)
    let imgW = CGFloat(faceImg.width), imgH = CGFloat(faceImg.height)
    let cx = ini["CenterX"].flatMap(Double.init).map { CGFloat($0) } ?? imgW / 2
    let cy = ini["CenterY"].flatMap(Double.init).map { CGFloat($0) } ?? imgH / 2

    func hand(_ colorKey: String, _ lenKey: String, _ lapKey: String, _ widKey: String,
              defaultColor: (CGFloat,CGFloat,CGFloat), defaultLen: CGFloat) ->
              (color: (CGFloat,CGFloat,CGFloat), len: CGFloat, lap: CGFloat, width: CGFloat) {
        let color = ini[colorKey].flatMap(parseBGR) ?? defaultColor
        let len   = ini[lenKey].flatMap({ Double($0) }).map { CGFloat($0) } ?? defaultLen
        let lap   = ini[lapKey].flatMap({ Double($0) }).map { CGFloat($0) } ?? 0
        let width = ini[widKey].flatMap({ Double($0) }).map { CGFloat($0) } ?? 2
        return (color, len, lap, width)
    }

    let faceRef = min(imgW, imgH)
    let hourH = hand("HourColor",   "HourLength",   "HourLap",   "HourWidth",
                     defaultColor: (0,0,0), defaultLen: faceRef * 0.23)
    let minH  = hand("MinuteColor", "MinuteLength", "MinuteLap", "MinuteWidth",
                     defaultColor: (0,0,0), defaultLen: faceRef * 0.32)
    let secH  = hand("SecondColor", "SecondLength", "SecondLap", "SecondWidth",
                     defaultColor: (1,0,0), defaultLen: faceRef * 0.35)

    let frac = Double(PREVIEW_SEC)
    let hourAngle = CGFloat(.pi/2 - Double(PREVIEW_HOUR % 12) * .pi/6 - Double(PREVIEW_MIN) * .pi/360 - frac * .pi/21600)
    let minAngle  = CGFloat(.pi/2 - Double(PREVIEW_MIN) * .pi/30 - frac * .pi/1800)
    let secAngle  = CGFloat(.pi/2 - frac * .pi/30)

    let sz = OUTPUT_SIZE
    guard let ctx = CGContext(data: nil, width: sz, height: sz,
                              bitsPerComponent: 8, bytesPerRow: sz * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { print("  ✗ ctx failed"); return }

    // Background
    ctx.setFillColor(red: bgR, green: bgG, blue: bgB, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: sz, height: sz))

    // Scale + position face
    let available = CGFloat(sz) - PAD * 2
    let scale = available / max(imgW, imgH)
    let drawW = imgW * scale, drawH = imgH * scale
    let ox = CGFloat(sz) / 2 - drawW / 2
    let oy = CGFloat(sz) / 2 - drawH / 2
    let faceRect = CGRect(x: ox, y: oy, width: drawW, height: drawH)

    // Apply cut-color mask for BMP / non-alpha images
    let alpha = faceImg.alphaInfo
    let hasAlpha = alpha != .none && alpha != .noneSkipFirst && alpha != .noneSkipLast
    let drawImg: CGImage
    if hasAlpha {
        drawImg = faceImg
    } else {
        let w = faceImg.width, hh = faceImg.height
        if let mctx = CGContext(data: nil, width: w, height: hh,
                                bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            mctx.draw(faceImg, in: CGRect(x:0,y:0,width:w,height:hh))
            if let data = mctx.data {
                let buf = data.bindMemory(to: UInt8.self, capacity: w*hh*4)
                for i in 0..<w*hh {
                    let r = buf[i*4], g = buf[i*4+1], b = buf[i*4+2]
                    if r > 200 && g < 60 && b < 60 {
                        buf[i*4]=0; buf[i*4+1]=0; buf[i*4+2]=0; buf[i*4+3]=0
                    }
                }
            }
            drawImg = mctx.makeImage() ?? faceImg
        } else { drawImg = faceImg }
    }
    ctx.draw(drawImg, in: faceRect)

    // Clock center in canvas coords
    let ccx = ox + cx * scale
    let ccy = oy + (imgH - cy) * scale

    func drawHand(_ h: (color: (CGFloat,CGFloat,CGFloat), len: CGFloat, lap: CGFloat, width: CGFloat),
                  angle: CGFloat) {
        let len = h.len * scale, lap = h.lap * scale
        ctx.move(to: CGPoint(x: ccx - lap * cos(angle), y: ccy - lap * sin(angle)))
        ctx.addLine(to: CGPoint(x: ccx + len * cos(angle), y: ccy + len * sin(angle)))
        ctx.setStrokeColor(red: h.color.0, green: h.color.1, blue: h.color.2, alpha: 1)
        ctx.setLineWidth(max(0.5, h.width))
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    drawHand(hourH, angle: hourAngle)
    drawHand(minH,  angle: minAngle)
    drawHand(secH,  angle: secAngle)

    // Center dot
    let dotR = max(1.5, hourH.width * 0.8)
    ctx.addEllipse(in: CGRect(x: ccx-dotR, y: ccy-dotR, width: dotR*2, height: dotR*2))
    ctx.setFillColor(red: hourH.color.0, green: hourH.color.1, blue: hourH.color.2, alpha: 1)
    ctx.fillPath()

    // AM/PM overlay — bottom-left of face, small font, semi-transparent white
    if showAmPm {
        let fsize = drawW * 0.10
        let tx = ox + drawW * 0.28
        let ty = CGFloat(sz) - (oy + drawH * 0.38)  // screen-space Y (top-down)
        let color = CGColor(red: 1, green: 1, blue: 1, alpha: 0.85)
        drawText(PREVIEW_AMPM, cx: tx, cy: CGFloat(sz) - ty,
                 fontSize: fsize, color: color, in: ctx, canvasH: sz)
    }

    // Date overlay — bottom-right of face
    if showDate {
        let fsize = drawW * 0.10
        let tx = ox + drawW * 0.72
        let ty = CGFloat(sz) - (oy + drawH * 0.38)
        let color = CGColor(red: 1, green: 1, blue: 1, alpha: 0.85)
        drawText(PREVIEW_DATE, cx: tx, cy: CGFloat(sz) - ty,
                 fontSize: fsize, color: color, in: ctx, canvasH: sz)
    }

    // Save
    guard let img = ctx.makeImage() else { print("  ✗ makeImage failed"); return }
    let outURL = outputDir.appendingPathComponent("\(skinName).png")
    let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("  ✓ \(skinName).png → Screenshots/")
}

// MARK: - Run

let root     = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let skinsDir = root.appendingPathComponent("Skins")
let outDir   = root.appendingPathComponent("Screenshots")

print("Generating screenshots…")

// Built-in originals
renderSkin(skinName: "KlokClassic", skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.92, bgG: 0.92, bgB: 0.94)
renderSkin(skinName: "KlokDark",    skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.18, bgG: 0.18, bgB: 0.20)
renderSkin(skinName: "KlokOutline", skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.85, bgG: 0.88, bgB: 0.92)

// Community ClocX skins
renderSkin(skinName: "Azul",             skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.10, bgG: 0.12, bgB: 0.18)
renderSkin(skinName: "BallClockAmber",   skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.14, bgG: 0.12, bgB: 0.10)
renderSkin(skinName: "Citizen",          skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.88, bgG: 0.88, bgB: 0.90)
renderSkin(skinName: "WidestoneStudios", skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.12, bgG: 0.12, bgB: 0.12)
renderSkin(skinName: "White_Apple_Clock", skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.20, bgG: 0.20, bgB: 0.22)
renderSkin(skinName: "Naranja",          skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.14, bgG: 0.11, bgB: 0.08)
renderSkin(skinName: "Rojo",             skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.12, bgG: 0.10, bgB: 0.10)
renderSkin(skinName: "Verde",            skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.10, bgG: 0.13, bgB: 0.10)
renderSkin(skinName: "JaguarClock",      skinsDir: skinsDir, outputDir: outDir,
           bgR: 0.14, bgG: 0.14, bgB: 0.14)

print("Done.")
