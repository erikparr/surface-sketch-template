# MIDI Clip Recording & Playback System

## Overview
Replaces fixed melody timing with **recorded timing data** that preserves expressive performance and enables real-time tempo scaling.

## Core Concept
- **Before**: Fixed `noteDuration`, `noteRestTime` → robotic playback
- **After**: Recorded note timing + velocity → expressive playback with tempo scaling

## System Architecture

### Files & Dependencies
```
clip-system/
├── clip-loader.scd          # Main entry point + GUI auto-loader
├── clip-playback.scd        # Core timing-based playback + VST verification
├── clip-procmod.scd         # ProcMod integration
├── clip-integration.scd     # Sketch system integration + sequence management
├── clip-controls.scd        # MIDI tempo controls
├── clip-filemanager.scd     # File save/load management
└── claude.md               # This documentation

setup/
└── clip-management.scd      # GUI for recording, managing, and playing clips
```

**Load Order**: playbook → procmod → integration → controls → filemanager → clip-management GUI → loader

**Auto-Loading**: `clip-loader.scd` automatically loads and opens the clip management GUI

### Data Structure
```supercollider
// Enhanced clip data structure with advanced looping
(
    key: "clip-220625_143022",
    name: "My Recorded Clip",
    clipLoopCount: 3,        // Number of loops (0 = infinite)
    loopMode: \pingpong,     // \forward, \reverse, \pingpong, \random
    active: true,
    isClip: true,
    clipData: (
        notePairs: [
            (note: 65, startTime: 0.593, duration: 0.301, velocity: 79, channel: 0),
            (note: 67, startTime: 1.195, duration: 0.303, velocity: 89, channel: 0),
            // ... preserves exact recorded timing
        ],
        duration: 2.316,
        eventCount: 6,
        metadata: (recordedAt: timestamp, noteCount: 3, recordingDuration: 2.316)
    )
)
```

## Usage

### Loading
```supercollider
// Loads entire clip system + GUI automatically
"sketch/clip-system/clip-loader.scd".load;

// Or manually load just the GUI
"setup/clip-management.scd".load;
```

### Core Functions
```supercollider
// System Status & Control
~clipStatus.()                    // Show system status + VST integration
~setupVSTForClips.()              // Verify and setup VST system
~emergencyStop.()                 // EMERGENCY STOP (stops everything)
~testClipPlayback.(clipKey)       // Test clip playback

// Tempo Control
~setClipTempo.(scale)             // Set tempo scale (0.25x - 4.0x)
~halfSpeed.() / ~normalSpeed.() / ~doubleSpeed.()

// Sequence Management
~loadMelodiesForClips.()          // Safe melody loading (no auto-playback)
~refreshClipSequence.()           // Refresh sequence after loading clips
```

### File Management Functions
```supercollider
// Individual Clip Save/Load
~saveClip.(clipKey, filename)     // Save individual clip to file
~loadClip.(filename)              // Load individual clip from file
~saveClipToFileStandalone.(clip)  // Standalone save (works without clip system)

// Clip Library Management
~saveClipLibrary.(libraryName)    // Save collection of clips
~loadClipLibrary.(libraryName)    // Load collection of clips
~quickSaveActiveClips.()          // Quick save all active clips

// File Utilities
~listClipFiles.()                 // List available clip files
~listClipLibraries.()             // List available clip libraries
```

### MIDI Controls
- **CC 20**: Tempo scale (0.25x - 4.0x)
- **Note 26**: Cycle tempo presets (0.5x → 1.0x → 2.0x → 0.5x)

## File Storage & Management

### Directory Structure
```
data/
├── clips/              # Individual clip files (from clip system)
│   ├── clip_key_20241221_143022.json
│   └── clip_another_20241221_143105.json
├── clips/libraries/    # Clip library collections  
│   ├── session_20241221.json
│   └── active_clips_20241221_143200.json
├── clips/backups/      # Automatic backups (future)
└── *.json              # Auto-saved clips from GUI
    ├── clip_clip-210625_113932_20250621_113936.json
    └── clip_clip-210625_112946_20250621_113000.json
```

### File Formats
**Individual Clip File:**
```json
{
    "formatVersion": "1.0",
    "savedAt": "2024-12-21 14:30:22",
    "clipData": {
        "key": "clip-143022",
        "name": "My Recorded Clip",
        "isClip": true,
        "clipData": {
            "notePairs": [...],
            "duration": 2.316
        }
    },
    "metadata": {
        "originalKey": "clip-143022",
        "noteCount": 5,
        "originalDuration": 2.316
    }
}
```

