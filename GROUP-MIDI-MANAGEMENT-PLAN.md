# VST Group MIDI Management Feature Plan

## Overview
Add comprehensive group management UI to the VST Manager window with manual MIDI row assignment capabilities that persist in configuration files.

---

## Current System Analysis

### Existing MIDI Row Assignment
- **Automatic assignment**: Groups get MIDI rows via modulo operation
  ```supercollider
  ~getMIDIRowForGroup = { |groupName|
      var idx = ~oscLayers.groupToIndex[groupName];  // Alphabetical index
      (idx % 3) + 1  // Returns 1, 2, or 3
  };
  ```
- **Limitation**: No manual override possible
- **Problem**: Groups may conflict when > 3 groups exist

### Existing UI Structure
- Window size: 400x650
- Sections: VST selection, instances list, group management, keyboard assignment, MIDI overrides, configuration management

### Configuration System
- Saves: VST instances, groups (with type), MIDI settings
- Missing: MIDI row assignments per group

---

## Proposed Solution

### 1. Data Structure Changes

#### Add Global MIDI Row Override Dictionary
```supercollider
// In layers-osc-core.scd (at top with other globals)
~midiRowOverrides = Dictionary.new;  // groupName → rowNumber (1-3)

// Modified ~getMIDIRowForGroup function
~getMIDIRowForGroup = { |groupName|
    var override, idx;

    // Check for manual override first
    override = ~midiRowOverrides[groupName];
    if (override.notNil) {
        override.clip(1, 3)  // Ensure valid range
    } {
        // Fall back to automatic assignment
        idx = ~oscLayers.groupToIndex[groupName];
        if (idx.notNil) {
            (idx % 3) + 1
        } {
            1  // Default
        }
    }
};
```

---

### 2. UI Design

#### New Section: "Group Details & MIDI Mapping"
Position: Between "Group Management" and "Keyboard Group Assignment"

**Layout Structure:**
```
┌─────────────────────────────────────────────┐
│ Group Details & MIDI Mapping:              │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ Groups List:                            │ │
│ │ ┌───────────────────────────────────┐  │ │
│ │ │ • bTuba-chord (Chord) - Row 1     │  │ │
│ │ │ • flute-melody (Regular) - Row 2  │  │ │
│ │ │ • sax-group (Regular) - Row 3     │  │ │
│ │ └───────────────────────────────────┘  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Selected Group: bTuba-chord                │
│ Type: Chord Group                          │
│ Index: 0 (alphabetically sorted)           │
│ MIDI Row: [1 ▼] □ Manual Override         │
│                                             │
│ Assigned Instruments:                      │
│ ┌─────────────────────────────────────────┐ │
│ │ • bTuba 00                             │ │
│ │ • bTuba 01                             │ │
│ │ • bTuba 02                             │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [Remove from Group] [Delete Group]         │
└─────────────────────────────────────────────┘
```

#### UI Components:
1. **Groups ListView** - Shows all groups with type and current MIDI row
2. **Details Section** - Shows selected group details:
   - Group name and type
   - Alphabetical index
   - MIDI row selector (PopUpMenu: 1, 2, 3)
   - Manual override checkbox
   - List of assigned VST instances
3. **Action Buttons**:
   - Remove selected VST from group
   - Delete entire group

---

### 3. Implementation Details

#### UI Code Structure (in vst-management.scd)
```supercollider
// Add after line 267 (end of group management section)

// --- Group Details & MIDI Mapping Section ---
layout.add(StaticText().string_("Group Details & MIDI Mapping:"));
groupDetailsLayout = VLayout();

// Groups list
groupsListView = ListView()
    .selectionMode_(\single)
    .items_([]);  // Will be populated by updateGroupsList

groupDetailsLayout.add(groupsListView, stretch: 1);

// Selected group details
selectedGroupLayout = VLayout();

// Group info display
groupNameText = StaticText().string_("No group selected");
groupTypeText = StaticText().string_("Type: -");
groupIndexText = StaticText().string_("Index: -");

// MIDI row control
midiRowLayout = HLayout();
midiRowLayout.add(StaticText().string_("MIDI Row:"));
midiRowMenu = PopUpMenu().items_(["1", "2", "3"]).value_(0);
midiRowLayout.add(midiRowMenu);
manualOverrideCheck = CheckBox().string_("Manual Override");
midiRowLayout.add(manualOverrideCheck);

// VST instances in group
groupMembersLabel = StaticText().string_("Assigned Instruments:");
groupMembersListView = ListView()
    .selectionMode_(\single)
    .items_([]);

// Group action buttons
groupActionsLayout = HLayout();
removeFromGroupButton = Button().states_([["Remove from Group"]]);
deleteGroupButton = Button().states_([["Delete Group"]]);
groupActionsLayout.add(removeFromGroupButton);
groupActionsLayout.add(deleteGroupButton);

// Add all to selected group layout
selectedGroupLayout.add(groupNameText);
selectedGroupLayout.add(groupTypeText);
selectedGroupLayout.add(groupIndexText);
selectedGroupLayout.add(midiRowLayout);
selectedGroupLayout.add(groupMembersLabel);
selectedGroupLayout.add(groupMembersListView, stretch: 1);
selectedGroupLayout.add(groupActionsLayout);

groupDetailsLayout.add(selectedGroupLayout);
layout.add(groupDetailsLayout, stretch: 1);
```

