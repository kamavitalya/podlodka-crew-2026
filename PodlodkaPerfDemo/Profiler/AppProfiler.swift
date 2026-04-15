//
//  AppProfiler.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import MachO

// Swift runtime demangling function
@_silgen_name("swift_demangle")
private func swift_demangle(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
) -> UnsafeMutablePointer<CChar>?

private func demangleSwiftSymbol(_ mangled: String) -> String {
    guard mangled.hasPrefix("$s") || mangled.hasPrefix("_$s") || mangled.hasPrefix("$S") else {
        return mangled
    }
    return mangled.withCString { cStr -> String in
        guard let result = swift_demangle(
            mangledName: cStr,
            mangledNameLength: UInt(strlen(cStr)),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0
        ) else { return mangled }
        defer { free(result) }
        return String(cString: result)
    }
}

// MARK: - Stack Sample

struct FrameInfo {
    let symbol: String   // formatted symbol string for display
    let module: String   // module/binary name (e.g. "PodlodkaPerfDemo", "UIKitCore")
}

struct StackSample {
    let timestamp: UInt64   // mach_absolute_time delta from profiler start
    let threadID: UInt64
    let frames: [FrameInfo]
}

// MARK: - Mach Time Helpers

private func machTimeToNanoseconds(_ machTime: UInt64) -> UInt64 {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return machTime * UInt64(info.numer) / UInt64(info.denom)
}

private func machTimeToMilliseconds(_ machTime: UInt64) -> Double {
    return Double(machTimeToNanoseconds(machTime)) / 1_000_000.0
}

// MARK: - Firefox Profiler JSON Builder (Gecko format v24)

/// Builds a Gecko profile JSON compatible with https://profiler.firefox.com
private struct GeckoProfileBuilder {

    // MARK: String Table

    private var stringTable: [String] = []
    private var stringIndex: [String: Int] = [:]

    mutating func internString(_ s: String) -> Int {
        if let idx = stringIndex[s] { return idx }
        let idx = stringTable.count
        stringTable.append(s)
        stringIndex[s] = idx
        return idx
    }

    // MARK: Frame Table
    // Schema: { location: 0, relevantForJS: 1, innerWindowID: 2, implementation: 3,
    //           optimizations: 4, line: 5, column: 6, category: 7, subcategory: 8 }

    private var frameTableData: [[Any]] = []
    private var frameMap: [String: Int] = [:]

    mutating func internFrame(locationStringIndex: Int, key: String, category: Int) -> Int {
        if let idx = frameMap[key] { return idx }
        let idx = frameTableData.count
        frameMap[key] = idx
        // [location, relevantForJS, innerWindowID, implementation, optimizations, line, column, category, subcategory]
        frameTableData.append([locationStringIndex, false, 0, NSNull(), NSNull(), NSNull(), NSNull(), category, 0])
        return idx
    }

    // MARK: Stack Table
    // Schema: { prefix: 0, frame: 1 }
    // Data tuples: [prefix, frame, 0]

    private var stackTableData: [[Any]] = []
    private var stackMap: [String: Int] = [:]

    mutating func internStack(frameIndex: Int, prefix: Int?) -> Int {
        let key = "\(frameIndex):\(prefix.map(String.init) ?? "nil")"
        if let idx = stackMap[key] { return idx }
        let idx = stackTableData.count
        stackMap[key] = idx
        // [prefix, frame, 0]
        stackTableData.append([prefix as Any, frameIndex, 0])
        return idx
    }

    // MARK: Samples
    // Schema: { stack: 0, time: 1, eventDelay: 2 }

    private var samplesData: [[Any]] = []

    // MARK: Markers
    // Schema: { name: 0, startTime: 1, endTime: 2, phase: 3, category: 4, data: 5 }
    // Phase: 0=Instant, 1=Interval, 2=IntervalStart, 3=IntervalEnd

