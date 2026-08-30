import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// モチモノのアイコン。
// ホーム画面では60px程度まで縮むので、細い線や文字は使わない。
// アプリの見た目そのもの（横長のタイルが2状態で並ぶ）をシルエットにする。
// 角丸マスクで端が欠けるため、全体を86%に縮めて余白を取る。

let size = 1024.0
let inset = size * 0.07          // 左右上下7% → 中身は86%
let area = size - inset * 2
let cols = 2.0, rows = 3.0
let gap = 34.0
let tileW = (area - gap * (cols - 1)) / cols
let tileH = (area - gap * (rows - 1)) / rows
let radius = tileH * 0.20

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: 1)
}

// 地色。タイルが浮くように暗く沈める。
let ground = rgb(0x11141A)
// 「持った」と「まだ」を、同じ色相の濃淡で並べる。
let tiles: [[UInt32]] = [
    [0x1E63E8, 0x24334F],   // 青：持った / まだ
    [0x1F5136, 0x14A75B],   // 緑：まだ / 持った
    [0xD9820C, 0x4A3418],   // 橙：持った / まだ
]

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("描画コンテキストを作れませんでした\n".utf8))
    exit(1)
}

ctx.setFillColor(ground)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

for (r, row) in tiles.enumerated() {
    for (c, hex) in row.enumerated() {
        let x = inset + Double(c) * (tileW + gap)
        // CoreGraphicsは下が原点。上の行から描くために反転する。
        let y = inset + (rows - 1 - Double(r)) * (tileH + gap)
        let rect = CGRect(x: x, y: y, width: tileW, height: tileH)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                           transform: nil))
        ctx.setFillColor(rgb(hex))
        ctx.fillPath()
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1
              ? CommandLine.arguments[1] : "AppIcon.png")
guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)
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
