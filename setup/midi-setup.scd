// MIDI setup with dynamic VST mapping
~initMIDISetup = {
    var mappingsFile, dir, saveMappingsOnClose, updateMIDIController;
    
    // DEBUG: Track function calls
    ~initMIDISetupCallCount = (~initMIDISetupCallCount ? 0) + 1;
    ("~initMIDISetup called #% times".format(~initMIDISetupCallCount)).postln;
    
    // Show current MIDIFunc count before cleanup
    ("Before cleanup: % total MIDIFuncs".format(MIDIFunc.allFuncProxies.size)).postln;
    
    // CLEANUP: Free existing MIDIController if it exists
    if(~midiController.notNil) {
        "Freeing existing MIDIController to prevent duplicates...".postln;
        ~midiController.free;
        ~midiController = nil;
        // Wait a moment for cleanup to complete
        0.1.wait;
    };
    
    // Show current MIDIFunc count after cleanup
    ("After cleanup: % total MIDIFuncs".format(MIDIFunc.allFuncProxies.size)).postln;
    
    // Check if VST Manager is available
    if (~vstManager.isNil) {
        "VST Manager not initialized yet. Will retry in 1 second...".postln;
        1.wait;
        if (~vstManager.isNil) {
            "VST Manager still not available. MIDI setup failed.".error;
            ^nil;
        };
    };
    
    "Initializing MIDI controller with VST instances...".postln;
    
    // Initialize MIDI controller for note handling
    // Defaulting to all VST instances
    ~midiController = MIDIController(
        ~vstManager.getInstances(), // Get all VST instances by default
        n, nil, 16, 0, true
    );
    
    // Configure MIDI controller
    ~midiController.setMultiChannelMode(false);    // Toggle multi-channel mode (off by default)
    ~midiController.setMultiInstrumentMode(false); // Toggle multi-instrument mode (off by default)
    // ~midiController.setVelocityCtrlMode(true);     // Enable velocity control via knob 7 // Removed
    ~midiController.setDebug(true);                // Enable debug logging
    
    // Set up MIDIMix controller preset
    if (~midiController.setControllerPreset(\midiMix)) {
        "Successfully set MIDI controller to MIDIMix preset".postln;
        ~midiController.listControllerPresets;  // Show available presets
    } {
        "Failed to set MIDI controller to MIDIMix preset".warn;
    };
    
   
    
    // Also save on Cmd+Q
    if (Platform.ideName == "scide") {
        // Use a more compatible way to handle quit
        thisProcess.addDependant({ |who, what|
            if (what == \serverQuit) {
                ~saveMappingsOnClose.();
            };
        });
    };

    // Function to update MIDI controller with current VST instances based on VSTManager's active group
    ~updateMIDIController = {
        var activeGroup, targetVSTs;
        if (~vstManager.isNil or: {~midiController.isNil}) {
            "VSTManager or MIDIController not ready for update.".warn;
            ^nil; // Exit if essential components are not ready
        };

        activeGroup = ~vstManager.getActiveGroupName(); // Get current active group from VSTManager
        targetVSTs = ~vstManager.getTargetInstances(activeGroup); // Get the VSTs for that group

        ("~updateMIDIController: VSTManager active group: '%', Target VSTs count: %".format(activeGroup, targetVSTs.size)).postln;

        ~midiController.updateVSTList(targetVSTs); // Tell MIDIController to use these VSTs
    };

    nil; // return nil to prevent rescheduling
};

// Schedule the MIDI setup to run
AppClock.sched(0, ~initMIDISetup);