import Foundation
import os

@MainActor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Wallpaper", category: "Performance")
    private var startTimes: [String: Date] = [:]
    
    func startMeasuring(_ operation: String) {
        startTimes[operation] = Date()
    }
    
    func endMeasuring(_ operation: String) {
        guard let startTime = startTimes[operation] else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        logger.info("\(operation) took \(duration, format: .fixed(precision: 3)) seconds")
        
        if duration > 1.0 {
            logger.warning("\(operation) is slow: \(duration, format: .fixed(precision: 3))s")
        }
        
        startTimes.removeValue(forKey: operation)
    }
    
    func logMemoryUsage() {
        let usage = reportMemoryUsage()
        logger.info("Memory usage: \(usage.used) MB / \(usage.total) MB")
    }
    
    private func reportMemoryUsage() -> (used: UInt64, total: UInt64) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let used = taskInfo.phys_footprint / 1024 / 1024
            let total = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
            return (UInt64(used), total)
        }
        
        return (0, 0)
    }
}
