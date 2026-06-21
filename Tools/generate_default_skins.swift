#!/usr/bin/env swift
// Generates three original default clock-face skins for Klok.
// Run: swift Tools/generate_default_skins.swift
import Foundation
import CoreGraphics
import ImageIO

let SIZE = 200
let F = CGFloat(SIZE)
let C = F / 2          // center = 100
let R = F / 2 - 3      // radius = 97

// MARK: - helpers

func ctx() -> CGContext {
    CGContext(data: nil, width: SIZE, height: SIZE,
              bitsPerComponent: 8, bytesPerRow: SIZE * 4,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func save(_ g: CGContext, name: String) {
    let url = URL(fileURLWithPath: "Skins/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, g.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("  \(name).png")
}

// angle for tick i (0=12 o'clock, clockwise) in CG coords (CCW from +X)
func tickAngle(_ i: Int, total: Int) -> CGFloat {
    .pi/2 - CGFloat(i) * 2 * .pi / CGFloat(total)
}

func drawTicks(_ g: CGContext,
               hourColor: CGColor, hourWidth: CGFloat, hourOuter: CGFloat, hourInner: CGFloat,
               minColor: CGColor,  minWidth: CGFloat,  minOuter: CGFloat,  minInner: CGFloat) {
    for i in 0..<60 {
        let a = tickAngle(i, total: 60)
        let isHour = i % 5 == 0
        let outer = isHour ? hourOuter : minOuter
        let inner = isHour ? hourInner : minInner
        g.move(to: CGPoint(x: C + outer*cos(a), y: C + outer*sin(a)))
        g.addLine(to: CGPoint(x: C + inner*cos(a), y: C + inner*sin(a)))
        g.setStrokeColor(isHour ? hourColor : minColor)
        g.setLineWidth(isHour ? hourWidth : minWidth)
        g.setLineCap(.round)
        g.strokePath()
    }
}

// MARK: - KlokClassic: white face, geometric marks

func makeClassic() {
    let g = ctx()

    // Face
    let faceR = CGRect(x: 2, y: 2, width: F-4, height: F-4)
    g.addEllipse(in: faceR)
    g.setFillColor(CGColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1))
    g.fillPath()

    // Border
    g.addEllipse(in: faceR.insetBy(dx: 0.75, dy: 0.75))
    g.setStrokeColor(CGColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1))
    g.setLineWidth(1.5)
    g.strokePath()

    // Inner guide ring (subtle)
    g.addEllipse(in: CGRect(x: F*0.1, y: F*0.1, width: F*0.8, height: F*0.8))
    g.setStrokeColor(CGColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1))
    g.setLineWidth(0.5)
    g.strokePath()

    // Ticks
    drawTicks(g,
        hourColor: CGColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1), hourWidth: 2.5,
        hourOuter: R-1, hourInner: R-14,
        minColor:  CGColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1), minWidth: 1.0,
        minOuter:  R-1, minInner:  R-7)

    // 4 bold corner dots at 12/3/6/9
    for i in [0, 3, 6, 9] {
        let a = tickAngle(i * 5, total: 60)
        let dotR: CGFloat = 3
        let dr  = R - 7
        let px = C + dr*cos(a)
        let py = C + dr*sin(a)
        g.addEllipse(in: CGRect(x: px-dotR, y: py-dotR, width: dotR*2, height: dotR*2))
        g.setFillColor(CGColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1))
        g.fillPath()
    }

    save(g, name: "KlokClassic")
}

// MARK: - KlokDark: charcoal face, cream marks

func makeDark() {
    let g = ctx()

    // Face
    let faceR = CGRect(x: 1.5, y: 1.5, width: F-3, height: F-3)
    g.addEllipse(in: faceR)
    g.setFillColor(CGColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1))
    g.fillPath()

    // Outer rim
    g.addEllipse(in: faceR.insetBy(dx: 0.75, dy: 0.75))
    g.setStrokeColor(CGColor(red: 0.35, green: 0.35, blue: 0.36, alpha: 1))
    g.setLineWidth(1.5)
    g.strokePath()

    // Ticks
    drawTicks(g,
        hourColor: CGColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1), hourWidth: 2.5,
        hourOuter: R-1, hourInner: R-14,
        minColor:  CGColor(red: 0.55, green: 0.52, blue: 0.47, alpha: 1), minWidth: 1.0,
        minOuter:  R-1, minInner:  R-7)

    // Subtle inner ring
    g.addEllipse(in: CGRect(x: F*0.1, y: F*0.1, width: F*0.8, height: F*0.8))
    g.setStrokeColor(CGColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 0.6))
    g.setLineWidth(0.5)
    g.strokePath()

    // Luminous dots at 12/3/6/9
    for i in [0, 3, 6, 9] {
        let a = tickAngle(i * 5, total: 60)
        let dotR: CGFloat = 3
        let dr  = R - 7
        let px = C + dr*cos(a)
        let py = C + dr*sin(a)
        g.addEllipse(in: CGRect(x: px-dotR, y: py-dotR, width: dotR*2, height: dotR*2))
        g.setFillColor(CGColor(red: 0.92, green: 0.88, blue: 0.80, alpha: 1))
        g.fillPath()
    }

    save(g, name: "KlokDark")
}

