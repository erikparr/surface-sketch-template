# Keyboard Mode Implementation Plan

## Overview
Keyboard mode transforms the system from sequence-based playback to real-time keyboard-triggered note and envelope events. When active, MIDI keyboard input triggers ProcMod instances with independent bend envelopes per note and sustained notes for the ProcMod duration.

## Core Behavior Specification

### 1. ProcMod Triggering
- **First note** played triggers a new ProcMod instance (10 second duration)
- Subsequent notes within the active ProcMod share the same instance
- Notes played after ProcMod expires trigger a new instance

### 2. Note Behavior
- Each note triggers its own independent bend envelope
- Notes sustain for the remaining ProcMod duration (ignore note-off)
- Multiple notes can play simultaneously with independent bends

### 3. CC Envelope Behavior
- Triggers once per ProcMod instance (existing behavior maintained)
- Shared across all notes in the ProcMod

## Technical Architecture

### A. New Components

#### 1. `keyboard-mode-manager.scd`
```supercollider
~keyboardMode = (
    enabled: false,
    currentProcMod: nil,
    procModStartTime: nil,
    procModDuration: 10,
    activeNotes: Dictionary.new,  // noteNum -> (synthID, bendEnvSynth)
    
    // Methods
    enable: { },
    disable: { },
    handleNoteOn: { |noteNum, velocity| },
    handleNoteOff: { |noteNum| },
    checkProcModExpired: { },
    triggerNewProcMod: { },
    cleanupExpiredProcMod: { }
);
```

#### 2. `keyboard-note-handler.scd`
```supercollider
~keyboardNoteHandler = (
    // Track individual note states
    noteStates: Dictionary.new,
    
    // Methods
    startNote: { |noteNum, velocity, remainingDuration| },
    createNoteBendEnvelope: { |noteNum, synthID| },
    scheduleNoteRelease: { |noteNum, duration| },
    releaseAllNotes: { }
);
```

### B. Modifications to Existing Components

#### 1. `load-sketch.scd`
- Add keyboard mode to ~modes dictionary:
```supercollider
~modes = (
    // ... existing modes ...
    keyboardMode: false  // New mode
);
```

#### 2. `musical-implementation.scd`
- Modify note playback logic to check keyboard mode:
```supercollider
~playNote = { |noteNum, velocity|
    if(~modes.keyboardMode) {
        ~keyboardMode.handleNoteOn(noteNum, velocity);
    } {
        // Existing sequence playback logic
    };
};
```

#### 3. `control-systems.scd`
- Add keyboard mode toggle function:
```supercollider
~toggleKeyboardMode = {
    ~modes.keyboardMode = ~modes.keyboardMode.not;
    if(~modes.keyboardMode) {
        ~keyboardMode.enable();
        ~stopContinuousLoopSequence.value;  // Stop sequence playback
    } {
        ~keyboardMode.disable();
    };
};
```

#### 4. `MIDIController.sc` modifications
- Add keyboard mode awareness to noteOn/noteOff handlers:
```supercollider
// In noteOn handler (around line 411)
if(noteHandlingEnabled) {
    // Add keyboard mode check
    if(~modes.notNil && ~modes.keyboardMode) {
        ~keyboardMode.handleNoteOn(pitch, effectiveVelocity);
        ^this;  // Early return, bypass normal handling
    }
    // ... existing note handling ...
}

// In noteOff handler (around line 514)
if(noteHandlingEnabled) {
    if(~modes.notNil && ~modes.keyboardMode) {
        ~keyboardMode.handleNoteOff(pitch);
        ^this;  // Early return, bypass normal handling
    }
    // ... existing note off handling ...
}
```

### C. Integration with ProcMod System

#### 1. ProcMod Integration Pattern
```supercollider
~createKeyboardProcMod = {
    var procMod = ProcMod(
        env: Env([0, 1, 1, 0], [0.01, 9.98, 0.01]),  // 10 second envelope
        amp: 1,
        id: "keyboard_" ++ Date.getDate.stamp,
        group: ~activeVSTGroup,
        function: { |group, envbus, server|
            // Set up CC envelope synth
            ~startCCEnvelope.(group, envbus);
        },
        onReleaseFunc: {
            ~keyboardMode.cleanupExpiredProcMod();
        }
    );
    procMod;
};
```

