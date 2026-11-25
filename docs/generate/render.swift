// Renders the README artwork: icon, launcher icons, banners, stack diagrams, terminal demo frames.
// Run via docs/generate/make.sh (needs Xcode Command Line Tools and ffmpeg).
import AppKit
import SwiftUI

let out = URL(fileURLWithPath: CommandLine.arguments[1])          // docs/
let work = URL(fileURLWithPath: CommandLine.arguments[2])         // scratch dir

enum Lang: String, CaseIterable { case en, ru, zh }
var lang = Lang.en
func tr(_ en: String, _ ru: String, _ zh: String) -> String { lang == .en ? en : lang == .ru ? ru : zh }

// MARK: palette
extension Color {
    static let wine = Color(red: 0.55, green: 0.11, blue: 0.31)
    static let plum = Color(red: 0.33, green: 0.13, blue: 0.52)
    static let indigo = Color(red: 0.14, green: 0.20, blue: 0.55)
    static let cyanX = Color(red: 0.37, green: 0.83, blue: 0.95)
    static let greenX = Color(red: 0.42, green: 0.86, blue: 0.52)
    static let bgA = Color(red: 0.04, green: 0.04, blue: 0.08)
    static let bgB = Color(red: 0.10, green: 0.04, blue: 0.12)
    static let accent = LinearGradient(colors: [.wine, .plum, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
}

@MainActor func save<V: View>(_ v: V, _ url: URL, scale: CGFloat = 2) {
    let r = ImageRenderer(content: v)
    r.scale = scale
    guard let cg = r.cgImage else { print("render failed: \(url.lastPathComponent)"); return }
    try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
}

// MARK: icon
struct Icon: View {
    var badge: String = "gamecontroller.fill"
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(Color.accent)
                .frame(width: 824, height: 824)
                .overlay(
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                )
                .shadow(color: .black.opacity(0.35), radius: 26, y: 12)
            Image(systemName: "wineglass.fill")
                .font(.system(size: 430, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                .offset(x: -70, y: -40)
            ZStack {
                Circle().fill(Color(red: 0.07, green: 0.07, blue: 0.13))
                Circle().strokeBorder(LinearGradient(colors: [.cyanX, .plum], startPoint: .top, endPoint: .bottom), lineWidth: 12)
                Image(systemName: badge).font(.system(size: 150, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 330, height: 330)
            .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
            .offset(x: 205, y: 205)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: terminal
struct Seg { var text: String; var color: Color; var bold = false }
typealias Line = [Seg]

let home = "~/steam-wine-mac"
func prompt(_ cmd: String, _ comment: String = "") -> Line {
    var l: Line = [Seg(text: "\(home) ", color: .cyanX.opacity(0.8)), Seg(text: "$ ", color: .white.opacity(0.5)),
                   Seg(text: cmd, color: .white, bold: true)]
    if !comment.isEmpty { l.append(Seg(text: "   # " + comment, color: .white.opacity(0.4))) }
    return l
}
func say(_ s: String) -> Line { [Seg(text: "==> ", color: .cyanX, bold: true), Seg(text: s, color: .white.opacity(0.92))] }
func ok(_ name: String, _ rest: String = "") -> Line {
    [Seg(text: "✓ ", color: .greenX, bold: true), Seg(text: name, color: .white.opacity(0.92)), Seg(text: rest, color: .white.opacity(0.6))]
}

/// Transcript: typed commands and printed lines, word for word from the winebox script.
let script: [(Line, Bool)] = [   // (line, typed?)
    (prompt("./winebox setup", "one time, about 20 minutes"), true),
    (say("Downloading wine.tar.xz"), false),
    ([Seg(text: String(repeating: "#", count: 58) + " 100.0%", color: .white.opacity(0.35))], false),
    (say("Unpacking libraries"), false),
    (say("Downloading wine-sources.tar.gz"), false),
    (say("Unpacking Wine sources"), false),
    (say("Building Wine (log: \(home)/logs/build-wine.log)"), false),
    (say("Installing DXMT into wine-cx"), false),
    (say("Built: \(home)/runtime/wine-cx"), false),
    (say("Building the dwmapi shim"), false),
    (say("Creating prefix: \(home)/prefix"), false),
    (say("Downloading SteamSetup.exe"), false),
    (say("Installing Steam"), false),
    (say("Done. Next: ./winebox steam   (sign in and install a game)"), false),
    (prompt("./winebox status"), true),
    (ok("Wine    ", "wine-11.0"), false),
    (ok("DXMT"), false),
    (ok("Prefix  ", "\(home)/prefix"), false),
    (ok("Steam"), false),
    (prompt("./winebox deadlock"), true),
    (say("Started. Log: \(home)/logs/steam.log"), false),
]

struct TerminalView: View {
    let lines: [Line]
    var cursor = true
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)
                Spacer()
                Text("winebox — zsh").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Color.clear.frame(width: 52, height: 12)
            }
            .padding(.horizontal, 16).frame(height: 38)
            .background(Color.white.opacity(0.05))
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    HStack(spacing: 0) {
                        ForEach(Array(line.enumerated()), id: \.offset) { _, s in
                            Text(s.text).foregroundStyle(s.color).fontWeight(s.bold ? .bold : .regular)
                        }
                        if cursor && i == lines.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.8)).frame(width: 9, height: 17)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 14.5, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 860, height: 560)
        .background(Color(red: 0.06, green: 0.06, blue: 0.10).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

struct Backdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgA, .bgB], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.wine.opacity(0.55)).frame(width: 620).blur(radius: 160).offset(x: -420, y: -200)
            Circle().fill(Color.indigo.opacity(0.6)).frame(width: 640).blur(radius: 170).offset(x: 480, y: 220)
            Circle().fill(Color.plum.opacity(0.45)).frame(width: 520).blur(radius: 150).offset(x: 60, y: -40)
        }
    }
}

