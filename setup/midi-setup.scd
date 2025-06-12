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
    };
    
    // Show current MIDIFunc count after cleanup
    ("After cleanup: % total MIDIFuncs".format(MIDIFunc.allFuncProxies.size)).postln;
    
    // Check if VST Manager is available
    if (~vstManager.isNil) {
        "VST Manager not initialized yet. MIDI setup skipped.".postln;
        ^nil;  // Don't reschedule - just exit
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
    ~midiController.setDebug(true);                // Enable debug logging
    
    // Set up MIDIMix controller preset
    if (~midiController.setControllerPreset(\midiMix)) {
        "Successfully set MIDI controller to MIDIMix preset".postln;
        ~midiController.listControllerPresets;  // Show available presets
    } {
        "Failed to set MIDI controller to MIDIMix preset".warn;
    };
    
    // Initialize MIDI Control Mapping integration (optional)
    ~setupMIDIControlMappingIntegration = {
        "Setting up MIDI Control Mapping integration...".postln;
        
        // Check if MIDI Control Mapping system is available
        if(~controlTemplates.notNil && ~rowMappings.notNil) {
            "MIDI Control Mapping system detected, enabling integration...".postln;
            
            // Configure MIDIController for mapping awareness
            ~midiController.setMappingMode(true);
            ~midiController.setControlTemplates(~controlTemplates);
            ~midiController.setRowMappings(~rowMappings);
            
            // Set up parameter update callback
            if(~updateGroupParameterCallback.notNil) {
                ~midiController.setGroupParameterCallback(~updateGroupParameterCallback);
                "Group parameter callback configured".postln;
            } {
                "Warning: No group parameter callback available".warn;
            };
            
            "MIDI Control Mapping integration complete".postln;
        } {
            "MIDI Control Mapping system not detected, using standard mode".postln;
            ~midiController.setMappingMode(false);
        };
    };
    
    // Attempt integration setup (will be called again later if mapping system loads after this)
    ~setupMIDIControlMappingIntegration.();
    
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

    // Function to refresh mapping integration (called when mapping system loads)
    ~refreshMIDIControlMappingIntegration = {
        if(~midiController.notNil) {
            "Refreshing MIDI Control Mapping integration...".postln;
            ~setupMIDIControlMappingIntegration.();
        } {
            "Cannot refresh mapping integration: MIDIController not available".warn;
        };
    };

    // Create MIDI Control Mapping GUI now that MIDIController is ready
    if (~createMIDIControlMappingGUIWhenReady.notNil) {
        "Calling function to create MIDI Control Mapping GUI...".postln;
        ~createMIDIControlMappingGUIWhenReady.();
    } {
        "MIDI Control Mapping GUI creation function not available yet".postln;
    };

    nil; // return nil to prevent rescheduling
};

// Call MIDI setup once manually when VST Manager is ready
// (Remove automatic scheduling to prevent infinite loops)
"MIDI setup function defined. Call ~initMIDISetup.() when VST Manager is ready.".postln;