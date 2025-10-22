# LMGMedication - Technical Architecture

## System Architecture Overview

LMGMedication follows a modern iOS application architecture built on SwiftUI, Core Data, and CloudKit, designed for reliability, maintainability, and scalability in healthcare environments.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                           UI Layer (SwiftUI)                    │
├─────────────────────────────────────────────────────────────────┤
│ ContentView │ PatientDetailView │ Templates │ Providers │ Print │
├─────────────────────────────────────────────────────────────────┤
│                        Business Logic Layer                     │
├─────────────────────────────────────────────────────────────────┤
│ MedicationPrintManager │ SharingManager │ Authentication        │
├─────────────────────────────────────────────────────────────────┤
│                         Data Layer                              │
├─────────────────────────────────────────────────────────────────┤
│                     Core Data Stack                             │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐     │
│ │     Patient     │ │ DispencedMed    │ │   Medication    │     │
│ │   (Entity)      │ │   (Entity)      │ │   (Entity)      │     │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘     │
├─────────────────────────────────────────────────────────────────┤
│                    Persistence Layer                            │
├─────────────────────────────────────────────────────────────────┤
│    NSPersistentCloudKitContainer │        SQLite               │
├─────────────────────────────────────────────────────────────────┤
│                         CloudKit                               │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Application Layer

#### LMGMedicationApp
- **Type**: `@main App`
- **Responsibility**: Application lifecycle management, Core Data initialization, error handling
- **Key Features**:
  - Persistence controller injection
  - Authentication gate integration
  - Core Data error recovery
  - App-wide environment configuration

#### ContentView & PatientsListRootView
- **Type**: SwiftUI Views
- **Responsibility**: Main patient dashboard interface
- **Key Features**:
  - Weekly patient organization by medication due dates
  - Real-time data updates via `@FetchRequest`
  - Swipe actions for patient management
  - Modal presentation coordination

### 2. Data Layer

#### Core Data Model
```swift
// Inheritance hierarchy
Person (Abstract)
├── Patient
└── Provider

// Main entities
Patient {
    - firstName: String?
    - lastName: String?
    - birthdate: Date?
    - isActive: Bool
    - timeStamp: Date?
    - medicationsPrescribed: Set<DispencedMedication>
}

DispencedMedication {
    - dose: String?
    - doseUnit: String?
    - dispenceAmt: Int32
    - dispenceDate: Date?
    - expDate: Date?
    - nextDoseDue: Date?
    - baseMedication: Medication?
    - patient: Patient?
    - prescriber: Provider?
}

Medication {
    - name: String?
    - ingredient1: String?
    - concentration1: Double
    - pharmacy: String?
    - injectable: Bool
}
```

#### PersistenceController
- **Type**: Struct (Singleton pattern)
- **Responsibility**: Core Data stack management, CloudKit integration
- **Key Features**:
  - NSPersistentCloudKitContainer configuration
  - Automatic lightweight migration
  - Error recovery with store recreation
  - Preview data generation
  - Remote change notification handling

### 3. Business Logic Layer

#### MedicationPrintManager
- **Type**: `@MainActor class`
- **Responsibility**: PDF generation and printing workflows
- **Key Features**:
  - Injectable vs. non-injectable label support
  - Single and dual label printing
  - PDF combination using Core Graphics
  - Async/await printing interface

#### SharingManager
- **Type**: Service class
- **Responsibility**: Data sharing and export functionality
- **Key Features**:
  - Patient data export
  - Medication history sharing
  - PDF document sharing

### 4. UI Layer Architecture

#### View Hierarchy
```
NavigationStack (ContentView)
└── PatientsListRootView
    ├── WeekSectionView (multiple)
    │   └── PatientCardView (multiple)
    ├── NoNextDoseSectionView
    │   └── PatientCardView (multiple)
    └── Modal Presentations
        ├── AddPatientView
        ├── MedicationTemplatesView
        └── ProvidersListView

PatientDetailView (Navigation destination)
├── Patient info header
├── Medications list
│   └── MedicationCardView (multiple)
└── Action buttons
    ├── Add Medication
    ├── Print Labels
    └── Share Patient
```

## Design Patterns

### 1. Model-View-ViewModel (MVVM)
- **Views**: SwiftUI views handle presentation and user interaction
- **ViewModels**: `@ObservableObject` classes manage view state (implicit in some views)
- **Models**: Core Data entities with computed properties for business logic

### 2. Repository Pattern
- **PersistenceController**: Abstracts Core Data complexity
- **Core Data Extensions**: Entity extensions provide repository-like methods

### 3. Observer Pattern
- **Core Data Notifications**: Real-time updates via `NSManagedObjectContextObjectsDidChange`
- **SwiftUI `@FetchRequest`**: Automatic UI updates on data changes
- **Custom notifications**: `persistentStoreLoadFailedNotification`

