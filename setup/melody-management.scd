// Melody Management GUI
// Provides interface to manage sketch melodies with active/inactive toggles
// Uses JSON format for reliable data persistence

// Capture the setup directory path at file load time
~melodyMgmtDir = thisProcess.nowExecutingPath.dirname;

// Global variables for melody management
~melodyData = nil;
~melodyManagerWin = nil;
~updateMelodyManagerUI = nil;

// Function to load melody data from JSON file or create default
~loadMelodyData = {
    var melodyDataPath, loadedData;
    melodyDataPath = ~melodyMgmtDir +/+ "../data/melody-data.json";
    
    if (File.exists(melodyDataPath)) {
        "Loading melody data from: %".format(melodyDataPath).postln;
        try {
            loadedData = JSONlib.parseFile(melodyDataPath, useEvent: true);
            ~melodyData = loadedData;
            "Successfully loaded melody data".postln;
        } { |error|
            "Error loading JSON file: %".format(error).postln;
            "Falling back to conversion from sketch-melody.scd".postln;
            ~convertSketchMelodyToNewFormat.();
        };
    } {
        "Melody data file not found, checking for sketch-melody.scd to convert...".postln;
        ~convertSketchMelodyToNewFormat.();
    };
};

// Function to save melody data to JSON file
~saveMelodyData = {
    var melodyDataPath, file, jsonString;
    melodyDataPath = ~melodyMgmtDir +/+ "../data/melody-data.json";
    
    if (~melodyData.notNil) {
        try {
            jsonString = JSONlib.convertToJSON(~melodyData);
            file = File(melodyDataPath, "w");
            file.write(jsonString);
            file.close;
            "Melody data saved to: %".format(melodyDataPath).postln;
        } { |error|
            "Error saving melody data: %".format(error).postln;
        };
    } {
        "No melody data to save".postln;
    };
};

// Function to convert sketch-melody.scd to new JSON format
~convertSketchMelodyToNewFormat = {
    var sketchMelodyPath, convertedMelodies, sequenceNumber;
    sketchMelodyPath = ~melodyMgmtDir +/+ "../data/sketch-melody.scd";
    
    if (File.exists(sketchMelodyPath)) {
        "Converting sketch-melody.scd to new JSON format...".postln;
        sketchMelodyPath.load; // This populates ~melodyDict
        
        convertedMelodies = [];
        sequenceNumber = 1;
        
        ~melodyDict.keysValuesDo { |key, melody|
            var pattern = if (melody.patterns.notNil and: { melody.patterns.size > 0 }) {
                melody.patterns[0]; // Get first pattern and flatten
            } {
                [60]; // Default pattern if none found
            };
            
            var velocityFirst = 1.0;
            var velocityLast = 1.0;
            
            // Extract velocity multipliers safely
            if (melody.velocityMultipliers.notNil) {
                if (melody.velocityMultipliers.isKindOf(Event)) {
                    velocityFirst = melody.velocityMultipliers[\first] ? 1.0;
                    velocityLast = melody.velocityMultipliers[\last] ? 1.0;
                };
            };
            
            convertedMelodies = convertedMelodies.add((
                key: "seq-" ++ sequenceNumber,
                name: "seq-" ++ sequenceNumber,
                pattern: pattern,
                velocityFirst: velocityFirst,
                velocityLast: velocityLast,
                loopCount: melody.loopCount ? 1,
                active: true
            ));
            sequenceNumber = sequenceNumber + 1;
        };
        
        ~melodyData = (
            settings: (
                defaultNamePrefix: "seq",
                nextSequenceNumber: sequenceNumber,
                windowSize: [600, 400],
                selectedMelodyIndex: 0
            ),
            melodies: convertedMelodies
        );
        
        ~saveMelodyData.(); // Save converted data
        "Converted % melodies from sketch-melody.scd".format(convertedMelodies.size).postln;
    } {
        "sketch-melody.scd not found, creating empty melody data".postln;
        ~melodyData = (
            settings: (
                defaultNamePrefix: "seq",
                nextSequenceNumber: 1,
                windowSize: [600, 400],
                selectedMelodyIndex: 0
            ),
            melodies: []
        );
        ~saveMelodyData.();
    };
};

