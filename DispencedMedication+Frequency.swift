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
    
    public static func from(string: String?) -> DosingFrequency {
        guard let string = string, let freq = DosingFrequency(rawValue: string) else {
            return .daily
        }
        return freq
    }
}

public extension DispencedMedication {
    var dosingFrequency: DosingFrequency {
        get {
            DosingFrequency.from(string: frequency)
        }
        set {
            frequency = newValue.rawValue
        }
    }
}
