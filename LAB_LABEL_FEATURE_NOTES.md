# Lab Draw Label Feature - Implementation Notes

## Summary
Added a blood draw test tube label printing feature to the Patient Detail screen. Users can now print 2" × 1" labels for lab specimen tubes with patient information and space for phlebotomist initials.

## Changes Made

### 1. PatientDetailView Updates

#### Added State
- `@State private var showingLabLabelPrint = false` - Controls lab label sheet presentation

#### Added Toolbar
- **Lab Label Button** in the navigation bar (top right)
  - Icon: Test tube (testtube.2)
  - Text: "Lab Label"
  - Opens the LabLabelPrintView sheet

#### Added Sheet Presentation
- `.sheet(isPresented: $showingLabLabelPrint)` - Presents LabLabelPrintView

### 2. New Components Created

#### LabLabelPrintView
Main view for lab label printing interface
- **Features:**
  - Preview of the label before printing
  - Print button to initiate print dialog
  - Label specifications information
  - Clean, professional UI matching app theme

#### LabLabelPreview
Preview component showing label format
- **Label Content (2" × 1" format):**
  1. **Line 1:** Patient name - "Last, First"
  2. **Line 2:** Date of birth - "DOB: MM/DD/YYYY"
  3. **Line 3:** Current date - "Drawn on: MM/DD/YYYY"
  4. **Separator line**
  5. **Line 4:** "Lazar Medical Group" (bold)
  6. **Line 5:** "Initials: ________" (for phlebotomist signature)

#### InfoRow
Helper view for displaying specifications
- Used in the info section to show label details

#### LabLabelPrintManager
Singleton manager for printing lab labels
- **Method:** `printLabLabel(for: Patient)` - Handles the print workflow
- Platform-specific (iOS) implementation

#### LabLabelRenderer
Custom print page renderer (iOS only)
- **Dimensions:** 144 points × 72 points (2" × 1" at 72 DPI)
- **Margins:** 4 points on all sides (printable area: 136 × 64 points)
- **Formatting:**
  - Name: 11pt bold
  - Regular text: 9pt
  - Small text: 8pt
  - Separator line between sections

## Label Format Details

### Physical Specifications
- **Size:** 2 inches wide × 1 inch tall
- **Print Resolution:** 72 DPI (standard)
- **Orientation:** Landscape
- **Paper Type:** Label stock suitable for test tubes

### Content Layout
```
[Patient Name (Last, First)]          - Bold, 11pt
DOB: MM/DD/YYYY                        - Regular, 9pt  
Drawn on: MM/DD/YYYY                   - Regular, 9pt
─────────────────────────               - Separator
Lazar Medical Group                    - Bold, 9pt
Initials: __________                   - Small, 8pt
```

### Typography
- **Patient Name:** Bold, 11pt - Most prominent
- **DOB and Date:** Regular, 9pt - Clear and readable
- **Organization:** Bold, 9pt - Professional branding
- **Initials:** Small, 8pt - Space-efficient

## User Workflow

1. **Navigate to Patient Detail** - Tap on a patient from the main list
2. **Tap "Lab Label"** - Button in top right corner (test tube icon)
3. **Review Preview** - See how the label will look
4. **Tap "Print Lab Label"** - Opens iOS print dialog
5. **Select Printer** - Choose label printer
6. **Print** - Label prints on 2" × 1" label stock

## Features

### ✅ Implemented
- Pull-up sheet interface for lab label
- Real-time preview of label content
- Current date automatically filled in
- Patient name and DOB automatically populated
- Professional formatting matching label size
- iOS native print dialog integration
- Custom print renderer for precise label dimensions
- Error handling for print failures
- Consistent app theming (bronze/gold colors)

### 📋 Label Information Included
- Patient last name and first name
- Date of birth (MM/DD/YYYY format)
- Current date as "drawn on" date
- Organization name (Lazar Medical Group)
- Signature line for phlebotomist initials

## Technical Details

### Print Manager Implementation
```swift
@MainActor
func printLabLabel(for patient: Patient) async {
    let printController = UIPrintInteractionController.shared
    let printInfo = UIPrintInfo.printInfo()
    
    printInfo.outputType = .general
    printInfo.jobName = "Lab Label - \(patient.displayName)"
    
    // Custom renderer for 2" × 1" label
    let renderer = LabLabelRenderer(patient: patient)
    printController.printPageRenderer = renderer
    
    printController.present(animated: true)
}
```

### Custom Renderer
- Overrides `drawPage(at:in:)` to draw label content
- Sets paper rect to exact label dimensions
- Uses Core Graphics for precise text positioning
- Handles all text formatting and layout

## Platform Support
- **iOS:** Full support with native print dialog
- **macOS:** Print manager can be extended for AppKit (not currently implemented)
- **visionOS/watchOS:** Not applicable for printing

## Testing Recommendations
1. Test on actual 2" × 1" label stock
2. Verify all patient information appears correctly
3. Test with patients missing DOB (should show "N/A")
4. Verify print preview shows correct layout
5. Test with different printer models
6. Verify label is readable when affixed to test tube
7. Check that initials line has adequate space
8. Test canceling print dialog
9. Verify sheet dismisses after successful print

## Design Considerations
- **Readability:** Large enough text for quick identification
- **Compliance:** Includes all necessary patient identifiers
- **Safety:** Clear labeling to prevent specimen mix-ups
- **Workflow:** Space for phlebotomist accountability (initials)
- **Branding:** Includes medical group name for professionalism

## Future Enhancements (Potential)
- Multiple label printing (print 2-3 labels at once)
- Barcode generation for electronic tracking
- Additional fields (MRN, order number)
- Label template customization
- Print directly to specific label printer
- Save print settings/preferences
