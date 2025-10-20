import Foundation
import CoreData

extension DispencedMedication {
    /// Updates `dispenceDate` to the current day and computes `nextDoseDue` based on dosing frequency and dispensed amount.
    /// - Behavior:
    ///   - Sets `dispenceDate = Date()` (the day the label is printed).
    ///   - Calculates days supply based on dosing frequency:
    ///     - Daily: dispenceAmt days
    ///     - Weekly: dispenceAmt × 7 days  
    ///     - Twice per day: dispenceAmt ÷ 2 days
    ///     - Twice per week: dispenceAmt ÷ 2 × 7 days
    ///     - Three times per week: dispenceAmt ÷ 3 × 7 days
    ///     - Every 4 hours as needed: dispenceAmt ÷ 6 days (assuming max 6 doses per day)
    ///   - Adds calculated days to dispenceDate to get nextDoseDue.
    ///   - Saves changes to the managed object context.
    public func updateNextDoseDueOnPrint() {
        let amount = max(0, Int(self.dispenceAmt))
        let now = Date()
        
        // Set the dispense date to the day of printing
        self.dispenceDate = now
        
        // Calculate days supply based on dosing frequency
        let daysSupply = calculateDaysSupply(dispenseAmount: amount, frequency: self.dosingFrequency)
        
        let calendar = Calendar.current
        let baseDate = self.dispenceDate ?? now
        let targetDate = calendar.date(byAdding: .day, value: daysSupply, to: baseDate)
        self.nextDoseDue = targetDate
        
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
    
    /// Calculates the number of days a dispensed amount will last based on dosing frequency.
    /// - Parameters:
    ///   - dispenseAmount: Number of units dispensed (tablets, syringes, etc.)
    ///   - frequency: The dosing frequency from DosingFrequency enum
    /// - Returns: Number of days the supply will last
    private func calculateDaysSupply(dispenseAmount: Int, frequency: DosingFrequency) -> Int {
        guard dispenseAmount > 0 else { return 0 }
        
        switch frequency {
        case .daily:
            // 1 dose per day: dispenseAmount days
            return dispenseAmount
            
        case .weekly:
            // 1 dose per week: dispenseAmount × 7 days
            return dispenseAmount * 7
            
        case .twicePerDay:
            // 2 doses per day: dispenseAmount ÷ 2 days
            return max(1, dispenseAmount / 2)
            
        case .twicePerWeek:
            // 2 doses per week: (dispenseAmount ÷ 2) × 7 days
            let weeksSupply = max(1, dispenseAmount / 2)
            return weeksSupply * 7
            
        case .threeTimesPerWeek:
            // 3 doses per week: (dispenseAmount ÷ 3) × 7 days
            let weeksSupply = max(1, dispenseAmount / 3)
            return weeksSupply * 7
            
        case .every4HoursAsNeeded:
            // Assuming maximum of 6 doses per day (every 4 hours): dispenseAmount ÷ 6 days
            return max(1, dispenseAmount / 6)
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

