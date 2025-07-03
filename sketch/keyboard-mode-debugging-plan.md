# Keyboard Mode Debugging Plan

## Issue We Are Trying to Resolve

**Primary Problem**: When keyboard mode is enabled and a MIDI note is played, the note is NOT being routed through the keyboard mode handler. Instead, it's being processed through the normal MIDI handling path.

**Symptoms**:
1. We see "Note On: pitch 84 chan 0 vel 82" (normal MIDI processing)
2. We do NOT see "Keyboard Mode: Note ON - pitch: 84, velocity: 82" 
3. No bend envelopes are being created for notes
4. The per-note bend functionality is completely non-functional

**Expected Behavior**:
- When keyboard mode is ON, ALL MIDI notes should be handled by `~keyboardMode.handleNoteOn()`
- Each note should trigger an independent bend envelope
- Notes should sustain for the ProcMod duration
- We should see keyboard mode debug messages, NOT normal MIDI messages

## Current State Analysis

From the output:
```
Keyboard Mode: Enabled
Mode keyboardMode set to true
Bend envelope mode ENABLED (per-note)
NoteOn Received: pitch 84, incoming vel 82, effective vel 82, chan 0, src 127280530
Note On: pitch 84 chan 0 vel 82
```

This shows:
- Keyboard mode IS enabled in the system (`~modes.keyboardMode = true`)
- Bend envelope mode IS enabled
- BUT notes are going through normal MIDI processing

## Hypothesis

### Primary Hypothesis
The `~modes.keyboardMode` check at line 419 of MIDIController.sc is evaluating to `false` even though keyboard mode is enabled. This is likely due to:

1. **Scope Issue**: The MIDIFunc callback cannot access the global `~modes` variable
2. **Environment Context**: The callback runs in a different environment where `~modes` is nil or different
3. **Timing Issue**: The value is being cached or evaluated before keyboard mode is enabled

### Secondary Hypothesis
Even if the check passes, `~keyboardMode` might be nil or inaccessible from within the MIDIFunc callback context.

## Debugging Plan

### Phase 1: Comprehensive Logging
Add detailed debug statements to trace execution flow:

1. **In MIDIController.sc noteOn handler** (lines 415-425):
   ```supercollider
   "DEBUG 1: noteHandlingEnabled = %".format(noteHandlingEnabled).postln;
   "DEBUG 2: ~modes = %".format(~modes).postln;
   "DEBUG 3: ~modes.keyboardMode = %".format(~modes.keyboardMode).postln;
   "DEBUG 4: ~keyboardMode = %".format(~keyboardMode).postln;
   "DEBUG 5: currentEnvironment = %".format(currentEnvironment).postln;
   ```

2. **Inside keyboard mode check**:
   ```supercollider
   if(~modes.keyboardMode) {
       "DEBUG 6: ENTERED keyboard mode branch".postln;
       "DEBUG 7: About to call handleNoteOn".postln;
       ~keyboardMode.handleNoteOn(pitch, veloc);
       "DEBUG 8: handleNoteOn returned".postln;
       shouldProcessNote = false;
       "DEBUG 9: shouldProcessNote = %".format(shouldProcessNote).postln;
   } {
       "DEBUG 10: SKIPPED keyboard mode (false or nil)".postln;
   };
   ```

3. **In keyboard-mode-manager.scd handleNoteOn**:
   ```supercollider
   "DEBUG KBD 1: handleNoteOn called".postln;
   "DEBUG KBD 2: self = %".format(self).postln;
   "DEBUG KBD 3: enabled = %".format(self.enabled).postln;
   ```

### Phase 2: Test Different Access Methods
If Phase 1 shows `~modes` is nil or inaccessible:

1. Try `currentEnvironment[\modes]`
2. Try `topEnvironment[\modes]`
3. Try storing a reference in the MIDIController instance

### Phase 3: Implement Fix
Based on findings, implement the appropriate solution:
- Use correct environment access method
- Store references in MIDIController
- Restructure the keyboard mode check

## Expected Results

### If Working Correctly:
```
DEBUG 1: noteHandlingEnabled = true
DEBUG 2: ~modes = (keyboardMode: true, fermata: false, ...)
DEBUG 3: ~modes.keyboardMode = true
DEBUG 4: ~keyboardMode = (enabled: true, currentProcMod: ..., ...)
DEBUG 6: ENTERED keyboard mode branch
DEBUG 7: About to call handleNoteOn
DEBUG KBD 1: handleNoteOn called
Keyboard Mode: Note ON - pitch: 84, velocity: 82
Creating bend envelope for pitch 84 (range: +/- 2 semitones)
DEBUG 8: handleNoteOn returned
DEBUG 9: shouldProcessNote = false
[NO "Note On: pitch 84 chan 0 vel 82" message should appear]
```

### If Scope Issue (Most Likely):
```
DEBUG 1: noteHandlingEnabled = true
DEBUG 2: ~modes = nil
DEBUG 3: ~modes.keyboardMode = nil
DEBUG 10: SKIPPED keyboard mode (false or nil)
[Continues with normal MIDI processing]
```

### If ~keyboardMode is nil:
```
DEBUG 1: noteHandlingEnabled = true
DEBUG 2: ~modes = (keyboardMode: true, ...)
DEBUG 3: ~modes.keyboardMode = true
DEBUG 4: ~keyboardMode = nil
DEBUG 6: ENTERED keyboard mode branch
[ERROR: Message 'handleNoteOn' not understood by nil]
```

## Success Criteria

1. When a MIDI note is played with keyboard mode ON:
   - We see "Keyboard Mode: Note ON" message
   - We see "Creating bend envelope" message
   - We do NOT see normal "Note On:" messages
   - OSC bend messages are generated
   - Bend values are sent to VSTs

2. The debug output clearly shows:
   - `~modes.keyboardMode` is accessible and true
   - `~keyboardMode` is accessible and not nil
   - The keyboard mode branch is entered
   - `shouldProcessNote` prevents normal processing

## Next Steps

1. Get approval to implement Phase 1 debugging
2. Run tests and collect debug output
3. Analyze results to confirm hypothesis
4. Implement appropriate fix based on findings
5. Verify bend envelopes are working correctly
6. Remove debug statements once fixed