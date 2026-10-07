// Earshot: exposes the system audio mix as a public input device ("System Audio")
// using a Core Audio process tap wrapped in an aggregate device. Runs as a LaunchAgent.
import Foundation
import CoreAudio
import AudioToolbox

let aggregateUID = "arrow7000.earshot.device"
let aggregateName = "System Audio"
let system = AudioObjectID(kAudioObjectSystemObject)

func log(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("\(ts) \(msg)"); fflush(stdout)
}

func check(_ status: OSStatus, _ what: String) {
    if status != noErr { log("\(what) failed: \(status)"); exit(1) }
}

func addr(_ selector: AudioObjectPropertySelector,
          _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func getUInt32(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
    var a = addr(selector); var v = UInt32(0); var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v) == noErr ? v : nil
}

func deviceUID(_ dev: AudioObjectID) -> String? {
    var a = addr(kAudioDevicePropertyDeviceUID)
    var uid: Unmanaged<CFString>? = nil; var size = UInt32(MemoryLayout<CFString>.size)
    guard AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &uid) == noErr, let uid else { return nil }
    return uid.takeRetainedValue() as String
}

func allDevices() -> [AudioObjectID] {
    var a = addr(kAudioHardwarePropertyDevices); var size = UInt32(0)
    guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return [] }
    var devs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &devs) == noErr else { return [] }
    return devs
}

func hasOutputStreams(_ dev: AudioObjectID) -> Bool {
    var a = addr(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput); var size = UInt32(0)
    return AudioObjectGetPropertyDataSize(dev, &a, 0, nil, &size) == noErr && size > 0
}

func deviceForUID(_ uid: String) -> AudioObjectID? {
    allDevices().first { deviceUID($0) == uid }
}

// Clock the aggregate off the built-in speakers so it survives headphones/AirPods coming and going.
func clockDeviceUID() -> String? {
    if let builtIn = allDevices().first(where: {
        getUInt32($0, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn && hasOutputStreams($0)
    }) { return deviceUID(builtIn) }
    var a = addr(kAudioHardwarePropertyDefaultSystemOutputDevice)
    var dev = AudioObjectID(0); var size = UInt32(MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &dev) == noErr else { return nil }
    return deviceUID(dev)
}

// Remove a stale device left behind by a previous crash.
if let stale = deviceForUID(aggregateUID) { AudioHardwareDestroyAggregateDevice(stale) }

guard let clockUID = clockDeviceUID() else { log("no output device to clock from"); exit(1) }

let tapDesc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
tapDesc.name = "System Audio Tap"
tapDesc.isPrivate = false
tapDesc.muteBehavior = .unmuted
var tapID = AudioObjectID(0)
check(AudioHardwareCreateProcessTap(tapDesc, &tapID), "create tap")

let desc: [String: Any] = [
    kAudioAggregateDeviceNameKey: aggregateName,
    kAudioAggregateDeviceUIDKey: aggregateUID,
    kAudioAggregateDeviceMainSubDeviceKey: clockUID,
    kAudioAggregateDeviceIsPrivateKey: false,
    kAudioAggregateDeviceIsStackedKey: false,
    kAudioAggregateDeviceTapAutoStartKey: true,
    kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: clockUID]],
    kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                       kAudioSubTapUIDKey: tapDesc.uuid.uuidString]],
]
var aggID = AudioObjectID(0)
check(AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggID), "create aggregate")
log("created \"\(aggregateName)\" (clock: \(clockUID))")

func cleanup() {
    AudioHardwareDestroyAggregateDevice(aggID)
    AudioHardwareDestroyProcessTap(tapID)
}

// Briefly run IO on the device ourselves: this is what makes macOS show the
// System Audio Recording prompt for this app if it hasn't been granted yet.
var procID: AudioDeviceIOProcID? = nil
check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, nil) { _, _, _, _, _ in }, "create ioproc")
check(AudioDeviceStart(aggID, procID), "start io")
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    AudioDeviceStop(aggID, procID)
    AudioDeviceDestroyIOProcID(aggID, procID!)
}

// If coreaudiod restarts (or anything else removes our device), exit and let launchd start us fresh.
var devicesAddr = addr(kAudioHardwarePropertyDevices)
AudioObjectAddPropertyListenerBlock(system, &devicesAddr, .main) { _, _ in
    if deviceForUID(aggregateUID) == nil { log("device disappeared, restarting"); exit(1) }
}
var restartAddr = addr(kAudioHardwarePropertyServiceRestarted)
AudioObjectAddPropertyListenerBlock(system, &restartAddr, .main) { _, _ in
    log("coreaudiod restarted, restarting"); exit(1)
}

for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { cleanup(); log("stopped"); exit(0) }
    src.resume()
    _ = Unmanaged.passRetained(src)
}
dispatchMain()
