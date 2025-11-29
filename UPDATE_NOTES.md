# Patient View Toggle - Update Notes

## Summary
Added a segmented control toggle to the opening screen that allows users to switch between two viewing modes:
1. **By Next Dose** (default) - Shows patients grouped by week based on their next medication dose due date
2. **Alphabetical** - Shows patients grouped alphabetically by the first letter of their last name

## Changes Made

### 1. ContentView.swift
- **Added `PatientViewMode` enum** to represent the two viewing modes
- **Modified `ContentView`** to manage the view mode state and switch between the two views
- **Updated `PatientsListRootView`** to accept a binding to the view mode
- **Created `AlphabeticalPatientListMainView`** - A new main view wrapper for the alphabetical list
  - Includes the same header, action buttons, and settings menu as the "By Next Dose" view
  - Displays patients grouped by first letter of last name
  - Shows summary card with patient count and letter group count
  - Includes search functionality

### 2. User Interface Changes
- **Segmented Control**: Added at the top of both views to easily switch between modes
  - "By Next Dose" shows a calendar icon
  - "Alphabetical" shows a list icon
- **Consistent Layout**: Both views maintain the same header structure and action buttons
- **Smooth Transitions**: The view mode change is animated smoothly

## Features Preserved
- All existing functionality remains intact:
  - Add Patient button
  - Settings menu with access to:
    - Medication Templates
    - Providers
    - Sharing Groups
    - About App
    - Patients by Medication (sheet)
  - Navigation to patient details
  - Search functionality
  - Consistent theming (bronze/gold color scheme)

## Usage
1. Open the app - you'll see the default "By Next Dose" view
2. Tap the segmented control at the top to switch to "Alphabetical" view
3. Toggle back and forth as needed

## Technical Details
- The view mode state is managed at the `ContentView` level
- State is passed down to child views using `@Binding`
- Both views are now part of the main navigation stack (not sheets)
- The original `AlphabeticalPatientListView` (shown as a sheet) remains unchanged and accessible from the Settings menu

## Benefits
- **Faster Access**: No need to go through the Settings menu to see alphabetical view
- **Better UX**: Users can quickly switch between organizational methods
- **Consistent Experience**: Both views have the same layout and capabilities
- **Preserved Options**: The sheet-based alphabetical view is still available if needed
