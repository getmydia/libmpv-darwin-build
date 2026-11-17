// Smoke probe for the video-hdr variant: mpv's macOS video output embedded in
// a host NSView passed as `wid` (patches/mpv-mac-wid-embed.patch).
//
//   probe <clip>
//
// It follows the order a host app uses at runtime (media_kit creates and
// initializes mpv with `vid=no` long before a view exists):
//
//   1. mpv_create, `vid=no`, mpv_initialize.
//   2. An NSWindow with a host NSView.
//   3. On a background queue: `wid` = the host view, `vo=gpu-next`,
//      `gpu-api=vulkan`, `gpu-context=macvk`, `target-colorspace-hint=yes`,
//      `hwdec=videotoolbox`, then `vid=auto`, then `loadfile <clip>`.
//
// After 5 s it checks that:
//   - `current-vo` is `gpu-next`;
//   - `video-target-params/gamma` is `pq`;
//   - the process has exactly one on-screen window (mpv opened none of its own);
//   - the host view holds a CAMetalLayer with wantsExtendedDynamicRangeContent.
//
// Teardown, also on the background queue: `vid=no`, wait (at most 3 s) for
// `current-vo` to empty, then mpv_terminate_destroy. mpv's mac output does
// DispatchQueue.main.sync while it is created and destroyed, so none of these
// calls may run on the main thread.
//
// Exits 0 when every check passes, 1 with a message otherwise.

import AppKit
import CoreGraphics
import Mpv
import QuartzCore

setvbuf(stdout, nil, _IOLBF, 0)

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: probe <clip>\n".data(using: .utf8)!)
    exit(2)
}
let clip = CommandLine.arguments[1]

func fail(_ message: String) -> Never {
    print("FAIL: \(message)")
    exit(1)
}

// A hang (for example a main-thread deadlock in mpv) must fail, not stall CI.
DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
    fail("timed out after 60 s")
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

guard let mpv = mpv_create() else { fail("mpv_create returned NULL") }

func check(_ what: String, _ code: Int32) {
    if code < 0 {
        fail("\(what): \(String(cString: mpv_error_string(code)))")
    }
}

func setOption(_ name: String, _ value: String) {
    check("set option \(name)=\(value)", mpv_set_option_string(mpv, name, value))
}

func setProperty(_ name: String, _ value: String) {
    check("set property \(name)=\(value)", mpv_set_property_string(mpv, name, value))
}

func property(_ name: String) -> String? {
    guard let c = mpv_get_property_string(mpv, name) else { return nil }
    defer { mpv_free(c) }
    return String(cString: c)
}

// 1. Created and initialized with no video output, as media_kit does.
setOption("vid", "no")
setOption("terminal", "yes")
setOption("msg-level", "all=warn,vo=v")
setOption("loop-file", "inf")
check("mpv_initialize", mpv_initialize(mpv))

// 2. The host window and view.
let window = NSWindow(
    contentRect: NSRect(x: 100, y: 100, width: 960, height: 540),
    styleMask: [.titled, .resizable, .closable], backing: .buffered, defer: false)
let host = NSView(frame: window.contentView!.bounds)
host.autoresizingMask = [.width, .height]
host.wantsLayer = true
host.layer?.backgroundColor = NSColor.black.cgColor
window.contentView!.addSubview(host)
// On the screen with the most EDR headroom: mpv only targets PQ on one.
if let screen = NSScreen.screens.max(by: {
    $0.maximumPotentialExtendedDynamicRangeColorComponentValue
        < $1.maximumPotentialExtendedDynamicRangeColorComponentValue
}) {
    window.setFrameOrigin(NSPoint(x: screen.visibleFrame.minX + 100, y: screen.visibleFrame.minY + 100))
}
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

let hostPointer = Int(bitPattern: Unmanaged.passUnretained(host).toOpaque())
let mpvQueue = DispatchQueue(label: "probe.mpv")

// 3. Attach at runtime, off the main thread.
mpvQueue.async {
    setProperty("wid", String(hostPointer))
    setProperty("vo", "gpu-next")
    setProperty("gpu-api", "vulkan")
    setProperty("gpu-context", "macvk")
    setProperty("target-colorspace-hint", "yes")
    setProperty("hwdec", "videotoolbox")
    setProperty("vid", "auto")
    clip.withCString { path in
        var args: [UnsafePointer<CChar>?] = [("loadfile" as NSString).utf8String, path, nil]
        check("loadfile", mpv_command(mpv, &args))
    }
}

