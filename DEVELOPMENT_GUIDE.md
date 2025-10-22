# Development Guide - LMGMedication

## Code Quality Improvements & Recommendations

### 1. Code Organization Improvements

#### Current Status
The codebase is well-structured but could benefit from some organizational improvements:

#### Recommended Improvements

1. **Create View Models**
   ```swift
   // Recommended: Extract business logic into view models
   @MainActor
   class PatientsListViewModel: ObservableObject {
       @Published var patients: [Patient] = []
       @Published var errorMessage: String = ""
       @Published var showingErrorAlert: Bool = false
       
       func togglePatientActive(_ patient: Patient, active: Bool) {
           // Move business logic here
       }
       
       func groupedPatientsByWeek() -> [(Date, [Patient])] {
           // Move computed property logic here
       }
   }
   ```

2. **Separate View Components**
   ```swift
   // ContentView.swift is quite large - consider extracting:
   - PatientWeekSectionView
   - PatientActionButtonsView  
   - PatientListEmptyStateView
   ```

3. **Create Service Layer**
   ```swift
   protocol PatientServiceProtocol {
       func fetchActivePatients() async throws -> [Patient]
       func togglePatientStatus(_ patient: Patient, isActive: Bool) async throws
       func deletePatient(_ patient: Patient) async throws
   }
   
   class PatientService: PatientServiceProtocol {
       // Implementation
   }
   ```

### 2. Error Handling Improvements

#### Current Error Handling
The app has basic error handling with user alerts, but could be enhanced:

#### Recommended Improvements

1. **Structured Error Types**
   ```swift
   enum MedicationAppError: LocalizedError {
       case coreDataSaveFailure(NSError)
       case cloudKitSyncError(CKError)
       case pdfGenerationFailure(String)
       case patientNotFound(String)
       
       var errorDescription: String? {
           switch self {
           case .coreDataSaveFailure(let error):
               return "Failed to save data: \(error.localizedDescription)"
           case .cloudKitSyncError(let error):
               return "Sync error: \(error.localizedDescription)"
           // ... etc
           }
       }
   }
   ```

2. **Error Recovery Mechanisms**
   ```swift
   struct ErrorRecoveryView: View {
       let error: MedicationAppError
       let retryAction: () async -> Void
       
       var body: some View {
           VStack {
               Image(systemName: "exclamationmark.triangle")
               Text(error.localizedDescription)
               Button("Retry") {
                   Task { await retryAction() }
               }
           }
       }
   }
   ```

### 3. Performance Optimizations

#### Current Performance Issues
- Large patient lists might cause performance issues
- PDF generation happens on main thread
- No pagination for large datasets

#### Recommended Improvements

1. **Implement Pagination**
   ```swift
   @FetchRequest(
       sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
       fetchLimit: 50,
       animation: .default
   )
   private var patients: FetchedResults<Patient>
   ```

2. **Background PDF Generation**
   ```swift
   func generatePDFInBackground(for medication: DispencedMedication) async {
       await withTaskGroup(of: Data?.self) { group in
           group.addTask {
               // Move to background actor
               await MedicationLabelPDFGenerator.generatePDF(for: medication)
           }
       }
   }
   ```

3. **Lazy Loading for Patient Cards**
   ```swift
   LazyVStack {
       ForEach(patients) { patient in
           PatientCardView(patient: patient)
               .onAppear {
                   // Load additional data if needed
               }
       }
   }
   ```

### 4. Testing Strategy

#### Unit Tests to Add
```swift
import Testing

@Suite("Patient Management Tests")
struct PatientTests {
    
    @Test("Patient display name formatting")
    func testPatientDisplayName() async throws {
        let patient = Patient(context: testContext)
        patient.firstName = "John"
        patient.lastName = "Doe"
        
        #expect(patient.displayName == "John Doe")
    }
    
    @Test("Next dose calculation")
    func testNextDoseCalculation() async throws {
        // Test the next dose due date calculation logic
    }
    
    @Test("Patient grouping by week")
    func testPatientGroupingByWeek() async throws {
        // Test the weekly grouping algorithm
    }
}
```

#### UI Tests to Add
```swift
import XCTest

class PatientManagementUITests: XCTestCase {
    
    func testAddPatientFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        app.buttons["Add Patient"].tap()
        app.textFields["First Name"].typeText("John")
        app.textFields["Last Name"].typeText("Doe")
        app.buttons["Save"].tap()
        
        XCTAssert(app.staticTexts["John Doe"].exists)
    }
    
    func testPatientActivationToggle() throws {
        // Test swipe actions for activation/deactivation
    }
}
```