// Function to load active melodies into ~melodyDict for sketch system
~loadActiveMelodies = {
    var activeMelodies, activeMelodyKeys;
    
    if (~melodyData.isNil) {
        "No melody data available. Loading first...".postln;
        ~loadMelodyData.();
    };
    
    activeMelodies = ~melodyData[\melodies].select({ |melody| melody[\active] == true });
    activeMelodyKeys = activeMelodies.collect({ |melody| melody[\key].asSymbol });
    
    // Load melodies into ~melodyDict (for sketch system compatibility)
    ~melodyDict = Dictionary.new;
    activeMelodies.do { |melody|
        ~melodyDict.put(melody[\key].asSymbol, (
            name: melody[\name],
            patterns: [melody[\pattern]], // Wrap back to array for compatibility
            velocityMultipliers: (
                first: melody[\velocityFirst],
                last: melody[\velocityLast]
            ),
            loopCount: melody[\loopCount]
        ));
    };
    
    // Set up the melody sequence for direct navigation
    ~currentSequence = activeMelodyKeys;
    
    // Initialize navigation index if not set
    if (~currentLoopIndex.isNil) {
        ~currentLoopIndex = 0;
    };
    
    // Ensure index is within bounds
    ~currentLoopIndex = ~currentLoopIndex.clip(0, activeMelodyKeys.size - 1);
    
    "Loaded % active melodies into ~melodyDict".format(activeMelodies.size).postln;
    "Updated ~currentSequence with active melody keys: %".format(activeMelodyKeys).postln;
    "Current melody index: % (melody: %)".format(~currentLoopIndex, activeMelodyKeys[~currentLoopIndex]).postln;
    
    ^activeMelodies.size;
};

// Function to generate next melody name
~generateMelodyName = { |prefix, number|
    prefix ++ "-" ++ number;
};

// Function to get next melody key
~getNextMelodyKey = {
    var settings = ~melodyData[\settings];
    var key = ~generateMelodyName.(settings[\defaultNamePrefix], settings[\nextSequenceNumber]);
    settings[\nextSequenceNumber] = settings[\nextSequenceNumber] + 1;
    key;
};