**Clip Library File:**
```json
{
    "formatVersion": "1.0", 
    "libraryName": "session_20241221",
    "savedAt": "2024-12-21 14:35:00",
    "clipCount": 3,
    "clips": [...]
}
```

### Usage Examples
```supercollider
// Save current clip
~saveClip.("clip-143022");                    // Auto-generated filename
~saveClip.("clip-143022", "my_favorite");     // Custom filename

// Load clip back
~loadClip.("my_favorite");                    // Adds to ~melodyData
~loadClip.("my_favorite", false);             // Load but don't add to system

// Save/load libraries
~saveClipLibrary.("today_session");           // Save all clips
~saveClipLibrary.("selected", ["clip1", "clip2"]); // Save specific clips
~loadClipLibrary.("today_session");           // Load entire library

// Utilities
~listClipFiles.();                            // Show available clips
~quickSaveActiveClips.();                     // One-click backup
```

## Clip Management GUI

### Recording Interface
- **🔴 RECORD Button** - Start/stop MIDI recording with visual feedback
- **Real-time event capture** - Shows note count as you record
- **Automatic processing** - Converts recorded MIDI to clip format
- **Auto-save functionality** - Clips saved immediately after recording
- **30-second timeout** - Prevents runaway recordings

### Playback Controls
- **▶️ PLAY Button** - Preview selected clips instantly
- **🕐 QUANT Button** - Quantized/synchronized playback (beat-grid aligned)
- **⏹ STOP Button** - Stop all clip playback
- **🎬 START/STOP Button** - Continuous sequence playback of active clips
- **🔄 MANUAL/⏩ AUTO Button** - Toggle sequence advance mode
- **Multiple playback methods** - Direct, quantized, and sequence playback
- **VST integration** - Routes through existing VST system

### File Management
- **📁 LOAD Button** - Import clips from files
- **💾 SAVE Button** - Export selected clip to file
- **🔄 RELOAD Button** - Sync with main melody data
- **🗑 DELETE Button** - Remove clips with confirmation

### Clip Organization
- **Visual clip list** - Shows duration, note count, loop info, and active status
- **Enhanced details** - Name, active status, loop count, and loop mode
- **Loop count control** - Set finite loops (1-99) or infinite loops (0)
- **Loop mode selection** - Forward, Reverse, Ping-Pong, Random playback
- **Real-time updates** - Automatic UI refresh
- **Selection tracking** - Detailed view of selected clip
- **Status indicators** - 🎵 for active clips, 🔇 for inactive, ∞ for infinite loops

### Usage
```supercollider
// Open Clip Management GUI
~createClipManagerGUI.();

// Recording Functions
~startClipRecording.();          // Start MIDI recording
~stopClipRecording.();           // Stop and process recording

// Clip Management Functions
~playSelectedClip.();            // Play selected clip (immediate)
~playSelectedClipQuantized.(4);  // Play selected clip (quantized to 4 beats)
~stopAllClipPlayback.();         // Stop all playback
~saveSelectedClipToFile.();      // Save selected clip
~loadClipFromFile.();            // Load clip from file dialog

// Sequence Functions
~startClipSequence.();           // Start continuous sequence of active clips
~stopClipSequence.();            // Stop sequence playback
~toggleSequenceMode.();          // Toggle manual/auto advance mode
~nextClipInSequence.();          // Manually advance to next clip
~prevClipInSequence.();          // Manually go to previous clip

// Loop Control Functions
~updateClipLoopCount.(clipKey, newCount);  // Change loop count real-time
~updateClipLoopMode.(clipKey, newMode);    // Change loop mode real-time
~setInfiniteLoop.(clipKey);                // Set infinite looping
~setLoopCount.(clipKey, count);            // Set specific loop count
~setLoopMode.(clipKey, mode);              // Set loop mode (\forward, \reverse, \pingpong, \random)
```

## Integration Points

### Melody Management
- Clips stored in `~melodyData` with `isClip: true`
- Compatible with existing melody sequence navigation
- Automatic detection in `~loadActiveMelodies.()`
- Auto-creation of `~melodyData` if missing

### Sketch System
- Integrates with `~currentSequence` and `~currentLoopIndex`
- Uses existing ProcMod envelope system
- Routes through `/note/on` OSC messages to VST targets