### 5. Accessibility Improvements

#### Current Accessibility
The app has basic SwiftUI accessibility but could be enhanced:

#### Recommended Improvements

1. **Enhanced VoiceOver Support**
   ```swift
   PatientCardView(patient: patient)
       .accessibilityLabel("Patient: \(patient.displayName)")
       .accessibilityHint("Next dose due: \(nextDoseDate?.formatted() ?? "No dose scheduled")")
       .accessibilityAddTraits(.isButton)
   ```

2. **Dynamic Type Support**
   ```swift
   Text(patient.displayName)
       .font(.headline)
       .lineLimit(nil) // Allow text wrapping for larger fonts
   ```

3. **Color Accessibility**
   ```swift
   private let goldColor = Color(red: 0.6, green: 0.4, blue: 0.2)
       .accessibility(diff: .increase) // Enhance contrast if needed
   ```

### 6. Security Enhancements

#### Current Security
Basic CloudKit and device-level security

#### Recommended Improvements

1. **Data Validation**
   ```swift
   extension Patient {
       var isValid: Bool {
           guard let firstName = firstName, !firstName.isEmpty else { return false }
           guard let lastName = lastName, !lastName.isEmpty else { return false }
           return true
       }
   }
   ```

2. **Input Sanitization**
   ```swift
   func sanitizeInput(_ input: String) -> String {
       return input
           .trimmingCharacters(in: .whitespacesAndNewlines)
           .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
   }
   ```

3. **Biometric Authentication**
   ```swift
   import LocalAuthentication
   
   class AuthenticationManager: ObservableObject {
       @Published var isAuthenticated = false
       
       func authenticate() async {
           let context = LAContext()
           let reason = "Access patient information"
           
           do {
               let result = await context.evaluatePolicy(.biometryAny, localizedReason: reason)
               await MainActor.run {
                   self.isAuthenticated = result
               }
           } catch {
               // Handle authentication error
           }
       }
   }
   ```

### 7. Code Documentation Standards

#### Recommended Documentation Format
```swift
/**
 * A comprehensive description of the function or class
 * 
 * Detailed explanation of the behavior, algorithms used,
 * and any important implementation notes.
 * 
 * - Parameters:
 *   - paramName: Description of parameter
 *   - anotherParam: Description of another parameter
 * - Returns: Description of return value
 * - Throws: Description of possible errors thrown
 * 
 * Example:
 * ```swift
 * let result = await functionName(param: value)
 * ```
 * 
 * - Note: Any important implementation notes
 * - Warning: Any important warnings or gotchas
 */
func functionName(param: Type) async throws -> ReturnType {
    // Implementation
}
```

### 8. SwiftUI Best Practices

#### ViewBuilder Usage
```swift
@ViewBuilder
private func patientSectionView(for section: PatientSection) -> some View {
    switch section.type {
    case .weekly:
        WeekSectionView(weekStart: section.date, patients: section.patients)
    case .noNextDose:
        NoNextDoseSectionView(patients: section.patients)
    }
}
```

#### Environment Values
```swift
private struct PatientListStyleKey: EnvironmentKey {
    static let defaultValue = PatientListStyle.default
}

extension EnvironmentValues {
    var patientListStyle: PatientListStyle {
        get { self[PatientListStyleKey.self] }
        set { self[PatientListStyleKey.self] = newValue }
    }
}
```

### 9. Modern Swift Features

#### Async/Await Improvements
```swift
// Current: Completion handlers
func loadPatients(completion: @escaping ([Patient]) -> Void)

// Recommended: Async/await
func loadPatients() async throws -> [Patient]
```

#### Result Builders
```swift
@resultBuilder
struct PatientSectionBuilder {
    static func buildBlock(_ sections: PatientSection...) -> [PatientSection] {
        sections
    }
}
```

### 10. Code Quality Tools

#### Recommended Tools to Add
1. **SwiftLint** - Code style and consistency
2. **SwiftFormat** - Automatic code formatting  
3. **Sourcery** - Code generation for boilerplate
4. **Swift Package Manager** - Dependency management

#### CI/CD Pipeline
```yaml
# .github/workflows/ios.yml
name: iOS CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Build and test
      run: |
        xcodebuild clean test -project LMGMedication.xcodeproj -scheme LMGMedication -destination 'platform=iOS Simulator,name=iPhone 14'
```

---

These improvements will enhance code quality, maintainability, and user experience while maintaining the app's core functionality and design principles.