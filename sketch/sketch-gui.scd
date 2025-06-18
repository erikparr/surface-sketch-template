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