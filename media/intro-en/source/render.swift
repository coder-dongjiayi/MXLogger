// Native motion graphics renderer. No third-party Swift packages required.
import AppKit
import CoreGraphics
import CoreImage
import Foundation

struct Cue: Decodable { let start: Double; let end: Double; let en: String; let zh: String }
struct Scene: Decodable {
    let id: String; let label: String; let headline: [String]
    let start: Double; let duration: Double; let cues: [Cue]
}
struct Board: Decodable { let width: Int; let height: Int; let fps: Int; let duration: Double; let scenes: [Scene]; let cues: [Cue] }

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("media/intro-en")
let work = out.appendingPathComponent("working")
let board = try JSONDecoder().decode(Board.self, from: Data(contentsOf: work.appendingPathComponent("timeline.json")))
let W = CGFloat(board.width), H = CGFloat(board.height)
let space = CGColorSpaceCreateDeviceRGB()
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255,
        blue: CGFloat(hex & 255)/255, alpha: alpha)
}
let bg = color(0x080C14), panel = color(0x141C2A), border = color(0x293B54)
let blue = color(0x67B5FF), white = color(0xF4F7FC), muted = color(0x95A7BF)
let mint = color(0x71D9BC), purple = color(0xB5A1FF), red = color(0xFF7A83)
func context(_ width: Int = board.width, _ height: Int = board.height) -> CGContext {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1)
    c.interpolationQuality = .high
    return c
}
func layer(_ width: Int = board.width, _ height: Int = board.height, _ draw: (CGContext) -> Void) -> CGImage {
    let c = context(width, height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
    draw(c)
    NSGraphicsContext.restoreGraphicsState()
    return c.makeImage()!
}
func image(_ c: CGContext, _ im: CGImage, _ rect: CGRect) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.maxY); c.scaleBy(x: 1, y: -1)
    c.draw(im, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height)); c.restoreGState()
}
func load(_ path: String) -> CGImage {
    let source = CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ fill: CGColor = white,
          _ weight: NSFont.Weight = .regular, _ maxWidth: CGFloat = 900,
          _ center: Bool = false, _ mono: Bool = false, _ tracking: CGFloat = 0) {
    var fs = size
    func attrs(_ f: CGFloat) -> [NSAttributedString.Key: Any] {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: f, weight: weight)
            : (NSFont(name: weight.rawValue >= NSFont.Weight.bold.rawValue ? "AvenirNext-Bold" : "AvenirNext-Medium", size: f)
                ?? NSFont.systemFont(ofSize: f, weight: weight))
        return [.font: font, .foregroundColor: NSColor(cgColor: fill)!, .kern: tracking]
    }
    while (s as NSString).size(withAttributes: attrs(fs)).width > maxWidth && fs > 18 { fs -= 1 }
    let attributes = attrs(fs)
    let actualWidth = (s as NSString).size(withAttributes: attributes).width
    (s as NSString).draw(at: CGPoint(x: center ? x - actualWidth/2 : x, y: y), withAttributes: attributes)
}
func rect(_ c: CGContext, _ r: CGRect, _ fill: CGColor, _ radius: CGFloat = 0, _ stroke: CGColor? = nil, _ line: CGFloat = 1.5) {
    let p = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    c.addPath(p); c.setFillColor(fill); c.fillPath()
    if let s = stroke { c.addPath(p); c.setStrokeColor(s); c.setLineWidth(line); c.strokePath() }
}
func line(_ c: CGContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ fill: CGColor, _ width: CGFloat = 2) {
    c.setStrokeColor(fill); c.setLineWidth(width); c.move(to: CGPoint(x: x1,y: y1)); c.addLine(to: CGPoint(x: x2,y: y2)); c.strokePath()
}
func pill(_ c: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ fill: CGColor = blue) {
    rect(c, CGRect(x: x,y: y,width: w,height: 64), color(0x14273D), 32, color(0x325374))
    text(s, x+w/2, y+11, 27, fill, .medium, w-24, true)
}
func glow(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ hex: UInt32, _ opacity: CGFloat) {
    let g = CGGradient(colorsSpace: space, colors: [color(hex, opacity),color(hex,0)] as CFArray, locations: [0,1])!
    c.drawRadialGradient(g, startCenter: CGPoint(x: x,y: y), startRadius: 0,
        endCenter: CGPoint(x: x,y: y), endRadius: radius, options: [])
}
let logo = load("flutter_mxlogger/example/assets/mxlogger_logo.png")
let mobile = load("media/intro-en/working/ui/mobile.png")
let filtered = load("media/intro-en/working/ui/mobile-filter.png")
let desktop = load("media/intro-en/working/ui/desktop.png")
let detail = load("media/intro-en/working/ui/detail-mobile.png")

