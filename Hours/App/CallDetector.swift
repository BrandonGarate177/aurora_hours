import CoreAudio
import CoreMediaIO

/// Says whether the person is on a call right now. The break checks it when it
/// starts and every few seconds while it runs; tests pass a fake.
@MainActor
protocol CallDetecting: AnyObject {
    func isOnCall() -> Bool
}

/// A call is any camera in use by any app, or the default input device
/// running for anyone. Both are public, need no Accessibility and no
/// permission prompt, and don't look at what the apps are.
///
/// Screen sharing is not detected: there is no public, cheap way to ask
/// whether another app is capturing the screen. CGDisplayStream and
/// SCShareableContent only capture for this app; they don't report others.
/// A screen share almost always comes with the mic open, which this catches.
@MainActor
final class SystemCallDetector: CallDetecting {
    #if DEBUG
    /// Set by the debug hook to fake a call (true) or its absence (false).
    var forced: Bool?
    #endif

    func isOnCall() -> Bool {
        #if DEBUG
        if let forced { return forced }
        #endif
        return Self.cameraInUse() || Self.microphoneInUse()
    }

    /// kCMIODevicePropertyDeviceIsRunningSomewhere on every video device.
    nonisolated static func cameraInUse() -> Bool {
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == 0 else { return false }

        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        for device in devices {
            var running: UInt32 = 0
            let runningSize = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(device, &address, 0, nil, runningSize, &used, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    /// kAudioDevicePropertyDeviceIsRunningSomewhere on the default input.
    nonisolated static func microphoneInUse() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == 0,
              device != kAudioObjectUnknown else { return false }

        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == 0 else { return false }
        return running != 0
    }
}