struct DemoFrame: View {
    let lines: [Line]
    var body: some View {
        ZStack {
            Backdrop()
            TerminalView(lines: lines).shadow(color: .black.opacity(0.55), radius: 40, y: 18)
        }
        .frame(width: 980, height: 660)
        .clipped()
    }
}

/// Frames of the typing animation.
func demoFrames() -> [[Line]] {
    var frames: [[Line]] = []
    var done: [Line] = []
    for (line, typed) in script {
        if typed {
            let full = line.map(\.text).joined()
            let promptLen = line[0].text.count + line[1].text.count
            frames.append(done + [Array(line.prefix(2))])
            frames.append(done + [Array(line.prefix(2))])
            var i = 0
            let typedCount = full.count - promptLen
            while i < typedCount {
                i = min(typedCount, i + 2)
                var remaining = i
                var partial: Line = Array(line.prefix(2))
                for s in line.dropFirst(2) {
                    if remaining <= 0 { break }
                    let take = min(remaining, s.text.count)
                    partial.append(Seg(text: String(s.text.prefix(take)), color: s.color, bold: s.bold))
                    remaining -= take
                }
                frames.append(done + [partial])
            }
            done.append(line)
            for _ in 0..<4 { frames.append(done) }
        } else {
            done.append(line)
            frames.append(done)
            frames.append(done)
        }
    }
    for _ in 0..<30 { frames.append(done) }
    return frames
}

// MARK: banner
struct Chip: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(0.08)).overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1)))
    }
}

