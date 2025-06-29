/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          SIMPLE SKETCH GUI                                   ║
║                        Just the basics that work                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Check if GUI already exists
if (~sketchGUIWindow.notNil) {
    try {
        if (~sketchGUIWindow.isClosed.not) {
            ~sketchGUIWindow.front;
        } {
            ~sketchGUIWindow = nil;
        };
    } {
        ~sketchGUIWindow = nil;
    };
};

if (~sketchGUIWindow.isNil) {
    ~createSketchGUI = {
        var win, layout, startButton, stopButton, statusText;
        
        // Create window
        win = Window("Sketch Control", Rect(100, 100, 300, 400));
        layout = VLayout();
        
        // Transport buttons
        layout.add(StaticText().string_("TRANSPORT").font_(Font.default.size_(14).bold_(true)));
        
        startButton = Button()
            .states_([["Start Sketch"]])
            .action_({
                if (~startContinuousLoopSequence.notNil) {
                    ~startContinuousLoopSequence.();
                    "Sketch started".postln;
                } {
                    "Start function not available".postln;
                };
            });
        layout.add(startButton);
        
        stopButton = Button()
            .states_([["Stop Sketch"]])
            .action_({
                if (~stopContinuousLoopSequence.notNil) {
                    ~stopContinuousLoopSequence.();
                    "Sketch stopped".postln;
                } {
                    "Stop function not available".postln;
                };
            });
        layout.add(stopButton);
        
        // Modes section
        layout.add(StaticText().string_("MODES").font_(Font.default.size_(12).bold_(true)));
        
        if (~modes.notNil) {
            var modeCheckboxes = Dictionary.new;
            ~modes.keysValuesDo { |key, value|
                var checkbox = CheckBox()
                    .string_(key.asString)
                    .value_(value)
                    .action_({ |cb|
                        ~modes[key] = cb.value;
                        "Mode % set to %".format(key, cb.value).postln;
                    });
                modeCheckboxes[key] = checkbox;
                layout.add(checkbox);
            };
            // Store reference to update chord checkbox later
            ~modeCheckboxes = modeCheckboxes;
        };
        
        // Bend Envelope section
        layout.add(StaticText().string_("BEND ENVELOPE").font_(Font.default.size_(12).bold_(true)));
        
        // Bend envelope toggle
        if (~toggleBendEnvelope.notNil) {
            var bendCheckbox = CheckBox()
                .string_("Enable Bend Envelope")
                .value_(~bendEnvelopeEnabled ? false)
                .action_({ |cb|
                    ~toggleBendEnvelope.(cb.value);
                    "Bend envelope %".format(if(cb.value, "enabled", "disabled")).postln;
                });
            layout.add(bendCheckbox);
            
            // Bend parameter display (read-only info)
            if (~bendEnvelopeParams.notNil) {
                layout.add(StaticText()
                    .string_("Control with Row 3 knobs:")
                    .font_(Font.default.size_(10)));
                layout.add(StaticText()
                    .string_("K1: Bend amount | K2: Peak time | K3: Return time")
                    .font_(Font.default.size_(10)));
            };
        };
        
        // Chord Progression section
        layout.add(StaticText().string_("CHORD PROGRESSION").font_(Font.default.size_(12).bold_(true)));
        
        // Enable chord mode button
        if (~enableChordMode.notNil) {
            var enableButton = Button()
                .states_([["Enable Chord Mode"], ["Chord Mode Active", Color.black, Color.green]])
                .value_(if(~modes.chordProgression && ~currentChordProgression.notNil, 1, 0))
                .action_({ |btn|
                    if (btn.value == 1) {
                        ~enableChordMode.();
                        ~updateChordStatusGUI.();
                        // Update the checkbox if it exists
                        if (~modeCheckboxes.notNil && ~modeCheckboxes[\chordProgression].notNil) {
                            { ~modeCheckboxes[\chordProgression].value = true }.defer;
                        };
                    } {
                        ~modes.chordProgression = false;
                        "Chord mode disabled".postln;
                        // Update the checkbox if it exists
                        if (~modeCheckboxes.notNil && ~modeCheckboxes[\chordProgression].notNil) {
                            { ~modeCheckboxes[\chordProgression].value = false }.defer;
                        };
                    };
                });
            layout.add(enableButton);
        };
        
        // Chord status display
        statusText = StaticText()
            .string_("Current: " ++ (if(~currentChordProgression.notNil, {~currentChordProgression.name}, {"None"})))
            .font_(Font.default.size_(10));
        layout.add(statusText);
        
        // Update function for chord status
        ~updateChordStatusGUI = {
            if (~currentChordProgression.notNil && statusText.notClosed) {
                {
                    statusText.string = "Current: % (% of %)".format(
                        ~currentChordProgression.name,
                        ~currentChordIndex + 1,
                        ~currentChordProgression.chords.size
                    );
                }.defer;
            };
        };
        
        // Chord navigation buttons
        layout.add(HLayout(
            Button()
                .states_([["< Prev Chord"]])
                .action_({
                    if (~modes.chordProgression) {
                        ~previousChord.();
                        ~updateChordStatusGUI.();
                    } {
                        "Enable chord mode first".postln;
                    };
                }),
            Button()
                .states_([["Next Chord >"]])
                .action_({
                    if (~modes.chordProgression) {
                        ~nextChord.();
                        ~updateChordStatusGUI.();
                    } {
                        "Enable chord mode first".postln;
                    };
                })
        ));
        
        layout.add(StaticText()
            .string_("MIDI: Note 23 = Toggle | 26/28 = Next/Prev")
            .font_(Font.default.size_(10)));
        
        // Set layout and show
        win.layout = layout;
        win.onClose = { ~sketchGUIWindow = nil; };
        win.front;
        
        ~sketchGUIWindow = win;
        "✓ Simple Sketch GUI created".postln;
    };
    
    // Create it
    if (~modes.notNil) {
        ~createSketchGUI.();
    } {
        "Dependencies not ready".postln;
    };
};

// Cleanup function  
~closeSketchGUI = {
    if (~sketchGUIWindow.notNil) {
        ~sketchGUIWindow.close;
        ~sketchGUIWindow = nil;
    };
};

"Simple Sketch GUI loaded".postln; 