### Timing Calculation
- `~calculateLoopWaitTime.()` handles both clips and traditional melodies
- Clip timing: `clipDuration / tempoScale`
- Traditional timing: existing `noteRest * noteCount` calculation

## Key Functions

### Playback Engine
```supercollider
~playClip.(clipData, tempoScale, targetVSTGroup)
// Schedules notes using recorded startTime/duration with tempo scaling
```

### ProcMod Creation
```supercollider
~createClipProc.(clipData, procModID)
// Creates ProcMod instance that plays clip with envelope control
```

### Validation
```supercollider
~isValidClip.(melody)           // Check if melody is valid clip
~isClipKey.(melodyKey)          // Check if key references clip
~getClipDuration.(clipData, tempoScale)  // Calculate scaled duration
```

## Technical Details

### Tempo Scaling
- **Formula**: `adjustedTime = recordedTime / tempoScale`
- **Range**: 0.25x (4x slower) to 4.0x (4x faster)
- **Preserves**: Relative timing relationships between notes

### Safety Features
- `~clipSystemLoading` flag prevents infinite loops during initialization
- Null checks for all clip system functions before calling
- Graceful fallback to traditional melody system
- VST system verification with diagnostic output
- Emergency stop functionality (`~emergencyStop.()`)
- Auto-save prevents clip loss
- Standalone save functions work without full clip system

### Performance
- Uses `SystemClock.sched()` for precise timing
- Compatible with existing VST routing and parameter mapping
- Maintains sketch system's dual-layer architecture

## Status Indicators
- **🎵 CLIP**: Timing-based playback
- **♪ MELODY**: Traditional fixed timing
- **Current sequence**: Shows active clips vs melodies

## Error Handling
- Invalid clip data → fallback to traditional melody
- Missing functions → error messages with graceful degradation
- Infinite loop protection during system loading
- VST setup verification with helpful error messages
- File save/load error handling with user feedback
- GUI closure protection with re-open functionality
- Syntax error fixes for reliable loading

## Workflow Examples

### Complete Recording Session
```supercollider
// 1. Load system (loads GUI automatically)
"sketch/clip-system/clip-loader.scd".load;

// 2. Verify VST setup
~setupVSTForClips.();

// 3. Record clips using GUI:
//    - Click RECORD button
//    - Play MIDI notes
//    - Click STOP button
//    - Clip auto-saved to data/ folder

// 4. Preview clips
//    - Select clip in list
//    - Click PLAY button

// 5. Save session
~quickSaveActiveClips.();
```

### Troubleshooting
```supercollider
// Check system status
~clipStatus.();

// Fix VST issues
~setupVSTForClips.();

// Emergency stop if needed
~emergencyStop.();

// Re-open GUI if closed
~createClipManagerGUI.();

// Refresh sequence after loading clips
~refreshClipSequence.();
```

## Enhanced Looping System

### Advanced Loop Modes
- **Forward**: Normal sequential playback of recorded notes
- **Reverse**: Notes play in reverse chronological order
- **Ping-Pong**: Forward then backward (seamless bidirectional)
- **Random**: Notes randomized each iteration for variation

### Infinite Looping
- **Set loop count to 0** for infinite loops
- **Visual indicator**: ∞ symbol in clip list
- **Real-time control**: Change loop count while playing
- **Smart sequence handling**: Infinite clips play once in sequences

### Quantized Playback
- **Beat-grid synchronization** using TempoClock
- **Configurable quantization** (4-beat, 8-beat, etc.)
- **Precise timing** for live performance
- **GUI integration** with dedicated QUANT button

### Sequence Playback
- **Continuous sequences** of active clips
- **Manual mode**: Stay on current clip indefinitely
- **Auto mode**: Advance automatically after completion
- **Navigation controls**: Next/previous clip selection
- **Real-time mode switching** during playback

### Real-time Loop Control
```supercollider
// Change settings while clips are playing
~setInfiniteLoop.("myClip");           // Switch to infinite
~setLoopCount.("myClip", 5);           // Set 5 loops
~setLoopMode.("myClip", \reverse);     // Switch to reverse mode
~updateClipLoopCount.("myClip", 0);    // Real-time update with restart
```

## Future Extensions
- Multiple clip layering and synchronization
- Clip editing (trim, quantize, velocity scaling)
- Note filtering by channel/range/velocity
- MIDI file import/export
- Visual waveform display
- Drag-and-drop clip arrangement
- Loop crossfading and seamless transitions
- Tempo-synced loop lengths 