// MARK: - KlokOutline: transparent, minimal ring + marks

func makeOutline() {
    let g = ctx()

    // Thin ring only — no fill (transparent background)
    let faceR = CGRect(x: 1.5, y: 1.5, width: F-3, height: F-3)
    g.addEllipse(in: faceR)
    g.setStrokeColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.55))
    g.setLineWidth(1.0)
    g.strokePath()

    // Hour marks: short filled rectangles via thick strokes
    for i in stride(from: 0, to: 60, by: 5) {
        let a = tickAngle(i, total: 60)
        let outer = R - 1
        let inner = R - 13
        g.move(to: CGPoint(x: C + outer*cos(a), y: C + outer*sin(a)))
        g.addLine(to: CGPoint(x: C + inner*cos(a), y: C + inner*sin(a)))
        g.setStrokeColor(CGColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 0.80))
        g.setLineWidth(2.5)
        g.setLineCap(.round)
        g.strokePath()
    }

    // Minute marks: dots
    for i in 0..<60 {
        if i % 5 == 0 { continue }
        let a = tickAngle(i, total: 60)
        let dr = R - 4
        let dotR: CGFloat = 1.2
        let px = C + dr*cos(a)
        let py = C + dr*sin(a)
        g.addEllipse(in: CGRect(x: px-dotR, y: py-dotR, width: dotR*2, height: dotR*2))
        g.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.50))
        g.fillPath()
    }

    save(g, name: "KlokOutline")
}

// MARK: - INI files

// BGR = (B << 16) | (G << 8) | R
func bgr(_ r: Int, _ g: Int, _ b: Int) -> String {
    String(format: "0x%06X", (b << 16) | (g << 8) | r)
}

func writeINI(name: String, content: String) {
    try! content.write(toFile: "Skins/\(name).ini", atomically: true, encoding: .utf8)
    print("  \(name).ini")
}

func makeClassicINI() {
    writeINI(name: "KlokClassic", content: """
;Klok Classic — clean white face
[Settings]
CenterX=100
CenterY=100
HourColor=\(bgr(45, 45, 45))
HourLength=55
HourLap=10
HourWidth=4
MinuteColor=\(bgr(45, 45, 45))
MinuteLength=76
MinuteLap=10
MinuteWidth=2.5
SecondColor=\(bgr(210, 45, 35))
SecondLength=87
SecondLap=14
SecondWidth=1.5
DisableAMPM=0
AMPMColor=\(bgr(110, 110, 110))
AMPMFont=
AMPMFontSize=12
AMPMCenterX=100
AMPMCenterY=140
DisableDate=0
DateColor=\(bgr(110, 110, 110))
DateFont=
DateFontSize=12
DateCenterX=100
DateCenterY=60
""")
}

func makeDarkINI() {
    writeINI(name: "KlokDark", content: """
;Klok Dark — charcoal face with cream hands
[Settings]
CenterX=100
CenterY=100
HourColor=\(bgr(235, 225, 205))
HourLength=55
HourLap=10
HourWidth=4
MinuteColor=\(bgr(220, 210, 190))
MinuteLength=76
MinuteLap=10
MinuteWidth=2.5
SecondColor=\(bgr(205, 100, 40))
SecondLength=87
SecondLap=14
SecondWidth=1.5
DisableAMPM=0
AMPMColor=\(bgr(155, 148, 135))
AMPMFont=
AMPMFontSize=12
AMPMCenterX=100
AMPMCenterY=140
DisableDate=0
DateColor=\(bgr(155, 148, 135))
DateFont=
DateFontSize=12
DateCenterX=100
DateCenterY=60
""")
}

func makeOutlineINI() {
    writeINI(name: "KlokOutline", content: """
;Klok Outline — transparent overlay, dark marks
[Settings]
CenterX=100
CenterY=100
HourColor=\(bgr(30, 30, 30))
HourLength=55
HourLap=10
HourWidth=3.5
MinuteColor=\(bgr(30, 30, 30))
MinuteLength=76
MinuteLap=10
MinuteWidth=2
SecondColor=\(bgr(200, 60, 30))
SecondLength=87
SecondLap=14
SecondWidth=1.5
DisableAMPM=1
DisableDate=1
""")
}

// MARK: - Run

print("Generating default skins into Skins/…")
makeClassic();   makeClassicINI()
makeDark();      makeDarkINI()
makeOutline();   makeOutlineINI()
print("Done.")