/// Every on-screen, normal-level window owned by this process.
@MainActor func onScreenWindows() -> [String] {
    let pid = ProcessInfo.processInfo.processIdentifier
    let all =
        CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.filter {
        ($0[kCGWindowOwnerPID as String] as? Int32) == pid
            && ($0[kCGWindowLayer as String] as? Int) == 0
    }.map { info in
        let bounds = (info[kCGWindowBounds as String] as? NSDictionary)
            .flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) }
        return "#\(info[kCGWindowNumber as String] ?? "?") \(bounds.map { "\($0)" } ?? "?")"
    }
}

/// Every CAMetalLayer in the view tree under `view`, including sublayers, as
/// (description, wantsExtendedDynamicRangeContent).
@MainActor func metalLayers(under view: NSView) -> [(String, Bool)] {
    func walk(_ layer: CALayer) -> [(String, Bool)] {
        let own = (layer as? CAMetalLayer).map {
            [("\(type(of: $0)) edr=\($0.wantsExtendedDynamicRangeContent)"
                + " format=\($0.pixelFormat.rawValue)"
                + " colorspace=\($0.colorspace?.name as String? ?? "nil")",
              $0.wantsExtendedDynamicRangeContent)]
        } ?? []
        return own + (layer.sublayers ?? []).flatMap(walk)
    }
    return (view.layer.map(walk) ?? []) + view.subviews.flatMap { metalLayers(under: $0) }
}

/// Runs `body` on the mpv queue and waits for it, or nil after `seconds`.
/// A stuck mpv core must fail the probe, not hang it.
final class Box<T>: @unchecked Sendable { var value: T? }
func onMpvQueue<T>(within seconds: Double, _ body: @escaping () -> T) -> T? {
    let done = DispatchSemaphore(value: 0)
    let box = Box<T>()
    mpvQueue.async {
        box.value = body()
        done.signal()
    }
    return done.wait(timeout: .now() + seconds) == .success ? box.value : nil
}

func finish(windows: [String], layers: [(String, Bool)], screens: [String]) -> Never {
    var failures: [String] = []

    print("on-screen windows: \(windows.count)")
    windows.forEach { print("  \($0)") }
    print("metal layers under host: \(layers.count)")
    layers.forEach { print("  \($0.0)") }
    print("screens: \(screens.joined(separator: ", "))")

    if windows.count != 1 {
        failures.append("\(windows.count) on-screen windows, expected 1 (mpv opened its own)")
    }
    if !layers.contains(where: { $0.1 }) {
        failures.append("no CAMetalLayer with wantsExtendedDynamicRangeContent under the host view")
    }

    let props = onMpvQueue(within: 3) {
        (property("current-vo") ?? "", property("video-target-params/gamma") ?? "")
    }
    if let (vo, gamma) = props {
        print("current-vo=\(vo)")
        print("video-target-params/gamma=\(gamma)")
        if vo != "gpu-next" { failures.append("current-vo is '\(vo)', expected 'gpu-next'") }
        if gamma != "pq" { failures.append("video-target-params/gamma is '\(gamma)', expected 'pq'") }

        // Teardown: drop the video output, wait for it to go, then destroy.
        let teardown = onMpvQueue(within: 10) { () -> String? in
            var problem: String?
            setProperty("vid", "no")
            let deadline = Date().addingTimeInterval(3)
            while let vo = property("current-vo"), !vo.isEmpty {
                if Date() > deadline {
                    problem = "current-vo still '\(vo)' 3 s after vid=no"
                    break
                }
                usleep(20_000)
            }
            mpv_terminate_destroy(mpv)
            return problem
        }
        switch teardown {
        case .none: failures.append("teardown did not finish within 10 s")
        case .some(.some(let problem)): failures.append(problem)
        case .some(.none): print("teardown: ok")
        }
    } else {
        failures.append("mpv did not answer a property read within 3 s (its core is blocked)")
    }

    if !failures.isEmpty {
        failures.forEach { print("FAIL: \($0)") }
        exit(1)
    }
    print("PASS")
    exit(0)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    let (windows, layers) = MainActor.assumeIsolated {
        (onScreenWindows(), metalLayers(under: host))
    }
    let screens = NSScreen.screens.map {
        "\($0.localizedName) edr=\($0.maximumExtendedDynamicRangeColorComponentValue)"
            + " potential=\($0.maximumPotentialExtendedDynamicRangeColorComponentValue)"
    }
    DispatchQueue.global().async {
        finish(windows: windows, layers: layers, screens: screens)
    }
}

app.run()
