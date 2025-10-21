import Foundation

public enum DispenseUnit: String, CaseIterable, Identifiable, Codable {
    case syringe = "Syringe"
    case tablet = "Tablet"
    case pill = "Pill"
    case dose = "Dose"

    public var id: String { rawValue }

    public var pluralLabel: String {
        switch self {
        case .syringe: return "Syringes"
        case .tablet: return "Tablets"
        case .pill: return "Pills"
        case .dose: return "Doses"
        }
    }

    /// A short lowercase label for UI where lowercase is preferred
    public var shortLabel: String {
        switch self {
        case .syringe: return "syringe"
        case .tablet: return "tablet"
        case .pill: return "pill"
        case .dose: return "dose"
        }
    }

    /// Returns a grammatically correct label for a given quantity (singular/plural)
    public func label(for quantity: Int) -> String {
        return quantity == 1 ? shortLabel : pluralLabel.lowercased()
    }

    /// Lenient initializer from an arbitrary string, handling plural/singular and case
    public static func from(string: String?) -> DispenseUnit {
        guard let str = string?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else {
            return .dose
        }
        if let exact = DispenseUnit(rawValue: str) { return exact }
        let normalized = str.lowercased()
        switch normalized {
        case "syringe", "syringes": return .syringe
        case "tablet", "tablets": return .tablet
        case "pill", "pills": return .pill
        case "dose", "doses": return .dose
        default:
            // Try matching against shortLabel
            if let byShort = DispenseUnit.allCases.first(where: { $0.shortLabel == normalized }) {
                return byShort
            }
            return .dose
        }
    }
}

public extension DispencedMedication {
    /// Typed accessor for the dispense unit backed by Core Data `dispenceUnit` string.
    var dispenseUnitType: DispenseUnit {
        get { DispenseUnit.from(string: dispenceUnit) }
        set { dispenceUnit = newValue.rawValue }
    }

    /// Convenience: grammatically correct dispensed quantity text using the enum
    var dispensedQuantityTextEnumDriven: String {
        let qty = max(0, Int(dispenceAmt))
        guard qty > 0 else { return "" }
        let unit = dispenseUnitType
        return "\(qty) \(unit.label(for: qty))"
    }
}