func screen(_ c: CGContext, _ im: CGImage, _ r: CGRect, _ radius: CGFloat = 26) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0,height: 12), blur: 45, color: color(0x000000,0.6))
    rect(c, r.insetBy(dx: -8,dy: -8), color(0x080A10), radius+8, color(0x465873), 2)
    c.restoreGState()
    c.saveGState(); c.addPath(CGPath(roundedRect: r, cornerWidth: radius,cornerHeight: radius,transform: nil)); c.clip()
    image(c,im,r); c.restoreGState()
}

func backdrop(_ scene: Scene, _ index: Int) -> CGImage {
    layer { c in
        c.setFillColor(bg); c.fill(CGRect(x: 0,y: 0,width: W,height: H))
        glow(c, 940, 800, 760, 0x2473D5, 0.15)
        glow(c, 150, 1430, 560, 0x7360DE, 0.09)
        for x in stride(from: CGFloat(0), through: W, by: 90) { line(c,x,200,x,1700,color(0x44638F,0.055),1) }
        for y in stride(from: CGFloat(200), through: 1700, by: 90) { line(c,0,y,W,y,color(0x44638F,0.055),1) }
        image(c,logo,CGRect(x: 86,y: 115,width: 60,height: 60))
        text("MXLogger",166,120,34,white,.bold)
        text(String(format: "%02d / 09", index+1), 850, 130, 23, muted,.regular,160)
        line(c,90,211,990,211,color(0x304158),1)
        text("MXLOGGER  /  CROSS-PLATFORM LOGGING",90,1733,20,muted,.medium,900,false,false,1.2)
    }
}
func title(_ scene: Scene) -> CGImage {
    layer { _ in
        text(scene.label,90,257,24,blue,.bold,900,false,false,2.8)
        text(scene.headline[0],86,320,78,white,.bold,910)
        text(scene.headline[1],86,414,78,scene.id == "hook" ? red : blue,.bold,910)
    }
}

