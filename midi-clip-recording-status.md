# MIDI Clip Recording System - Current Status & Implementation Plan

## 🎯 Original Vision

**Goal**: Replace the existing melody system's fixed timing parameters with **recorded timing data** that can be scaled in real-time via MIDI control.

### What We Wanted to Eliminate:
- Fixed `noteDuration`, `noteRestTime`, `melodyRestTime` parameters
- Sequential note-by-note playback with uniform timing
- Loss of expressive timing from live performance

### What We Wanted to Achieve:
- **Timing-Accurate Playback**: Use recorded note durations and intervals
- **Scalable Performance**: Speed up/slow down clips via MIDI control while preserving relative timing
- **Expressive Capture**: Preserve velocity, overlaps, and natural timing variations
- **Integration**: Work seamlessly with existing ProcMod and VST system

---

## ✅ Phase 1: What's Actually Working

### MIDI Input & Recording Infrastructure
- ✅ **Direct MIDI Input**: Uses `MIDIdef` for precise note on/off capture
- ✅ **Timing Precision**: Records events with sub-millisecond timing accuracy
- ✅ **State Machine**: Proper `\idle` → `\recording` → `\processing` → `\idle` flow
- ✅ **Event Capture**: Records note number, channel, velocity, and precise timestamps
- ✅ **Note Pairing**: Correctly matches note on/off events to calculate durations
- ✅ **Polyphonic Recording**: Handles multiple simultaneous notes correctly
- ✅ **Auto-timeout**: 10-second maximum recording duration
- ✅ **UI Integration**: Record/stop button with real-time status updates

### Data Structure (Correctly Captured)
```supercollider
// What we're actually capturing (correctly):
recordedEvents = [
    (type: \noteOn,  note: 74, channel: 0, velocity: 57, time: 0.487),
    (type: \noteOff, note: 74, channel: 0, velocity: 62, time: 0.812),
    (type: \noteOn,  note: 79, channel: 0, velocity: 51, time: 1.125),
    // ... etc
];

// What we're calculating (correctly):
notePairs = [
    (note: 74, startTime: 0.487, duration: 0.325, velocity: 57, channel: 0),
    (note: 79, startTime: 1.125, duration: 0.343, velocity: 51, channel: 0),
    // ... etc
];
```

---

## ❌ Phase 1: What's Broken (The Critical Flaw)

### **PROBLEM: Converting Back to Old Format**
After correctly capturing all timing data, I'm **throwing it away** and converting back to the old melody system:

```supercollider
// WRONG: What I'm currently doing
clipMelody = (
    key: clipName,
    pattern: [74, 79, 77],  // ← LOST ALL TIMING!
    velocityFirst: 1.0,     // ← LOST RECORDED VELOCITIES!
    velocityLast: 1.0,
    // ... uses old melody playback system
);
```

This means recorded clips play back with the **same old fixed timing** - completely defeating the purpose!

### **Missing Components**
- ❌ **Clip-Based Playback Function**: No system to play clips using recorded timing
- ❌ **Tempo Scaling**: No way to speed up/slow down clip playback
- ❌ **ProcMod Integration**: Not integrated with the sketch system's ProcMod sequencing
- ❌ **MIDI Control**: No MIDI mapping to control clip tempo in real-time

---

## 🎯 Phase 2: Implementation Plan

### **Step 1: Create Clip Playback Function**
Replace the melody conversion with proper timing-based playback:

```supercollider
~playClip = { |clipData, tempoScale=1.0, targetVST|
    var notePairs = clipData[\notePairs];
    var baseTime = Main.elapsedTime;
    
    notePairs.do { |note|
        var adjustedStartTime = note[\startTime] / tempoScale;
        var adjustedDuration = note[\duration] / tempoScale;
        
        // Schedule note on
        AppClock.sched(adjustedStartTime, {
            targetVST.midi.noteOn(0, note[\note], note[\velocity]);
            nil;
        });
        
        // Schedule note off
        AppClock.sched(adjustedStartTime + adjustedDuration, {
            targetVST.midi.noteOff(0, note[\note], 0);
            nil;
        });
    };
};
```

