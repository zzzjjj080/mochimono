import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 生スクリーンショットに見出しを載せて、掲載枠の寸法に組む。
//
// **1枚目はテキストと盤面を並べる。** このアプリの芯は「書いたテキストが盤面になる」ことで、
// 盤面だけを見せると、よくあるチェックリストと区別が付かない。
//
//   swiftc -O MakeScreenshots.swift -o /tmp/makeshots
//   /tmp/makeshots raw out            # 6.9インチ
//   /tmp/makeshots raw out-65 1242 2688

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("使い方: makeshots <生の入力> <出力先> [幅 高さ]\n".utf8))
    exit(1)
}
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let W = args.count > 4 ? Double(args[3])! : 1320
let H = args.count > 4 ? Double(args[4])! : 2868
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

struct Shot {
    let out: String
    let files: [String]          // 1枚 or 2枚
    let lines: [String]
    let ground: UInt32
}
let shots = [
    Shot(out: "01-concept", files: ["text", "board"],
         lines: ["書いたテキストが、", "そのまま盤面になる"], ground: 0x2C7BF0),
    Shot(out: "02-tap", files: ["board"],
         lines: ["タップで埋める。", "残りがひと目で分かる"], ground: 0x117C46),
    Shot(out: "03-paste", files: ["paste"],
         lines: ["ほかのアプリの箇条書きを、", "貼るだけ"], ground: 0x1B2331),
    Shot(out: "04-export", files: ["export"],
         lines: ["盤面はテキストに戻せる。", "渡した相手も同じ盤面に"], ground: 0xC97A08),
    Shot(out: "05-lists", files: ["home"],
         lines: ["リストごとに色が違うから、", "見ただけで分かる"], ground: 0x6D3FD6),
]

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: 1)
}
func load(_ name: String) -> CGImage? {
    let url = inDir.appendingPathComponent("\(name).png") as CFURL
    guard let src = CGImageSourceCreateWithURL(url, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

for shot in shots {
    let images = shot.files.compactMap { load($0) }
    guard images.count == shot.files.count else {
        FileHandle.standardError.write(Data("素材が足りません: \(shot.files)\n".utf8))
        exit(1)
    }
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(rgb(shot.ground))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let fontSize = W * 0.058
    let font = CTFontCreateWithName("HiraginoSans-W6" as CFString, fontSize, nil)
    var y = H - W * 0.11
    for line in shot.lines {
        let attrs: [CFString: Any] = [kCTFontAttributeName: font,
                                      kCTForegroundColorAttributeName: rgb(0xFFFFFF)]
        let ct = CTLineCreateWithAttributedString(
            NSAttributedString(string: line,
                               attributes: attrs as! [NSAttributedString.Key: Any]))
        let b = CTLineGetBoundsWithOptions(ct, .useOpticalBounds)
        ctx.textPosition = CGPoint(x: (W - b.width) / 2, y: y)
        CTLineDraw(ct, ctx)
        y -= fontSize * 1.42
    }

    func draw(_ image: CGImage, in rect: CGRect, radius: Double) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.008), blur: W * 0.02,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                           transform: nil))
        ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                           transform: nil))
        ctx.clip(); ctx.draw(image, in: rect); ctx.restoreGState()
    }

    let top = y - fontSize * 0.9
    if images.count == 1 {
        let scale = W * 0.80 / Double(images[0].width)
        let w = Double(images[0].width) * scale, h = Double(images[0].height) * scale
        draw(images[0], in: CGRect(x: (W - w) / 2, y: top - h, width: w, height: h),
             radius: W * 0.045)
    } else {
        // 2枚並べて、あいだに矢印。左が書いたもの、右がその結果
        let gap = W * 0.085
        let each = (W * 0.90 - gap) / 2
        let scale = each / Double(images[0].width)
        let h = Double(images[0].height) * scale
        let left = CGRect(x: (W - (each * 2 + gap)) / 2, y: top - h, width: each, height: h)
        let right = CGRect(x: left.maxX + gap, y: top - h, width: each, height: h)
        draw(images[0], in: left, radius: W * 0.03)
        draw(images[1], in: right, radius: W * 0.03)
        let arrow = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, W * 0.075, nil)
        let attrs: [CFString: Any] = [kCTFontAttributeName: arrow,
                                      kCTForegroundColorAttributeName: rgb(0xFFFFFF)]
        let ct = CTLineCreateWithAttributedString(
            NSAttributedString(string: "▶", attributes: attrs as! [NSAttributedString.Key: Any]))
        let b = CTLineGetBoundsWithOptions(ct, .useOpticalBounds)
        ctx.textPosition = CGPoint(x: left.maxX + gap / 2 - b.width / 2,
                                   y: left.midY - b.height / 2)
        CTLineDraw(ct, ctx)
    }

    let out = outDir.appendingPathComponent("\(shot.out).png")
    let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString,
                                               1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("書き出し失敗: \(out.path)\n".utf8)); exit(1)
    }
    print("\(shot.out).png  \(Int(W))x\(Int(H))")
}
