/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         PARAMETER MONITOR GUI                                 ║
║                    Real-time MIDI/OSC parameter monitoring                    ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         GUI CREATION                                       │
// └─────────────────────────────────────────────────────────────────────────────┘

~createParameterMonitorGUI = { |midiController|
    var win, layout;
    var oscControlSection, statusSection;
    var statusText, updateRoutine, updateDisplay;
    var parameterViews = Dictionary.new;
    var sliderLayout, oscToggleButton, oscEnabled = true;
    
    // Check if window already exists
    if (~parameterMonitorWindow.notNil) {
        try {
            if (~parameterMonitorWindow.isClosed.not) {
                ~parameterMonitorWindow.front;
                ^~parameterMonitorWindow;
            } {
                ~parameterMonitorWindow = nil;
            };
        } {
            ~parameterMonitorWindow = nil;
        };
    };
    
    if (midiController.isNil) {
        "Error: MIDIController instance required".postln;
        ^nil;
    };
    
    if (midiController.oscEnabled.not) {
        "Error: MIDIController must have OSC enabled for Parameter Monitor".postln;
        ^nil;
    };
    
    // Create window
    win = Window("Parameter Monitor", Rect(100, 100, 600, 400));
    layout = VLayout();
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         PARAMETER GRID SECTION                             │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(StaticText()
        .string_("PARAMETER GRID")
        .font_(Font.default.size_(14).bold_(true))
        .align_(\center)
    );
    
    // Sliders section (9 sliders in a row)
    layout.add(StaticText()
        .string_("Sliders")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\left)
    );
    
    // Create slider displays (circular visualization)
    sliderLayout = HLayout();
    9.do { |i|
        var parameterId, parameterView, userView, paramLabel;
        parameterId = "midi_slider_" ++ i;
        parameterView = VLayout();
        
        // Compact label
        paramLabel = StaticText()
            .string_("S" ++ (i+1))
            .font_(Font.default.size_(8))
            .align_(\center)
            .fixedHeight_(12);
        
        // Circular visualization
        userView = UserView()
            .fixedSize_(Size(40, 24))
            .background_(Color.clear);
            
        // Initialize view properties
        userView.setProperty(\normalizedValue, 0);
        userView.setProperty(\displayValue, 0);
        userView.setProperty(\bgColor, Color.blue.alpha_(0.3));
        userView.setProperty(\debugName, "slider_" ++ i);
            
        userView.drawFunc = { |view|
            var bounds, trackRect, fillRect;
            var fillColor, normalizedValue, displayValue;
            var trackWidth, trackHeight, fillHeight;
            
            bounds = view.bounds;
            
            // Get data directly from view's stored properties
            normalizedValue = view.getProperty(\normalizedValue, 0);
            displayValue = view.getProperty(\displayValue, 0);
            fillColor = view.getProperty(\bgColor, Color.gray.alpha_(0.3));
            
            // Slider track dimensions (vertical slider)
            trackWidth = 8;
            trackHeight = 20;
            trackRect = Rect(
                (bounds.width - trackWidth) * 0.5,  // Centered horizontally
                2,                                   // Top margin
                trackWidth,
                trackHeight
            );
            
            // Draw background track
            Pen.fillColor_(Color.gray.alpha_(0.2));
            Pen.fillRect(trackRect);
            Pen.strokeColor_(Color.gray);
            Pen.strokeRect(trackRect);
            
            // Draw filled portion (from bottom up)
            fillHeight = normalizedValue * trackHeight;
            if (fillHeight > 0) {
                fillRect = Rect(
                    trackRect.left,
                    trackRect.top + trackHeight - fillHeight,  // Start from bottom
                    trackWidth,
                    fillHeight
                );
                Pen.fillColor_(fillColor);
                Pen.fillRect(fillRect);
            };
            
            // Draw value text below slider
            Pen.color_(Color.black);
            Pen.font_(Font.default.size_(7));
            Pen.stringCenteredIn(displayValue.asString, 
                Rect(0, 23, bounds.width, 8));
        };
        
        parameterView.add(paramLabel);
        parameterView.add(userView);
        sliderLayout.add(parameterView);
        
        // Store reference
        parameterViews[parameterId] = (
            userView: userView,
            type: \slider,
            index: i,
            normalizedValue: 0,
            displayValue: 0,
            bgColor: Color.blue.alpha_(0.3)
        );
    };
    layout.add(sliderLayout);
    
    // Knobs section (3 rows × 8 knobs)
    layout.add(StaticText()
        .string_("Knobs")
        .font_(Font.default.size_(12).bold_(true))
        .align_(\left)
    );
    
    3.do { |row|
        var rowLayout, parameterId, parameterView, userView, paramLabel;
        rowLayout = HLayout();
        8.do { |pos|
            parameterId = "midi_row" ++ (row+1) ++ "_pos" ++ (pos+1);
            parameterView = VLayout();
            
            // Compact label
            paramLabel = StaticText()
                .string_("R" ++ (row+1) ++ "P" ++ (pos+1))
                .font_(Font.default.size_(7))
                .align_(\center)
                .fixedHeight_(10);
            
            // Circular visualization
            userView = UserView()
                .fixedSize_(Size(40, 24))
                .background_(Color.clear);
                
            // Initialize view properties
            userView.setProperty(\normalizedValue, 0.5);
            userView.setProperty(\displayValue, 64);
            userView.setProperty(\bgColor, Color.blue.alpha_(0.3));
            userView.setProperty(\debugName, "row" ++ (row+1) ++ "_pos" ++ (pos+1));
                
            userView.drawFunc = { |view|
                var bounds, center, radius, startAngle, sweepAngle;
                var fillColor, normalizedValue, displayValue;
                
                bounds = view.bounds;
                center = Point(bounds.width * 0.5, 15);
                radius = 12;
                
                // Get data directly from view's stored properties
                normalizedValue = view.getProperty(\normalizedValue, 0.5);
                displayValue = view.getProperty(\displayValue, 64);
                fillColor = view.getProperty(\bgColor, Color.gray.alpha_(0.3));
                
                // Draw background circle
                Pen.strokeColor_(Color.gray);
                Pen.addArc(center, radius, 0, 2pi);
                Pen.stroke;
                
                // Draw filled pie slice (0 = bottom, clockwise)
                sweepAngle = normalizedValue * 2pi;
                if (sweepAngle > 0) {
                    var startAngle, endAngle, startPoint, endPoint;
                    startAngle = 0.5pi;  // Start at bottom (6 o'clock)
                    endAngle = startAngle + sweepAngle;
                    
                    // Calculate start and end points on circumference
                    startPoint = Point(
                        center.x + ((radius - 1) * cos(startAngle)),
                        center.y + ((radius - 1) * sin(startAngle))
                    );
                    endPoint = Point(
                        center.x + ((radius - 1) * cos(endAngle)),
                        center.y + ((radius - 1) * sin(endAngle))
                    );
                    
                    // Draw proper pie slice
                    Pen.fillColor_(fillColor);
                    Pen.moveTo(center);           // Start at center
                    Pen.lineTo(startPoint);       // Line to arc start
                    Pen.addArc(center, radius - 1, startAngle, sweepAngle);  // Arc
                    Pen.lineTo(center);           // Line back to center
                    Pen.fill;
                };
                
                // Draw value text
                Pen.color_(Color.black);
                Pen.font_(Font.default.size_(7));
                Pen.stringCenteredIn(displayValue.asString, 
                    Rect(bounds.width * 0.5 - 15, 22, 30, 8));
            };
            
            parameterView.add(paramLabel);
            parameterView.add(userView);
            rowLayout.add(parameterView);
            
            // Store reference
            parameterViews[parameterId] = (
                userView: userView,
                type: \knob,
                row: row + 1,
                pos: pos + 1,
                normalizedValue: 0.5,
                displayValue: 64,
                bgColor: Color.blue.alpha_(0.3)
            );
        };
        layout.add(rowLayout);
    };
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         OSC CONTROL SECTION                                │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(View().fixedHeight_(5)); // Separator
    
    // Single OSC toggle button
    oscToggleButton = Button()
        .states_([
            ["OSC: OFF", Color.white, Color.red.alpha_(0.7)],
            ["OSC: ON", Color.white, Color.green.alpha_(0.7)]
        ])
        .value_(1) // Default to ON
        .action_({ |btn|
            oscEnabled = btn.value.asBoolean;
            if (oscEnabled) {
                midiController.generateOSCAddresses();
                statusText.string_("OSC enabled for all parameters");
            } {
                midiController.getParameterIDs().do { |paramId|
                    midiController.disableOSCForParameter(paramId);
                };
                statusText.string_("OSC disabled for all parameters");
            };
        })
        .fixedHeight_(30);
    
    layout.add(oscToggleButton);
    
    // Enable OSC by default on startup
    { midiController.generateOSCAddresses(); }.defer(0.1);
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         STATUS SECTION                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    layout.add(View().fixedHeight_(10)); // Separator
    
    statusText = StaticText()
        .string_("Status: Initializing...")
        .font_(Font.default.size_(10))
        .align_(\center)
        .background_(Color.gray.alpha_(0.1));
    
    layout.add(statusText);
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UPDATE ROUTINE                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    updateDisplay = {
        var totalParams, oscEnabledCount, lastInputSource;
        var value, oscAddress, isOSCEnabled, paramView, displayText, bgColor, statusString;
        
        totalParams = midiController.getParameterIDs().size;
        oscEnabledCount = 0;
        lastInputSource = "none";
        
        // Update parameter values and colors
        midiController.getParameterIDs().do { |parameterId|
            value = midiController.parameterRegistry.getParameterValue(parameterId);
            oscAddress = midiController.getParameterOSCAddress(parameterId);
            isOSCEnabled = oscAddress.notNil;
            paramView = parameterViews[parameterId];
            
            if (isOSCEnabled) { oscEnabledCount = oscEnabledCount + 1; };
            
            
            // Update parameter grid display
            if (paramView.notNil) {
                var displayValue, normalizedValue;
                
                // Both sliders and knobs now use 0-127 range in parameter system
                displayValue = value.round(1);
                
                // Normalized value for visualization (0.0-1.0)
                normalizedValue = value / 127.0;
                
                bgColor = if (oscEnabled) {
                    Color.green.alpha_(0.3)  // OSC enabled
                } {
                    Color.blue.alpha_(0.3)   // MIDI only
                };
                
                { 
                    // Store data in UserView properties, then refresh
                    paramView.userView.setProperty(\normalizedValue, normalizedValue);
                    paramView.userView.setProperty(\displayValue, displayValue);
                    paramView.userView.setProperty(\bgColor, bgColor);
                    paramView.userView.refresh;  // Refresh AFTER setting values
                }.defer;
            };
            
            // OSC status is now handled globally by the toggle button
        };
        
        // Update status text
        statusString = "Status: % parameters, OSC %".format(
            totalParams, if(oscEnabled, "ON", "OFF")
        );
        
        {
            statusText.string_(statusString);
        }.defer;
    };
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         WINDOW SETUP                                       │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    win.layout_(layout);
    
    win.onClose_({
        ~parameterMonitorWindow = nil;
        if (~parameterMonitorUpdateRoutine.notNil) {
            ~parameterMonitorUpdateRoutine.stop;
            ~parameterMonitorUpdateRoutine = nil;
        };
    });
    
    // Start update routine
    ~parameterMonitorUpdateRoutine = Routine({
        loop {
            try {
                updateDisplay.();
            } { |error|
                ("Parameter monitor update error: " ++ error).postln;
            };
            0.1.wait; // Update every 100ms
        }
    }).play(AppClock);
    
    // Initial update
    updateDisplay.();
    
    win.front;
    ~parameterMonitorWindow = win;
    
    win
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         CONVENIENCE FUNCTIONS                              │
// └─────────────────────────────────────────────────────────────────────────────┘