#### Update Functions
```supercollider
// Function to update groups list display
updateGroupsList = {
    var groupItems, groupNames, currentSelection;

    if (~vstManager.notNil) {
        groupNames = ~vstManager.getGroupNames().sort;
        groupItems = groupNames.collect { |name|
            var groupType, midiRow, override;
            groupType = ~vstManager.getGroupType(name);
            midiRow = ~getMIDIRowForGroup.(name);
            override = ~midiRowOverrides[name].notNil;

            format("% (%) - Row % %",
                name,
                if(groupType == \chord) { "Chord" } { "Regular" },
                midiRow,
                if(override) { "[M]" } { "" }  // [M] indicates manual override
            )
        };

        currentSelection = groupsListView.value;
        groupsListView.items = groupItems;

        // Restore selection if valid
        if (currentSelection.notNil and: { currentSelection < groupItems.size }) {
            groupsListView.value = currentSelection;
        };
    };
};

// Function to update selected group details
updateSelectedGroupDetails = { |groupName|
    var groupType, groupIndex, members, currentRow, hasOverride;

    if (groupName.notNil and: { ~vstManager.notNil }) {
        groupType = ~vstManager.getGroupType(groupName);
        groupIndex = ~oscLayers.groupToIndex[groupName] ? "-";
        members = ~vstManager.groups[groupName].members;
        currentRow = ~getMIDIRowForGroup.(groupName);
        hasOverride = ~midiRowOverrides[groupName].notNil;

        groupNameText.string = "Selected Group: " ++ groupName;
        groupTypeText.string = "Type: " ++ if(groupType == \chord) { "Chord Group" } { "Regular Group" };
        groupIndexText.string = format("Index: % (alphabetically sorted)", groupIndex);

        midiRowMenu.value = currentRow - 1;  // Menu is 0-indexed
        manualOverrideCheck.value = hasOverride.asInteger;

        groupMembersListView.items = members ? [];
    } {
        // Clear details
        groupNameText.string = "No group selected";
        groupTypeText.string = "Type: -";
        groupIndexText.string = "Index: -";
        groupMembersListView.items = [];
    };
};
```

---

### 4. Configuration Persistence

#### Modified Configuration Save (ConfigurationManager.sc)
```supercollider
// In saveVSTConfiguration method, add after line 97:
// Get MIDI row overrides
var midiRowMappings = Dictionary.new;
if (~midiRowOverrides.notNil) {
    ~midiRowOverrides.keysValuesDo { |groupName, rowNum|
        midiRowMappings[groupName] = rowNum;
    };
};

// Modify config object at line 100 to include:
config = (
    configName: name,
    description: description ? "",
    isDefault: false,
    timestamp: Date.getDate.stamp,
    vstInstances: instanceData,
    groups: groupData,
    midiSettings: midiSettings,
    midiRowMappings: midiRowMappings  // NEW
);
```

#### Modified Configuration Load
```supercollider
// In applyConfiguration method, add after groups are restored:
// Restore MIDI row mappings
if (config["midiRowMappings"].notNil) {
    ~midiRowOverrides.clear;
    config["midiRowMappings"].keysValuesDo { |groupName, rowNum|
        ~midiRowOverrides[groupName] = rowNum;
    };
    "Restored MIDI row mappings for % groups".format(~midiRowOverrides.size).postln;
};

// Trigger dynamic layers refresh to apply new MIDI mappings
if (~refreshDynamicLayersMIDI.notNil) {
    ~refreshDynamicLayersMIDI.();
};
```

---

### 5. Action Handlers

