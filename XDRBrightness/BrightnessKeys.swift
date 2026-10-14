import AppKit
import ApplicationServices

/// A session event tap is needed because macOS stops changing SDR brightness at 100%.
final class BrightnessKeys {
    var onKey: ((Bool, Bool) -> Bool)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gate = KeyGate()
    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        stop()
        guard AXIsProcessTrusted() else { return false }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << 14) // NX_SYSDEFINED: brightness media keys
        let callback: CGEventTapCallBack = { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<BrightnessKeys>.fromOpaque(pointer).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return owner.handle(type, event: event) ? nil : Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else { return false }
        tap = port
        source = loopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return isRunning
    }

    private func handle(_ type: CGEventType, event: CGEvent) -> Bool {
        guard let ns = NSEvent(cgEvent: event) else { return false }
        let key: Int
        let increase: Bool
        let pressed: Bool
        if type.rawValue == 14, ns.subtype.rawValue == 8 {
            key = (ns.data1 >> 16) & 0xffff
            guard key == 2 || key == 3 else { return false }
            increase = key == 2
            pressed = ((ns.data1 >> 8) & 0xff) == 0x0a
        } else if type == .keyDown || type == .keyUp {
            key = Int(event.getIntegerValueField(.keyboardEventKeycode))
            guard key == 144 || key == 145 else { return false }
            increase = key == 144
            pressed = type == .keyDown
        } else { return false }
        if !pressed { return gate.release(key) }
        let modifiers = ns.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Preserve system shortcuts such as Option–Brightness (Display Settings).
        guard !modifiers.contains(.command), !modifiers.contains(.control),
              !modifiers.contains(.option) || modifiers.contains(.shift) else {
            gate.press(key, handled: false)
            return false
        }
        let fine = modifiers.contains([.option, .shift])
        let handled = onKey?(increase, fine) ?? false
        gate.press(key, handled: handled)
        return handled
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        gate.reset()
    }

    deinit { stop() }
}
