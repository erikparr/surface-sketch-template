// Sketch GUI - Enhanced with Looping Envelope Controls
// Visual interface for the looping envelope system

(
// GUI state
~guiState = (
    window: nil,
    updateRoutine: nil,
    sliderViews: Dictionary.new,
    meterViews: Dictionary.new,
    statusViews: Dictionary.new
);

// Create main GUI window
~createEnvelopeGUI = {
    var window, mainView, groupViews, transportView, statusView, meterView, globalView;
    
    groupViews = Dictionary.new;
    
    // Close existing window if any
    if(~guiState.window.notNil) {
        ~guiState.window.close;
    };
    
    // Create window
    window = Window("Looping Envelope Control", Rect(100, 100, 800, 600));
    window.background = Color.grey(0.1);
    
    mainView = View(window, window.bounds.insetBy(10, 10));
    mainView.layout = VLayout();
    
    // Title
    StaticText(mainView, Rect(0, 0, 800, 30))
        .string_("Looping Envelope System")
        .font_(Font("Arial", 20, true))
        .stringColor_(Color.white)
        .align_(\center);
    
    // Transport controls
    transportView = View(mainView, Rect(0, 0, 780, 80));
    transportView.background = Color.grey(0.2);
    transportView.layout = HLayout(
        // Play button
        Button()
            .states_([
                ["▶ Play", Color.white, Color.green(0.5)],
                ["◼ Stop", Color.white, Color.red(0.5)]
            ])
            .action_({ |btn|
                if(btn.value == 1) {
                    ~startPerformance.value();
                } {
                    ~stopPerformance.value();
                };
            })
            .fixedWidth_(100),
        
        // Target selector
        PopUpMenu()
            .items_([\All] ++ ~vstManager.getGroupNames)
            .action_({ |menu|
                ~setTarget.value(menu.item);
            })
            .fixedWidth_(150),
        
        // Test button
        Button()
            .states_([["Test Current", Color.white, Color.blue(0.5)]])
            .action_({
                ~testEnvelopePlayback.value(~currentTarget);
            })
            .fixedWidth_(100),
        
        // Emergency stop
        Button()
            .states_([["Emergency Stop", Color.white, Color.red(0.7)]])
            .action_({
                ~emergencyReset.value();
            })
            .fixedWidth_(120),
        
        nil // Spacer
    );
    
    mainView.layout.add(transportView);
    
    // Group controls
    [\Strings, \Winds, \Brass].do { |groupName, i|
        var groupView = View(mainView, Rect(0, 0, 780, 120));
        var params = ~groupEnvelopeParams[groupName] ? ~defaultEnvelopeParams;
        var color = [Color.blue(0.3), Color.green(0.3), Color.red(0.3)][i];
        
        groupView.background = color;
        groupView.layout = VLayout(
            StaticText()
                .string_(groupName.asString)
                .font_(Font("Arial", 16, true))
                .stringColor_(Color.white),
            
            HLayout(
                // Bend percentage
                VLayout(
                    StaticText().string_("Bend %").stringColor_(Color.white),
                    Slider()
                        .value_(params.bendPercent / 100)
                        .action_({ |sl|
                            var val = (sl.value * 127).asInteger;
                            ~updateGroupBendPercent.value(groupName, val);
                        })
                        .onClose_({ |v| ~guiState.sliderViews[groupName ++ "_bend"] = nil }),
                    {
                        var bendText = StaticText().string_(params.bendPercent.round(0.1).asString ++ "%")
                            .stringColor_(Color.white)
                            .align_(\center);
                        ~guiState.sliderViews[groupName ++ "_bend"] = bendText;
                        bendText;
                    }.value()
                ),
                
                // Bend duration
                VLayout(
                    StaticText().string_("Bend Dur").stringColor_(Color.white),
                    Slider()
                        .value_(params.bendDuration.linlin(0.5, 15.0, 0, 1))
                        .action_({ |sl|
                            var val = (sl.value * 127).asInteger;
                            ~updateGroupBendDuration.value(groupName, val);
                        })
                        .onClose_({ |v| ~guiState.sliderViews[groupName ++ "_dur"] = nil }),
                    {
                        var durText = StaticText().string_(params.bendDuration.round(0.1).asString ++ "s")
                            .stringColor_(Color.white)
                            .align_(\center);
                        ~guiState.sliderViews[groupName ++ "_dur"] = durText;
                        durText;
                    }.value()
                ),
                
                // Expression level
                VLayout(
                    StaticText().string_("Expr Level").stringColor_(Color.white),
                    Slider()
                        .value_(params.exprLevel / 127)
                        .action_({ |sl|
                            var val = (sl.value * 127).asInteger;
                            var p = ~groupEnvelopeParams[groupName];
                            if(p.notNil) {
                                p.exprLevel = val;
                                ~applyEnvelopeToTarget.value(groupName, p);
                            };
                        })
                        .onClose_({ |v| ~guiState.sliderViews[groupName ++ "_expr"] = nil }),
                    {
                        var exprText = StaticText().string_(params.exprLevel.asString)
                            .stringColor_(Color.white)
                            .align_(\center);
                        ~guiState.sliderViews[groupName ++ "_expr"] = exprText;
                        exprText;
                    }.value()
                ),
                
                // Active indicator
                VLayout(
                    StaticText().string_("Active").stringColor_(Color.white),
                    {
                        var statusView = View().background_(Color.grey(0.3)).fixedSize_(50@50);
                        ~guiState.statusViews[groupName] = statusView;
                        statusView;
                    }.value()
                )
            )
        );
        
        groupViews[groupName] = groupView;
        mainView.layout.add(groupView);
    };
    
    // Global controls
    globalView = View(mainView, Rect(0, 0, 780, 80));
    globalView.background = Color.grey(0.25);
    globalView.layout = HLayout(
        StaticText().string_("Global:").stringColor_(Color.white).fixedWidth_(60),
        
        // Global expression
        VLayout(
            StaticText().string_("Expression").stringColor_(Color.white),
            Slider()
                .value_(100 / 127)
                .action_({ |sl|
                    ~updateGlobalExpressionLevel.value((sl.value * 127).asInteger);
                })
        ),
        
        // Global duration
        VLayout(
            StaticText().string_("Expr Duration").stringColor_(Color.white),
            Slider()
                .value_(1.0.linlin(0.1, 5.0, 0, 1))
                .action_({ |sl|
                    ~updateGlobalExpressionDuration.value((sl.value * 127).asInteger);
                })
        ),
        
        // Info display
        {
            var infoText = StaticText()
                .string_("Ready")
                .stringColor_(Color.white)
                .background_(Color.grey(0.3))
                .align_(\center)
                .fixedWidth_(200);
            ~guiState.statusViews[\info] = infoText;
            infoText;
        }.value()
    );
    
    mainView.layout.add(globalView);
    
    // Store references
    ~guiState.window = window;
    ~guiState.groupViews = groupViews;
    
    // Update routine
    ~guiState.updateRoutine = Routine({
        inf.do {
            defer {
                var hasActive, statusView, params, bendText, durText, exprText, infoText;
                
                // Update group status indicators
                [\Strings, \Winds, \Brass].do { |groupName|
                    hasActive = ~groupHasActiveEnvelopes.value(groupName);
                    statusView = ~guiState.statusViews[groupName];
                    if(statusView.notNil) {
                        statusView.background = if(hasActive) {
                            Color.green(0.7)
                        } {
                            Color.grey(0.3)
                        };
                    };
                    
                    // Update parameter displays
                    params = ~groupEnvelopeParams[groupName];
                    if(params.notNil) {
                        bendText = ~guiState.sliderViews[groupName ++ "_bend"];
                        durText = ~guiState.sliderViews[groupName ++ "_dur"];
                        exprText = ~guiState.sliderViews[groupName ++ "_expr"];
                        
                        if(bendText.notNil) { bendText.string = params.bendPercent.round(0.1).asString ++ "%" };
                        if(durText.notNil) { durText.string = params.bendDuration.round(0.1).asString ++ "s" };
                        if(exprText.notNil) { exprText.string = params.exprLevel.asString };
                    };
                };
                
                // Update info text
                infoText = ~guiState.statusViews[\info];
                if(infoText.notNil) {
                    infoText.string = if(~isPlaying) {
                        "Playing - Dev " ++ ~currentDevelopment ++ " - " ++ ~currentTarget
                    } {
                        "Stopped"
                    };
                };
            };
            
            0.1.wait;
        };
    }).play(AppClock);
    
    // Window close handler
    window.onClose = {
        if(~guiState.updateRoutine.notNil) {
            ~guiState.updateRoutine.stop;
        };
        ~guiState.window = nil;
    };
    
    window.front;
};

// Create preset manager window
~createPresetGUI = {
    var window, listView, saveButton, loadButton, deleteButton;
    var presetList, updatePresetList, presetDir;
    
    window = Window("Envelope Presets", Rect(200, 200, 400, 300));
    presetList = [];
    
    updatePresetList = {
        presetDir = Platform.userAppSupportDir +/+ "SuperCollider/EnvelopePresets";
        presetList = PathName(presetDir).files.collect { |f|
            f.fileNameWithoutExtension
        };
        listView.items = presetList;
    };
    
    window.layout = VLayout(
        StaticText().string_("Envelope Presets").font_(Font("Arial", 16, true)),
        listView = ListView().background_(Color.grey(0.9)),
        HLayout(
            saveButton = Button()
                .states_([["Save New", Color.white, Color.green(0.5)]])
                .action_({
                    var name;
                    name = "preset_" ++ Date.localtime.stamp;
                    ~saveEnvelopePreset.value(name);
                    updatePresetList.value();
                }),
            
            loadButton = Button()
                .states_([["Load", Color.white, Color.blue(0.5)]])
                .action_({
                    var selected;
                    selected = listView.selection;
                    if(selected.notNil) {
                        ~loadEnvelopePreset.value(presetList[selected[0]]);
                    };
                }),
            
            deleteButton = Button()
                .states_([["Delete", Color.white, Color.red(0.5)]])
                .action_({
                    var selected, path;
                    selected = listView.selection;
                    if(selected.notNil) {
                        path = Platform.userAppSupportDir +/+ "SuperCollider/EnvelopePresets" +/+ 
                            presetList[selected[0]] ++ ".scd";
                        File.delete(path);
                        updatePresetList.value();
                    };
                })
        )
    );
    
    updatePresetList.value();
    window.front;
};

// Auto-create GUI on load
~createEnvelopeGUI.value();

"GUI loaded - Window created".postln;
)