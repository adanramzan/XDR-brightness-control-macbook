import Foundation

/// Decides whether a brightness key-up may be swallowed. If macOS saw any press of the key
/// (e.g. the press that reached SDR maximum before repeats crossed into XDR), it must also see the
/// release, or its brightness HUD stays on screen waiting for it.
struct KeyGate {
    private var systemSaw: Set<Int> = []
    private var consumed: Set<Int> = []

    mutating func press(_ key: Int, handled: Bool) {
        if handled { consumed.insert(key) } else { systemSaw.insert(key) }
    }

    /// true = swallow the release.
    mutating func release(_ key: Int) -> Bool {
        let wasConsumed = consumed.remove(key) != nil
        return systemSaw.remove(key) == nil && wasConsumed
    }

    mutating func reset() { systemSaw.removeAll(); consumed.removeAll() }
}

enum BoostPolicy {
    static func supported(builtIn: Bool, headroom: Double) -> Bool {
        builtIn && headroom.isFinite && headroom > 1
    }

    static func gain(level: Double) -> Double {
        guard level.isFinite else { return 1 }
        return 1 + min(1, max(0, level)) * 2.2
    }

    // Gamma tables act on encoded values, so the linear gain becomes gain^(1/2.2), capped at the current EDR headroom.
    // ponytail: fixed 2.2 exponent, calibrate per panel if measured output differs.
    static func gammaFactor(gain: Double, headroom: Double) -> Double {
        guard gain.isFinite, headroom.isFinite else { return 1 }
        return pow(min(max(1, gain), max(1, headroom)), 1 / 2.2)
    }

    static func scrolledLevel(_ level: Double, delta: Double) -> Double {
        guard level.isFinite, delta.isFinite else { return 0 }
        return min(1, max(0, level + delta * 0.01))
    }

    // nil leaves the key to macOS; a value consumes it and changes only XDR gain.
    static func keyStep(brightness: Double, level: Double, increase: Bool, fine: Bool) -> Double? {
        guard brightness.isFinite, level.isFinite else { return nil }
        if increase && brightness < 0.999 { return nil }
        if !increase && level <= 0 { return nil }
        let step = fine ? 1.0 / 64 : 1.0 / 16
        return min(1, max(0, level + (increase ? step : -step)))
    }

    static func estimatedNits(brightness: Double, level: Double) -> Double {
        guard brightness.isFinite else { return 0 }
        let value = min(1, max(0, brightness))
        // Approximate M1 XDR SDR curve; this is not panel luminance telemetry.
        let sdr = value <= 0.5 ? value * 280 : 140 * pow(500 / 140, (value - 0.5) * 2)
        return min(1600, sdr * gain(level: level))
    }
}