### **Step 2: Create Clip ProcMod Integration**
Integrate clip playback with the existing ProcMod system:

```supercollider
~createClipProc = { |clipData, procModID|
    var env = Env([0, 1, 1, 0], [0.1, 1.0, 0.1]);
    ProcMod.new(env, 1.0, procModID, nil, 0, 1, { |group, envbus|
        ~playClip.(clipData, ~currentTempoScale ? 1.0, ~vstManager.currentVST);
    });
};
```

### **Step 3: Add Tempo Control via MIDI**
Map MIDI controls to adjust clip playback speed:

```supercollider
// Add to existing MIDI control mapping
~clipTempoControl = MIDIdef.cc(\clipTempo, { |val, cc, chan, src|
    ~currentTempoScale = val.linexp(0, 127, 0.25, 4.0); // 4x slower to 4x faster
    "Clip tempo scale: %".format(~currentTempoScale.round(0.01)).postln;
}, 15); // Example: CC 15 for tempo control
```

### **Step 4: Update Melody Management Integration**
Store clips with full timing data and create proper playback methods:

```supercollider
// CORRECT: Store clip with timing data
clipMelody = (
    key: clipName,
    name: clipName ++ " (recorded clip)",
    isClip: true,
    clipData: (
        notePairs: notePairs,
        duration: totalDuration,
        metadata: (
            recordedAt: Date.getDate.stamp,
            eventCount: ~recordedEvents.size,
            noteCount: notePairs.size
        )
    ),
    // For legacy compatibility, provide simple pattern
    pattern: notePairs.collect({ |pair| pair[\note] }),
    active: true
);
```

### **Step 5: Update Sketch System Integration**
Modify the sketch system to detect clips and use clip playback instead of melody playback:

```supercollider
// In sketch system melody loading
~loadClipBasedMelodies = {
    ~melodyData[\melodies].do { |melody|
        if (melody[\isClip] == true) {
            // Create clip-based ProcMod
            ~melodyProcs[melody[\key]] = ~createClipProc.(melody[\clipData], melody[\key]);
        } {
            // Use existing melody ProcMod for non-clips
            ~melodyProcs[melody[\key]] = ~createMelodyProc.(melody[\key]);
        };
    };
};
```

---

## 🎮 User Experience Goal

### **Before (Current State)**
1. Record clip → Converts to `[74, 79, 77]`
2. Playback → Uses fixed timing parameters, sounds robotic
3. MIDI control → Only affects volume/expression, not timing

### **After (Target State)**
1. Record clip → Preserves all timing: `[(74@0.487s, 0.325s dur), (79@1.125s, 0.343s dur)]`
2. Playback → Uses recorded timing, sounds natural and expressive
3. MIDI control → Can speed up/slow down entire clip while preserving relative timing

---

## 📋 Implementation Priority

### **Immediate (Phase 2A)**
1. ✅ Fix clip data storage (stop converting to old format)
2. ✅ Create `~playClip` function with tempo scaling
3. ✅ Test basic timing-accurate playback

### **Core Integration (Phase 2B)**
4. ✅ Create clip-specific ProcMod integration
5. ✅ Update melody management to store full clip data
6. ✅ Modify sketch system to detect and handle clips

### **Performance Features (Phase 2C)**
7. ✅ Add MIDI tempo control mapping
8. ✅ Add clip loop/repeat functionality
9. ✅ Add real-time tempo adjustment UI

### **Polish (Phase 3)**
10. ✅ Add clip visualization in GUI
11. ✅ Add clip editing capabilities (trim, adjust timing)
12. ✅ Add multiple clip layering/triggering

---

## 🔥 Critical Next Step

**STOP converting clips to old melody format!** 

The entire timing capture system is working perfectly, but I'm throwing away all the timing data in the final step. The next action should be implementing the timing-based playback system that actually uses the captured note durations and start times.

**Bottom Line**: Phase 1 captured the data correctly, but Phase 2 needs to USE that data for playback instead of discarding it. 