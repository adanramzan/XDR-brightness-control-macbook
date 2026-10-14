// XDR Brightness — GPL-3.0. Metal overlay adapted from BrightXDR by Dmitry Starkov.
import AppKit
import MetalKit
import Darwin

final class NativeBrightness {
    typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias Set = @convention(c) (UInt32, Float) -> Int32
    private let library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    func read(_ id: UInt32) -> Float? {
        guard let library, let symbol = dlsym(library, "DisplayServicesGetBrightness") else { return nil }
        var value: Float = 0
        guard unsafeBitCast(symbol, to: Get.self)(id, &value) == 0, value.isFinite else { return nil }
        return value
    }

    func write(_ value: Float, to id: UInt32) -> Bool {
        guard value.isFinite, let library, let symbol = dlsym(library, "DisplayServicesSetBrightness") else { return false }
        return unsafeBitCast(symbol, to: Set.self)(id, min(1, max(0, value))) == 0
    }
}

/// Brightness HUD for the XDR range. macOS 27 only shows its own HUD when hardware brightness changes
/// (the old OSD.framework call is silently ignored), so consumed F1/F2 presses draw this lookalike instead.
final class BrightnessHUD {
    private let size = NSSize(width: 300, height: 64)
    private let title = NSTextField(labelWithString: "XDR Brightness")
    private let detail = NSTextField(labelWithString: "")
    private let track = NSView()
    private let fill = NSView()
    private lazy var panel = makePanel()
    private var hideWork: DispatchWorkItem?
    var isVisible: Bool { panel.isVisible }

    func show(level: Double, nits: Double, on screen: NSScreen) {
        detail.stringValue = "≈\(Int(nits.rounded())) nits"
        fill.frame.size.width = track.bounds.width * min(1, max(0, level.isFinite ? level : 0))
        // Same spot as the system HUD: centered under the menu bar.
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 8))
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 },
                                                 completionHandler: { if panel.alphaValue == 0 { panel.orderOut(nil) } })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.appearance = NSAppearance(named: .darkAqua)

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 16, y: 38, width: 150, height: 18)
        detail.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.alignment = .right
        detail.frame = NSRect(x: 150, y: 38, width: 134, height: 18)
        let small = NSImageView(image: NSImage(systemSymbolName: "sun.min", accessibilityDescription: nil)!)
        small.frame = NSRect(x: 12, y: 10, width: 18, height: 18)
        let large = NSImageView(image: NSImage(systemSymbolName: "sun.max", accessibilityDescription: nil)!)
        large.frame = NSRect(x: 270, y: 9, width: 20, height: 20)
        for icon in [small, large] { icon.contentTintColor = .white }
        track.frame = NSRect(x: 38, y: 16, width: 224, height: 6)
        fill.frame = NSRect(x: 0, y: 0, width: 0, height: 6)
        for (bar, alpha) in [(track, 0.3), (fill, 1.0)] {
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 3
            bar.layer?.backgroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
        }
        track.addSubview(fill)
        [title, detail, small, large, track].forEach(content.addSubview)

        #if compiler(>=6.2) // NSGlassEffectView needs the macOS 26 SDK (Xcode 26).
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: content.frame)
            glass.cornerRadius = 22
            glass.contentView = content
            panel.contentView = glass
            return panel
        }
        #endif
        let blur = NSVisualEffectView(frame: content.frame)
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true
        blur.addSubview(content)
        panel.contentView = blur
        return panel
    }
}

/// A 1×1 EDR trigger: keeps the display in EDR mode so a gamma table above 1.0 can use the headroom.
/// A full-screen multiply overlay turns white during Space swipes and window animations.
final class BoostView: MTKView, MTKViewDelegate {
    private var queue: MTLCommandQueue?
    private(set) var completedFrames = 0
    private(set) var renderError: String?
    private(set) var gain: Double

    init?(frame: NSRect, gain: Double) {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        self.gain = gain
        super.init(frame: frame, device: device)
        self.queue = queue
        colorPixelFormat = .rgba16Float
        colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        clearColor = MTLClearColor(red: gain, green: gain, blue: gain, alpha: 1)
        preferredFramesPerSecond = 2
        autoResizeDrawable = false
        drawableSize = CGSize(width: 1, height: 1)
        guard let metalLayer = layer as? CAMetalLayer else { return nil }
        metalLayer.wantsExtendedDynamicRangeContent = true
        metalLayer.isOpaque = false
        delegate = self
    }