func art(_ id: String, _ alternate: Bool = false) -> CGImage {
    layer { c in
        switch id {
        case "hook":
            glow(c,540,825,400,0xDA4655,0.13)
            rect(c,CGRect(x: 90,y: 628,width: 900,height: 532),panel,30,border)
            for i in 0..<3 { rect(c,CGRect(x: 126+CGFloat(i)*30,y: 656,width: 12,height: 12),i == 0 ? red : muted,6) }
            text("APP LOG",770,645,22,muted,.medium,170)
            let rows: [(String,String,CGColor)] = [
                ("INFO","Checkout started.",mint), ("WARN","Request timed out.",color(0xF3C775)), ("ERROR","Payment failed.",red)]
            for (i,row) in rows.enumerated() {
                let y = CGFloat(720+i*132)
                rect(c,CGRect(x: 116,y: y,width: 848,height: 112),color(0x0C1320),14,i == 2 ? color(0x894450) : color(0x263449))
                text(row.0,141,y+16,23,row.2,.bold,150,false,true)
                text(row.1,141,y+52,34,white,.medium,800,false,true)
            }
            pill(c,"Every record is a clue.",245,1240,590,mint)
        case "brand":
            glow(c,540,803,440,0x4C9BE8,0.19)
            for r: CGFloat in [166,240,310] {
                c.setStrokeColor(color(0x4C9BE8,0.17)); c.setLineWidth(2)
                c.strokeEllipse(in: CGRect(x: 540-r,y: 805-r,width: 2*r,height: 2*r))
            }
            image(c,logo,CGRect(x: 410,y: 670,width: 260,height: 260))
            let names = ["iOS","Android","Flutter"]
            let subs = ["NATIVE","NATIVE","DART FFI"]
            for i in 0..<3 {
                let x = CGFloat(90+i*306)
                rect(c,CGRect(x: x,y: 1090,width: 288,height: 178),panel,24,border)
                text(names[i],x+144,1120,42,white,.bold,260,true)
                text(subs[i],x+144,1193,21,blue,.medium,260,true,false,2)
            }
            text("Shared C / C++ core",540,1360,31,muted,.medium,850,true)
        case "core":
            pill(c,"Flutter → dart:ffi → C++",220,574,640,purple)
            rect(c,CGRect(x: 155,y: 715,width: 770,height: 155),panel,24,border)
            text("YOUR APP",193,738,21,muted,.bold,650,false,false,2)
            text("logger.info('Checkout started');",193,783,31,mint,.regular,698,false,true)
            line(c,540,872,540,958,blue,3)
            rect(c,CGRect(x: 155,y: 960,width: 770,height: 195),color(0x142B44),24,color(0x407CB3))
            text("mmap",540,974,86,blue,.bold,700,true)
            text("Memory-mapped log files",540,1094,29,white,.medium,700,true)
            line(c,540,1158,540,1234,blue,3)
            rect(c,CGRect(x: 230,y: 1237,width: 620,height: 134),panel,22,border)
            text("FlatBuffers  →  .mx",540,1276,42,white,.bold,560,true,true)
        case "storage":
            glow(c,540,821,390,0x4C9BE8,0.12)
            rect(c,CGRect(x: 367,y: 618,width: 346,height: 346),color(0x142A44),40,color(0x467AA5),2)
            c.setStrokeColor(blue); c.setLineWidth(15)
            c.addPath(CGPath(roundedRect: CGRect(x: 471,y: 678,width: 138,height: 131),cornerWidth: 65,cornerHeight: 65,transform: nil)); c.strokePath()
            rect(c,CGRect(x: 443,y: 770,width: 194,height: 135),blue,20)
            rect(c,CGRect(x: 531,y: 807,width: 18,height: 55),bg,9)
            text("AES-CFB-128",540,1014,49,white,.bold,850,true)
            let labels = ["File rotation", "Age limits", "Size limits"]
            for i in 0..<3 {
                let y = CGFloat(1115+i*92)
                rect(c,CGRect(x: 180,y: y,width: 720,height: 75),panel,18,border)
                text("✓",213,y+8,34,mint,.bold,80)
                text(labels[i],270,y+12,32,white,.medium,570)
            }
        case "search":
            let r = CGRect(x: 280,y: 563,width: 462,height: 882)
            screen(c,alternate ? filtered : mobile,r)
            text(".mx",90,625,40,purple,.bold,180,false,true)
            text("IMPORT",90,679,18,muted,.bold,180,false,false,2)
            text("SEARCH",782,740,20,blue,.bold,210,false,false,1.8)
            line(c,753,773,916,773,blue)
            text("FILTER",782,841,20,mint,.bold,210,false,false,1.8)
            text("Level",784,892,27,white,.medium,180)
            text("Time",784,944,27,white,.medium,180)
            text("Name",784,996,27,white,.medium,180)
            text("Tag",784,1048,27,white,.medium,180)
            text("Actual UI · sample records",90,1457,19,muted,.regular,900)
        case "detail":
            screen(c,detail,CGRect(x: 294,y: 563,width: 484,height: 924))
            text("JSON",90,636,32,mint,.bold,185,false,true)
            text("EXPAND",90,686,18,muted,.bold,185,false,false,1.3)
            text("CONTEXT",805,967,18,purple,.bold,188,false,false,1.2)
            text("Before.",805,1010,27,white,.medium,180)
            text("After.",805,1060,27,white,.medium,180)
        case "embed":
            screen(c,desktop,CGRect(x: 92,y: 646,width: 896,height: 612),22)
            rect(c,CGRect(x: 344,y: 1260,width: 392,height: 30),color(0x384B65),8)
            rect(c,CGRect(x: 480,y: 1282,width: 120,height: 73),color(0x293B51),8)
            screen(c,mobile,CGRect(x: 679,y: 890,width: 260,height: 496),25)
            rect(c,CGRect(x: 646,y: 1250,width: 88,height: 88),color(0x184775),44,color(0x67B5FF),2)
            image(c,logo,CGRect(x: 662,y: 1266,width: 56,height: 56))
            pill(c,"macOS  ·  Windows  ·  Linux",155,552,770)
            text("Desktop analyzer + in-app viewer",540,1430,30,muted,.medium,900,true)
        case "code":
            rect(c,CGRect(x: 90,y: 650,width: 900,height: 646),panel,28,border)
            text("FLUTTER / DART",128,686,24,blue,.bold,830,false,false,2)
            line(c,128,744,952,744,border,1)
            let rows: [(String,CGColor)] = [
                ("logger.info(",white),
                ("  'Checkout started',",mint),
                ("  name: 'checkout',",purple),
                ("  tag: 'payment',",blue),
                (");",white)]
            for (i,row) in rows.enumerated() { text(row.0,137,788+CGFloat(i)*72,40,row.1,.regular,790,false,true) }
            text("One useful record. More context.",128,1218,27,muted,.medium,810)
            pill(c,"iOS  ·  Android  ·  Flutter",172,1382,736)
        case "cta":
            glow(c,540,800,420,0x4C9BE8,0.17)
            image(c,logo,CGRect(x: 441,y: 623,width: 198,height: 198))
            text("MXLogger",540,879,69,white,.bold,900,true)
            rect(c,CGRect(x: 153,y: 1020,width: 774,height: 105),color(0x67B5FF),24)
            text("Explore on GitHub  ↗",540,1043,39,bg,.bold,740,true)
            text("github.com",540,1158,31,muted,.medium,900,true)
            text("coder-dongjiayi / MXLogger",540,1204,36,white,.bold,900,true)
            let filter = CIFilter(name: "CIQRCodeGenerator")!
            filter.setValue(Data("https://github.com/coder-dongjiayi/MXLogger".utf8),forKey: "inputMessage")
            filter.setValue("M",forKey: "inputCorrectionLevel")
            if let qr = filter.outputImage, let cg = CIContext(options: nil).createCGImage(qr,from: qr.extent) {
                rect(c,CGRect(x: 447,y: 1292,width: 186,height: 186),color(0xFFFFFF),12)
                c.saveGState(); c.interpolationQuality = .none
                image(c,cg,CGRect(x: 460,y: 1305,width: 160,height: 160)); c.restoreGState()
            }
        default: break
        }
    }
}

