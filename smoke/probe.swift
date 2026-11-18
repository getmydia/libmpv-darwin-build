// Smoke probe for the video-hdr variant: mpv's macOS video output embedded in
// a host NSView passed as `wid` (patches/mpv-mac-wid-embed.patch).
//
//   probe <clip> [--sleep-displays]
//
// --sleep-displays puts every display to sleep (`pmset displaysleepnow`)
// before the video output starts, so mpv's display link never ticks. The
// probe must still pass: mpv may only pace badly, never block.
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
//   - the host view holds a CAMetalLayer with wantsExtendedDynamicRangeContent;
//   - `display-names` names the host window's screen (mpv follows the host's
//     screen, not the main one), and prints `display-fps`.
//
// Then it resizes the window 40 times, reading `display-names` on the main
// thread after each resize (fails on a deadlock: the VO thread must never
// wait on the main thread while resizing), and checks that `osd-width` x
// `osd-height` then match the host view's size in pixels.
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

let arguments = Array(CommandLine.arguments.dropFirst())
let sleepDisplays = arguments.count == 2 && arguments[1] == "--sleep-displays"
guard arguments.count == 1 || sleepDisplays else {
    FileHandle.standardError.write("usage: probe <clip> [--sleep-displays]\n".data(using: .utf8)!)
    exit(2)
}
let clip = arguments[0]

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

guard let handle = mpv_create() else { fail("mpv_create returned NULL") }
// Only ever used from one queue at a time; libmpv handles are thread-safe.
nonisolated(unsafe) let mpv = handle

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

@Sendable func property(_ name: String) -> String? {
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
    if sleepDisplays {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["displaysleepnow"]
        do { try pmset.run() } catch { fail("pmset displaysleepnow: \(error)") }
        pmset.waitUntilExit()
        sleep(4)
        print("displays asleep: \(CGDisplayIsAsleep(CGMainDisplayID()) != 0)")
    }
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

/// A screen's name as mpv's `display-names` reports it (NSScreen.uniqueName in
/// mpv's osdep/mac/swift_extensions.swift): the localized name without a
/// trailing " (n)", then the display's serial number in parentheses.
func mpvScreenName(_ screen: NSScreen) -> String {
    let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    let name = screen.localizedName.replacingOccurrences(
        of: " \\(\\d+\\)$", with: "", options: .regularExpression)
    return "\(name) (\(CGDisplaySerialNumber(id)))"
}

/// Runs `body` on the mpv queue and waits for it, or nil after `seconds`.
/// A stuck mpv core must fail the probe, not hang it.
final class Box<T>: @unchecked Sendable { var value: T? }
@Sendable func onMpvQueue<T>(within seconds: Double, _ body: @escaping () -> T) -> T? {
    let done = DispatchSemaphore(value: 0)
    let box = Box<T>()
    mpvQueue.async {
        box.value = body()
        done.signal()
    }
    return done.wait(timeout: .now() + seconds) == .success ? box.value : nil
}

func finish(windows: [String], layers: [(String, Bool)], screens: [String], hostScreen: String, hostPixels: String) -> Never {
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
        ["current-vo", "video-target-params/gamma", "display-names", "display-fps", "osd-width", "osd-height"].map {
            property($0) ?? ""
        }
    }
    if let props {
        let (vo, gamma, displayNames, displayFps) = (props[0], props[1], props[2], props[3])
        print("current-vo=\(vo)")
        print("video-target-params/gamma=\(gamma)")
        print("display-names=\(displayNames)")
        print("display-fps=\(displayFps)")
        print("host window screen=\(hostScreen)")
        let osd = "\(props[4])x\(props[5])"
        print("osd size=\(osd), host view pixels=\(hostPixels)")
        if osd != hostPixels {
            failures.append("osd size is \(osd), expected the host view's \(hostPixels) pixels")
        }
        if vo != "gpu-next" { failures.append("current-vo is '\(vo)', expected 'gpu-next'") }
        if gamma != "pq" { failures.append("video-target-params/gamma is '\(gamma)', expected 'pq'") }
        if displayNames != hostScreen {
            failures.append("display-names is '\(displayNames)', expected the host window's screen '\(hostScreen)'")
        }

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

// 5 s after attaching (which waits 4 s for the displays to sleep first)
DispatchQueue.main.asyncAfter(deadline: .now() + (sleepDisplays ? 9 : 5)) {
    let (windows, layers, hostScreen) = MainActor.assumeIsolated {
        (onScreenWindows(), metalLayers(under: host), window.screen.map(mpvScreenName) ?? "none")
    }
    let screens = NSScreen.screens.map {
        "\($0.localizedName) edr=\($0.maximumExtendedDynamicRangeColorComponentValue)"
            + " potential=\($0.maximumPotentialExtendedDynamicRangeColorComponentValue)"
    }
    resizeStress(step: 0) {
        // let the last resize reach mpv before reading its size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let hostPixels = MainActor.assumeIsolated {
                let size = host.convertToBacking(host.bounds).size
                return "\(Int(size.width))x\(Int(size.height))"
            }
            DispatchQueue.global().async {
                finish(windows: windows, layers: layers, screens: screens,
                       hostScreen: hostScreen, hostPixels: hostPixels)
            }
        }
    }
}

// A host app may read properties synchronously on the main thread while its
// window resizes. `display-names` is answered by the VO thread, so if the VO
// thread waits on the main thread while resizing, this can deadlock. The read
// runs in a frame-change observer added after mpv's, so it comes right after
// mpv has flagged the resize to its VO thread; another follows 10 ms later.
let resizeSteps = 40
let resizeDeadline = DispatchWorkItem {
    fail("deadlock: a main-thread read of display-names during host resizes did not return within 20 s")
}
nonisolated(unsafe) var resizeObserver: NSObjectProtocol?
func resizeStress(step: Int, then done: @escaping () -> Void) {
    if step == 0 {
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: resizeDeadline)
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: nil, queue: .main
        ) { note in
            if MainActor.assumeIsolated({ (note.object as? NSView)?.superview === host }) {
                _ = property("display-names")
            }
        }
    }
    if step == resizeSteps {
        resizeDeadline.cancel()
        resizeObserver.map { NotificationCenter.default.removeObserver($0) }
        print("resize stress: \(resizeSteps) resizes with main-thread reads, ok")
        done()
        return
    }
    MainActor.assumeIsolated {
        let small = step % 2 == 1
        window.setContentSize(NSSize(width: small ? 640 : 960, height: small ? 360 : 540))
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        _ = property("display-names")
        resizeStress(step: step + 1, then: done)
    }
}

app.run()
