# OSC Parameter Control System

A modular architecture that adds OSC control to MIDI parameters while maintaining full backward compatibility.

## Overview

The OSC Parameter Control System extends the existing MIDIController with OSC capabilities, enabling external applications (TouchOSC, Max/MSP, Pure Data, etc.) to control the same parameters as MIDI hardware knobs and sliders.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  MIDIController │    │   OSCController  │    │  External Apps  │
│   (Enhanced)    │    │                  │    │  (TouchOSC,etc) │
└─────────┬───────┘    └─────────┬────────┘    └─────────┬───────┘
          │                      │                       │
          ▼                      ▼                       ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    InputRouter                              │
    │  • Routes MIDI/OSC to parameters                           │
    │  • Handles input source priorities                         │
    │  • Manages conflict resolution                             │
    └─────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                ParameterRegistry                            │
    │  • Central parameter storage                                │
    │  • Multiple address types (MIDI CC, OSC, semantic)         │
    │  • Change notification system                               │
    └─────────────────────────────────────────────────────────────┘
```

## Key Components

### ParameterRegistry
- **Purpose**: Central parameter storage and management
- **Features**: 
  - Parameter validation and constraining
  - Multiple address types per parameter
  - Input source enable/disable
  - Change notification callbacks
- **File**: `etc/ParameterRegistry/ParameterRegistry.sc`

### InputRouter
- **Purpose**: Routes input from multiple sources to parameters
- **Features**:
  - Source priority management
  - Conflict resolution (MIDI beats OSC after timeout)
  - Input source enable/disable
- **File**: `etc/InputRouter/InputRouter.sc`

### OSCController
- **Purpose**: Manages OSC integration
- **Features**:
  - Auto-generated OSC addresses
  - Bidirectional sync
  - OSC client discovery
  - Custom address mapping
- **File**: `etc/OSCController/OSCController.sc`

### MIDIControllerEnhanced
- **Purpose**: Enhanced MIDIController with OSC support
- **Features**:
  - 100% backward compatibility
  - OSC enable/disable per parameter
  - Bulk operations
  - Enhanced debugging
- **File**: `etc/MIDIController/MIDIControllerEnhanced.sc`

## Quick Start

### 1. Create Enhanced MIDI Controller

```supercollider
// Create with OSC support
~midiController = MIDIControllerEnhanced.new(
    ~vstInstances,      // Your VST instances
    ~oscNetAddr,        // Your OSC network address
    debug: true,        // Enable debug output
    enableOSC: true     // Enable OSC functionality
);
```

### 2. Enable OSC for Specific Parameters

```supercollider
// Enable OSC for specific knobs
~midiController.enableOSCForKnob(1, 8);  // Row 1, Position 8 (duration knob)
~midiController.enableOSCForKnob(1, 3);  // Row 1, Position 3 (velocity knob)

// Enable OSC for specific sliders
~midiController.enableOSCForSlider(0);   // Slider 0
```

### 3. Bulk Enable OSC

```supercollider
// Enable OSC for all knobs
~addresses = ~midiController.enableOSCForAllKnobs();

// Enable OSC for all sliders
~sliderAddresses = ~midiController.enableOSCForAllSliders();

// Or enable everything at once
~allAddresses = ~midiController.generateOSCAddresses();
```

### 4. List OSC Addresses

```supercollider
// See all OSC-enabled parameters
~midiController.listOSCAddresses().keysValuesDo { |paramId, address|
    "Parameter %: %".format(paramId, address).postln;
};
```

### 5. Send OSC Messages

```supercollider
// From SuperCollider
var addr = NetAddr("127.0.0.1", 57121);
addr.sendMsg("/midi/row1/pos8", 0.5);    // Set duration knob to 50%
addr.sendMsg("/midi/row1/pos3", 100);    // Set velocity to 100

