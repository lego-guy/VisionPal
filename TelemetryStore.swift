//
//  Telemetry.swift
//  VisionPal
//
//  Created by Zachary D'Souza on 10/18/26.


import Foundation
import Combine

enum MetricCategory {
    case count
    case duration
}
struct TelemetryChartItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct DailyTelemetryRecord: Codable {
    var triggers: Int
    var durationSeconds: Double
}

class TelemetryStore: ObservableObject {
    static let shared = TelemetryStore()
    @Published var history: [String: DailyTelemetryRecord] = [:]
    
    private let storageKey = "VisionPal_TelemetryRecords_V2"
    private let legacyStorageKey = "visionPalTelemetryHistory"
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init() {
        loadHistory()
    }

    private func loadHistory() {
        // 1. Attempt to load the current V2 record structure
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: DailyTelemetryRecord].self, from: data) {
            self.history = decoded
            return
        }
        
        // 2. Backward compatibility: Migrate legacy [String: Int] data if present
        if let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
           let legacyDecoded = try? JSONDecoder().decode([String: Int].self, from: legacyData) {
            var migrated: [String: DailyTelemetryRecord] = [:]
            for (dateKey, count) in legacyDecoded {
                migrated[dateKey] = DailyTelemetryRecord(triggers: count, durationSeconds: 0)
            }
            self.history = migrated
            saveHistory()
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func logTrigger(for date: Date = Date()) {
        let key = dateFormatter.string(from: date)
        var record = history[key] ?? DailyTelemetryRecord(triggers: 0, durationSeconds: 0)
        record.triggers += 1
        history[key] = record
        saveHistory()
    }

    func logDuration(seconds: Double, for date: Date = Date()) {
        let key = dateFormatter.string(from: date)
        var record = history[key] ?? DailyTelemetryRecord(triggers: 0, durationSeconds: 0)
        record.durationSeconds += seconds
        history[key] = record
        saveHistory()
    }

    func getTodayTotals() -> (triggers: Int, duration: Double) {
        let key = dateFormatter.string(from: Date())
        if let record = history[key] {
            return (record.triggers, record.durationSeconds)
        }
        return (0, 0.0)
    }

    func clearAllHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
    }

    // Replace the three query functions inside TelemetryStore:

    func getWeeklyData(metric: MetricCategory) -> [TelemetryChartItem] {
        let calendar = Calendar.current
        var result: [TelemetryChartItem] = []
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let key = dateFormatter.string(from: date)
                let weekdayIndex = calendar.component(.weekday, from: date) - 1
                let record = history[key]
                let val = metric == .count ? Double(record?.triggers ?? 0) : ((record?.durationSeconds ?? 0) / 60.0)
                result.append(TelemetryChartItem(label: dayNames[weekdayIndex], value: val))
            }
        }
        return result
    }

    func getMonthlyData(metric: MetricCategory) -> [TelemetryChartItem] {
        let calendar = Calendar.current
        var result: [TelemetryChartItem] = []
        let weekLabels = ["3 Wks Ago", "2 Wks Ago", "Last Wk", "This Wk"]
        
        // Group past 28 days into 4 clean 7-day intervals
        for weekIndex in (0..<4).reversed() {
            var periodTotal: Double = 0.0
            for dayOffset in 0..<7 {
                let daysAgo = (weekIndex * 7) + dayOffset
                if let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) {
                    let key = dateFormatter.string(from: date)
                    if let record = history[key] {
                        periodTotal += metric == .count ? Double(record.triggers) : (record.durationSeconds / 60.0)
                    }
                }
            }
            result.append(TelemetryChartItem(label: weekLabels[3 - weekIndex], value: periodTotal))
        }
        return result
    }

    func getYearlyData(metric: MetricCategory) -> [TelemetryChartItem] {
        let calendar = Calendar.current
        var result: [TelemetryChartItem] = []
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        
        for i in (0..<12).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: Date()) {
                let monthIndex = calendar.component(.month, from: date) - 1
                let year = calendar.component(.year, from: date)
                let prefix = String(format: "%04d-%02d", year, monthIndex + 1)
                
                let matches = history.filter { $0.key.hasPrefix(prefix) }
                let total = matches.values.reduce(0.0) { acc, rec in
                    acc + (metric == .count ? Double(rec.triggers) : (rec.durationSeconds / 60.0))
                }
                result.append(TelemetryChartItem(label: monthNames[monthIndex], value: total))
            }
        }
        return result
    }

}