// Main function to create the Melody Manager UI
~createMelodyManagerUI = {
    var win, layout, melodyList, editPanel;
    var prefixField, loadButton, saveButton, addButton, deleteButton;
    var nameField, patternField, firstVelField, lastVelField, loopCountField, activeCheckbox;
    var updateButton, updateMelodyList, updateEditPanel, selectedMelodyIndex, statusText;
    var topLayout, mainLayout, leftLayout, rightLayout, listButtonLayout;

    // Check if melody data is loaded
    if (~melodyData.isNil) {
        "Loading melody data...".postln;
        ~loadMelodyData.();
    };

    // Create the window
    win = Window("Melody Manager", Rect(100, 100, 700, 500));
    layout = VLayout();

    // Top controls
    topLayout = HLayout();
    topLayout.add(StaticText().string_("Prefix:"));
    prefixField = TextField()
        .string_(~melodyData[\settings][\defaultNamePrefix])
        .fixedWidth_(60)
        .action_({ |field|
            ~melodyData[\settings][\defaultNamePrefix] = field.string;
        });
    topLayout.add(prefixField);
    topLayout.add(nil, stretch: 1); // Spacer
    
    loadButton = Button()
        .states_([["Load Melodies"]])
        .action_({
            var count = ~loadActiveMelodies.();
            statusText.string = "Loaded % active melodies into ~melodyDict".format(count);
        });
    topLayout.add(loadButton);
    
    saveButton = Button()
        .states_([["Save"]])
        .action_({
            ~saveMelodyData.();
            statusText.string = "Melody data saved";
        });
    topLayout.add(saveButton);
    
    layout.add(topLayout);

    // Main content area
    mainLayout = HLayout();
    
    // Left side - Melody List
    leftLayout = VLayout();
    leftLayout.add(StaticText().string_("Melody List"));
    
    melodyList = ListView()
        .selectionMode_(\single);
    leftLayout.add(melodyList, stretch: 1);
    
    // Bottom buttons for melody list
    listButtonLayout = HLayout();
    addButton = Button()
        .states_([["Add New"]])
        .action_({
            var newKey = ~getNextMelodyKey.();
            var newMelody = (
                key: newKey,
                name: newKey,
                pattern: [60, 62, 64],
                velocityFirst: 1.0,
                velocityLast: 1.0,
                loopCount: 1,
                active: true
            );
            ~melodyData[\melodies] = ~melodyData[\melodies].add(newMelody);
            updateMelodyList.();
            statusText.string = "Added new melody: %".format(newKey);
        });
    
    deleteButton = Button()
        .states_([["Delete Selected"]])
        .action_({
            var selectedIndex = melodyList.value;
            if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
                var deletedKey = ~melodyData[\melodies][selectedIndex][\key];
                ~melodyData[\melodies].removeAt(selectedIndex);
                updateMelodyList.();
                statusText.string = "Deleted melody: %".format(deletedKey);
            };
        });
    
    listButtonLayout.add(addButton);
    listButtonLayout.add(deleteButton);
    leftLayout.add(listButtonLayout);
    
    mainLayout.add(leftLayout, stretch: 1);
    
    // Right side - Edit Panel (COMPLETE FORM)
    rightLayout = VLayout();
    rightLayout.add(StaticText().string_("Edit Selected Melody"));
    
    // Create all form fields
    nameField = TextField().string_("TEST TEXT FIELD");
    patternField = TextField().string_("");
    firstVelField = NumberBox().value_(1.0).decimals_(2);
    lastVelField = NumberBox().value_(1.0).decimals_(2);
    loopCountField = NumberBox().value_(1).decimals_(0);
    activeCheckbox = CheckBox().value_(true);
    
    // Add all fields to layout
    rightLayout.add(HLayout([
        StaticText().string_("Key:").fixedWidth_(80),
        StaticText().string_("(readonly)").background_(Color.gray(0.9))
    ]));
    
    rightLayout.add(StaticText().string_("Name:"));
    rightLayout.add(nameField);
    
    rightLayout.add(StaticText().string_("Pattern:"));
    rightLayout.add(patternField);
    
    rightLayout.add(StaticText().string_("First Vel:"));
    rightLayout.add(firstVelField);
    
    rightLayout.add(StaticText().string_("Last Vel:"));
    rightLayout.add(lastVelField);
    
    rightLayout.add(StaticText().string_("Loop Count:"));
    rightLayout.add(loopCountField);
    
    rightLayout.add(StaticText().string_("Active:"));
    rightLayout.add(activeCheckbox);
    
    // Update button
    updateButton = Button()
        .states_([["Update Melody"]])
        .action_({
            var selectedIndex = melodyList.value;
            if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
                var melody = ~melodyData[\melodies][selectedIndex];
                var patternString = patternField.string;
                var patternArray;
                
                // Parse pattern string to array
                try {
                    patternArray = patternString.interpret;
                    if (patternArray.isArray.not) {
                        patternArray = [patternArray];
                    };
                } {
                    "Invalid pattern format, keeping original".postln;
                    patternArray = melody[\pattern];
                };
                
                melody[\name] = nameField.string;
                melody[\pattern] = patternArray;
                melody[\velocityFirst] = firstVelField.value;
                melody[\velocityLast] = lastVelField.value;
                melody[\loopCount] = loopCountField.value.asInteger;
                melody[\active] = activeCheckbox.value;
                
                updateMelodyList.();
                statusText.string = "Updated melody: %".format(melody[\key]);
            };
        });
    rightLayout.add(updateButton);
    
    mainLayout.add(rightLayout, stretch: 1);
    layout.add(mainLayout, stretch: 1);

    // Status text - create AFTER other widgets
    statusText = StaticText()
        .string_("Ready. Use checkboxes to toggle active/inactive status");
    layout.add(statusText);

    // Update functions
    updateMelodyList = {
        var items = ~melodyData[\melodies].collect { |melody, i|
            var checkbox = if (melody[\active]) { "☑" } { "☐" };
            "% % (%)".format(checkbox, melody[\key], melody[\name]);
        };
        
        "updateMelodyList called, melody count: %".format(~melodyData[\melodies].size).postln;
        "First melody example: %".format(~melodyData[\melodies][0]).postln;
        
        {
            melodyList.items = items;
            if (~melodyData[\melodies].size > 0 and: { melodyList.value.isNil }) {
                melodyList.value = 0;
                updateEditPanel.();
            };
        }.defer;
    };
    
    updateEditPanel = {
        var selectedIndex, melody;
        
        if (~melodyData.isNil or: { ~melodyData[\melodies].isNil }) {
            "ERROR: melodyData is nil in updateEditPanel".postln;
            ^nil;
        };
        
        selectedIndex = melodyList.value;
        "updateEditPanel called with selectedIndex: %".format(selectedIndex).postln;
        
        if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
            melody = ~melodyData[\melodies][selectedIndex];
            "Selected melody: %".format(melody).postln;
            
            {
                // Update all fields
                "Updating name field to: %".format(melody[\name]).postln;
                nameField.string_(melody[\name].asString);
                
                "Updating pattern field to: %".format(melody[\pattern]).postln;
                patternField.string_(melody[\pattern].asCompileString);
                
                "Updating velocity fields: first=%, last=%".format(melody[\velocityFirst], melody[\velocityLast]).postln;
                firstVelField.value_(melody[\velocityFirst]);
                lastVelField.value_(melody[\velocityLast]);
                
                "Updating loop count: %".format(melody[\loopCount]).postln;
                loopCountField.value_(melody[\loopCount]);
                
                "Updating active checkbox: %".format(melody[\active]).postln;
                activeCheckbox.value_(melody[\active]);
                
                "Field updates completed".postln;
            }.defer;
        } {
            "No valid selection or index out of range".postln;
            "melodyData size: %, selectedIndex: %".format(
                if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) { ~melodyData[\melodies].size } { "nil or invalid" },
                selectedIndex
            ).postln;
        };
    };
    
    // List selection action
    melodyList.action = { |list|
        updateEditPanel.();
    };
    
    // List mouse action for checkbox toggling
    melodyList.mouseDownAction = { |list, x, y, modifiers, buttonNumber, clickCount|
        var selectedIndex = list.value;
        if (selectedIndex.notNil and: { selectedIndex < ~melodyData[\melodies].size }) {
            // Check if click is in checkbox area (first ~15 pixels)
            if (x < 15) {
                ~melodyData[\melodies][selectedIndex][\active] = ~melodyData[\melodies][selectedIndex][\active].not;
                updateMelodyList.();
                updateEditPanel.();
                statusText.string = "Toggled % to %".format(
                    ~melodyData[\melodies][selectedIndex][\key],
                    if (~melodyData[\melodies][selectedIndex][\active]) { "active" } { "inactive" }
                );
            };
        };
    };

    // Store update function globally
    ~updateMelodyManagerUI = {
        updateMelodyList.();
    };

    // Set the layout and show
    win.layout = layout;
    updateMelodyList.();
    
    // Cleanup on close
    win.onClose = {
        ~melodyManagerWin = nil;
    };
    
    // Store window reference
    ~melodyManagerWin = win;
    
    win.front;
    ^win;
};

// Initialize GUI after setup completes - with delay to avoid setup conflicts
AppClock.sched(1.0, {
    if (~melodyManagerWin.isNil) {
        ~createMelodyManagerUI.();
    };
    nil; // Don't reschedule
});

// Note: To create the melody manager UI, call ~createMelodyManagerUI.(); 