### 4. Factory Pattern
- **PDF Generators**: `MedicationLabelPDFGenerator` and `NonInjectableLabelPDFGenerator`
- **Entity Creation**: Core Data entity factories in preview data

### 5. Singleton Pattern
- **PersistenceController.shared**: Global Core Data access
- **MedicationPrintManager.shared**: Global print functionality

## Data Flow

### 1. Data Creation Flow
```
User Input (SwiftUI View)
    ↓
View Model / State Updates
    ↓
Core Data Context Operations
    ↓
Save to NSPersistentCloudKitContainer
    ↓
CloudKit Sync (Background)
    ↓
Remote Devices Update
```

### 2. Data Reading Flow
```
Core Data @FetchRequest
    ↓
NSManagedObject Results
    ↓
Entity Computed Properties
    ↓
SwiftUI View Rendering
    ↓
Real-time Updates via Notifications
```

### 3. Print Flow
```
User Selects Print
    ↓
MedicationPrintManager
    ↓
PDF Generator (Injectable/Non-Injectable)
    ↓
Core Graphics PDF Creation
    ↓
UIActivityViewController Presentation
    ↓
Native iOS Print Interface
```

## Threading Model

### Main Actor Usage
- **UI Components**: All SwiftUI views run on main actor
- **Print Manager**: `@MainActor` for UI presentation
- **Core Data**: View context operations on main thread

### Background Processing
- **CloudKit Sync**: Automatic background synchronization
- **PDF Generation**: May use background queues within generators
- **Core Data Saves**: Performed on main context with automatic merging

## Error Handling Strategy

### Core Data Errors
```swift
// Persistence layer error handling
do {
    try viewContext.save()
} catch {
    // User-friendly error message
    errorMessage = "Failed to save: \(error.localizedDescription)"
    showingErrorAlert = true
}
```

### CloudKit Errors
- Automatic retry mechanisms in NSPersistentCloudKitContainer
- Network availability handling
- Conflict resolution via merge policies

### Print Errors
- Graceful PDF generation failure handling
- User notification for printing issues
- Fallback to original label if dual printing fails

## Performance Considerations

### Core Data Optimizations
- **Batch Fetching**: Enabled for relationships
- **Fault Management**: `shouldDeleteInaccessibleFaults = true`
- **Merge Policy**: `NSMergeByPropertyObjectTrumpMergePolicy` for conflict resolution

### UI Performance
- **Lazy Loading**: `LazyVStack` for patient lists
- **Computed Properties**: Efficient display name calculations
- **Animation Management**: Controlled animations with `dataVersion` state

### Memory Management
- **Automatic Reference Counting**: Standard Swift ARC
- **Core Data Faulting**: Automatic memory management for large datasets
- **PDF Generation**: Temporary data cleanup after printing

## Security Considerations

### Data Protection
- **CloudKit Encryption**: Automatic encryption in transit and at rest
- **Local Storage**: Core Data SQLite encryption (if configured)
- **Authentication**: Gated access via `AuthenticationGateView`

### Healthcare Compliance
- **HIPAA Considerations**: Appropriate for PHI handling with proper deployment
- **Audit Trail**: Core Data change tracking available
- **Access Control**: Device-level security integration

## Testing Strategy

### Unit Testing
- Core Data model validation
- Business logic in computed properties
- Date calculations and medication scheduling
- PDF generation functionality

### Integration Testing
- Core Data stack initialization
- CloudKit synchronization
- Print workflow end-to-end
- Authentication flow

### UI Testing
- Patient management workflows
- Medication dispensing processes
- Navigation and data entry
- Error handling scenarios

## Deployment Architecture

### Development Environment
- Local Core Data store
- CloudKit Development container
- Xcode Simulator/Device testing

### Production Environment
- Production CloudKit container
- App Store distribution
- Device-specific Core Data stores
- iCloud synchronization across user devices

## Extension Points

### Potential Enhancements
1. **Widget Support**: Today widget for upcoming medications
2. **Watch App**: watchOS companion for medication reminders
3. **Export Options**: CSV/Excel export functionality
4. **Barcode Scanning**: Medication identification via camera
5. **Reminder System**: Local notifications for medication schedules
6. **Reporting**: Analytics and usage reports
7. **Multi-language**: Localization support
8. **Backup/Restore**: Manual backup functionality

### API Integration Opportunities
- Pharmacy systems integration
- Electronic Health Records (EHR) connectivity
- Drug interaction checking
- Insurance verification systems

---

This technical architecture provides the foundation for understanding, maintaining, and extending the LMGMedication application while ensuring robust healthcare data management capabilities.