struct Banner: View {
    let icon: NSImage
    let lines: [Line]
    var body: some View {
        ZStack {
            Backdrop()
            HStack(spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    Image(nsImage: icon).resizable().frame(width: 112, height: 112)
                        .shadow(color: .wine.opacity(0.6), radius: 30, y: 10)
                    Text("steam-wine-mac")
                        .font(.system(size: 60, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(tr("Windows Steam games on Apple Silicon.\nWine + DXMT → Metal. No emulator, no VM.",
                            "Windows-игры из Steam на Apple Silicon.\nWine + DXMT → Metal. Без эмулятора и ВМ.",
                            "在 Apple Silicon 上运行 Windows 版 Steam 游戏。\nWine + DXMT → Metal，无需模拟器或虚拟机。"))
                        .font(.system(size: 23, design: .rounded)).foregroundStyle(.white.opacity(0.72)).lineSpacing(4)
                    HStack(spacing: 10) {
                        Chip(text: "Apple Silicon"); Chip(text: "Wine 11"); Chip(text: "D3D11 → Metal")
                        Chip(text: tr("Open source", "Открытый код", "开源"))
                    }.padding(.top, 6)
                }
                TerminalView(lines: lines, cursor: false)
                    .scaleEffect(0.72)
                    .frame(width: 620, height: 404)
                    .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
                    .rotation3DEffect(.degrees(-10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            }
        }
        .frame(width: 1280, height: 520)
        .clipped()
    }
}

// MARK: stack diagram
struct Layer: View {
    let symbol: String, title: String, text: String
    var highlight = false
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(highlight ? AnyShapeStyle(Color.accent) : AnyShapeStyle(Color.white.opacity(0.1))))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(text).font(.system(size: 13.5, design: .rounded)).foregroundStyle(.white.opacity(0.62))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(highlight ? AnyShapeStyle(Color.accent) : AnyShapeStyle(Color.white.opacity(0.12)), lineWidth: highlight ? 1.5 : 1)))
    }
}

struct Arrow: View {
    var body: some View {
        Image(systemName: "arrow.down").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.35)).frame(height: 18)
    }
}

struct Stack: View {
    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 8) {
                Layer(symbol: "gamecontroller.fill", title: tr("Windows game + Steam client", "Windows-игра + клиент Steam", "Windows 游戏 + Steam 客户端"),
                      text: tr("unchanged x86-64 .exe files", "обычные x86-64 .exe, без изменений", "原版 x86-64 .exe，不做修改"))
                Arrow()
                Layer(symbol: "wineglass.fill", title: "Wine 11.0",
                      text: tr("Windows API → macOS, built from source", "Windows API → macOS, собран из исходников", "Windows API → macOS，从源码构建"), highlight: true)
                Arrow()
                HStack(spacing: 10) {
                    Layer(symbol: "cube.transparent", title: "DXMT", text: "Direct3D 10/11 → Metal", highlight: true)
                    Layer(symbol: "bolt.horizontal.fill", title: "MSync", text: tr("fast thread sync", "быстрая синхронизация потоков", "快速线程同步"))
                }
                Arrow()
                Layer(symbol: "cpu", title: "Rosetta 2", text: "x86-64 → ARM64")
                Arrow()
                Layer(symbol: "laptopcomputer", title: tr("macOS · Metal · Apple GPU", "macOS · Metal · GPU Apple", "macOS · Metal · Apple GPU"),
                      text: tr("native process, no VM", "обычный процесс macOS, без ВМ", "原生进程，无虚拟机"))
            }
            .frame(width: 620)
        }
        .frame(width: 780, height: 600)
        .clipped()
    }
}

// MARK: main
MainActor.assumeIsolated {
    let fm = FileManager.default
    try? fm.createDirectory(at: work, withIntermediateDirectories: true)
    save(Icon(), work.appendingPathComponent("icon-1024.png"), scale: 1)
    save(Icon(badge: "play.fill"), work.appendingPathComponent("icon-play-1024.png"), scale: 1)

    let frames = demoFrames()
    let framesDir = work.appendingPathComponent("frames")
    try? fm.removeItem(at: framesDir)
    try? fm.createDirectory(at: framesDir, withIntermediateDirectories: true)
    for (i, f) in frames.enumerated() {
        save(DemoFrame(lines: f), framesDir.appendingPathComponent(String(format: "f%03d.png", i)), scale: 1)
    }
    let icon = NSImage(contentsOf: work.appendingPathComponent("icon-1024.png"))!
    let finalLines = frames.last ?? []
    for l in Lang.allCases {
        lang = l
        let sfx = l == .en ? "" : "-\(l.rawValue)"
        save(Banner(icon: icon, lines: Array(finalLines.prefix(19))), out.appendingPathComponent("banner\(sfx).png"))
        save(Stack(), out.appendingPathComponent("stack\(sfx).png"))
    }
    print("frames: \(frames.count)")
}