    required init(coder: NSCoder) { fatalError("Not used") }

    func setGain(_ value: Double) {
        gain = value
        clearColor = MTLClearColor(red: value, green: value, blue: value, alpha: 1)
        draw()
    }

    func draw(in view: MTKView) {
        guard let descriptor = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let buffer = queue?.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.addCompletedHandler { [weak self] command in
            DispatchQueue.main.async {
                if command.status == .completed { self?.completedFrames += 1 }
                else { self?.renderError = command.error?.localizedDescription ?? "Metal rendering failed" }
            }
        }
        buffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

final class BoostWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let native = NativeBrightness()
    private let keys = BrightnessKeys()
    private let hud = BrightnessHUD()
    private var baseGamma: [[CGGammaValue]]?
    private var gammaFactor = 1.0
    private var keyPermissionItem: NSMenuItem!
    private var keyRetryTimer: Timer?
    private var status: NSStatusItem!
    private var boostSlider: NSSlider!
    private var boostLabel: NSTextField!
    private var scrollMonitor: Any?
    private var statusTimer: Timer?
    private var menuOpen = false
    private var boostPanel: NSView!
    private var slider: NSSlider!
    private var label: NSTextField!
    private var notice: NSMenuItem!
    private var window: BoostWindow?
    private var metal: BoostView?
    private var screen: NSScreen?
    private var displayID: UInt32?
    private var boostLevel = 0.0
    private var enabled: Bool { boostLevel > 0 }
    private var suspended = false
    private var brightnessTimer: Timer?
    private let selfTest = CommandLine.arguments.contains("--self-test")
    private var originalBrightness: Float?
    private var gainChangeVerified = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "XDR Brightness")
        status.button?.toolTip = "XDR Brightness"
        let menu = NSMenu()
        menu.delegate = self
        status.button?.title = ""
        status.button?.toolTip = "XDR Brightness"
        boostPanel = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 58))
        boostLabel = NSTextField(labelWithString: "XDR brightness")
        boostLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        boostLabel.toolTip = "Estimated luminance. Scroll inside this popup or drag the slider to adjust XDR boost."
        boostLabel.frame = NSRect(x: 18, y: 34, width: 214, height: 18)
        boostPanel.addSubview(boostLabel)
        boostSlider = NSSlider(value: boostLevel, minValue: 0, maxValue: 1, target: self, action: #selector(changeBoost))
        boostSlider.frame = NSRect(x: 18, y: 8, width: 214, height: 24)
        boostSlider.setAccessibilityLabel("XDR boost")
        boostSlider.isContinuous = true
        boostPanel.addSubview(boostSlider)
        let boostRow = NSMenuItem()
        boostRow.view = boostPanel
        menu.addItem(boostRow)
        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 58))
        label = NSTextField(labelWithString: "Brightness")
        label.frame = NSRect(x: 18, y: 34, width: 214, height: 18)
        label.textColor = .labelColor
        panel.addSubview(label)
        slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: self, action: #selector(changeBrightness))
        slider.frame = NSRect(x: 18, y: 8, width: 214, height: 24)
        slider.setAccessibilityLabel("Native brightness")
        slider.isContinuous = true
        panel.addSubview(slider)
        let row = NSMenuItem()
        row.view = panel
        menu.addItem(row)
        notice = NSMenuItem(title: "1600-nit peak target", action: nil, keyEquivalent: "")
        menu.addItem(notice)
        keyPermissionItem = NSMenuItem(title: "Enable F1/F2 control…", action: #selector(enableBrightnessKeys), keyEquivalent: "")
        keyPermissionItem.target = self
        menu.addItem(keyPermissionItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit XDR Brightness", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        status.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(self, selector: #selector(suspend), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        configureDisplay()
        keys.onKey = { [weak self] increase, fine in
            guard let self, !self.suspended, let id = self.displayID,
                  let hardware = self.native.read(id),
                  let next = BoostPolicy.keyStep(brightness: Double(hardware), level: self.boostLevel,
                                                increase: increase, fine: fine) else { return false }
            // Return from the event tap before creating or redrawing Metal windows.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.setBoostLevel(next)
                // The key is consumed, so macOS shows no HUD of its own.
                if let screen = self.screen {
                    let nits = BoostPolicy.estimatedNits(brightness: Double(hardware), level: self.boostLevel)
                    self.hud.show(level: self.boostLevel, nits: nits, on: screen)
                }
            }
            return true
        }
        updateBrightnessKeys()
        keyRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.updateBrightnessKeys() }
        if let keyRetryTimer { RunLoop.main.add(keyRetryTimer, forMode: .eventTracking) }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.menuOpen, self.screen != nil,
                  let frame = self.boostPanel.window?.frame, frame.contains(NSEvent.mouseLocation) else { return event }
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.1 : event.scrollingDeltaY
            self.setBoostLevel(BoostPolicy.scrolledLevel(self.boostLevel, delta: delta))
            return nil
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refreshReadout() }
        if selfTest {
            setBoostLevel(1)
            if let screen { hud.show(level: 1, nits: 1600, on: screen) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.boostSlider.doubleValue = 0.5
                self.changeBoost()
                self.gainChangeVerified = abs((self.metal?.gain ?? 0) - 2.1) < 0.001 && self.window != nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.finishSelfTest() }
        }
    }

    private func configureDisplay() {
        removeOverlay()
        screen = NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return BoostPolicy.supported(builtIn: CGDisplayIsBuiltin(id) != 0, headroom: screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
        }
        displayID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
        if selfTest, originalBrightness == nil, let id = displayID { originalBrightness = native.read(id) }
        applyBoost()
    }

    private func applyBoost() {
        removeOverlay()
        if enabled, !suspended, let screen {
            let pixel = NSRect(x: screen.frame.minX, y: screen.frame.maxY - 1, width: 1, height: 1)
            let overlay = BoostWindow(contentRect: pixel, styleMask: .borderless, backing: .buffered, defer: false)
            overlay.isReleasedWhenClosed = false
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            overlay.hasShadow = false
            overlay.ignoresMouseEvents = true
            overlay.hidesOnDeactivate = false
            overlay.animationBehavior = .none
            overlay.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if let view = BoostView(frame: NSRect(origin: .zero, size: pixel.size), gain: BoostPolicy.gain(level: boostLevel)) {
                overlay.contentView = view
                metal = view
                window = overlay
                overlay.orderFrontRegardless()
                applyGamma()
            }
        }
        refreshControls()
    }

    private func removeOverlay() {
        metal?.isPaused = true
        window?.orderOut(nil)
        window?.close()
        window = nil
        metal = nil
        if baseGamma != nil { CGDisplayRestoreColorSyncSettings() }
        baseGamma = nil
        gammaFactor = 1
    }

    /// Scales the captured gamma table by the boost; reapplies if headroom changed or something reset the table.
    private func applyGamma() {
        guard window != nil, let id = displayID, let screen else { return }
        let size: UInt32 = 256
        var red = [CGGammaValue](repeating: 0, count: Int(size)), green = red, blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, size, &red, &green, &blue, &count) == .success, count > 0 else { return }
        if baseGamma == nil { baseGamma = [red, green, blue].map { Array($0.prefix(Int(count))) } }
        guard let base = baseGamma, let top = base[0].last else { return }
        let factor = BoostPolicy.gammaFactor(gain: BoostPolicy.gain(level: boostLevel),
                                             headroom: screen.maximumExtendedDynamicRangeColorComponentValue)
        // Headroom is ~1 until the EDR trigger engages; the readout timer picks up the real value.
        guard abs(Double(red[Int(count) - 1]) - Double(top) * factor) > 0.001 else { return }
        var r = base[0].map { $0 * Float(factor) }, g = base[1].map { $0 * Float(factor) }, b = base[2].map { $0 * Float(factor) }
        if CGSetDisplayTransferByTable(id, UInt32(r.count), &r, &g, &b) == .success { gammaFactor = factor }
    }

    private func refreshControls() {
        boostSlider.isEnabled = screen != nil
        boostSlider.doubleValue = boostLevel
        refreshReadout()
        status.button?.appearsDisabled = screen == nil
        if screen == nil { notice.title = "Built-in XDR display unavailable" }
        else if enabled && window == nil && !suspended { notice.title = "Metal boost unavailable" }
        else { notice.title = enabled ? "1600-nit peak target" : "Normal brightness range" }
        guard let id = displayID, let brightness = native.read(id) else {
            slider.isEnabled = false
            label.stringValue = "Brightness control unavailable"
            return
        }
        slider.isEnabled = true
        slider.doubleValue = Double(brightness)
        label.stringValue = "Brightness  \(Int((brightness * 100).rounded()))%"
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        refreshControls()
        brightnessTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refreshControls() }
        RunLoop.main.add(brightnessTimer!, forMode: .eventTracking)
    }
    func menuDidClose(_ menu: NSMenu) { menuOpen = false; brightnessTimer?.invalidate(); brightnessTimer = nil }
    private func refreshReadout() {
        applyGamma()
        guard let id = displayID, let value = native.read(id) else {
            boostLabel.stringValue = "XDR unavailable"
            return
        }
        let actualLevel = window != nil ? boostLevel : 0
        let nits = BoostPolicy.estimatedNits(brightness: Double(value), level: actualLevel)
        boostLabel.stringValue = "≈\(Int(nits.rounded())) nits"
    }

    private func setBoostLevel(_ level: Double) {
        let wasEnabled = enabled
        boostLevel = min(1, max(0, level))
        if wasEnabled != enabled || (enabled && window == nil) { applyBoost() }
        else {
            metal?.setGain(BoostPolicy.gain(level: boostLevel))
            applyGamma()
            refreshControls()
        }
    }
    @objc private func changeBoost() { setBoostLevel(boostSlider.doubleValue) }
    @objc private func changeBrightness() {
        guard let id = displayID else { return }
        if !native.write(slider.floatValue, to: id) { notice.title = "Could not change brightness" }
        else { label.stringValue = "Brightness  \(Int((slider.doubleValue * 100).rounded()))%" }
    }
    private func updateBrightnessKeys() {
        let available = keys.start()
        keyPermissionItem.isHidden = available
        keyPermissionItem.title = AXIsProcessTrusted() ? "Retry F1/F2 control…" : "Enable F1/F2 control…"
    }
    @objc private func enableBrightnessKeys() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if !AXIsProcessTrusted() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        updateBrightnessKeys()
    }
    @objc private func displaysChanged() { configureDisplay() }
    @objc private func suspend() { suspended = true; applyBoost() }
    @objc private func resume() { suspended = false; configureDisplay() }
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = scrollMonitor { NSEvent.removeMonitor(monitor) }
        keys.stop()
        keyRetryTimer?.invalidate()
        statusTimer?.invalidate()
        brightnessTimer?.invalidate()
        removeOverlay()
    }

    private func finishSelfTest() {
        let rendered = metal?.completedFrames ?? 0
        let error = metal?.renderError
        let supported = screen != nil
        let edr = screen?.maximumExtendedDynamicRangeColorComponentValue ?? 0
        let potential = screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 0
        let before = originalBrightness
        let after = displayID.flatMap { native.read($0) }
        let nativeReadOK = before != nil && after != nil
        let nativeWriteOK = displayID.flatMap { id in after.map { native.write($0, to: id) } } ?? false
        let iconOnly = status.button?.title.isEmpty == true
        let popupReadout = boostLabel.stringValue
        let nitsInPopup = popupReadout.hasPrefix("≈") && popupReadout.hasSuffix(" nits") && popupReadout.contains(where: { $0.isNumber })
        let brightnessUnchanged = nativeReadOK && abs(before! - after!) < 0.015
        let appliedGamma = gammaFactor
        boostLevel = 0
        applyBoost()
        let removed = window == nil && metal == nil && baseGamma == nil
        let report: [String: Any] = ["supportedDisplay": supported, "brightnessKeyTapActive": keys.isRunning, "accessibilityTrusted": AXIsProcessTrusted(), "metalFrames": rendered,
            "metalError": error ?? "", "hudHidden": !hud.isVisible, "gammaFactor": appliedGamma, "currentEDR": edr, "potentialEDR": potential,
            "nativeBrightnessReadable": nativeReadOK, "nativeBrightnessWriteAccepted": nativeWriteOK,
            "gainSliderUpdatesRenderer": gainChangeVerified, "brightnessUnchanged": brightnessUnchanged,
            "overlayRemovedOnDisable": removed, "menuBarIconOnly": iconOnly,
            "nitsReadoutInPopup": nitsInPopup, "popupText": popupReadout]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) { print(json); fflush(stdout) }
        let passed = supported && rendered > 0 && !hud.isVisible && appliedGamma > 1 && error == nil && nativeWriteOK && gainChangeVerified && brightnessUnchanged && removed && iconOnly && nitsInPopup
        exit(passed ? 0 : 1)
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
