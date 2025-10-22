# LMGMedication

A comprehensive medication management application designed for healthcare providers to track patients and their dispensed medications.

## Overview

LMGMedication is a SwiftUI-based iOS application that helps healthcare providers manage patient medication dispensing, tracking, and labeling. The app features a clean, professional interface with robust data management capabilities powered by Core Data and CloudKit synchronization.

## Key Features

### Patient Management
- **Patient Registration**: Add and manage patient information including names, birthdates, and contact details
- **Active/Inactive Status**: Toggle patient status to organize active vs. inactive patients
- **Weekly Organization**: Patients are automatically grouped by upcoming medication due dates
- **Search and Navigation**: Quick access to patient details and medication history

### Medication Management
- **Medication Templates**: Pre-configured medication templates with ingredient information
- **Dispensed Medications**: Track specific instances of medications given to patients
- **Dosage Tracking**: Record dose amounts, units, quantities, and expiration dates
- **Prescription Management**: Link medications to prescribing providers
- **Injectable vs. Non-Injectable**: Support for different medication types

### Provider Management
- **Provider Directory**: Maintain a list of healthcare providers
- **Prescription Tracking**: Link dispensed medications to specific providers
- **Provider Information**: Store provider names and credentials

### Label Generation & Printing
- **PDF Label Generation**: Create professional medication labels
- **Dual Label Printing**: Print original date and current date labels
- **Bulk Printing**: Generate multiple labels at once
- **Custom Formatting**: Professional layouts for different medication types

### Data Synchronization
- **CloudKit Integration**: Automatic sync across devices using iCloud
- **Offline Support**: Full functionality when offline with sync when connection is restored
- **Data Recovery**: Robust error handling with automatic recovery mechanisms
- **Real-time Updates**: Live updates when data changes occur

## Architecture

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence with CloudKit integration
- **CloudKit**: iCloud synchronization and backup
- **PDFKit**: PDF generation for medication labels
- **Swift Concurrency**: Async/await for modern asynchronous programming
- **Combine**: Reactive programming for data binding

### Design Patterns
- **MVVM**: Model-View-ViewModel architecture
- **Repository Pattern**: Data access abstraction
- **Observer Pattern**: Real-time data updates via Core Data notifications
- **Singleton Pattern**: Shared persistence controller

### Core Data Model
```
Patient (extends Person)
├── firstName, lastName, birthdate
├── isActive, timeStamp
└── medications (1:many) → DispencedMedication

DispencedMedication
├── dose, doseUnit, dispenceAmt
├── dispenceDate, expDate, lotNum
├── baseMedication (many:1) → Medication
├── patient (many:1) → Patient
└── prescriber (many:1) → Provider

Medication
├── name, ingredient1, ingredient2
├── concentration1, concentration2
├── pharmacy, injectable
└── timestamp

Provider (extends Person)
├── firstName, lastName
└── timeStamp
```

## Project Structure

```
LMGMedication/
├── App/
│   ├── LMGMedicationApp.swift          # Main app entry point
│   ├── ContentView.swift               # Root view with patient list
│   └── Persistence.swift               # Core Data stack
├── Models/
│   ├── Patient+CoreDataClass.swift     # Patient entity extensions
│   ├── DispencedMedication+...         # Medication entity extensions
│   └── Core Data Properties files
├── Views/
│   ├── PatientDetailView.swift         # Patient detail interface
│   ├── MedicationTemplatesView.swift   # Template management
│   ├── ProvidersListView.swift         # Provider management
│   └── NewMedicationLabelView.swift    # Label creation
├── Managers/
│   ├── MedicationPrintManager.swift    # PDF and print handling
│   └── SharingManager.swift            # Data sharing utilities
└── Resources/
    └── LMGMedication.xcdatamodeld      # Core Data model
```

## Installation & Setup

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Apple Developer Account (for CloudKit)
- iCloud account for synchronization

### Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone [repository-url]
   cd LMGMedication
   ```

2. **Configure CloudKit**
   - Open project in Xcode
   - Update CloudKit container identifier in:
     - Persistence.swift: Update `iCloud.LMGMedication` identifier
     - Project capabilities: Ensure CloudKit is enabled
   - Configure CloudKit schema in CloudKit Console

3. **Build and Run**
   ```bash
   # Open in Xcode
   open LMGMedication.xcodeproj
   
   # Build and run on simulator or device
   ```

## Usage Guide

### Adding a Patient
1. Tap "Add Patient" on the main screen
2. Enter patient information (name, birthdate, etc.)
3. Save to create the patient record

### Dispensing Medication
1. Select a patient from the main list
2. Tap "Add Medication" in patient details
3. Choose medication template or create new
4. Enter dosage, quantity, and expiration details
5. Select prescribing provider
6. Save the dispensed medication

### Printing Labels
1. Navigate to patient's medication list
2. Select medications to print (single or multiple)
3. Choose print options (original date, current date, or dual)
4. Generate PDF labels for printing

### Managing Templates
1. Tap "Templates" on main screen
2. Add new medication templates with ingredients and concentrations
3. Templates are reused when dispensing medications

## Development

### Key Components

#### PersistenceController
Manages Core Data stack with CloudKit integration, including error recovery and preview data generation.

#### Patient & DispencedMedication Models
Core entities with computed properties for display formatting and relationship management.

#### MedicationPrintManager
Handles PDF generation and printing workflows for medication labels.

#### ContentView
Main interface with patient organization, filtering, and navigation.

### Custom Features

#### Theming System
- Consistent bronze/gold color scheme throughout app
- Light theme optimized for medical environments
- Professional appearance suitable for healthcare settings

#### Error Handling
- Comprehensive error handling for Core Data operations
- User-friendly error messages and recovery options
- Automatic retry mechanisms for CloudKit sync issues

#### Accessibility
- VoiceOver support throughout the interface
- Semantic labels and hints for assistive technologies
- High contrast support for better visibility

## Testing

### Unit Tests
- Core Data model validation
- Business logic testing
- Date calculation accuracy
- PDF generation verification

### UI Tests
- Patient management workflows
- Medication dispensing flows
- Label printing processes
- Navigation and data entry

### Preview Support
- SwiftUI previews with sample data
- Multiple device size testing
- Light/dark mode compatibility

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

### Coding Standards
- Swift style guide compliance
- Comprehensive documentation for public APIs
- Unit tests for new functionality
- SwiftUI preview support for new views

## License

Copyright © 2025 Michael Lazar. All rights reserved.

## Support

For questions, issues, or feature requests, please contact the development team or create an issue in the repository.

---

**Note**: This application handles sensitive medical information. Ensure compliance with HIPAA and other relevant healthcare data protection regulations when deploying in production environments.