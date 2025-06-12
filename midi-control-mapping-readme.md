# MIDI Control Mapping System

The MIDI Control Mapping system (`setup/midi-control-mapping.scd`) provides dynamic assignment of MIDI knob rows to different VST groups with configurable control templates. This allows performers to control multiple VST groups independently using different rows of knobs on their MIDI controller.

## System Overview

### **Control Templates**
The system defines two control templates that map MIDI knobs to specific parameters:

- **Expression Control Template**: Maps knobs 5, 6, 7 to expression parameters
  - Knob 5 → `expressionMin` (range: 0-127)
  - Knob 6 → `expressionMax` (range: 0-127)  
  - Knob 7 → `expressionDurationScalar` (range: 0.1-1.0)

- **Timing Control Template**: Maps knobs 2, 3, 4 to timing parameters
  - Knob 2 → `noteDuration` (range: 0.005-0.5s)
  - Knob 3 → `noteRestTime` (range: 0.0001-0.4s)
  - Knob 4 → `velocity` (range: 1-127)

### **Row Assignment System**
Each of the three knob rows can be independently configured:

- **Row 1**: Defaults to current system behavior (backwards compatible)
- **Row 2**: Can be assigned to specific VST groups with any template
- **Row 3**: Can be assigned to specific VST groups with any template

### **VST Group Integration**
The system integrates with the existing VSTManager to provide:

- **Group-Specific Control**: Each VST group can have independent parameter values
- **Real-time Updates**: Parameter changes are applied immediately to target groups
- **Seamless Integration**: Works alongside existing control systems without conflicts

## Configuration Interface

### **GUI Controls**
The MIDI Control Mapping GUI provides intuitive configuration:

- **Row Enable/Disable**: Checkbox to activate each row
- **Group Selection**: Dropdown to choose target VST group ("Current/Default" or specific groups)
- **Template Selection**: Dropdown to choose control template (Expression or Timing)
- **Apply All**: Button to activate current configuration
- **Reset All**: Button to restore default settings
- **Save/Load**: Buttons for configuration persistence

### **Default Configuration**
```supercollider
// Row 1: Backwards compatible (current behavior)
Row 1: Enabled → Current/Default → Expression Control

// Row 2: Disabled by default
Row 2: Disabled → Current/Default → Expression Control

// Row 3: Disabled by default  
Row 3: Disabled → Current/Default → Timing Control
```

## Parameter Storage

### **Group-Specific Parameters**
Each VST group maintains independent parameter values:

```supercollider
~groupControlParams["Strings"] = (
    expressionMin: 20,
    expressionMax: 100,
    expressionDurationScalar: 0.8,
    noteDuration: 0.15,
    noteRestTime: 0.1,
    velocity: 110
);
```

### **Default Behavior**
- **Row 1 with nil group**: Uses existing `~ccControl` global parameters
- **Other configurations**: Create group-specific parameter storage
- **Parameter validation**: Ensures `expressionMax > expressionMin` automatically

## Integration Hooks

### **Existing System Integration**
The system hooks into the existing control functions:

```supercollider
// Original function becomes universal updater
~updateExpressionRangeFromKnobs = {
    // Calls new system that handles all rows/groups
    ~updateAllGroupControls.();
};
```

### **Universal Update Function**
```supercollider
~updateAllGroupControls = {
    // Processes all enabled row mappings
    ~rowMappings.keysValuesDo { |rowNum, mapping|
        if (mapping.enabled) {
            // Apply knob values to group parameters
            // Handle template-specific mappings
            // Ensure parameter validation
        };
    };
};
```

## State Persistence

### **Automatic Saving**
- **Configuration File**: `data/midi-control-mappings.scd`
- **Content**: Row mappings and group-specific parameters
- **Format**: SuperCollider-readable dictionary format

### **Save/Load Operations**
```supercollider
// Save current configuration
~saveMIDIControlMappings.();

// Load saved configuration  
~loadMIDIControlMappings.();

// View current status
~showMIDIControlMappingStatus.();
```

## Performance Usage

### **Multi-Group Control Example**
```supercollider
// Configure for multi-group performance
Row 1: Enabled → Current/Default → Expression Control  // Primary group
Row 2: Enabled → Strings → Expression Control          // String section
Row 3: Enabled → Winds → Timing Control               // Wind section timing

// Now performer can:
// - Control primary group expression with row 1 knobs 5,6,7
// - Control string expression independently with row 2 knobs 5,6,7  
// - Control wind timing with row 3 knobs 2,3,4
```

### **Real-time Workflow**
1. **Setup Phase**: Configure row assignments via GUI before performance
2. **Performance Phase**: Use assigned knobs to control different groups independently
3. **Adaptation Phase**: Save configurations for different pieces/sections

## Status Monitoring

### **Debug Functions**
```supercollider
// View complete system status
~showMIDIControlMappingStatus.();

// Check specific group parameters
~getGroupParams.("Strings");

// Verify row mappings
~rowMappings.postln;
```

### **GUI Status Display**
The GUI shows active mappings in real-time:
```
Active: Row 1→Default (Expression Control), Row 2→Strings (Expression Control)
```

## Backward Compatibility

The system maintains full backward compatibility:

- **Default Row 1**: Automatically recreates existing `~ccControl` behavior
- **Existing Code**: All existing sketches work without modification
- **Parameter Access**: `~ccControl` continues to work as before
- **Integration**: New system enhances rather than replaces existing functionality

## Technical Implementation

### **File Structure**
```
setup/midi-control-mapping.scd     # Main system file
data/midi-control-mappings.scd     # Saved configurations
```

### **Key Functions**
- `~createMIDIControlMappingGUI.()` - Create the configuration interface
- `~updateAllGroupControls.()` - Apply knob values to all enabled mappings
- `~showMIDIControlMappingStatus.()` - Display current system status
- `~saveMIDIControlMappings.()` - Save current configuration
- `~loadMIDIControlMappings.()` - Load saved configuration

### **Integration Points**
- Hooks into `~updateExpressionRangeFromKnobs` from control-systems.scd
- Uses VSTManager for group names and targeting
- Uses MIDIController for knob value access
- Maintains backward compatibility with existing `~ccControl` global

This MIDI Control Mapping system significantly expands the system's performance capabilities by enabling sophisticated multi-group control while maintaining the simplicity and reliability of the existing single-group workflow. 