import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// モチモノのアイコン。
//
// **かばんのシルエットにした。** チェックマークだけのアイコンはToDoアプリと区別が付かず、
// タイルを並べただけでは何のアプリか伝わらない。かばんなら、他のアプリと並んだときに
// 「持ち物のやつだ」と指が覚える。
//
// ホーム画面では60px程度まで縮むので、細い線や文字は使わない。
// 中身のタイルは、アプリの画面（グループごとに色が変わる）と地続きにしてある。
// 角丸マスクで端が欠けるため、全体を86%に縮めて余白を取る。

let S = 1024.0
let inset = S * 0.07
let area = S - inset * 2

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: 1)
}
/// 0...1 を中身の座標へ。yは上が0。
func ux(_ x: Double) -> Double { inset + x * area }
func uy(_ y: Double) -> Double { inset + (1 - y) * area }

let ground = rgb(0xF3F4F7)
let bagColor = rgb(0x1B2331)
/// 中身。アプリの配色（カラフル）の1〜3番目のグループに合わせる。
let contents: [UInt32] = [0x2C7BF0, 0x14A75B, 0xF0A32B]

guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("描画コンテキストを作れませんでした\n".utf8))
    exit(1)
}
ctx.setFillColor(ground)
ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))

// 持ち手。細いと60pxで消えるので、思い切って太くする。
ctx.setStrokeColor(bagColor)
ctx.setLineWidth(0.095 * area)
ctx.setLineCap(.round)
ctx.addArc(center: CGPoint(x: ux(0.5), y: uy(0.31)), radius: 0.205 * area,
           startAngle: 0, endAngle: .pi, clockwise: false)
ctx.strokePath()

// 本体
let body = CGRect(x: ux(0.05), y: uy(0.98), width: 0.90 * area, height: 0.65 * area)
ctx.addPath(CGPath(roundedRect: body, cornerWidth: 0.10 * area, cornerHeight: 0.10 * area,
                   transform: nil))
ctx.setFillColor(bagColor)
ctx.fillPath()

// 中身のタイル
let tileW = 0.21, tileH = 0.32, gap = 0.045
let startX = (1 - (Double(contents.count) * tileW + Double(contents.count - 1) * gap)) / 2
for (i, hex) in contents.enumerated() {
    let x = startX + Double(i) * (tileW + gap)
    let rect = CGRect(x: ux(x), y: uy(0.48 + tileH), width: tileW * area, height: tileH * area)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: tileW * area * 0.28,
                       cornerHeight: tileW * area * 0.28, transform: nil))
    ctx.setFillColor(rgb(hex))
    ctx.fillPath()
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
              ? CommandLine.arguments[1] : "AppIcon.png")
guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString,
                                                 1, nil)
else {
    FileHandle.standardError.write(Data("書き出しに失敗しました\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("PNGを閉じられませんでした\n".utf8))
    exit(1)
}
print("書き出しました: \(out.path)")
