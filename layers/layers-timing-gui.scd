/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                     LAYER TIMING - GUI MONITOR                               ║
║                Real-time visualization of sequential timing                    ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading Layer Timing GUI...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         TIMING GUI CREATION                                │
// └─────────────────────────────────────────────────────────────────────────────┘

~createTimingControllerGUI = {
    var win, layout;
    var modeText, waitTimeText, timelineView, midiStatusText;
    var updateGUI, guiUpdateRoutine;
    var presetButtons, manualControls, statusLayout, indicatorView;
    var midiSection, midiButton;

    // Check if window already exists
    if (~timingControllerGUIWindow.notNil) {
        try {
            if (~timingControllerGUIWindow.isClosed.not) {
                ~timingControllerGUIWindow.front;
                ^~timingControllerGUIWindow;
            } {
                ~timingControllerGUIWindow = nil;
            };
        } {
            ~timingControllerGUIWindow = nil;
        };
    };

    // Create compact window
    win = Window("Layer Timing Controller", Rect(120, 500, 450, 180));
    layout = VLayout();

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                            HEADER SECTION                                  │
    // └─────────────────────────────────────────────────────────────────────────────┘

    layout.add(StaticText()
        .string_("LAYER TIMING CONTROLLER")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\center)
    );

    // Mode and timing display
    statusLayout = HLayout();

    modeText = StaticText()
        .string_("Mode: Simultaneous")
        .font_(Font.default.size_(10).bold_(true))
        .align_(\left);

    waitTimeText = StaticText()
        .string_("Wait Time: 0.50s")
        .font_(Font.default.size_(10))
        .align_(\right);

    statusLayout.add(modeText);
    statusLayout.add(waitTimeText);
    layout.add(statusLayout);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                          TIMELINE VISUALIZATION                            │
    // └─────────────────────────────────────────────────────────────────────────────┘

    timelineView = UserView()
        .background_(Color.black)
        .maxHeight_(60)
        .drawFunc_({ |view|
            var bounds, layerY, layerHeight, timeScale, maxTime;
            var triggerStates, offsetEnabled, offsetTime;

            bounds = view.bounds;
            layerHeight = (bounds.height - 20) / 3;
            layerY = 10;

            // Get current state
            triggerStates = ~oscLayers.state.layerTriggerStates;
            offsetEnabled = ~oscLayers.state.offsetTimingEnabled;
            offsetTime = ~oscLayers.state.offsetTime;

            // Calculate timeline scale
            maxTime = if (offsetEnabled) { offsetTime * 2.5 } { 1.0 };
            timeScale = (bounds.width - 40) / maxTime;

            // Clear background
            Pen.fillColor_(Color.gray(0.1));
            Pen.fillRect(bounds);

            // Draw timeline background
            Pen.strokeColor_(Color.gray(0.3));
            Pen.moveTo(20 @ (bounds.height - 5));
            Pen.lineTo((bounds.width - 20) @ (bounds.height - 5));
            Pen.stroke;

            // Draw layer timelines
            [\layer1, \layer2, \layer3].do { |layerKey, index|
                var config = ~oscLayers.configs[layerKey];
                var layerYPos = layerY + (index * layerHeight);
                var triggerState = triggerStates[layerKey];
                var enabled = config.enabled;
                var triggerTime = 0, triggered = false;

                if (triggerState.notNil) {
                    triggerTime = triggerState.scheduledTime;
                    triggered = triggerState.triggered;
                };

                // Layer background
                Pen.fillColor_(if (enabled) {
                    if (triggered) { Color.green.alpha_(0.3) } { Color.blue.alpha_(0.2) }
                } {
                    Color.gray.alpha_(0.1)
                });
                Pen.fillRect(Rect(20, layerYPos, bounds.width - 40, layerHeight - 2));

                // Layer label
                Pen.color_(Color.white);
                Pen.font_(Font.default.size_(9));
                Pen.stringAtPoint("L" ++ (index + 1), Point(5, layerYPos + 2));

                if (enabled) {
                    // Trigger indicator
                    var triggerX = 20 + (triggerTime * timeScale);
                    Pen.fillColor_(if (triggered) { Color.green } { Color.yellow });
                    Pen.fillOval(Rect(triggerX - 3, layerYPos + 2, 6, layerHeight - 6));

                    // Time label
                    if (offsetEnabled and: { triggerTime > 0 }) {
                        Pen.color_(Color.white);
                        Pen.stringAtPoint("%.2fs".format(triggerTime),
                            Point(triggerX + 8, layerYPos + 2));
                    };
                };

                // Border
                Pen.strokeColor_(Color.gray(0.5));
                Pen.strokeRect(Rect(20, layerYPos, bounds.width - 40, layerHeight - 2));
            };

            // Current time indicator (during playback)
            if (~oscLayers.state.isRunning) {
                var currentTime = if (~oscLayers.state.startTime.notNil) {
                    Main.elapsedTime - ~oscLayers.state.startTime
                } { 0 };

                if (currentTime >= 0 and: { currentTime <= maxTime }) {
                    var currentX = 20 + (currentTime * timeScale);
                    Pen.strokeColor_(Color.red);
                    Pen.width_(2);
                    Pen.moveTo(currentX @ 10);
                    Pen.lineTo(currentX @ (bounds.height - 10));
                    Pen.stroke;
                    Pen.width_(1);
                };
            };
        });

    layout.add(timelineView);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                        LAYER TRIGGER INDICATORS                            │
    // └─────────────────────────────────────────────────────────────────────────────┘

    // Simple row of circles that light up when layers trigger
    indicatorView = UserView()
        .background_(Color.black)
        .maxHeight_(40)
        .drawFunc_({ |view|
            var bounds, circleSize, spacing, yCenter;
            var triggerStates;

            bounds = view.bounds;
            circleSize = 20;
            spacing = (bounds.width - (3 * circleSize)) / 4;
            yCenter = bounds.height / 2;

            triggerStates = ~oscLayers.state.layerTriggerStates;

            // Draw 3 circles for the 3 layers
            [\layer1, \layer2, \layer3].do { |layerKey, index|
                var config = ~oscLayers.configs[layerKey];
                var triggerState = triggerStates[layerKey];
                var enabled = config.enabled;
                var triggered = false;
                var centerX, centerY;

                if (triggerState.notNil) {
                    triggered = triggerState.triggered;
                };

                centerX = spacing + (index * (circleSize + spacing)) + (circleSize / 2);
                centerY = yCenter;

                // Circle color based on state
                Pen.fillColor_(case
                    { triggered and: enabled } { Color.green }
                    { enabled } { Color.blue.alpha_(0.3) }
                    { Color.gray.alpha_(0.2) }
                );

                Pen.fillOval(Rect(centerX - (circleSize/2), centerY - (circleSize/2), circleSize, circleSize));

                // Layer number in center
                Pen.color_(Color.white);
                Pen.font_(Font.default.size_(10).bold_(true));
                Pen.stringAtPoint((index + 1).asString, Point(centerX - 3, centerY - 6));
            };
        });

    layout.add(indicatorView);

    // MIDI control section
    midiSection = HLayout();

    midiButton = Button()
        .states_([
            ["Start MIDI Control", Color.black, Color.green.alpha_(0.3)],
            ["Stop MIDI Control", Color.black, Color.red.alpha_(0.3)]
        ])
        .action_({ |btn|
            if (btn.value == 1) {
                ~startTimingControlMIDIPolling.();
                "MIDI timing control started".postln;
            } {
                ~stopTimingControlMIDIPolling.();
                "MIDI timing control stopped".postln;
            };
        });

    midiStatusText = StaticText()
        .string_("MIDI: Waiting...")
        .font_(Font.default.size_(9))
        .align_(\center)
        .stringColor_(Color.blue);

    midiSection.add(midiButton);
    midiSection.add(midiStatusText);
    layout.add(midiSection);

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UPDATE FUNCTIONS                                   │
    // └─────────────────────────────────────────────────────────────────────────────┘

    // GUI update function
    updateGUI = {
        var midiValues, offsetEnabled, offsetTime;

        // Update from current state
        offsetEnabled = ~oscLayers.state.offsetTimingEnabled;
        offsetTime = ~oscLayers.state.offsetTime;

        // Mode text
        {
            modeText.string_("Mode: " ++ if (offsetEnabled) { "Sequential" } { "Simultaneous" });
            modeText.stringColor_(if (offsetEnabled) { Color.green } { Color.blue });

            waitTimeText.string_("Wait Time: %.2fs".format(offsetTime));

            // MIDI status
            if (~midiController.notNil) {
                midiValues = ~getTimingControlMIDIValues.();
                midiStatusText.string_("MIDI: K1=%s K2=%.2fs".format(
                    if(midiValues.enabled, "ON", "OFF"),
                    midiValues.waitTime
                ));
                midiStatusText.stringColor_(Color.green);
            } {
                midiStatusText.string_("MIDI: Not Available");
                midiStatusText.stringColor_(Color.red);
            };

            // Refresh timeline
            timelineView.refresh;
        }.defer;
    };

    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         FINALIZE WINDOW                                    │
    // └─────────────────────────────────────────────────────────────────────────────┘

    win.layout_(layout);

    // Window close action
    win.onClose_({
        if (guiUpdateRoutine.notNil) {
            guiUpdateRoutine.stop;
            guiUpdateRoutine = nil;
        };
        ~timingControllerGUIWindow = nil;
        "Timing Controller GUI closed".postln;
    });

    // Initial update
    updateGUI.();

    // Show window
    win.front;

    // Store reference
    ~timingControllerGUIWindow = win;

    // Start GUI update routine
    guiUpdateRoutine = Routine({
        inf.do {
            updateGUI.();
            0.1.wait; // Update every 100ms
        };
    }).play;

    "Timing Controller GUI created".postln;
    "  - Real-time timing visualization".postln;
    "  - MIDI control display".postln;
    "  - Timeline shows layer trigger sequence".postln;

    win;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        INTEGRATION HELPERS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

// Function to update GUI from external state changes
~updateTimingGUIFromState = {
    // This can be called by other parts of the system to refresh the GUI
    if (~timingControllerGUIWindow.notNil) {
        AppClock.sched(0, {
            // GUI will update automatically via the routine
            "Timing GUI updated from external state".postln;
        });
    };
};

// Auto-refresh function for timeline during playback
~refreshTimingGUITimeline = {
    if (~timingControllerGUIWindow.notNil) {
        AppClock.sched(0, {
            // Force timeline refresh
            var view = ~timingControllerGUIWindow.view;
            if (view.notNil) {
                view.children.do { |child|
                    if (child.class == UserView) {
                        child.refresh;
                    };
                };
            };
        });
    };
};

"Layer Timing GUI loaded".postln;
"Available functions:".postln;
"• ~createTimingControllerGUI.() - Open timing visualization".postln;
"• ~updateTimingGUIFromState.() - Force GUI update".postln;
"• ~refreshTimingGUITimeline.() - Refresh timeline display".postln;