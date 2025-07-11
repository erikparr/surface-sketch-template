ORDER OF OPERATIONS:

1. SUPERCOLLIDER BOOTS AUTOMATICALLY AND BOOTS AUTOMATICALLY. IT IS ALWAYS BOOTED ON START.
2. WE AUTOMATICALLY LOAD THE SETUP FILES @_setup-loader.scd
3. THEN @sketch/load-sketch.scd LOADS AUTOMATICALLY. 

REMEMBER @sketch/ SYSTEM WORKS AND REFER TO IT IF YOU HAVE QUESTIONS.

FOR CONTEXT ABOUT THE SYSTEM SEE @reference/ especially @reference/procmod-reference/ProcMod.sc and @reference/vst-reference/VSTManager.sc and @reference/midi-reference/MIDIController.sc

NEW: DEPENDENT LAYER SYSTEM
To use the 3-layer synchronized playback system:
1. After normal startup, load: (thisProcess.nowExecutingPath.dirname +/+ "layers/load-layers.scd").load;
2. Open GUI: ~createLayersGUI.()
3. Or use API: ~setLayerMelody.(\layer1, \melody1); ~startLayers.();
See @layers/test-layers.scd for examples.

IF YOU GET STUCK, ASK ME.
