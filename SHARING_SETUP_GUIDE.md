# Core Data Model Updates for Automatic Sharing

## New Entity: SharingGroup

Add a new entity to your LMGMedication.xcdatamodeld file:

### Entity Name: SharingGroup

### Attributes:
- `name` (String, Optional)
- `participantEmails` (String, Optional) - Comma-separated list of email addresses
- `isActive` (Boolean, Default: YES)
- `autoShareNewPatients` (Boolean, Default: YES)
- `createdDate` (Date, Optional)
- `cloudKitRecordID` (String, Optional)

### CloudKit Configuration:
- Enable CloudKit for this entity
- Used with CloudKit: ✅
- CloudKit Container: iCloud.LMGMedication

## CloudKit Setup

### New Record Types to Add:

1. **SharingGroup**
   - name: String (Queryable, Sortable)
   - participantEmails: String
   - isActive: Int64
   - autoShareNewPatients: Int64
   - createdDate: Date/Time

2. **SharedPatient** (already implemented in CloudKitManager)
   - firstName: String
   - lastName: String
   - birthdate: Date/Time
   - timeStamp: Date/Time

3. **SharedDispensedMedication** (already implemented in CloudKitManager)
   - dose: String
   - doseUnit: String
   - dispenceAmt: Int64
   - dispenceUnit: String
   - dispenceDate: Date/Time
   - expDate: Date/Time
   - lotNum: String
   - createdDate: Date/Time
   - medicationName: String
   - ingredient1: String
   - concentration1: Double
   - ingredient2: String
   - concentration2: Double
   - pharmacy: String
   - injectable: Int64
   - prescriberFirstName: String
   - prescriberLastName: String

## Integration Steps:

1. **Update Core Data Model:**
   - Add the SharingGroup entity with the attributes above
   - Regenerate Core Data classes (or use the provided files)

2. **Add CloudKit Record Types:**
   - Go to CloudKit Console
   - Add the SharingGroup record type
   - Configure the fields as specified above

3. **Update Your Main UI:**
   - Add the sharing groups management button
   - See the integration example below

4. **Test the Integration:**
   - Create a sharing group
   - Add participants
   - Create a new patient and verify automatic sharing

## Main UI Integration Example:

Add this to your main content view's toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            // Your existing menu items...
            
            Divider()
            
            Button(action: {
                showingSharingGroups = true
            }) {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("Sharing Groups")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
.sheet(isPresented: $showingSharingGroups) {
    SharingGroupsView()
}
```

And add this state variable:
```swift
@State private var showingSharingGroups = false
```