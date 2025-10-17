/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                      OSC LAYERS - GUI INTERFACE                               ║
║                   GUI controls via OSC messages                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         OSC GUI CREATION                                   │
// └─────────────────────────────────────────────────────────────────────────────┘

~createLayersGUI = {
    var win, layout;
    var transportSection, layerSections, statusSection;
    var startButton, stopButton, statusText;
    var bendModeCheckbox, simpleRampCheckbox;
    var updateStatus, vstGroupMenus = [];
    var refreshButton, melodyMenus = [];
    var globalMelodyStatus, globalLoadButton;
    var currentMelodyDisplay, navigationSection;
    var prevButton, nextButton;
    var bpmDisplay, restTimeDisplay;
    var chordCheckbox, arpeggioCheckbox, arpeggioDisplay;

    // Check if window already exists
    if (~layersGUIWindow.notNil) {
        try {
            if (~layersGUIWindow.isClosed.not) {
                ~layersGUIWindow.front;
                ^~layersGUIWindow;
            } {
                ~layersGUIWindow = nil;
            };
        } {
            ~layersGUIWindow = nil;
        };
    };

    // Create window
    win = Window("OSC Layers Control", Rect(100, 100, 400, 850));

    // Main layout
    layout = VLayout();

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         TRANSPORT SECTION                                  │
    // └─────────────────────────────────────────────────────────────────────────────┘

    layout.add(StaticText()
        .string_("OSC TRANSPORT")
        .font_(Font.default.size_(14).bold_(true))
        .align_(\center)
    );

    transportSection = HLayout();

    startButton = Button()
        .states_([
            ["Start All Layers", Color.black, Color.green.alpha_(0.3)]
        ])
        .action_({
            "GUI → OSC: Starting layers".postln;
            // Send OSC message instead of calling function directly
            NetAddr.localAddr.sendMsg('/system/start');
        });

    stopButton = Button()
        .states_([
            ["Stop All Layers", Color.black, Color.red.alpha_(0.3)]
        ])
        .action_({
            "GUI → OSC: Stopping layers".postln;
            // Send OSC message instead of calling function directly
            NetAddr.localAddr.sendMsg('/system/stop');
        });

    transportSection.add(startButton);
    transportSection.add(stopButton);
    layout.add(transportSection);

    // OSC Status indicator
    layout.add(StaticText()
        .string_("Control via OSC messages")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.blue)
    );

    // Looping mode checkbox
    layout.add(
        CheckBox()
            .string_("Loop Mode")
            .value_(~oscLayers.state.loopingMode)
            .action_({ |cb|
                "GUI → OSC: Looping mode %".format(cb.value).postln;
                NetAddr.localAddr.sendMsg('/system/looping', cb.value);
                statusText.string = if (cb.value) {
                    "Loop mode: ON (OSC)"
                } {
                    "Loop mode: OFF (OSC)"
                };
            })
    );

    // Manual control mode checkbox
    layout.add(
        CheckBox()
            .string_("Manual Control (MIDI Knobs: BPM + Velocity)")
            .value_(~oscLayers.state.manualControl)
            .action_({ |cb|
                "GUI → OSC: Manual control %".format(cb.value).postln;
                NetAddr.localAddr.sendMsg('/system/manual_control', cb.value);
                updateStatus.();
            })
    );

    // BPM display
    bpmDisplay = StaticText()
        .string_("BPM: 120 (Row 1 Knob 8)")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.gray);

    layout.add(bpmDisplay);

    // Melody rest time display
    restTimeDisplay = StaticText()
        .string_("Melody Rest: 0.00s (Slider 2)")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.gray);

    layout.add(restTimeDisplay);

    // Live melody OSC status (always active)
    layout.add(StaticText()
        .string_("Live Melody OSC: Active on /liveMelody/update/layer[1-3]")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.green)
    );

    // Single note CC mode checkbox
    layout.add(
        CheckBox()
            .string_("Single Note CC Mode")
            .value_(~oscLayers.state.singleNoteCCMode)
            .action_({ |cb|
                "GUI → OSC: Single note CC mode %".format(cb.value).postln;
                NetAddr.localAddr.sendMsg('/system/single_note_cc', cb.value);
                updateStatus.();
            })
    );

    // Chord mode checkbox
    chordCheckbox = CheckBox()
        .string_("Chord Mode (Max 3 notes, Multi-Instrument)")
        .value_(~oscLayers.state.chordMode)
        .action_({ |cb|
            "GUI → OSC: Chord mode %".format(cb.value).postln;
            NetAddr.localAddr.sendMsg('/system/chord_mode', cb.value);
            // Enable/disable arpeggio checkbox based on chord mode
            if (arpeggioCheckbox.notNil) {
                arpeggioCheckbox.enabled_(cb.value);
            };
            updateStatus.();
            // Update BPM display to show new range
            if (bpmDisplay.notNil) {
                if (cb.value) {
                    bpmDisplay.string_("BPM: 6-100 (Chord Mode, Row 1 Knob 8)");
                } {
                    if (~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil }) {
                        var bpm = ~getBPMFromKnob.();
                        bpmDisplay.string_("BPM: % (60-400 range, Row 1 Knob 8)".format(bpm.round(1)));
                    };
                };
            };
        });

    layout.add(chordCheckbox);

    // Arpeggio mode checkbox (requires chord mode)
    arpeggioCheckbox = CheckBox()
        .string_("Arpeggio Mode (Random Chord Delays)")
        .value_(~oscLayers.state.arpeggioMode)
        .enabled_(~oscLayers.state.chordMode)
        .action_({ |cb|
            "GUI → OSC: Arpeggio mode %".format(cb.value).postln;
            NetAddr.localAddr.sendMsg('/system/arpeggio_mode', cb.value);
            updateStatus.();
        });

    layout.add(arpeggioCheckbox);

    // Arpeggio delay display
    arpeggioDisplay = StaticText()
        .string_("Delays: 0-20% of duration (Sliders 3-4)")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.gray);

    layout.add(arpeggioDisplay);

    // Bend mode checkbox
    bendModeCheckbox = CheckBox()
        .string_("Bend Mode")
        .value_(~oscLayers.state.bendMode)
        .action_({ |cb|
            "GUI → OSC: Bend mode %".format(cb.value).postln;
            NetAddr.localAddr.sendMsg('/system/bend_mode', cb.value);
            simpleRampCheckbox.enabled_(cb.value);
            updateStatus.();
        });

    layout.add(bendModeCheckbox);

    // Simple ramp checkbox (for bend mode)
    simpleRampCheckbox = CheckBox()
        .string_("Simple Ramp (Bend)")
        .value_(~getLayerBendSimpleRamp.() ? false)  // Get current state from system
        .enabled_(~oscLayers.state.bendMode)
        .action_({ |cb|
            "GUI → System: Simple ramp mode %".format(cb.value).postln;
            // FIXED: Connect GUI to system state
            if (~setLayersBendSimpleRamp.notNil) {
                ~setLayersBendSimpleRamp.(cb.value);
            };
            updateStatus.();
        });

    layout.add(simpleRampCheckbox);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                    GLOBAL MELODY MANAGEMENT                                │
    // └─────────────────────────────────────────────────────────────────────────────┘

    layout.add(StaticText()
        .string_("GLOBAL MELODY MANAGEMENT")
        .font_(Font.default.size_(14).bold_(true))
        .align_(\center)
    );

    // Global melody file status
    globalMelodyStatus = StaticText()
        .string_("No melody file loaded")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.gray);

    layout.add(globalMelodyStatus);

    // Global melody file loading button
    globalLoadButton = Button()
        .states_([["Load Melody File (All Layers)", Color.black, Color.yellow.alpha_(0.5)]])
        .action_({
            FileDialog({ |path|
                if (path.notNil) {
                    "Loading global melody file: %".format(path).postln;

                    // Use enhanced global loading function
                    ~loadGlobalMelodyFile.(path, { |success, melodyCount, filename|
                        AppClock.sched(0, {
                            if (success) {
                                globalMelodyStatus.string_(
                                    "% (% melodies)".format(filename, melodyCount)
                                ).stringColor_(Color.green);

                                // Update all layer melody menus
                                melodyMenus.do { |melodyMenu|
                                    if (melodyMenu.notNil) {
                                        var items = ["None"] ++ if (~melodyDict.notNil) {
                                            ~melodyDict.keys.asArray.sort.collect(_.asString)
                                        } { [] };
                                        melodyMenu.items = items;
                                    };
                                };

                                // Update current melody display
                                if (~oscLayers.notNil and: { ~oscLayers.state.melodyList.size > 0 }) {
                                    var currentMelody = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
                                    currentMelodyDisplay.string_("% (% of %)".format(
                                        currentMelody,
                                        ~oscLayers.state.currentMelodyIndex + 1,
                                        ~oscLayers.state.melodyList.size
                                    ));
                                };

                                "Global melody file loaded successfully".postln;
                            } {
                                globalMelodyStatus.string_(
                                    "Failed to load melody file"
                                ).stringColor_(Color.red);
                                "Failed to load global melody file".warn;
                            };
                        });
                    });
                };
            }, fileMode: 1, acceptMode: 0, stripResult: true);
        });

    layout.add(globalLoadButton);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                    GLOBAL MELODY NAVIGATION                                │
    // └─────────────────────────────────────────────────────────────────────────────┘

    // Current melody display
    layout.add(StaticText()
        .string_("MELODY NAVIGATION")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\center)
    );

    // Current melody status
    currentMelodyDisplay = StaticText()
        .string_("No melodies loaded")
        .font_(Font.default.size_(10))
        .align_(\center)
        .stringColor_(Color.blue);

    layout.add(currentMelodyDisplay);

    // Navigation buttons
    navigationSection = HLayout();

    prevButton = Button()
        .states_([["◀ Previous", Color.black, Color.yellow.alpha_(0.3)]])
        .action_({
            if (~prevMelody.notNil) {
                var melody = ~prevMelody.();
                if (melody.notNil) {
                    currentMelodyDisplay.string_("% (% of %)".format(
                        melody,
                        (~oscLayers.state.currentMelodyIndex ? 0) + 1,
                        (~oscLayers.state.melodyList ? []).size
                    ));
                    updateStatus.();
                };
            };
        });

    nextButton = Button()
        .states_([["Next ▶", Color.black, Color.yellow.alpha_(0.3)]])
        .action_({
            if (~nextMelody.notNil) {
                var melody = ~nextMelody.();
                if (melody.notNil) {
                    currentMelodyDisplay.string_("% (% of %)".format(
                        melody,
                        (~oscLayers.state.currentMelodyIndex ? 0) + 1,
                        (~oscLayers.state.melodyList ? []).size
                    ));
                    updateStatus.();
                };
            };
        });

    navigationSection.add(prevButton);
    navigationSection.add(nextButton);
    layout.add(navigationSection);

    // Apply current melody button
    layout.add(
        Button()
            .states_([["Apply Current Melody to All Layers", Color.black, Color.green.alpha_(0.2)]])
            .action_({
                if (~applyCurrentMelodyToAllLayers.notNil) {
                    var applied = ~applyCurrentMelodyToAllLayers.();
                    updateStatus.();
                    "Applied current melody to % layers".format(applied).postln;
                };
            })
    );

    layout.add(StaticText().string_("═══════════════════════════════"));

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         LAYER SECTIONS                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘

    [\layer1, \layer2, \layer3].do { |layerName, index|
        var layerSection, enableCheck, melodyMenu, vstGroupMenu;
        var layerNum = index + 1;
        var config = ~oscLayers.configs[layerName];

        // Layer header
        layout.add(StaticText()
            .string_("LAYER % (OSC)".format(layerNum))
            .font_(Font.default.size_(12).bold_(true))
            .align_(\center)
        );

        // Enable checkbox
        enableCheck = CheckBox()
            .string_("Enable Layer %".format(layerNum))
            .value_(config.enabled)
            .action_({ |cb|
                "GUI → OSC: Layer % enabled: %".format(layerNum, cb.value).postln;
                NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/enabled', cb.value);
                updateStatus.();
            });

        layout.add(enableCheck);

        // Melody selection
        melodyMenu = PopUpMenu()
            .items_(["None"] ++ if (~melodyDict.notNil) {
                ~melodyDict.keys.asArray.sort.collect(_.asString)
            } { [] })
            .action_({ |menu|
                if (menu.value > 0 and: { ~melodyDict.notNil }) {
                    var melodyKeys = ~melodyDict.keys.asArray.sort;
                    if (menu.value <= melodyKeys.size) {
                        var melodyKey = melodyKeys[menu.value - 1];
                        "GUI → OSC: Setting layer % melody to %".format(layerNum, melodyKey).postln;
                        NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/melody', melodyKey);
                        updateStatus.();
                    };
                };
            });

        // Store melody menu for global updates
        melodyMenus = melodyMenus.add(melodyMenu);

        layout.add(HLayout(
            StaticText().string_("Melody:"),
            melodyMenu
        ));

        // VST Group selection
        vstGroupMenu = PopUpMenu()
            .items_(if (~vstManager.notNil) {
                ~vstManager.getGroupNames()
            } {
                ['Layer1', 'Layer2', 'Layer3']
            })
            .value_(if (~vstManager.notNil) {
                var groupNames = ~vstManager.getGroupNames();
                groupNames.indexOf(config.vstGroup) ? 0;
            } { index })
            .action_({ |menu|
                var groupNames = if (~vstManager.notNil) {
                    ~vstManager.getGroupNames()
                } {
                    ['Layer1', 'Layer2', 'Layer3']
                };
                if (menu.value < groupNames.size) {
                    var groupName = groupNames[menu.value];
                    "GUI → OSC: Setting layer % VST group to %".format(layerNum, groupName).postln;
                    // Update config directly for now (could be OSC message in future)
                    config.vstGroup = groupName;
                    updateStatus.();
                };
            });

        vstGroupMenus = vstGroupMenus.add(vstGroupMenu);

        layout.add(HLayout(
            StaticText().string_("VST Group:"),
            vstGroupMenu
        ));

        // Windowing controls (placeholder for now)
        layout.add(
            CheckBox()
                .string_("Windowing Mode (Layer %)".format(layerNum))
                .value_(config.windowing.enabled)
                .action_({ |cb|
                    config.windowing.enabled = cb.value;
                    "Layer % windowing: %".format(layerNum, cb.value).postln;
                    updateStatus.();
                })
        );

        // Test button for individual layer
        layout.add(
            Button()
                .states_([["Test Layer % (Single Note)".format(layerNum), Color.black, Color.cyan.alpha_(0.3)]])
                .action_({
                    "GUI → OSC: Testing layer % with single note".format(layerNum).postln;
                    NetAddr.localAddr.sendMsg('/layer' ++ layerNum ++ '/note', 60, 100, 1.0);
                })
        );

        layout.add(StaticText().string_("───────────────"));
    };

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         STATUS SECTION                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘

    layout.add(StaticText()
        .string_("STATUS")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\center)
    );

    statusText = StaticText()
        .string_("OSC Layers System Ready")
        .align_(\center);

    layout.add(statusText);

    // Refresh button
    refreshButton = Button()
        .states_([["Refresh Status", Color.black, Color.gray.alpha_(0.3)]])
        .action_({ updateStatus.() });

    layout.add(refreshButton);

    // OSC Info section
    layout.add(StaticText()
        .string_("OSC CONTROL INFO")
        .font_(Font.default.size_(10).bold_(true))
        .align_(\center)
    );

    layout.add(StaticText()
        .string_("Send OSC to localhost:")
        .font_(Font.default.size_(10))
        .align_(\center)
    );

    layout.add(StaticText()
        .string_("/system/start, /system/stop")
        .font_(Font.default.size_(9))
        .align_(\center)
        .stringColor_(Color.blue)
    );

    layout.add(StaticText()
        .string_("/layer1/note <note> <vel> <dur>")
        .font_(Font.default.size_(9))
        .align_(\center)
        .stringColor_(Color.blue)
    );

    // Update status function
    updateStatus = {
        var statusStr = "";
        var activeCount = 0;

        [\layer1, \layer2, \layer3].do { |layerName, i|
            var config = ~oscLayers.configs[layerName];
            if (config.enabled and: { config.melodyList.size > 0 }) {
                activeCount = activeCount + 1;
            };
        };

        statusStr = "Active layers: %\n".format(activeCount);
        statusStr = statusStr ++ "Running: %\n".format(~oscLayers.state.isRunning);

        // Per-layer playback status
        statusStr = statusStr ++ "layer1 playing: %\n".format(~layer1_isPlaying);
        statusStr = statusStr ++ "layer2 playing: %\n".format(~layer2_isPlaying);
        statusStr = statusStr ++ "layer3 playing: %\n".format(~layer3_isPlaying);

        statusStr = statusStr ++ "Loop mode: %\n".format(~oscLayers.state.loopingMode);
        statusStr = statusStr ++ "Manual control: %\n".format(~oscLayers.state.manualControl);
        statusStr = statusStr ++ "Single note CC: %\n".format(~oscLayers.state.singleNoteCCMode);
        statusStr = statusStr ++ "Chord mode: %\n".format(~oscLayers.state.chordMode);
        statusStr = statusStr ++ "Arpeggio mode: %\n".format(~oscLayers.state.arpeggioMode);
        statusStr = statusStr ++ "Bend mode: %\n".format(~oscLayers.state.bendMode);
        statusStr = statusStr ++ "Simple ramp: %".format(~getLayerBendSimpleRamp.() ? false);

        statusText.string_(statusStr);

        // Update BPM display
        if (bpmDisplay.notNil and: { ~oscLayers.state.manualControl and: { ~getBPMFromKnob.notNil } }) {
            var bpm = ~getBPMFromKnob.();
            var range = if (~oscLayers.state.chordMode) { "6-100" } { "60-400" };
            bpmDisplay.string_("BPM: % (% range, Row 1 Knob 8)".format(bpm.round(1), range));
        };

        // Update melody rest display
        if (restTimeDisplay.notNil) {
            var melodyRest = ~oscLayers.state.melodyRestTime;
            restTimeDisplay.string_("Melody Rest: %s (Slider 2)".format(
                melodyRest.round(0.01)
            ));
        };

        // Update arpeggio delay display
        if (arpeggioDisplay.notNil) {
            var minPercent = (~oscLayers.state.arpeggioMinDelay * 100).round(1);
            var maxPercent = (~oscLayers.state.arpeggioMaxDelay * 100).round(1);
            arpeggioDisplay.string_("Delays: %-%%  of duration (Sliders 3-4)".format(
                minPercent, maxPercent
            ));
        };

        // Update current melody display
        if (~oscLayers.notNil and: { ~oscLayers.state.melodyList.size > 0 }) {
            var currentMelody = ~oscLayers.state.melodyList[~oscLayers.state.currentMelodyIndex];
            currentMelodyDisplay.string_("% (% of %)".format(
                currentMelody,
                ~oscLayers.state.currentMelodyIndex + 1,
                ~oscLayers.state.melodyList.size
            ));
        } {
            currentMelodyDisplay.string_("No melodies loaded");
        };
    };

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         FINALIZE WINDOW                                    │
    // └─────────────────────────────────────────────────────────────────────────────┘

    win.layout_(layout);

    // Window close action
    win.onClose_({
        ~layersGUIWindow = nil;
        "OSC Layers GUI closed".postln;
    });

    // Initial status update
    updateStatus.();

    // Show window
    win.front;

    // Store reference
    ~layersGUIWindow = win;

    "OSC Layers GUI created".postln;
    "  - All controls send OSC messages".postln;
    "  - Compatible with external OSC control".postln;

    win;
};