// From external applications, send OSC to port 57121:
// /midi/row1/pos8 0.5
// /midi/row1/pos3 100
// /midi/cc/58 64
```

## OSC Address Schema

### Auto-Generated Addresses

The system automatically generates intuitive OSC addresses based on parameter types:

#### MIDI CC Addresses
```
/midi/cc/{ccNumber}     # Direct CC control
# Examples:
/midi/cc/58             # CC 58 (Row 1, Pos 8 on MIDIMix)
/midi/cc/16             # CC 16 (Row 1, Pos 1 on MIDIMix)
```

#### MIDI Row/Position Addresses  
```
/midi/row{row}/pos{pos} # Physical layout
# Examples:
/midi/row1/pos8         # Row 1, Position 8 (duration knob)
/midi/row1/pos3         # Row 1, Position 3 (velocity knob)  
/midi/row2/pos5         # Row 2, Position 5 (expression min)
```

#### Parameter-Based Addresses
```
/param/{context}/{parameter}
# Examples:
/param/layer1/velocity   # Layer 1 velocity
/param/global/duration   # Global duration
/param/layer2/expression # Layer 2 expression
```

#### Mapping System Addresses
```
/mapping/row{row}/{parameter}
# Examples:
/mapping/row1/velocity      # Row 1 mapped velocity
/mapping/row2/expressionMin # Row 2 mapped expression minimum
```

## Backward Compatibility

The enhanced system maintains 100% compatibility with existing code:

```supercollider
// All existing API calls work unchanged:
~midiController.getKnobRow(1, 8);        // Still works
~midiController.getSliderValue(0);       // Still works
~midiController.setMappingMode(true);    // Still works
~midiController.saveSnapshot("preset1"); // Still works

// New OSC features are additive:
~midiController.enableOSCForKnob(1, 8);           // New
~midiController.getParameterOSCAddress("midi_row1_pos8"); // New
```

## Advanced Features

### Bidirectional Sync

Enable sending parameter changes back to OSC clients:

```supercollider
// Enable bidirectional sync
~midiController.enableBidirectionalOSC(true);

// Add OSC clients to receive updates
~midiController.addOSCClient("192.168.1.100", 9000);  // TouchOSC device

// Now when MIDI knobs move, OSC clients receive updates
```

### Input Source Priorities

The system automatically handles conflicts between MIDI and OSC:

- **MIDI**: Priority 20 (high)
- **OSC**: Priority 10 (medium)  
- **Programmatic**: Priority 0 (low)

MIDI input always wins immediately. OSC can override MIDI after 2 seconds of inactivity.

### Parameter Change Callbacks

Register callbacks for parameter changes:

```supercollider
~midiController.parameterRegistry.onParameterChange("midi_row1_pos8", { |id, oldVal, newVal, source|
    "Duration changed to % seconds (source: %)".format(newVal, source).postln;
});
```

### Custom OSC Addresses

Override auto-generated addresses:

```supercollider
// Set custom address for a parameter
~midiController.setCustomOSCAddress("midi_row1_pos8", "/custom/duration");

// Enable with custom address
~midiController.enableOSCForParameter("midi_row1_pos8", "/my/custom/address");
```

## Integration Examples

### Layers System Integration

```supercollider
// Load layers OSC integration
(thisProcess.nowExecutingPath.dirname +/+ "layers-osc-integration.scd").load;

// Now control layers via OSC:
NetAddr("127.0.0.1", 57121).sendMsg("/layers/start", 3.0);      // Start with 3s duration
NetAddr("127.0.0.1", 57121).sendMsg("/param/layer1/velocity", 120); // Set layer 1 velocity
NetAddr("127.0.0.1", 57121).sendMsg("/layers/stop");           // Stop layers
```

### TouchOSC Setup

1. **Enable bidirectional sync**:
```supercollider
~midiController.enableBidirectionalOSC(true);
~midiController.addOSCClient("192.168.1.100", 9000); // Your TouchOSC device IP
```

2. **Create TouchOSC layout** with faders/knobs sending to:
   - `/midi/row1/pos8` (Duration)
   - `/midi/row1/pos3` (Velocity) 
   - `/midi/row2/pos5` (Expression)

3. **Receive feedback**: TouchOSC faders will move when you adjust MIDI knobs

## Testing

### Run Basic Tests

```supercollider
// Load and run comprehensive tests
(thisProcess.nowExecutingPath.dirname +/+ "test-osc-parameters.scd").load;
```

### Manual Testing

```supercollider
// Create test OSC sender
~testOSC = NetAddr("127.0.0.1", 57121);

