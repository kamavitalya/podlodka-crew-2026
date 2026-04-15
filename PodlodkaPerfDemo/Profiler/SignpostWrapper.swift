//
//  SignpostWrapper.swift
//  PodlodkaPerfDemo
//
//  Created by Vitaliy Kamashev on 03.04.2026.
//

import Foundation
import os

// MARK: - Signpost Event

struct SignpostEvent {
    let timestamp: UInt64
    let type: String // "begin", "end", "event"
    let name: String
    let signpostID: UInt64
    let message: String?
//    let threadID: UInt64
//    let stackTrace: [String]?
}

// MARK: - Signpost Logger

class SignpostLogger {
    static let shared = SignpostLogger()
    
    private let queue = DispatchQueue(label: "com.podlodka.signpostlogger", attributes: .concurrent)
    private var events: [SignpostEvent] = []
    private let startTime: UInt64
    
    init() {
        startTime = mach_absolute_time()
    }
    
    func log(_ type: OSSignpostType, log: OSLog = .pointsOfInterest, name: StaticString, signpostID: OSSignpostID = .exclusive, message: @autoclosure () -> String? = nil) {
        let timestamp = mach_absolute_time() - startTime
        let message = message() ?? ""
        
        // Store event internally
        queue.async(flags: .barrier) {
            let event = SignpostEvent(
                timestamp: timestamp,
                type: self.signpostTypeToString(type),
                name: name.description,
                signpostID: signpostID.rawValue,
                message: message
            )
            self.events.append(event)
        }
        
        // Also create system signpost
        os_signpost(type, log: log, name: name, signpostID: signpostID, "%@", message)
    }
    
    func getEvents() -> [SignpostEvent] {
        var result: [SignpostEvent] = []
        queue.sync {
            result = events
        }
        return result
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.events.removeAll()
        }
    }
    
    private func signpostTypeToString(_ type: OSSignpostType) -> String {
        switch type {
        case .begin: return "begin"
        case .end: return "end"
        case .event: return "event"
//        case .interval: return "interval"
        default: return "unknown"
        }
    }
}

// MARK: - Custom Signpost Functions

func ps_log(_ type: OSSignpostType, log: OSLog = .pointsOfInterest, name: StaticString, signpostID: OSSignpostID = .exclusive, message: @autoclosure () -> String? = nil) {
    SignpostLogger.shared.log(type, log: log, name: name, signpostID: signpostID, message: message())
}

// Convenience functions
func ps_begin(_ name: StaticString, signpostID: OSSignpostID = .exclusive, message: @autoclosure () -> String? = nil) {
    ps_log(.begin, name: name, message: message())
}

func ps_end(_ name: StaticString, signpostID: OSSignpostID = .exclusive, message: @autoclosure () -> String? = nil) {
    ps_log(.end, name: name, message: message())
}

func ps_event(_ name: StaticString, signpostID: OSSignpostID = .exclusive, message: @autoclosure () -> String? = nil) {
    ps_log(.event, name: name, message: message())
}

func signpostID(for object: AnyObject) -> OSSignpostID {
    OSSignpostID(log: .pointsOfInterest, object: object)
}
