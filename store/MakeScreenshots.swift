import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 生スクリーンショットに見出しを載せて、掲載枠の寸法に組む。
//
// **寸法は欄に表示されているものしか受け付けない。** 引数で渡せるようにしてあるのは、
// 6.9インチ(1320x2868)と6.5インチ(1242x2688)の両方を作るため。
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
    let file: String
    let lines: [String]
    let ground: UInt32
    let ink: UInt32
}
let shots = [
    Shot(file: "01-home", lines: ["用途ごとに、", "リストを持てる"], ground: 0x2C7BF0, ink: 0xFFFFFF),
    Shot(file: "02-grid", lines: ["タップで埋める。", "残りがひと目で分かる"], ground: 0x117C46, ink: 0xFFFFFF),
    Shot(file: "03-edit", lines: ["テキストで書くだけ。", "空行を入れると色が分かれる"], ground: 0x1B2331, ink: 0xFFFFFF),
    Shot(file: "04-palette", lines: ["配色はリストごとに", "8種類から選べる"], ground: 0xC97A08, ink: 0xFFFFFF),
    Shot(file: "05-presets", lines: ["旅行も通勤も点検も。", "12種類の雛形つき"], ground: 0x6D3FD6, ink: 0xFFFFFF),
]

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: 1)
}
func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

for shot in shots {
    let src = inDir.appendingPathComponent("\(shot.file).png")
    guard let phone = load(src) else {
        FileHandle.standardError.write(Data("読めません: \(src.path)\n".utf8))
        exit(1)
    }
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(rgb(shot.ground))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // 見出し。上に置いて、下に端末の画面を大きく見せる。
    let fontSize = W * 0.062
    let font = CTFontCreateWithName("HiraginoSans-W6" as CFString, fontSize, nil)
    var y = H - W * 0.115
    for line in shot.lines {
        let attrs: [CFString: Any] = [kCTFontAttributeName: font,
                                      kCTForegroundColorAttributeName: rgb(shot.ink)]
        let ct = CTLineCreateWithAttributedString(
            NSAttributedString(string: line,
                               attributes: attrs as! [NSAttributedString.Key: Any]))
        let bounds = CTLineGetBoundsWithOptions(ct, .useOpticalBounds)
        ctx.textPosition = CGPoint(x: (W - bounds.width) / 2, y: y)
        CTLineDraw(ct, ctx)
        y -= fontSize * 1.42
    }

    // 端末の画面。角丸で切り抜き、下端は枠外へ逃がして「続いている」感じにする。
    let scale = W * 0.80 / Double(phone.width)
    let pw = Double(phone.width) * scale, ph = Double(phone.height) * scale
    let rect = CGRect(x: (W - pw) / 2, y: y - fontSize * 0.9 - ph, width: pw, height: ph)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.008), blur: W * 0.02,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: W * 0.045, cornerHeight: W * 0.045,
                       transform: nil))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: W * 0.045, cornerHeight: W * 0.045,
                       transform: nil))
    ctx.clip()
    ctx.draw(phone, in: rect)
    ctx.restoreGState()

    let out = outDir.appendingPathComponent("\(shot.file).png")
    let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString,
                                               1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("書き出し失敗: \(out.path)\n".utf8))
        exit(1)
    }
    print("\(out.lastPathComponent)  \(Int(W))x\(Int(H))")
}