// Test parameter updates
~testOSC.sendMsg("/midi/row1/pos8", 0.75);  // Set duration to 75%
~testOSC.sendMsg("/midi/cc/58", 96);        // Same parameter via CC number

// Check values
~midiController.getKnobRow(1, 8);          // Should show updated value
```

## Troubleshooting

### Common Issues

1. **OSC not working**: 
   - Ensure `enableOSC: true` when creating MIDIControllerEnhanced
   - Check OSC port conflicts (default: 57121)

2. **Parameter not found**:
   - Use `~midiController.getParameterIDs()` to see available parameters
   - Ensure parameter is registered before enabling OSC

3. **Address conflicts**:
   - Use `~midiController.listOSCAddresses()` to see current mappings
   - Check for duplicate OSC address registrations

### Debug Output

Enable debug output for detailed logging:

```supercollider
~midiController = MIDIControllerEnhanced.new(debug: true, enableOSC: true);

// See full system state
~midiController.printParameterState();
```

## Performance Notes

- **Parameter Lookup**: O(1) dictionary lookups for address resolution
- **OSC Filtering**: Only enabled parameters create OSC handlers
- **Change Notifications**: Lazy evaluation prevents unnecessary processing
- **Memory Usage**: Minimal overhead - only enabled parameters consume resources

## File Structure

```
etc/
├── ParameterRegistry/
│   └── ParameterRegistry.sc        # Core parameter management
├── InputRouter/
│   └── InputRouter.sc              # Input routing and conflicts
├── OSCController/
│   ├── OSCController.sc            # OSC integration
│   ├── test-osc-parameters.scd     # Comprehensive tests
│   ├── layers-osc-integration.scd  # Layers system integration
│   └── README.md                   # This file
└── MIDIController/
    └── MIDIControllerEnhanced.sc   # Enhanced MIDI controller
```

## API Reference

### MIDIControllerEnhanced

#### OSC Control Methods
- `enableOSCForParameter(parameterId, oscAddress=nil)` - Enable OSC for parameter
- `disableOSCForParameter(parameterId)` - Disable OSC for parameter
- `enableOSCForKnob(row, pos, oscAddress=nil)` - Enable OSC for knob
- `enableOSCForSlider(index, oscAddress=nil)` - Enable OSC for slider
- `getParameterOSCAddress(parameterId)` - Get OSC address for parameter
- `listOSCAddresses()` - List all OSC-enabled parameters

#### Bulk Operations
- `enableOSCForAllKnobs()` - Enable OSC for all knobs
- `enableOSCForAllSliders()` - Enable OSC for all sliders  
- `generateOSCAddresses()` - Auto-generate OSC addresses for all parameters

#### Bidirectional Sync
- `enableBidirectionalOSC(enabled=true)` - Enable/disable bidirectional sync
- `addOSCClient(hostname, port)` - Add OSC client for sync

#### Parameter Access
- `getParameterIDs()` - Get all parameter IDs
- `getParameterSpec(parameterId)` - Get parameter specification
- `getParameterMetadata(parameterId)` - Get parameter metadata

## Future Enhancements

- **WebSocket Support**: Web browser control interfaces
- **MIDI Learn**: Click-to-assign OSC addresses  
- **Parameter Grouping**: Bulk enable/disable by parameter type
- **Preset System**: Save/load OSC address mappings
- **Multiple OSC Ports**: Different ports for different parameter types
- **Advanced Routing**: Parameter math and scaling