// Function to update GUI from OSC state changes
~updateGUIFromOSC = {
    if (~layersGUIWindow.notNil) {
        AppClock.sched(0, {
            // Update checkboxes and status
            // This could be enhanced to reflect OSC state changes
            "GUI updated from OSC state".postln;
        });
    };
};

// Function to refresh layer GUI after VST configuration changes
~refreshLayerVSTGroups = {
    if (~layersGUIWindow.notNil) {
        AppClock.sched(0, {
            var window = ~layersGUIWindow;
            if (window.notNil and: { window.isClosed.not }) {
                "Refreshing layer GUI with new VST groups...".postln;
                // Close and recreate the GUI with updated state
                window.close;
                // FIXED: Use AppClock.sched instead of .wait
                AppClock.sched(0.1, {
                    ~createLayersGUI.();
                });
            };
        });
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                    ENHANCED GLOBAL MELODY LOADING                          │
// └─────────────────────────────────────────────────────────────────────────────┘

~loadGlobalMelodyFile = { |filePath, callback|
    var filename, melodyCount = 0, success = false;

    filename = PathName(filePath).fileName;

    if (File.exists(filePath)) {
        var extension = PathName(filePath).extension.toLower;

        if (extension == "json") {
            // Handle JSON files using timing-aware import function
            try {
                "Loading global JSON melody file: %".format(filePath).postln;

                // Use the existing timing-aware import function
                if (~importLayerMelodyFromJSON.notNil) {
                    var melodies = ~importLayerMelodyFromJSON.(filePath);

                    if (melodies.notNil) {
                        // Clear existing melody dictionary
                        ~melodyDict = Dictionary.new();

                        // Add imported melodies to global dictionary
                        ~addImportedMelodiesToDict.(melodies, "");  // Empty prefix to use original layer names

                        // Note: melodyList is populated by ~addImportedMelodiesToDict with base melody names
                        melodyCount = ~melodyDict.keys.size;
                        success = true;

                        "Global melody file loaded: % melodies from %".format(
                            melodyCount, filename
                        ).postln;
                        "Melody navigation: % melodies available".format(~oscLayers.state.melodyList.size).postln;
                    } {
                        "Failed to parse JSON melody file".warn;
                    };
                } {
                    "~importLayerMelodyFromJSON function not available".warn;
                };
            } { |error|
                "Error loading JSON melody file: %".format(error).warn;
            };
        } {
            if (extension == "scd") {
                // Handle SuperCollider files (legacy support)
                try {
                    "Loading global SuperCollider melody file: %".format(filePath).postln;
                    filePath.load;

                    // Count melodies if ~melodyDict exists
                    if (~melodyDict.notNil) {
                        // Note: melodyList should be populated by file loading mechanism with base melody names
                        melodyCount = ~melodyDict.keys.size;
                        success = true;
                        "Global melody file loaded: % melodies from %".format(
                            melodyCount, filename
                        ).postln;
                        "Melody navigation: % melodies available".format(~oscLayers.state.melodyList.size).postln;
                    } {
                        "Melody dictionary not populated after loading file".warn;
                    };
                } { |error|
                    "Error loading SuperCollider melody file: %".format(error).warn;
                };
            } {
                "Unsupported file format. Use .json or .scd files.".warn;
            };
        };
    } {
        "File does not exist: %".format(filePath).warn;
    };

    // Execute callback with results
    if (callback.notNil) {
        callback.(success, melodyCount, filename);
    };

    success;
};

"OSC Layers GUI loaded".postln;
"  - GUI controls via OSC messages".postln;
"  - Global melody file loading".postln;
"  - External control ready".postln;