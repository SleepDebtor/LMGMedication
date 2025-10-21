import Foundation

public enum DosingFrequency: String, CaseIterable, Identifiable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case twicePerDay = "Twice per day"
    case twicePerWeek = "Twice per week"
    case threeTimesPerWeek = "Three times per week"
    case every4HoursAsNeeded = "Every 4 hours as needed"
    
    public var id: String { rawValue }
    
    public var shortLabel: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .twicePerDay:
            return "BID"
        case .twicePerWeek:
            return "2x/week"
        case .threeTimesPerWeek:
            return "3x/week"
        case .every4HoursAsNeeded:
            return "q4h PRN"
        }
    }
    
    public var instructionsSuffix: String {
        switch self {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        case .twicePerDay:
            return "twice daily"
        case .twicePerWeek:
            return "twice weekly"
        case .threeTimesPerWeek:
            return "three times weekly"
        case .every4HoursAsNeeded:
            return "every 4 hours as needed"
        }
    }
    
    public var daysPerUnit: Double? {
        switch self {
        case .daily:
            return 1.0
        case .weekly:
            return 7.0
        case .twicePerDay:
            return 0.5 // 2 doses per day
        case .twicePerWeek:
            return 3.5 // 2 doses per week => 7/2 days per unit
        case .threeTimesPerWeek:
            return 7.0 / 3.0 // ~2.33 days per unit
        case .every4HoursAsNeeded:
            return nil // PRN; do not auto-schedule based on quantity
        }
    }
    
    public func coverageDays(for quantity: Int) -> Int? {
        guard quantity > 0, let dpu = self.daysPerUnit, dpu > 0 else { return nil }
        let total = Double(quantity) * dpu
        return Int(ceil(total))
    }

    public func nextDueDate(from baseDate: Date, quantity: Int, calendar: Calendar = .current) -> Date? {
        if let days = coverageDays(for: quantity) {
            return calendar.date(byAdding: .day, value: days, to: baseDate)
        }
        // Fallback: if frequency is weekly but quantity is zero, schedule one week out
        if self == .weekly {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
        }
        // For PRN or unknown mappings, return nil to allow caller-defined behavior
        return nil
    }
    
    public static func from(string: String) -> DosingFrequency {
        // Try exact raw value match first
        if let exact = DosingFrequency(rawValue: string) {
            return exact
        }
        // Normalize input for lenient matching
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "daily":
            return .daily
        case "weekly":
            return .weekly
        case "twice per day", "twice daily", "2/day", "2 per day", "bid":
            return .twicePerDay
        case "twice per week", "twice weekly", "2x/week", "2 per week", "2x per week":
            return .twicePerWeek
        case "three times per week", "three times weekly", "3x/week", "3 per week", "3x per week":
            return .threeTimesPerWeek
        case "every 4 hours as needed", "q4h prn", "q4h", "as needed", "prn":
            return .every4HoursAsNeeded
        default:
            // Also try matching against short labels
            let mappedByShortLabel: DosingFrequency? = DosingFrequency.allCases.first(where: { $0.shortLabel.lowercased() == normalized })
            return mappedByShortLabel ?? .daily
        }
    }
}

public extension DispencedMedication {
    var dosingFrequency: DosingFrequency {
        get {
            DosingFrequency.from(string: frequency ?? "")
        }
        set {
            frequency = newValue.rawValue
        }
    }
}
