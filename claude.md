ORDER OF OPERATIONS:

1. SUPERCOLLIDER BOOTS AUTOMATICALLY using @etc/startup/startup.scd which configures audio hardware and MIDI
2. STARTUP FILE AUTOMATICALLY LOADS THE SETUP FILES via @setup/_setup-loader.scd
3. STARTUP FILE AUTOMATICALLY LOADS THE LAYERS SYSTEM via @layers/load-layers.scd

FOR CONTEXT ABOUT THE SYSTEM SEE:
- @reference/procmod-reference/ProcMod.sc (legacy reference - project now uses OSC-based architecture)
- @etc/VSTManager/VSTManager.sc (current VST management system)
- @etc/MIDIController/MIDIController.sc (current MIDI control system)

OSC-BASED LAYERS SYSTEM:
The project uses a pure OSC-based 3-layer synchronized playback system:
1. System loads automatically on startup via @layers/load-layers.scd
2. Open GUI: ~createLayersGUI.()
3. Or use OSC API: Send messages to port 7000 (/layer1/note, /system/start, etc.)
4. Or use SC API: ~setLayerMelody.(\layer1, \melody1); ~startLayers.();

IF YOU GET STUCK, ASK ME.