    private var markerTuples: [[Any]] = []

    // MARK: Build

    mutating func build(
        samples: [StackSample],
        signpostEvents: [SignpostEvent],
        sampleIntervalMs: Double,
        profileStartMachTime: UInt64,
        appModuleName: String
    ) -> [String: Any] {

        // Process samples
        for sample in samples {
            let timeMs = machTimeToMilliseconds(sample.timestamp)

            // Filter to app frames only, skip system frames

            // Build the stack bottom-up (reversed so root frame comes first)
            var prefixIndex: Int? = nil
            for frame in sample.frames.reversed() {
                let category = frame.module.hasPrefix(appModuleName) ? 0 : 1
                if category == 1 { continue } // hide system libs
                let funcName = extractFunctionName(from: frame.symbol)
                let nameIdx = internString(funcName)
                let frameIdx = internFrame(locationStringIndex: nameIdx, key: frame.symbol, category: category)
                prefixIndex = internStack(frameIndex: frameIdx, prefix: prefixIndex)
            }

            // [stack, time, eventDelay]
            samplesData.append([prefixIndex as Any, timeMs, 0.0])
        }

        // Process signpost events as markers
        // Use an array (queue) per key so multiple begin/end pairs with the same name match in FIFO order
        var openIntervals: [String: [(nameIdx: Int, startTime: Double, tupleIndex: Int)]] = [:]

        for event in signpostEvents {
            let timeMs = machTimeToMilliseconds(event.timestamp)
            var label = "\(event.name)"
            if let message = event.message {
                label += ": \(message)"
            }
            let nameIdx = internString(label)
            let pairKey = "\(event.name)_\(event.signpostID)"

            switch event.type {
            case "begin":
                let idx = markerTuples.count
                // Placeholder IntervalStart (phase 2): [name, startTime, endTime, phase, category]
                markerTuples.append([nameIdx, timeMs, NSNull(), 2, 0])
                openIntervals[pairKey, default: []].append((nameIdx, timeMs, idx))

            case "end":
                if openIntervals[pairKey] != nil, !openIntervals[pairKey]!.isEmpty {
                    // Match the earliest unmatched begin (FIFO)
                    let open = openIntervals[pairKey]!.removeFirst()
                    // Upgrade to complete Interval (phase 1)
                    markerTuples[open.tupleIndex] = [open.nameIdx, open.startTime, timeMs, 1, 0]
                } else {
                    // Orphan end — Instant
                    markerTuples.append([nameIdx, timeMs, NSNull(), 0, 0])
                }

            default: // Instant (phase 0)
                markerTuples.append([nameIdx, timeMs, NSNull(), 0, 0])
            }
        }

        // Convert any remaining unmatched begins to Instant markers
        for entries in openIntervals.values {
            for open in entries {
                markerTuples[open.tupleIndex] = [open.nameIdx, open.startTime, NSNull(), 0, 0]
            }
        }

        // Compute timing
        let startTimeMs = samplesData.isEmpty ? 0.0 : (samplesData.first![1] as! Double)
        let pid = Int(getpid())
        let threadName = "GeckoMain"

        // Assemble thread
        let thread: [String: Any] = [
            "name": threadName,
            "registerTime": 0,
            "processType": "default",
            "processName": NSNull(),
            "unregisterTime": NSNull(),
            "tid": pid,
            "pid": 0,
            "samples": [
                "schema": [
                    "stack": 0,
                    "time": 1,
                    "eventDelay": 2
                ],
                "data": samplesData
            ] as [String: Any],
            "stackTable": [
                "schema": [
                    "prefix": 0,
                    "frame": 1
                ],
                "data": stackTableData
            ] as [String: Any],
            "frameTable": [
                "schema": [
                    "location": 0,
                    "relevantForJS": 1,
                    "innerWindowID": 2,
                    "implementation": 3,
                    "optimizations": 4,
                    "line": 5,
                    "column": 6,
                    "category": 7,
                    "subcategory": 8
                ],
                "data": frameTableData
            ] as [String: Any],
            "stringTable": stringTable,
            "markers": [
                "schema": [
                    "name": 0,
                    "startTime": 1,
                    "endTime": 2,
                    "phase": 3,
                    "category": 4,
                    "data": 5
                ],
                "data": markerTuples
            ] as [String: Any]
        ]

        // Categories: 0 = User (app frames), 1 = System
        let categories: [[String: Any]] = [
            [
                "name": "User",
                "color": "yellow",
                "subcategories": ["Other"]
            ],
            [
                "name": "System",
                "color": "orange",
                "subcategories": ["Other"]
            ]
        ]

        // Top-level Gecko profile
        let profile: [String: Any] = [
            "meta": [
                "version": 24,
                "startTime": startTimeMs,
                "shutdownTime": NSNull(),
                "categories": categories,
                "markerSchema": [] as [[String: Any]],
                "interval": sampleIntervalMs,
                "stackwalk": 1,
                "debug": 0,
                "gcpoision": 0,
                "processType": 0,
                "presymbolicated": true
            ] as [String: Any],
            "libs": [] as [[String: Any]],
            "threads": [thread],
            "pausedRange": [] as [[String: Any]],
            "processes": [] as [[String: Any]]
        ]

        return profile
    }

