import Foundation

public enum Degree: String, CaseIterable, Identifiable {
    case MD
    case PA
    case NP
    
    public var id: String { rawValue }
    
    public var displayName: String { rawValue }
}

public extension Provider {
    /// Convenience typed access to the Core Data `degree` string field.
    var degreeEnum: Degree? {
        get {
            guard let degree = self.degree else { return nil }
            return Degree(rawValue: degree)
        }
        set {
            self.degree = newValue?.rawValue
        }
    }
}
