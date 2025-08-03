/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         DEPENDENT LAYERS - GUI                                ║
║                         User interface controls                               ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         GUI CREATION                                       │
// └─────────────────────────────────────────────────────────────────────────────┘

~createLayersGUI = {
    var win, layout;
    var transportSection, layerSections, statusSection;
    var startButton, stopButton, statusText;
    var updateStatus, vstGroupMenus = [];
    var refreshButton;
    
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
    win = Window("Dependent Layers Control", Rect(100, 100, 400, 850));
    
    // Main layout
    layout = VLayout();
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         TRANSPORT SECTION                                  │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(StaticText()
        .string_("TRANSPORT")
        .font_(Font.default.size_(14).bold_(true))
        .align_(\center)
    );
    
    transportSection = HLayout();
    
    startButton = Button()
        .states_([
            ["Start All Layers", Color.black, Color.green.alpha_(0.3)]
        ])
        .action_({ 
            "DEBUG: Start button pressed".postln;
            ~startLayers.();
        });
    
    stopButton = Button()
        .states_([
            ["Stop All Layers", Color.black, Color.red.alpha_(0.3)]
        ])
        .action_({ ~stopLayers.() });
    
    transportSection.add(startButton);
    transportSection.add(stopButton);
    layout.add(transportSection);
    
    // Looping mode checkbox
    layout.add(
        CheckBox()
            .string_("Loop Mode")
            .value_(~layers.state.loopingMode)
            .action_({ |cb|
                ~layers.state.loopingMode = cb.value;
                statusText.string = if (cb.value) {
                    "Loop mode: ON"
                } {
                    "Loop mode: OFF"
                };
            })
    );
    
    // Manual control mode checkbox
    layout.add(
        CheckBox()
            .string_("Manual Control (MIDI Knobs: Duration + Velocity)")
            .value_(~layers.state.manualControl)
            .action_({ |cb|
                ~setLayersManualControl.(cb.value);
                updateStatus.(); // Use updateStatus to show consistent formatting
            })
    );
    
    // Live melody mode checkbox
    layout.add(
        CheckBox()
            .string_("Live Melody Mode (OSC Updates)")
            .value_(~layers.state.liveMelodyMode)
            .action_({ |cb|
                if (cb.value) {
                    ~enableLiveMelodyMode.();
                } {
                    ~disableLiveMelodyMode.();
                };
                updateStatus.();
            })
    );
    
    // Single note CC mode checkbox
    layout.add(
        CheckBox()
            .string_("Single Note CC Mode (Per-note envelopes)")
            .value_(~layers.state.singleNoteCCMode)
            .action_({ |cb|
                ~layers.state.singleNoteCCMode = cb.value;
                statusText.string = if (cb.value) {
                    "Single note CC mode: ON"
                } {
                    "Single note CC mode: OFF"
                };
            })
    );
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         STATUS SECTION                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    statusText = StaticText()
        .string_("Status: Ready")
        .font_(Font.default.size_(10))
        .align_(\center);
    
    layout.add(statusText);
    
    // Separator
    layout.add(View().fixedHeight_(10));
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         LAYER CONTROLS                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(StaticText()
        .string_("LAYER CONTROLS")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\center)
    );
    
    // Create controls for exactly 3 layers
    3.do { |i|
        var layerName = ("layer" ++ (i+1)).asSymbol;
        var config = ~layers.configs[layerName];
        var layerLayout, enableCheck, melodyMenu, vstGroupMenu;
        var statusIndicator, loadFileButton;
        
        // Debug VST group availability
        if (i == 0) {  // Only print once
            "=== Layer GUI Debug ===".postln;
            "~vstManager available: %".format(~vstManager.notNil).postln;
            if (~vstManager.notNil) {
                "VST groups: %".format(~vstManager.getGroupNames()).postln;
            };
            "===================".postln;
        };
        
        // Layer header
        layout.add(View().fixedHeight_(5));
        layout.add(StaticText()
            .string_("Layer " ++ (i+1))
            .font_(Font.default.bold_(true))
            .background_(Color.gray.alpha_(0.2))
        );
        
        layerLayout = VLayout();
        
        // Enable checkbox
        enableCheck = CheckBox()
            .string_("Enabled")
            .value_(config[\enabled] ? true)
            .action_({ |cb|
                ~setLayerEnabled.(layerName, cb.value);
                updateStatus.();
            });
        
        layerLayout.add(enableCheck);
        
        // Melody selection
        melodyMenu = PopUpMenu()
            .items_(["None"] ++ if (~melodyDict.notNil) { 
                ~melodyDict.keys.asArray.sort.collect(_.asString)
            } { 
                [] 
            })
            .action_({ |menu|
                if (menu.value > 0 and: { ~melodyDict.notNil }) {
                    var melodyKeys = ~melodyDict.keys.asArray.sort;
                    if (menu.value <= melodyKeys.size) {
                        var melodyKey = melodyKeys[menu.value - 1];
                        ~setLayerMelody.(layerName, melodyKey);
                        updateStatus.();
                    };
                };
            });
        
        // Load file button for this layer
        loadFileButton = Button()
            .states_([["Load File"]])
            .action_({
                FileDialog({ |path|
                    if (path.notNil) {
                        // Load melody from file for this specific layer
                        ~loadMelodyFileForLayer.(layerName, path);
                        
                        // Update the melody menu with newly loaded melodies
                        {
                            if (~melodyDict.notNil) {
                                var items = ["None"] ++ ~melodyDict.keys.asArray.sort.collect(_.asString);
                                melodyMenu.items = items;
                                
                                // Find and select the current melody for this layer
                                if (config[\melodyList].notNil && config[\melodyList].size > 0) {
                                    var currentMelody = config[\melodyList][0];
                                    var index = ~melodyDict.keys.asArray.sort.indexOf(currentMelody);
                                    if (index.notNil) {
                                        melodyMenu.value = index + 1; // +1 because "None" is at index 0
                                    };
                                };
                            };
                        }.defer;
                        
                        updateStatus.();
                    };
                }, fileMode: 1, acceptMode: 0, stripResult: true);
            });
        
        layerLayout.add(HLayout(
            StaticText().string_("Melody:").fixedWidth_(60),
            melodyMenu,
            loadFileButton
        ));
        
        // VST group selection
        vstGroupMenu = PopUpMenu()
            .items_(if (~vstManager.notNil) { 
                ~vstManager.getGroupNames() 
            } { 
                ['Layer1', 'Layer2', 'Layer3'] 
            })
            .value_(if (~vstManager.notNil) {
                var groups = ~vstManager.getGroupNames();
                groups.indexOf(config[\vstGroup] ? 'Layer1') ? 0
            } {
                ['Layer1', 'Layer2', 'Layer3'].indexOf(config[\vstGroup] ? 'Layer1') ? 0
            })
            .action_({ |menu|
                var groupNames = if (~vstManager.notNil) {
                    ~vstManager.getGroupNames()
                } {
                    ['Layer1', 'Layer2', 'Layer3']
                };
                if (menu.value < groupNames.size) {
                    var groupName = groupNames[menu.value];
                    ~setLayerVSTGroup.(layerName, groupName);
                    updateStatus.();
                };
            });
        
        layerLayout.add(HLayout(
            StaticText().string_("VST Group:").fixedWidth_(60),
            vstGroupMenu
        ));
        
        // Windowing controls - only for Layer 1
        if (config.windowing.notNil && (layerName == \layer1)) {
            var windowingCheck, windowSizeField, triggerField, stepField;
            var windowingLayout = VLayout();
            var melodyScalarText;
            
            // Windowing checkbox
            windowingCheck = CheckBox()
                .string_("Windowing (uses all 3 layers)")
                .value_(config.windowing.enabled)
                .action_({ |cb|
                    ~setLayerWindowing.(layerName, cb.value);
                    updateStatus.();
                });
            
            windowingLayout.add(windowingCheck);
            
            // Windowing parameters
            windowingLayout.add(HLayout(
                StaticText().string_("Window:").fixedWidth_(50),
                windowSizeField = NumberBox()
                    .value_(config.windowing.windowSize)
                    .decimals_(0)
                    .clipLo_(1)
                    .action_({ |nb|
                        ~setLayerWindowingParams.(layerName, nb.value, nil, nil);
                    })
                    .fixedWidth_(40),
                StaticText().string_("Trigger:").fixedWidth_(50),
                triggerField = NumberBox()
                    .value_(config.windowing.overlapTriggerIndex)
                    .decimals_(0)
                    .clipLo_(0)
                    .action_({ |nb|
                        ~setLayerWindowingParams.(layerName, nil, nb.value, nil);
                    })
                    .fixedWidth_(40),
                StaticText().string_("Step:").fixedWidth_(35),
                stepField = NumberBox()
                    .value_(config.windowing.stepSize)
                    .decimals_(0)
                    .clipLo_(1)
                    .action_({ |nb|
                        ~setLayerWindowingParams.(layerName, nil, nil, nb.value);
                    })
                    .fixedWidth_(40)
            ));
            
            // Add melody duration scalar display
            melodyScalarText = StaticText()
                .string_("Melody Duration: 100% (K8)")
                .font_(Font.default.size_(9).italic_(true));
            
            windowingLayout.add(melodyScalarText);
            
            layerLayout.add(windowingLayout);
            
            // Store windowing GUI references
            if (config[\gui].isNil) {
                config[\gui] = ();
            };
            config[\gui][\windowingCheck] = windowingCheck;
            config[\gui][\windowSizeField] = windowSizeField;
            config[\gui][\triggerField] = triggerField;
            config[\gui][\stepField] = stepField;
            config[\gui][\melodyScalarText] = melodyScalarText;
        };
        
        // Status indicator
        statusIndicator = UserView()
            .drawFunc_({ |view|
                var isReady = ~isLayerReady.(layerName) ? false;
                if (isReady) {
                    Pen.fillColor = Color.green;
                } {
                    Pen.fillColor = Color.gray;
                };
                Pen.fillRect(view.bounds);
            })
            .fixedHeight_(3);
        
        layerLayout.add(statusIndicator);
        
        // Store references for updates
        if (config.notNil) {
            config[\gui] = (
                enableCheck: enableCheck,
                melodyMenu: melodyMenu,
                vstGroupMenu: vstGroupMenu,
                statusIndicator: statusIndicator
            );
        };
        
        // Store the VST group menu for refresh capability
        vstGroupMenus = vstGroupMenus.add(vstGroupMenu);
        
        layout.add(layerLayout);
    };
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         INFO SECTION                                       │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(View().fixedHeight_(10));
    
    // Refresh VST Groups button with visual indicator
    ~layersRefreshButton = Button()
        .states_([
            ["Auto-loading VST Groups...", Color.black, Color.yellow.alpha_(0.3)],
            ["VST Groups Loaded", Color.black, Color.green.alpha_(0.3)]
        ])
        .action_({ |btn|
            ~refreshLayerVSTGroups.();
            // Check if we got any groups
            if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
                statusText.string = "VST groups loaded: %".format(~vstManager.getGroupNames());
                btn.value = 1; // Change to "OK" state
            } {
                statusText.string = "Still waiting for VST groups...";
                btn.value = 0; // Keep in refresh state
            };
        });
    
    layout.add(~layersRefreshButton);
    
    layout.add(StaticText()
        .string_("TIMING INFO")
        .font_(Font.default.size_(10).bold_(true))
        .align_(\center)
    );
    
    layout.add(StaticText()
        .string_("Manual Control: K8=Duration, K3=Velocity, K2=Note Dur (1-150%)")
        .font_(Font.default.size_(9).italic_(true))
        .align_(\center)
    );
    
    layout.add(StaticText()
        .string_("Windowing: K8=Melody Speed, K3=Velocity (when manual control on)")
        .font_(Font.default.size_(9).italic_(true))
        .align_(\center)
    );
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UPDATE FUNCTION                                    │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    updateStatus = {
        var activeCount = ~getActiveLayerCount.();
        var statusString;
        
        if (~layers.parentProc.notNil and: { ~layers.parentProc.isRunning }) {
            var playTime = ~getLayersPlayTime.();
            statusString = "Playing: % layers, Time: %s".format(
                activeCount, 
                playTime.round(0.1)
            );
            
            // Add duration info if manual control is active
            if (~layers.state.manualControl) {
                var duration = ~getLayersDurationFromKnob.();
                statusString = statusString ++ " | Duration: %s".format(duration.round(0.1));
            };
            
            // Add windowing melody scalar info if windowing is enabled
            if (~layers.configs[\layer1].windowing.enabled) {
                var scalar = ~getWindowingMelodyDurationScalar.();
                statusString = statusString ++ " | Melody: %%".format((scalar * 100).round(1));
            };
            
            // Add live melody info if active
            if (~layers.state.liveMelodyMode) {
                var pendingCount = 0;
                if (~layers.state.pendingUpdates.notNil) {
                    ~layers.state.pendingUpdates.keysValuesDo { |layer, data|
                        if (data.notNil) { pendingCount = pendingCount + 1 };
                    };
                };
                if (pendingCount > 0) {
                    statusString = statusString ++ " | Live: % pending".format(pendingCount);
                } {
                    statusString = statusString ++ " | Live: active";
                };
            };
        } {
            statusString = "Ready: % layers configured".format(activeCount);
            
            // Show duration when not playing if manual control is active
            if (~layers.state.manualControl) {
                var duration = ~getLayersDurationFromKnob.();
                statusString = statusString ++ " | Duration: %s".format(duration.round(0.1));
            };
            
            // Show windowing melody scalar when not playing if windowing is enabled
            if (~layers.configs[\layer1].windowing.enabled) {
                var scalar = ~getWindowingMelodyDurationScalar.();
                statusString = statusString ++ " | Melody: %%".format((scalar * 100).round(1));
            };
            
            // Show live melody status when not playing
            if (~layers.state.liveMelodyMode) {
                statusString = statusString ++ " | Live mode enabled";
            };
        };
        
        statusText.string = statusString;
        
        // Update status indicators
        ~layers.configs.keysValuesDo { |name, config|
            if (config[\gui].notNil) {
                config[\gui].statusIndicator.refresh;
            };
        };
    };
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         WINDOW SETUP                                       │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    win.layout = layout;
    
    win.onClose = {
        ~layersGUIWindow = nil;
        if (~layersStatusRoutine.notNil) {
            ~layersStatusRoutine.stop;
            ~layersStatusRoutine = nil;
        };
    };
    
    // Status update routine
    ~layersStatusRoutine = Routine({
        var vstCheckCounter = 0;
        var vstGroupsLoaded = false;
        
        loop {
            try {
                updateStatus.();
                
                // Update windowing melody scalar display if enabled
                if (~layers.configs[\layer1].windowing.enabled) {
                    var scalar = ~getWindowingMelodyDurationScalar.();
                    var scalarPercent = (scalar * 100).round(1);
                    var melodyScalarText = ~layers.configs[\layer1][\gui][\melodyScalarText];
                    if (melodyScalarText.notNil) {
                        melodyScalarText.string = "Melody Duration: %% (K8)".format(scalarPercent);
                    };
                };
                
                // Auto-check for VST groups every second for first 30 seconds
                if (vstGroupsLoaded.not and: { vstCheckCounter < 30 }) {
                    if (~vstManager.notNil and: { ~vstManager.getGroupNames().size > 0 }) {
                        "VST groups detected! Auto-refreshing...".postln;
                        ~refreshLayerVSTGroups.();
                        vstGroupsLoaded = true;
                        statusText.string = "VST groups loaded automatically!";
                        // Update the button to show success
                        if (~layersRefreshButton.notNil) {
                            ~layersRefreshButton.value = 1;
                        };
                    };
                    vstCheckCounter = vstCheckCounter + 0.1;
                };
            } { |error|
                ("Error in status update routine: " ++ error).postln;
                ~layersStatusRoutine.stop;
                ~layersStatusRoutine = nil;
            };
            0.1.wait;
        }
    }).play(AppClock);
    
    // Initial status update
    updateStatus.();
    
    // Check VST availability on startup
    if (~vstManager.isNil or: { ~vstManager.getGroupNames().size == 0 }) {
        statusText.string = "VST groups not ready - click 'Refresh VST Groups' button";
    };
    
    win.front;
    ~layersGUIWindow = win;
    
    // Function to refresh VST group menus
    ~refreshLayerVSTGroups = {
        var groupNames, currentValue, currentGroupName, newIndex;
        
        if (~vstManager.notNil) {
            groupNames = ~vstManager.getGroupNames();
            if (groupNames.notNil and: { groupNames.size > 0 }) {
                vstGroupMenus.do { |menu, i|
                    currentValue = menu.value;
                    currentGroupName = if (currentValue < menu.items.size) {
                        menu.items[currentValue]
                    } { nil };
                    menu.items = groupNames;
                    // Try to restore selection
                    newIndex = groupNames.indexOf(currentGroupName);
                    if (newIndex.notNil) {
                        menu.value = newIndex;
                    } {
                        var layerName;
                        // Default to matching layer index or first group
                        menu.value = min(i, groupNames.size - 1);
                        // Also update the layer's vstGroup to match
                        layerName = [\layer1, \layer2, \layer3][i];
                        if (layerName.notNil && groupNames.size > i) {
                            ~setLayerVSTGroup.(layerName, groupNames[i]);
                        };
                    };
                };
                "Refreshed VST group menus with % groups".format(groupNames.size).postln;
            } {
                "No VST groups available".postln;
            };
        } {
            "VSTManager not available".postln;
        };
    };
    
    // Initial refresh of VST groups
    ~refreshLayerVSTGroups.();
    
    win
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CONVENIENCE FUNCTIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Close the GUI window
~closeLayersGUI = {
    if (~layersGUIWindow.notNil and: { ~layersGUIWindow.isClosed.not }) {
        ~layersGUIWindow.close;
    };
};

// Refresh the GUI
~refreshLayersGUI = {
    if (~layersGUIWindow.notNil and: { ~layersGUIWindow.isClosed.not }) {
        ~layersGUIWindow.close;
        ~createLayersGUI.();
    };
};

// Auto-create GUI - commented out to prevent errors on startup
// ~createLayersGUI.();

"Dependent layers GUI loaded".postln;