    // MARK: Helpers

    private func extractFunctionName(from symbol: String) -> String {
        // Symbol format from dladdr: "0   Module   0xaddr   $s17mangled... + 42"
        let components = symbol.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 4 else { return symbol.trimmingCharacters(in: .whitespaces) }

        let rawName: String
        if let plusIndex = components.lastIndex(of: "+"), plusIndex > 3 {
            rawName = components[3..<plusIndex].joined(separator: " ")
        } else if components.count > 3 {
            rawName = String(components[3])
        } else {
            return symbol.trimmingCharacters(in: .whitespaces)
        }

        return demangleSwiftSymbol(rawName)
    }
}

// MARK: - App Profiler

class AppProfiler {
    static let shared = AppProfiler()

    private let queue = DispatchQueue(label: "com.podlodka.appprofiler", attributes: .concurrent)
    private var stackSamples: [StackSample] = []
    private var isProfiling = false
    private var timer: DispatchSourceTimer?
    private var sampleIntervalMs: UInt64 = 10
    private let profileStartMachTime: UInt64

    private init() {
        self.profileStartMachTime = mach_absolute_time()
    }

    // MARK: Start / Stop

    func start(sampleIntervalMs: UInt64 = 10) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self.isProfiling else { return }
            self.isProfiling = true
            self.sampleIntervalMs = sampleIntervalMs
            self.stackSamples.removeAll()
        }

        let mainThread = mach_thread_self() // cache the main thread port (called from main)
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(Int(sampleIntervalMs)))
        timer.setEventHandler { [weak self] in
            self?.captureMainThreadStack(mainThread: mainThread)
        }

        queue.async(flags: .barrier) { [weak self] in
            self?.timer = timer
        }
        timer.resume()

        ps_begin("AppProfiler", message: "Profiling started with interval \(sampleIntervalMs)ms")
    }

    func stop() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, self.isProfiling else { return }
            self.timer?.cancel()
            self.timer = nil
            self.isProfiling = false
        }
        ps_end("AppProfiler", message: "Profiling stopped")
    }

    // MARK: Capture (Mach-based main thread stack walking)

    /// Suspends the main thread, walks its frame pointer chain, resumes it,
    /// then symbolizes the addresses via dladdr. Called from a background thread.
    private func captureMainThreadStack(mainThread: mach_port_t) {
        let timestamp = mach_absolute_time() - profileStartMachTime

        // Suspend the main thread so we can read its registers
        guard thread_suspend(mainThread) == KERN_SUCCESS else { return }

        // Read the thread state (arm64)
        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &state) { ptr in
            ptr.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { base in
                thread_get_state(mainThread, ARM_THREAD_STATE64, base, &count)
            }
        }

        var addresses: [UnsafeRawPointer] = []

        if kr == KERN_SUCCESS {
            // On arm64: __pc is the program counter, __fp is the frame pointer (x29)
            let pc = UnsafeRawPointer(bitPattern: UInt(state.__pc))
            if let pc = pc { addresses.append(pc) }

            // Walk the frame pointer chain
            var fp = UnsafeRawPointer(bitPattern: UInt(state.__fp))
            let maxFrames = 128
            while let currentFP = fp, addresses.count < maxFrames {
                // Each frame: [previous_fp, return_address]
                let framePtr = currentFP.assumingMemoryBound(to: UnsafeRawPointer?.self)
                guard let returnAddress = framePtr.advanced(by: 1).pointee else { break }
                addresses.append(returnAddress)
                fp = framePtr.pointee
            }
        }

        // Resume the main thread immediately
        thread_resume(mainThread)

        // Symbolize off the critical path
        let frames = addresses.map { addr -> FrameInfo in
            var info = dl_info()
            if dladdr(addr, &info) != 0, let sname = info.dli_sname {
                let symbol = String(cString: sname)
                let offset = addr - UnsafeRawPointer(info.dli_saddr)
                let module = info.dli_fname.map { String(cString: $0).components(separatedBy: "/").last ?? "" } ?? "???"
                let formatted = "0   \(module)   \(addr)   \(symbol) + \(offset)"
                return FrameInfo(
                    symbol: formatted,
                    module: module
                )
            }
            let hex = "0x\(String(UInt(bitPattern: addr), radix: 16))"
            return FrameInfo(
                symbol: "0   ???   \(addr)   \(hex) + 0",
                module: "???"
            )
        }

        let sample = StackSample(
            timestamp: timestamp,
            threadID: UInt64(mainThread),
            frames: frames
        )

        queue.async(flags: .barrier) {
            self.stackSamples.append(sample)
        }
    }

    // MARK: Access Samples

    func getStackSamples() -> [StackSample] {
        var result: [StackSample] = []
        queue.sync { result = self.stackSamples }
        return result
    }

    // MARK: Generate Firefox Profiler JSON

    func generateFirefoxProfilerJSON() -> Data? {
        let samples = getStackSamples()
        guard !samples.isEmpty else {
            print("[AppProfiler] No samples collected.")
            return nil
        }

        let signpostEvents = SignpostLogger.shared.getEvents()

        let appModule = Bundle.main.executableURL?.lastPathComponent ?? "PodlodkaPerfDemo"

        var builder = GeckoProfileBuilder()
        let profile = builder.build(
            samples: samples,
            signpostEvents: signpostEvents,
            sampleIntervalMs: Double(sampleIntervalMs),
            profileStartMachTime: profileStartMachTime,
            appModuleName: appModule
        )

        do {
            let data = try JSONSerialization.data(withJSONObject: profile, options: [.sortedKeys])
            return data
        } catch {
            print("[AppProfiler] Failed to serialize profile: \(error)")
            return nil
        }
    }

    // MARK: Save to File

    func saveProfile(to url: URL) -> Bool {
        guard let data = generateFirefoxProfilerJSON() else { return false }

        do {
            try data.write(to: url)
            print("[AppProfiler] Profile saved to: \(url.path)")
            return true
        } catch {
            print("[AppProfiler] Failed to save profile: \(error)")
            return false
        }
    }

    @discardableResult
    func saveProfileToDocuments() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "profile_\(formatter.string(from: Date())).json"

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[AppProfiler] Could not locate Documents directory.")
            return nil
        }

        let url = docs.appendingPathComponent(name)
        return saveProfile(to: url) ? url : nil
    }
}
