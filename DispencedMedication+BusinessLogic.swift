import Foundation
import CoreData

extension DispencedMedication {
    /// Updates `dispenceDate` to the current day and computes `nextDoseDue` based on medication type and dispensed amount.
    /// - Behavior:
    ///   - Sets `dispenceDate = Date()` (the day the label is printed).
    ///   - If `baseMedication?.injectable == true`, adds `dispenceAmt` weeks to `dispenceDate`.
    ///   - Otherwise, adds `dispenceAmt` days to `dispenceDate`.
    ///   - Saves changes to the managed object context.
    public func updateNextDoseDueOnPrint() {
        let isInjectable = (baseMedication?.injectable == true)
        let now = Date()
        // Set the dispense date to the day of printing
        self.dispenceDate = now
        let calendar = Calendar.current
        let baseDate = self.dispenceDate ?? now

        let quantity = max(0, Int(self.dispenceAmt))
        if let daysPerUnit = self.dosingFrequency.daysPerUnit, daysPerUnit > 0, quantity > 0 {
            let totalDays = Double(quantity) * daysPerUnit
            // Use whole days for scheduling
            if let targetDate = calendar.date(byAdding: .day, value: Int(ceil(totalDays)), to: baseDate) {
                self.nextDoseDue = targetDate
            } else {
                self.nextDoseDue = nil
            }
        } else if self.dosingFrequency == .weekly {
            // Fallback: if quantity is zero but frequency is weekly, schedule one week out
            self.nextDoseDue = calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
        } else {
            // Preserve previous fallback based on injectable/day if frequency is PRN or missing mapping
            let component: Calendar.Component = isInjectable ? .weekOfYear : .day
            let targetDate = calendar.date(byAdding: component, value: quantity, to: baseDate)
            self.nextDoseDue = targetDate
        }

        // Persist the change safely
        if let context = self.managedObjectContext {
            context.perform {
                do {
                    try context.save()
                } catch {
                    print("Failed to save nextDoseDue/dispenceDate on print: \(error)")
                }
            }
        }
    }
    
    /// Total fill volume in mL for the dispensed medication.
    ///
    /// Calculation:
    /// - Uses the base medication's primary concentration (`concentration1`) in mg/mL.
    /// - Uses the numeric dose (`doseNum`) in mg per unit (e.g., per syringe).
    /// - Computes volume per unit as `doseNum / concentration1` (mL), then multiplies by `dispenceAmt`.
    /// - Returns 0 if required values are missing or invalid.
    public var fillAmount: Double {
        guard let med = baseMedication else { return 0 }
        let concentration = med.concentration1 // expected mg/mL
        guard concentration > 0 else { return 0 }
        let doseMg = doseNum > 0 ? doseNum : 0 // numeric dose in mg
        guard doseMg > 0 else { return 0 }
        let quantity = max(0, Int(dispenceAmt))
        let perUnitVolumeML = doseMg / concentration
        return perUnitVolumeML
    }
}
