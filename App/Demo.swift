// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Patrick Saade

#if DEBUG
    import AnalyzeKit
    import AppKit
    import CleanKit
    import ImageIO
    import OptimizeKit
    import PersistenceKit
    import StatusKit
    import SwiftUI
    import UniformTypeIdentifiers
    import UninstallKit

    /// `MacPat -MacPatDemo <folder>` renders each module with fixture data, writes PNGs and GIFs, and quits.
    /// The views are the real ones. Only the data is made up.
    @MainActor
    enum Demo {
        static let size = CGSize(width: 960, height: 640)

        static func runIfAsked() {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-MacPatDemo"), i + 1 < args.count else { return }
            let out = URL(filePath: args[i + 1])
            DispatchQueue.main.async {
                Task {
                    await render(to: out)
                    NSApp.terminate(nil)
                }
            }
        }

        static func render(to out: URL) async {
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let shots: [(String, () async -> AnyView)] = [
                ("clean", { await CleanDemo.view() }),
                ("persistence", { await PersistenceDemo.view() }),
                ("uninstall", { await UninstallDemo.view() }),
                ("analyze", { await AnalyzeDemo.view() }),
                ("status", { StatusDemo.view() }),
                ("optimize", { await OptimizeDemo.view() }),
            ]
            for (id, make) in shots {
                for dark in [false, true] {
                    if let image = await capture(RootView(demo: id, view: await make()), dark: dark) {
                        write(png: image, to: out.appending(path: "\(id)-\(dark ? "dark" : "light").png"))
                    }
                }
            }
            for dark in [false, true] {
                let suffix = dark ? "dark" : "light"
                let clean = [
                    await CleanDemo.view(expanded: [], preview: false), await CleanDemo.view(preview: false), await CleanDemo.view(),
                    await CleanDemo.view(commands: true),
                ]
                await gif(clean.map { RootView(demo: "clean", view: $0) }, dark: dark, to: out.appending(path: "clean-flow-\(suffix).gif"))
                let persist = [await PersistenceDemo.view(preview: false, commands: false), await PersistenceDemo.view()]
                await gif(
                    persist.map { RootView(demo: "persistence", view: $0) }, dark: dark,
                    to: out.appending(path: "persistence-flow-\(suffix).gif"))
                let uninstall = [await UninstallDemo.view(preview: false), await UninstallDemo.view()]
                await gif(
                    uninstall.map { RootView(demo: "uninstall", view: $0) }, dark: dark,
                    to: out.appending(path: "uninstall-flow-\(suffix).gif"))
            }
        }

        /// Draws the view in an off-screen window and copies its pixels. No screen recording involved.
        static func capture(_ view: some View, dark: Bool) async -> CGImage? {
            let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderFrontRegardless()
            try? await Task.sleep(for: .milliseconds(600))
            host.layoutSubtreeIfNeeded()
            defer { window.orderOut(nil) }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
            host.cacheDisplay(in: host.bounds, to: rep)
            return rep.cgImage
        }

        static func write(png image: CGImage, to url: URL) {
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }

        static func gif(_ views: [some View], dark: Bool, to url: URL) async {
            var frames: [CGImage] = []
            for view in views { if let image = await capture(view, dark: dark) { frames.append(image) } }
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
                return
            }
            CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for frame in frames {
                CGImageDestinationAddImage(
                    dest, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.6]] as CFDictionary)
            }
            CGImageDestinationFinalize(dest)
        }
    }
#endif