#### 2. Bend Envelope Per Note
```supercollider
~createNoteBendEnvelope = { |noteNum, outputChannel|
    var bendSynth = Synth(\noteBendEnvelope, [
        \startNote: noteNum,
        \bendRange: ~ccControl.expressionMax,  // Use CC control values
        \duration: ~keyboardMode.procModDuration,
        \channel: outputChannel
    ]);
    bendSynth;
};
```

### D. SynthDef Requirements

```supercollider
// Individual note bend envelope
SynthDef(\noteBendEnvelope, { |startNote = 60, bendRange = 12, duration = 10, channel = 0|
    var env = EnvGen.kr(
        Env([0, bendRange, 0], [duration * 0.5, duration * 0.5], \sin),
        doneAction: 2
    );
    var bendValue = (env * 682).asInteger + 8192;  // Convert to MIDI bend range
    // Send to specific VST based on channel routing
    SendReply.kr(Impulse.kr(30), '/noteBend', [channel, bendValue, startNote]);
}).add;

// Sustained note synth (no envelope, just gate)
SynthDef(\sustainedNote, { |freq = 440, amp = 0.5, gate = 1, out = 0|
    var sig = SinOsc.ar(freq) * amp;
    var env = EnvGen.kr(Env.asr(0.01, 1, 0.01), gate, doneAction: 2);
    Out.ar(out, sig * env);
}).add;
```

### E. State Management

```supercollider
~keyboardModeState = (
    // Timing
    procModStartTime: nil,
    procModEndTime: nil,
    
    // Active notes tracking
    activeNotes: Dictionary.new,  // pitch -> (synth, bendEnv, startTime)
    
    // VST routing
    vstChannelMap: Dictionary.new,  // pitch -> vstChannel
    
    // Cleanup scheduled
    cleanupTask: nil
);
```

## Implementation Steps

### Phase 1: Core Infrastructure
1. Create `keyboard-mode-manager.scd`
2. Add keyboard mode to global modes
3. Create basic enable/disable functions
4. Add GUI toggle button

### Phase 2: MIDI Integration
1. Modify MIDIController noteOn/noteOff handlers
2. Implement keyboard mode routing
3. Test basic note triggering

### Phase 3: ProcMod Integration
1. Implement ProcMod creation on first note
2. Add timing logic for ProcMod duration
3. Implement cleanup after expiration

### Phase 4: Bend Envelopes
1. Create per-note bend envelope SynthDef
2. Implement bend envelope triggering
3. Add OSC responder for bend messages
4. Route bend to appropriate VSTs

### Phase 5: Note Sustain
1. Implement sustained note behavior
2. Schedule automatic note releases
3. Handle multiple simultaneous notes

### Phase 6: CC Integration
1. Ensure CC envelopes trigger with ProcMod
2. Maintain existing CC behavior
3. Test with expression control

### Phase 7: Polish & Testing
1. Add visual feedback in GUI
2. Implement smooth mode transitions
3. Add error handling
4. Performance optimization

## Key Considerations

### 1. Resource Management
- Track and free all synths properly
- Limit maximum simultaneous notes
- Clean up bend envelopes after use

### 2. Timing Precision
- Use server-side scheduling for accuracy
- Account for network latency
- Synchronize bend with note events

### 3. Mode Transitions
- Cleanly stop sequence playback
- Release all active notes on disable
- Preserve VST group settings

### 4. Error Handling
- Handle rapid note triggering
- Manage VST communication failures
- Graceful degradation if resources exhausted

## Testing Strategy

### 1. Unit Tests
- ProcMod triggering logic
- Note duration calculations
- Bend envelope generation

### 2. Integration Tests
- MIDI input handling
- VST communication
- Mode switching

### 3. Performance Tests
- Maximum polyphony
- CPU usage monitoring
- Memory leak detection

### 4. User Acceptance Tests
- Musical responsiveness
- Bend envelope musicality
- Mode switching smoothness

## Success Criteria
1. First note triggers 10-second ProcMod
2. Each note has independent bend envelope
3. Notes sustain for ProcMod duration
4. CC envelope triggers once per ProcMod
5. Smooth transition between modes
6. No resource leaks or crashes
7. Musical and responsive performance