let backs = board.scenes.enumerated().map { backdrop($0.element,$0.offset) }
let titles = board.scenes.map { title($0) }
let arts = board.scenes.map { art($0.id) }
let searchAlt = art("search",true)
let captionLayers = board.cues.map { cue in
    layer(940,178) { c in
        rect(c,CGRect(x: 0,y: 0,width: 940,height: 178),color(0x0A111E,0.97),24,color(0x2B405C))
        rect(c,CGRect(x: 0,y: 34,width: 4,height: 110),blue,2)
        text(cue.en,470,23,37,white,.medium,878,true)
        text(cue.zh,470,86,39,color(0xA7D5FF),.medium,878,true)
    }
}
func ease(_ x: Double) -> CGFloat { let t = max(0,min(1,x)); return CGFloat(1-pow(1-t,3)) }
func drawFrame(_ c: CGContext, _ time: Double, _ captions: Bool = true) {
    let index = board.scenes.lastIndex(where: { time >= $0.start }) ?? 0
    let scene = board.scenes[index]
    let local = time-scene.start
    c.saveGState()
    image(c,backs[index],CGRect(x: 0,y: 0,width: W,height: H))
    let leave = min(1,max(0,(scene.duration-local)/0.15))
    c.saveGState(); c.setAlpha(ease(local/0.38)*CGFloat(leave))
    image(c,titles[index],CGRect(x: 0,y: (1-ease(local/0.58))*36,width: W,height: H)); c.restoreGState()
    c.saveGState(); c.setAlpha(ease((local-0.1)/0.42)*CGFloat(leave))
    let sc = 0.965 + 0.035*ease((local-0.1)/0.75) + CGFloat(local/scene.duration)*0.005
    c.translateBy(x: W/2,y: 1010); c.scaleBy(x: sc,y: sc); c.translateBy(x: -W/2,y: -1010)
    let selectedArt = scene.id == "search" && local > scene.duration*0.51 ? searchAlt : arts[index]
    image(c,selectedArt,CGRect(x: 0,y: 0,width: W,height: H)); c.restoreGState()
    if scene.id == "core" && local > 0.6 {
        for offset in [0.0,0.5] {
            let t = (local*0.7+offset).truncatingRemainder(dividingBy: 1)
            let y: CGFloat = t < 0.5 ? 875+CGFloat(t*2)*80 : 1158+CGFloat((t-0.5)*2)*78
            glow(c,540,y,24,0x67B5FF,0.7)
            rect(c,CGRect(x: 534,y: y-6,width: 12,height: 12),white,6)
        }
    }
    if scene.id == "storage" && local > 0.5 {
        let y = 640 + CGFloat((local*0.22).truncatingRemainder(dividingBy: 1))*290
        line(c,387,y,693,y,color(0x8FD9FF,0.35),2)
    }
    if scene.id == "hook" && local > 1 {
        let a = CGFloat(0.4+0.18*sin(local*3))
        rect(c,CGRect(x: 116,y: 984,width: 848,height: 112),color(0,0),14,color(0xFF7A83,a),2)
    }
    if captions, let cueIndex = board.cues.firstIndex(where: { time >= $0.start && time < $0.end+0.045 }) {
        let cue = board.cues[cueIndex]
        c.saveGState(); c.setAlpha(ease((time-cue.start)/0.10))
        image(c,captionLayers[cueIndex],CGRect(x: 70,y: 1526,width: 940,height: 178)); c.restoreGState()
    }
    rect(c,CGRect(x: 90,y: 1792,width: 900,height: 4),color(0x26364D),2)
    rect(c,CGRect(x: 90,y: 1792,width: max(1,900*CGFloat(time/board.duration)),height: 4),blue,2)
    c.restoreGState()
}
func save(_ im: CGImage, _ path: URL, _ jpeg: Bool = false) {
    let destination = CGImageDestinationCreateWithURL(path as CFURL,jpeg ? "public.jpeg" as CFString : "public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(destination,im,jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary : nil)
    precondition(CGImageDestinationFinalize(destination))
}

for (i,scene) in board.scenes.enumerated() {
    let preview = layer { c in drawFrame(c,scene.start+min(1.8,scene.duration*0.5)) }
    save(preview,work.appendingPathComponent(String(format: "preview-%02d.png",i+1)))
}
let contact = layer { c in
    for (i,scene) in board.scenes.enumerated() {
        let im = layer { drawFrame($0,scene.start+min(1.8,scene.duration*0.5)) }
        image(c,im,CGRect(x: CGFloat(i%3)*360,y: CGFloat(i/3)*640,width: 360,height: 640))
    }
}
save(contact,out.appendingPathComponent("MXLogger_storyboard.jpg"),true)
let cover = layer { drawFrame($0,board.scenes[1].start+1.8,false) }
save(cover,out.appendingPathComponent("MXLogger_cover.jpg"),true)
if CommandLine.arguments.contains("--preview") { print("Preview images ready."); exit(0) }

let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/usr/local/Cellar/ffmpeg/9.0.2/bin/ffmpeg")
encoder.arguments = ["-hide_banner","-y","-f","rawvideo","-pixel_format","rgba","-video_size","1080x1920",
    "-framerate",String(board.fps),"-i","pipe:0","-i",work.appendingPathComponent("mix.wav").path,
    "-map","0:v:0","-map","1:a:0","-c:v","libx264","-preset","fast","-crf","19","-threads","4",
    "-pix_fmt","yuv420p","-c:a","aac","-b:a","192k","-ar","48000","-af","loudnorm=I=-16:TP=-1.5:LRA=9",
    "-movflags","+faststart","-metadata","title=MXLogger — Write fast. Debug smarter.",
    "-metadata","comment=English narration with English and Simplified Chinese subtitles. Actual UI with illustrative sample records.",
    out.appendingPathComponent("MXLogger_intro_EN_ZH_vertical.mp4").path]
let pipe = Pipe(); encoder.standardInput = pipe
let log = work.appendingPathComponent("encode.log")
FileManager.default.createFile(atPath: log.path,contents: nil)
encoder.standardError = try FileHandle(forWritingTo: log)
try encoder.run()
let c = context()
let frames = Int(round(board.duration*Double(board.fps)))
for frame in 0..<frames {
    autoreleasepool {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: c,flipped: true)
        drawFrame(c,Double(frame)/Double(board.fps))
        NSGraphicsContext.restoreGraphicsState()
        pipe.fileHandleForWriting.write(Data(bytesNoCopy: c.data!,count: board.width*board.height*4,deallocator: .none))
    }
    if frame%150 == 0 { print("Rendered \(frame) / \(frames) frames"); fflush(stdout) }
}
try pipe.fileHandleForWriting.close()
encoder.waitUntilExit()
guard encoder.terminationStatus == 0 else { fatalError("Encoder failed. See working/encode.log") }
print("Video complete: \(frames) frames / \(board.duration) seconds")
