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
        var win, layout, startButton, stopButton;
        
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
            ~modes.keysValuesDo { |key, value|
                var checkbox = CheckBox()
                    .string_(key.asString)
                    .value_(value)
                    .action_({ |cb|
                        ~modes[key] = cb.value;
                        "Mode % set to %".format(key, cb.value).postln;
                    });
                layout.add(checkbox);
            };
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