#### MIDI Row Change Handler
```supercollider
midiRowMenu.action = { |menu|
    var selectedGroupIdx, groupName, newRow;

    selectedGroupIdx = groupsListView.value;
    if (selectedGroupIdx.notNil) {
        groupName = ~vstManager.getGroupNames().sort[selectedGroupIdx];
        newRow = menu.value + 1;  // Convert 0-indexed to 1-indexed

        if (manualOverrideCheck.value.asBoolean) {
            ~midiRowOverrides[groupName] = newRow;
            "Set manual MIDI row % for group '%'".format(newRow, groupName).postln;
        } {
            // Remove override to use automatic assignment
            ~midiRowOverrides[groupName] = nil;
            "Removed manual MIDI row for group '%' (using automatic)".format(groupName).postln;
        };

        // Refresh dynamic layers to apply change
        if (~updateLayerMIDIRow.notNil) {
            ~updateLayerMIDIRow.(groupName);
        };

        // Update display
        updateGroupsList.();
        statusText.string = format("MIDI row updated for group: %", groupName);
    };
};

manualOverrideCheck.action = { |check|
    var selectedGroupIdx, groupName;

    selectedGroupIdx = groupsListView.value;
    if (selectedGroupIdx.notNil) {
        groupName = ~vstManager.getGroupNames().sort[selectedGroupIdx];

        if (check.value.asBoolean) {
            // Enable manual override with current value
            ~midiRowOverrides[groupName] = midiRowMenu.value + 1;
        } {
            // Disable manual override
            ~midiRowOverrides[groupName] = nil;
        };

        // Trigger updates
        updateGroupsList.();
        if (~updateLayerMIDIRow.notNil) {
            ~updateLayerMIDIRow.(groupName);
        };
    };
};
```

---

### 6. Integration with Dynamic Layers

#### Add to layers-osc-core.scd
```supercollider
// Function to update a specific layer's MIDI row
~updateLayerMIDIRow = { |groupName|
    var config, newRow;

    config = ~oscLayers.dynamicConfigs[groupName];
    if (config.notNil) {
        newRow = ~getMIDIRowForGroup.(groupName);

        "Updating MIDI row for group '%': % → %".format(
            groupName,
            config.midiRow ? "none",
            newRow
        ).postln;

        config.midiRow = newRow;

        // Update any active parameter callbacks
        if (~updateLayerParameterCallbacks.notNil) {
            ~updateLayerParameterCallbacks.(groupName);
        };
    };
};

// Function to refresh all MIDI rows (for config load)
~refreshDynamicLayersMIDI = {
    ~oscLayers.dynamicConfigs.keysValuesDo { |groupName, config|
        ~updateLayerMIDIRow.(groupName);
    };
    "Refreshed MIDI rows for all dynamic layers".postln;
};
```

---

### 7. Benefits & Features

#### Benefits:
1. **Visual clarity** - See all groups, their types, and MIDI assignments at a glance
2. **Manual control** - Override automatic assignment when needed
3. **Persistence** - MIDI mappings saved with configurations
4. **Conflict resolution** - Manually resolve conflicts when >3 groups exist
5. **Real-time updates** - Changes apply immediately to dynamic layers

#### Features:
- **[M] indicator** - Shows which groups have manual overrides
- **Group details view** - Complete information about selected group
- **Member management** - Remove individual VSTs from groups
- **Group deletion** - Delete entire groups when needed
- **Alphabetical index display** - Understand automatic assignment logic

---

### 8. Implementation Steps

1. **Add global Dictionary** for MIDI row overrides
2. **Modify ~getMIDIRowForGroup** to check overrides first
3. **Add UI section** to vst-management.scd
4. **Implement update functions** for list and details display
5. **Add action handlers** for MIDI row changes
6. **Update ConfigurationManager** save/load methods
7. **Add refresh functions** to layers-osc-core.scd
8. **Test** manual overrides, persistence, and dynamic updates

---

### 9. Window Size Consideration

Current window: 400x650
Proposed: Increase to **400x850** to accommodate new section

Alternative: Make groups section collapsible or move to separate tab/window if space is concern.

---

### 10. Edge Cases & Error Handling

1. **Deleted groups** - Clear overrides when group deleted
2. **Renamed groups** - Transfer overrides on rename
3. **Duplicate MIDI rows** - Allow (user's choice), but show warning
4. **Config compatibility** - Handle old configs without midiRowMappings gracefully

---

## Summary

This feature adds essential manual control over MIDI row assignments while maintaining backward compatibility with the automatic system. The UI provides clear visibility of all groups and their assignments, making it easy to manage complex multi-group setups.

Key improvements:
- Manual MIDI row override capability
- Persistent configuration storage
- Clear visual indication of overrides
- Real-time dynamic layer updates
- Complete group management interface