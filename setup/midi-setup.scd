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
        NetAddr.localAddr, nil, 16, 0, true
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

    // AUTOMATICALLY OPEN SINGLE DEVICE MIDI SELECTOR GUI
    AppClock.sched(2, {
        if(~midiController.notNil) {
            "Opening Single Device MIDI Selector GUI automatically...".postln;
            ~createSingleDeviceSelectorGUI.();
        } {
            "MIDI Controller not ready - Single Device GUI not opened".postln;
        };
        nil; // Don't reschedule
    });

    nil; // return nil to prevent rescheduling
};

// ========== SINGLE DEVICE MIDI SELECTOR GUI ==========
~createSingleDeviceSelectorGUI = {
    var win, devicePopup, modeButton, statusText, refreshButton;
    var updateDeviceList, updateUI;
    var devices = Array.new;
    
    if(~midiController.isNil) {
        "MIDI Controller not initialized. Please run ~initMIDISetup.() first.".warn;
        ^nil;
    };
    
    // Close existing window if any
    if(~singleDeviceWindow.notNil) { 
        if(~singleDeviceWindow.isClosed.not) {
            ~singleDeviceWindow.close;
        };
    };
    
    // Create window
    win = Window("Single Device MIDI Selector", Rect(100, 100, 400, 200));
    ~singleDeviceWindow = win;
    
    // Create UI elements
    statusText = StaticText()
        .string_("Mode: Listening to all devices")
        .font_(Font("Arial", 12))
        .align_(\center);
        
    devicePopup = PopUpMenu()
        .items_(["All Devices"])
        .action_({ |menu|
            if(menu.value == 0) {
                ~midiController.clearMIDIDeviceSelection;
            } {
                var deviceID = devices[menu.value - 1].uid;
                ~midiController.setMIDIDevice(deviceID);
            };
            updateUI.();
        });
        
    modeButton = Button()
        .states_([
            ["Enable Selective Mode", Color.black, Color.gray(0.9)],
            ["Disable Selective Mode", Color.white, Color.red(0.7)]
        ])
        .action_({ |btn|
            if(btn.value == 1) {
                // Enable selective mode
                if(~midiController.selectedDeviceID.notNil) {
                    ~midiController.setSelectiveMode(true);
                } {
                    "Please select a device first".warn;
                    { btn.value = false }.defer;
                };
            } {
                // Disable selective mode
                ~midiController.setSelectiveMode(false);
            };
            updateUI.();
        });
        
    refreshButton = Button()
        .states_([["Refresh", Color.black, Color.gray(0.9)]])
        .action_({
            updateDeviceList.();
            updateUI.();
        });
    
    // Function to update device list
    updateDeviceList = {
        {
            var sources = MIDIClient.sources;
            var items = ["All Devices"];
            
            devices = sources;
            sources.do { |src|
                items = items.add(src.name);
            };
            
            devicePopup.items = items;
        }.defer;
    };
    
    // Function to update UI state
    updateUI = {
        {
            var modeStr;
            
            // Update mode button state
            modeButton.value = if(~midiController.selectiveMode, 1, 0);
            
            // Update status text
            if(~midiController.selectiveMode) {
                if(~midiController.selectedDeviceID.notNil) {
                    modeStr = "Mode: SELECTIVE - Listening to %".format(~midiController.selectedDevice.name);
                } {
                    modeStr = "Mode: SELECTIVE - No device selected!";
                };
            } {
                modeStr = "Mode: Listening to ALL devices";
            };
            statusText.string = modeStr;
            
            // Update popup selection
            if(~midiController.selectedDeviceID.notNil) {
                var index = devices.detectIndex { |dev| dev.uid == ~midiController.selectedDeviceID };
                if(index.notNil) {
                    devicePopup.value = index + 1; // +1 because "All Devices" is at index 0
                };
            } {
                devicePopup.value = 0; // "All Devices"
            };
        }.defer;
    };
    
    // Set layout
    win.layout = VLayout(
        // Title
        StaticText().string_("Single Device MIDI Selector")
            .font_(Font("Arial", 16, true))
            .align_(\center)
            .maxHeight_(30),
        
        // Current status
        statusText.maxHeight_(30),
        
        // Device selection
        StaticText().string_("Select MIDI device:").maxHeight_(20),
        devicePopup,
        
        // Buttons
        HLayout(
            modeButton,
            refreshButton
        )
    );
    
    // Initialize
    updateDeviceList.();
    updateUI.();
    
    // Set window actions
    win.onClose = {
        ~singleDeviceWindow = nil;
    };
    
    win.front;
    
    // Return window for reference
    win;
};

// Convenience function
~singleDeviceGUI = { ~createSingleDeviceSelectorGUI.() };

// Call MIDI setup once manually when VST Manager is ready
// (Remove automatic scheduling to prevent infinite loops)
"MIDI setup function defined. Call ~initMIDISetup.() when VST Manager is ready.".postln;