// Close the parameter monitor GUI
~closeParameterMonitorGUI = {
    if (~parameterMonitorWindow.notNil and: { ~parameterMonitorWindow.isClosed.not }) {
        ~parameterMonitorWindow.close;
    };
};

// Refresh the parameter monitor GUI
~refreshParameterMonitorGUI = { |midiController|
    ~closeParameterMonitorGUI.();
    ~createParameterMonitorGUI.(midiController);
};

// Debug function to manually check parameter system state
~debugParameterMonitor = {
    "=== MANUAL DEBUG ===".postln;
    if (~midiController.notNil and: { ~midiController.oscEnabled }) {
        var paramIDs = ~midiController.getParameterIDs();
        "Total parameters: %".format(paramIDs.size).postln;
        
        // Check first slider and knob
        [\slider_0, \row1_pos1].do { |paramKey|
            var parameterId = "midi_" ++ paramKey;
            var value = ~midiController.parameterRegistry.getParameterValue(parameterId);
            var metadata = ~midiController.parameterRegistry.getParameterMetadata(parameterId);
            
            "Parameter %: value=%, type=%, ccNum=%".format(
                parameterId, 
                value ? "nil", 
                metadata.type ? "unknown",
                metadata.ccNum ? "none"
            ).postln;
        };
    } {
        "MIDIController or OSC not available".postln;
    };
    "==================".postln;
};

"Parameter Monitor GUI loaded. Use ~debugParameterMonitor.() to check state.".postln;