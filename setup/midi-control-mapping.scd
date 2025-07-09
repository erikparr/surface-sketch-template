/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          MIDI CONTROL MAPPING                                ║
║                   GUI for Row-to-Group-to-Template Assignment                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

"Loading MIDI Control Mapping system...".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            GLOBAL STATE                                    │
// └─────────────────────────────────────────────────────────────────────────────┘

"Setting up control templates...".postln;

// Control templates based on existing parameter names
~controlTemplates = (
    expressionControl: (
        name: "Expression + Timing Control",
        knobMappings: [
            (pos: 2, param: \noteDuration, range: [0.005, 0.5]),
            (pos: 3, param: \noteRestTime, range: [0.0001, 0.4]),
            (pos: 4, param: \velocity, range: [1, 127]),
            (pos: 5, param: \expressionMin, range: [0, 127]),
            (pos: 6, param: \expressionMax, range: [0, 127]), 
            (pos: 7, param: \expressionDurationScalar, range: [0.1, 1.0])
        ]
    ),
    timingControl: (
        name: "Timing Control", 
        knobMappings: [
            (pos: 2, param: \noteDuration, range: [0.005, 0.5]),
            (pos: 3, param: \noteRestTime, range: [0.0001, 0.4]),
            (pos: 4, param: \velocity, range: [1, 127])
        ]
    )
);

"Control templates defined: %".format(~controlTemplates.keys).postln;

// Row mapping state - Row 1 defaults to current behavior
~rowMappings = (
    1: (enabled: true, vstGroup: nil, template: \expressionControl),  // Default = current behavior
    2: (enabled: false, vstGroup: nil, template: \expressionControl),
    3: (enabled: false, vstGroup: nil, template: \timingControl)
);

"Row mappings initialized: %".format(~rowMappings).postln;

// Group-specific parameter storage
~groupControlParams = Dictionary.new;

"Group control params dictionary created".postln;

// Data file path
~mappingDataPath = {
    var dir = Platform.userHomeDir ++ "/Documents/_Music/sc-projects/intro/first-light/data";
    "Checking mapping data directory: %".format(dir).postln;
    if(File.exists(dir).not) {
        try {
            File.mkdir(dir);
            "Created mapping data directory: %".format(dir).postln;
        } { |error|
            "Failed to create directory: %".format(error).postln;
        };
    } {
        "Mapping data directory exists".postln;
    };
    dir ++ "/midi-control-mappings.scd";
}.value;

"Mapping data path set to: %".format(~mappingDataPath).postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                         PARAMETER MANAGEMENT                               │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining parameter management functions...".postln;

// Helper function to check if ANY enabled row handles a specific parameter
~anyRowHandlesParameter = { |paramName|
    var handled = false;
    
    "Checking if ANY row handles parameter: %".format(paramName).postln;
    
    ~rowMappings.keysValuesDo { |rowNum, mapping|
        if (mapping.enabled && mapping.template.notNil) {
            var template = ~controlTemplates[mapping.template];
            if (template.notNil) {
                var hasParam = template.knobMappings.any { |knobMap|
                    knobMap.param == paramName
                };
                if (hasParam) { 
                    "✓ Row % (template: %) handles %".format(rowNum, mapping.template, paramName).postln;
                    handled = true; 
                };
            };
        };
    };
    
    if (handled.not) {
        "⚠ No enabled row handles parameter: %".format(paramName).postln;
    };
    
    handled;
};

// Get parameter storage for a group (nil = default ~ccControl)
~getGroupParams = { |vstGroup|
    if (vstGroup.isNil) {
        ~ccControl; // Use existing global for default/current behavior
    } {
        if (~groupControlParams[vstGroup].isNil) {
            // Initialize with default values including timing parameters
            ~groupControlParams[vstGroup] = (
                // Expression parameters
                expressionMin: 10,
                expressionMax: 120,
                expressionDurationScalar: 0.5,
                // Timing parameters  
                noteDuration: 0.2,
                noteRestTime: 0.2,
                velocity: 100
            );
            "Initialized parameters for group: %".format(vstGroup).postln;
        };
        ~groupControlParams[vstGroup];
    };
};

"~getGroupParams function defined".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                      ACTIVE ROW DISCONNECTION                              │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining row management functions...".postln;

// Simplified row disconnection function
~disconnectMIDIRow = { |rowNum|
    var mapping = ~rowMappings[rowNum];
    "=== DISCONNECT ROW % CALLED ===".format(rowNum).postln;
    if (mapping.notNil) {
        "Row % mapping found: %".format(rowNum, mapping).postln;
        
        // Disable the row
        mapping.enabled = false;
        "Row % disabled".format(rowNum).postln;
        
        // Clear group-specific parameters if not shared
        if (mapping.vstGroup.notNil) {
            var groupStillUsed = ~rowMappings.values.any { |otherMapping|
                otherMapping.enabled && (otherMapping.vstGroup == mapping.vstGroup)
            };
            if (groupStillUsed.not) {
                ~groupControlParams.removeAt(mapping.vstGroup);
                "Cleared parameters for unused group: %".format(mapping.vstGroup).postln;
            };
        };
        
        // Update MIDIController with new mappings
        ~refreshMIDIControllerMappings.();
        
        "Row % disconnected and cleared. New state: %".format(rowNum, ~rowMappings[rowNum]).postln;
    } {
        "ERROR: Row % mapping is nil!".format(rowNum).postln;
    };
    "=== DISCONNECT ROW % COMPLETE ===".format(rowNum).postln;
};

// Clear all rows function
~clearAllMIDIRows = {
    // Disconnect all rows
    [1, 2, 3].do { |rowNum| 
        var mapping = ~rowMappings[rowNum];
        if(mapping.notNil) {
            mapping.enabled = false;
        };
    };
    
    // Clear all group parameters
    ~groupControlParams.clear;
    
    // Update MIDIController
    ~refreshMIDIControllerMappings.();
    
    "All rows cleared".postln;
};

"Row management functions defined".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                     MIDI CONTROLLER INTEGRATION                            │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining MIDIController integration functions...".postln;

// Group parameter callback for MIDIController
~updateGroupParameterCallback = { |vstGroup, param, value|
    var paramStorage = ~getGroupParams.(vstGroup);
    
    // DEBUG: Log every callback trigger
    "=== PARAMETER UPDATE CALLBACK ===".postln;
    "Group: %, Param: %, Value: %".format(vstGroup ? "Default", param, value).postln;
    "Before update - paramStorage[%]: %".format(param, paramStorage[param]).postln;
    
    // Update the parameter
    paramStorage[param] = value;
    
    // DEBUG: Confirm the update
    "After update - paramStorage[%]: %".format(param, paramStorage[param]).postln;
    
    // Handle validation (e.g., ensure expressionMax > expressionMin)
    if(param == \expressionMax && paramStorage[\expressionMin].notNil) {
        if(value <= paramStorage[\expressionMin]) {
            paramStorage[\expressionMax] = paramStorage[\expressionMin] + 1;
            "Validation: Fixed expressionMax to %".format(paramStorage[\expressionMax]).postln;
        };
    };
    
    if(param == \expressionMin && paramStorage[\expressionMax].notNil) {
        if(paramStorage[\expressionMax] <= value) {
            paramStorage[\expressionMax] = value + 1;
            "Validation: Fixed expressionMax to %".format(paramStorage[\expressionMax]).postln;
        };
    };
    
    // DEBUG: Show current state of all parameters
    "Current ~ccControl state:".postln;
    if(vstGroup.isNil && ~ccControl.notNil) {
        ~ccControl.keysValuesDo { |key, val|
            "  %: %".format(key, val).postln;
        };
    };
    "=== CALLBACK COMPLETE ===".postln;
    "".postln;
};

// Function to refresh MIDIController mappings  
~refreshMIDIControllerMappings = {
    if(~midiController.notNil) {
        "Refreshing MIDIController with updated mappings...".postln;
        ~midiController.setRowMappings(~rowMappings);
        ~midiController.setControlTemplates(~controlTemplates);
        "MIDIController mappings updated".postln;
    } {
        "Cannot refresh mappings: MIDIController not available".warn;
    };
};

// Simplified integration function (replaces the complex override approach)
~initializeMIDIControlMappingIntegration = {
    "Initializing MIDI Control Mapping integration...".postln;
    
    // Set up the parameter callback
    // ~updateGroupParameterCallback.();
    
    // Try to refresh MIDI setup integration if available
    if(~refreshMIDIControlMappingIntegration.notNil) {
        ~refreshMIDIControlMappingIntegration.();
        "MIDI setup integration refreshed".postln;
    } {
        "MIDI setup integration not available yet".postln;
    };
    
    "MIDI Control Mapping integration initialized".postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          STATE PERSISTENCE                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining state persistence functions...".postln;

// Save mappings to file
~saveMIDIControlMappings = {
    var file;
    "Attempting to save MIDI control mappings...".postln;
    file = File(~mappingDataPath, "w");
    if (file.isOpen) {
        file.write("~savedRowMappings = ");
        file.write(~rowMappings.asCompileString);
        file.write(";\n~savedGroupControlParams = ");
        file.write(~groupControlParams.asCompileString);
        file.write(";");
        file.close;
        "MIDI Control mappings saved to %".format(~mappingDataPath).postln;
        ^true;
    } {
        "Failed to save MIDI Control mappings to %".format(~mappingDataPath).warn;
        ^false;
    };
};

// Load mappings from file
~loadMIDIControlMappings = {
    var file, data, loadSuccess = false;
    "Attempting to load MIDI control mappings...".postln;
    "Checking file path: %".format(~mappingDataPath).postln;
    
    try {
        file = File(~mappingDataPath, "r");
        "File object created".postln;
        
        if (file.isOpen) {
            "File is open, reading contents...".postln;
            data = file.readAllString;
            file.close;
            "File closed, attempting to interpret data...".postln;
            
            try {
                data.interpret;
                if (~savedRowMappings.notNil) {
                    ~rowMappings = ~savedRowMappings.copy;
                    "Row mappings loaded".postln;
                };
                if (~savedGroupControlParams.notNil) {
                    ~groupControlParams = ~savedGroupControlParams.copy;
                    "Group control parameters loaded".postln;
                };
                "MIDI Control mappings loaded from %".format(~mappingDataPath).postln;
                loadSuccess = true;
            } { |error|
                "Error loading MIDI Control mappings: %".format(error).warn;
                loadSuccess = false;
            };
        } {
            "MIDI Control mappings file not found at %".format(~mappingDataPath).postln;
            loadSuccess = false;
        };
    } { |error|
        "Error opening MIDI Control mappings file: %".format(error).warn;
        loadSuccess = false;
    };
    
    "Load function returning: %".format(loadSuccess).postln;
    loadSuccess;
};

"State persistence functions defined".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                              GUI CREATION                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining GUI creation function...".postln;

~createMIDIControlMappingGUI = {
    var win, layout, statusText;
    var row1Layout, row2Layout, row3Layout;
    var row1Enable, row1Group, row1Template;
    var row2Enable, row2Group, row2Template;
    var row3Enable, row3Group, row3Template;
    var buttonLayout, applyButton, resetButton, saveButton, loadButton, clearAllButton;
    var groupNames, templateNames;
    var updateMappingStatus; // Local function, not global
    
    "Creating MIDI Control Mapping GUI...".postln;
    
    // Check if GUI has already been created to prevent multiple windows
    if (~midiControlMappingGUICreated == true) {
        "MIDI Control Mapping GUI already exists, skipping creation...".postln;
    } {
        // Check dependencies
        if (~vstManager.isNil) {
            "VST Manager not available. Cannot create MIDI Control Mapping GUI.".warn;
        } {
            if (~midiController.isNil) {
                "MIDI Controller not available. Cannot create MIDI Control Mapping GUI.".warn;
            } {
                "Dependencies available, proceeding with GUI creation...".postln;
                
                // Set flag to prevent multiple creation
                ~midiControlMappingGUICreated = true;
                
                // Create window
                win = Window("MIDI Control Mapping", Rect(200, 200, 500, 400));
                layout = VLayout();
                
                // Title
                layout.add(StaticText().string_("MIDI Control Mapping").font_(Font.default.size_(16)));
                layout.add(StaticText().string_("Assign knob rows to VST groups with control templates").font_(Font.default.size_(10)));
                
                // Get available groups and templates
                groupNames = ["Current/Default"] ++ (~vstManager.getGroupNames().sort ? []);
                templateNames = ["Expression Control", "Timing Control"];
                
                // Status text - declare once
                statusText = StaticText().string_("").maxHeight_(40);
                
                // Function to update status text (local scope)
                updateMappingStatus = {
                    var activeRows = [];
                    
                    ~rowMappings.keysValuesDo { |rowNum, mapping|
                        if (mapping.enabled) {
                            var groupName = mapping.vstGroup ? "Default";
                            var templateName = ~controlTemplates[mapping.template].name;
                            activeRows = activeRows.add("Row %→% (%)".format(rowNum, groupName, templateName));
                        };
                    };
                    
                    {
                        if (activeRows.isEmpty) {
                            statusText.string = "No active mappings";
                        } {
                            statusText.string = "Active: " ++ activeRows.join(", ");
                        };
                    }.defer;
                };
                
                // Row 1 Configuration
                row1Layout = HLayout();
                row1Layout.add(StaticText().string_("Row 1:"));
                row1Enable = CheckBox().value_(~rowMappings[1].enabled);
                row1Layout.add(row1Enable);
                row1Layout.add(StaticText().string_("Group:"));
                row1Group = PopUpMenu().items_(groupNames).value_(0); // Default to "Current/Default"
                row1Layout.add(row1Group, stretch: 1);
                row1Layout.add(StaticText().string_("Template:"));
                row1Template = PopUpMenu().items_(templateNames).value_(0); // Default to Expression Control
                row1Layout.add(row1Template, stretch: 1);
                // Add Remove button for Row 1
                row1Layout.add(Button().states_([["Remove"]])
                    .action_({
                        {
                            ~disconnectMIDIRow.(1);
                            // Update GUI to reflect disconnection
                            row1Enable.value_(false);
                            row1Group.value_(0);
                            row1Template.value_(0);
                            updateMappingStatus.();
                            statusText.string = "Row 1 removed and cleared";
                            "Row 1 removed via GUI".postln;
                        }.defer;
                    }));
                layout.add(row1Layout);
                
                // Row 2 Configuration
                row2Layout = HLayout();
                row2Layout.add(StaticText().string_("Row 2:"));
                row2Enable = CheckBox().value_(~rowMappings[2].enabled);
                row2Layout.add(row2Enable);
                row2Layout.add(StaticText().string_("Group:"));
                row2Group = PopUpMenu().items_(groupNames).value_(0);
                row2Layout.add(row2Group, stretch: 1);
                row2Layout.add(StaticText().string_("Template:"));
                row2Template = PopUpMenu().items_(templateNames).value_(0);
                row2Layout.add(row2Template, stretch: 1);
                // Add Remove button for Row 2
                row2Layout.add(Button().states_([["Remove"]])
                    .action_({
                        {
                            ~disconnectMIDIRow.(2);
                            // Update GUI to reflect disconnection
                            row2Enable.value_(false);
                            row2Group.value_(0);
                            row2Template.value_(0);
                            updateMappingStatus.();
                            statusText.string = "Row 2 removed and cleared";
                            "Row 2 removed via GUI".postln;
                        }.defer;
                    }));
                layout.add(row2Layout);
                
                // Row 3 Configuration
                row3Layout = HLayout();
                row3Layout.add(StaticText().string_("Row 3:"));
                row3Enable = CheckBox().value_(~rowMappings[3].enabled);
                row3Layout.add(row3Enable);
                row3Layout.add(StaticText().string_("Group:"));
                row3Group = PopUpMenu().items_(groupNames).value_(0);
                row3Layout.add(row3Group, stretch: 1);
                row3Layout.add(StaticText().string_("Template:"));
                row3Template = PopUpMenu().items_(templateNames);
                if (templateNames.size > 1) { row3Template.value_(1) } { row3Template.value_(0) }; // Default to Timing Control with bounds check
                row3Layout.add(row3Template, stretch: 1);
                // Add Remove button for Row 3
                row3Layout.add(Button().states_([["Remove"]])
                    .action_({
                        {
                            ~disconnectMIDIRow.(3);
                            // Update GUI to reflect disconnection
                            row3Enable.value_(false);
                            row3Group.value_(0);
                            if (templateNames.size > 1) { row3Template.value_(1) } { row3Template.value_(0) };
                            updateMappingStatus.();
                            statusText.string = "Row 3 removed and cleared";
                            "Row 3 removed via GUI".postln;
                        }.defer;
                    }));
                layout.add(row3Layout);
                
                // Separator
                layout.add(StaticText().string_("").maxHeight_(10));
                
                // Buttons
                buttonLayout = HLayout();
                
                applyButton = Button().states_([["Apply All"]])
                .action_({
                    {
                        // Update mappings from GUI with bounds checking
                        var row1GroupVal, row2GroupVal, row3GroupVal;
                        var row1TemplateVal, row2TemplateVal, row3TemplateVal;
                        
                        // Get UI values with safe type conversion
                        try {
                            row1GroupVal = row1Group.value ? 0;
                            row1GroupVal = row1GroupVal.asInteger;
                            row2GroupVal = row2Group.value ? 0;
                            row2GroupVal = row2GroupVal.asInteger;
                            row3GroupVal = row3Group.value ? 0;
                            row3GroupVal = row3GroupVal.asInteger;
                            row1TemplateVal = row1Template.value ? 0;
                            row1TemplateVal = row1TemplateVal.asInteger;
                            row2TemplateVal = row2Template.value ? 0;
                            row2TemplateVal = row2TemplateVal.asInteger;
                            row3TemplateVal = row3Template.value ? 0;
                            row3TemplateVal = row3TemplateVal.asInteger;
                            
                            // Debug output
                            "Apply All - Values: r1g=%, r2g=%, r3g=%, r1t=%, r2t=%, r3t=%"
                                .format(row1GroupVal, row2GroupVal, row3GroupVal, row1TemplateVal, row2TemplateVal, row3TemplateVal).postln;
                                
                            ~rowMappings[1] = (
                                enabled: row1Enable.value.asBoolean,
                                vstGroup: if ((row1GroupVal == 0) || (row1GroupVal >= groupNames.size)) { nil } { groupNames[row1GroupVal] },
                                template: if (row1TemplateVal < [\expressionControl, \timingControl].size) { 
                                    [\expressionControl, \timingControl][row1TemplateVal] 
                                } { \expressionControl }
                            );
                            
                            ~rowMappings[2] = (
                                enabled: row2Enable.value.asBoolean,
                                vstGroup: if ((row2GroupVal == 0) || (row2GroupVal >= groupNames.size)) { nil } { groupNames[row2GroupVal] },
                                template: if (row2TemplateVal < [\expressionControl, \timingControl].size) { 
                                    [\expressionControl, \timingControl][row2TemplateVal] 
                                } { \expressionControl }
                            );
                            
                            ~rowMappings[3] = (
                                enabled: row3Enable.value.asBoolean,
                                vstGroup: if ((row3GroupVal == 0) || (row3GroupVal >= groupNames.size)) { nil } { groupNames[row3GroupVal] },
                                template: if (row3TemplateVal < [\expressionControl, \timingControl].size) { 
                                    [\expressionControl, \timingControl][row3TemplateVal] 
                                } { \expressionControl }
                            );
                            
                            updateMappingStatus.();
                            
                            // Refresh MIDIController with new mappings
                            ~refreshMIDIControllerMappings.();
                            
                            "MIDI Control mappings applied".postln;
                        } { |error|
                            "Error in Apply All: %".format(error).error;
                        };
                    }.defer;
                });
                buttonLayout.add(applyButton);
                
                resetButton = Button().states_([["Reset All"]])
                .action_({
                    {
                        // Reset to default state
                        ~rowMappings = (
                            1: (enabled: true, vstGroup: nil, template: \expressionControl),
                            2: (enabled: false, vstGroup: nil, template: \expressionControl),
                            3: (enabled: false, vstGroup: nil, template: \timingControl)
                        );
                        ~groupControlParams.clear;
                        
                        // Update GUI
                        row1Enable.value_(true);
                        row1Group.value_(0);
                        row1Template.value_(0);
                        row2Enable.value_(false);
                        row2Group.value_(0);
                        row2Template.value_(0);
                        row3Enable.value_(false);
                        row3Group.value_(0);
                        if (templateNames.size > 1) { row3Template.value_(1) } { row3Template.value_(0) };
                        
                        updateMappingStatus.();
                        
                        // Refresh MIDIController with reset mappings
                        ~refreshMIDIControllerMappings.();
                        
                        "MIDI Control mappings reset to defaults".postln;
                    }.defer;
                });
                buttonLayout.add(resetButton);
                
                // Add Clear All button
                clearAllButton = Button().states_([["Clear All"]])
                .action_({
                    {
                        // Clear all rows
                        ~clearAllMIDIRows.();
                        
                        // Reset GUI to all disabled
                        row1Enable.value_(false); row1Group.value_(0); row1Template.value_(0);
                        row2Enable.value_(false); row2Group.value_(0); row2Template.value_(0);
                        row3Enable.value_(false); row3Group.value_(0); 
                        if (templateNames.size > 1) { row3Template.value_(1) } { row3Template.value_(0) };
                        
                        updateMappingStatus.();
                        statusText.string = "All rows cleared";
                        "All rows cleared via GUI".postln;
                    }.defer;
                });
                buttonLayout.add(clearAllButton);
                
                saveButton = Button().states_([["Save"]])
                .action_({
                    {
                        if (~saveMIDIControlMappings.()) {
                            statusText.string = "Mappings saved successfully";
                            "Mappings saved successfully".postln;
                        } {
                            statusText.string = "Failed to save mappings";
                        };
                    }.defer;
                });
                buttonLayout.add(saveButton);
                
                loadButton = Button().states_([["Load"]])
                .action_({
                    {
                        if (~loadMIDIControlMappings.()) {
                            // Update GUI from loaded state with bounds checking
                            var groupIndex, templateIndex1, templateIndex2, templateIndex3;
                            
                            row1Enable.value_(~rowMappings[1].enabled);
                            
                            if (~rowMappings[1].vstGroup.isNil) { 
                                row1Group.value_(0);
                            } {
                                groupIndex = groupNames.indexOf(~rowMappings[1].vstGroup);
                                row1Group.value_(if (groupIndex.notNil && groupIndex < groupNames.size) { groupIndex } { 0 });
                            };
                            
                            templateIndex1 = [\expressionControl, \timingControl].indexOf(~rowMappings[1].template);
                            row1Template.value_(if (templateIndex1.notNil && templateIndex1 < templateNames.size) { templateIndex1 } { 0 });
                            
                            row2Enable.value_(~rowMappings[2].enabled);
                            
                            if (~rowMappings[2].vstGroup.isNil) { 
                                row2Group.value_(0);
                            } {
                                groupIndex = groupNames.indexOf(~rowMappings[2].vstGroup);
                                row2Group.value_(if (groupIndex.notNil && groupIndex < groupNames.size) { groupIndex } { 0 });
                            };
                            
                            templateIndex2 = [\expressionControl, \timingControl].indexOf(~rowMappings[2].template);
                            row2Template.value_(if (templateIndex2.notNil && templateIndex2 < templateNames.size) { templateIndex2 } { 0 });
                            
                            row3Enable.value_(~rowMappings[3].enabled);
                            
                            if (~rowMappings[3].vstGroup.isNil) { 
                                row3Group.value_(0);
                            } {
                                groupIndex = groupNames.indexOf(~rowMappings[3].vstGroup);
                                row3Group.value_(if (groupIndex.notNil && groupIndex < groupNames.size) { groupIndex } { 0 });
                            };
                            
                            templateIndex3 = [\expressionControl, \timingControl].indexOf(~rowMappings[3].template);
                            row3Template.value_(if (templateIndex3.notNil && templateIndex3 < templateNames.size) { templateIndex3 } { 0 });
                            
                            updateMappingStatus.();
                            
                            // Refresh MIDIController with loaded mappings
                            ~refreshMIDIControllerMappings.();
                            
                            statusText.string = "Mappings loaded successfully";
                            "Mappings loaded and GUI updated".postln;
                        } {
                            statusText.string = "Failed to load mappings";
                        };
                    }.defer;
                });
                buttonLayout.add(loadButton);
                
                layout.add(buttonLayout);
                
                // Separator
                layout.add(StaticText().string_("").maxHeight_(10));
                
                // Status
                layout.add(statusText);
                
                // Template info
                layout.add(StaticText().string_("Expression Control: Knobs 5,6,7 (expressionMin, expressionMax, expressionDurationScalar)").font_(Font.default.size_(9)));
                layout.add(StaticText().string_("Timing Control: Knobs 2,3,4 (noteDuration, noteRestTime, velocity)").font_(Font.default.size_(9)));
                
                // Set layout and show
                win.layout = layout;
                updateMappingStatus.();
                
                // Cleanup on close
                win.onClose = {
                    "MIDI Control Mapping GUI closed".postln;
                };
                
                win.front;
                
                "MIDI Control Mapping GUI created successfully".postln;
            };
        };
    };
};

"~createMIDIControlMappingGUI function defined".postln;

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           AUTO-INITIALIZATION                              │
// └─────────────────────────────────────────────────────────────────────────────┘

"Defining status and initialization functions...".postln;

// Status function for debugging
~showMIDIControlMappingStatus = {
    var groupName, templateName, template, paramStorage, currentValue;
    "=== MIDI Control Mapping Status ===".postln;
    ~rowMappings.keysValuesDo { |rowNum, mapping|
        if (mapping.enabled) {
            groupName = mapping.vstGroup ? "Default";
            templateName = ~controlTemplates[mapping.template].name;
            template = ~controlTemplates[mapping.template];
            paramStorage = ~getGroupParams.(mapping.vstGroup);
            
            "Row %: % → % (%)"
                .format(rowNum, groupName, templateName, if(mapping.enabled, "ACTIVE", "inactive")).postln;
            
            template.knobMappings.do { |knobMap|
                currentValue = paramStorage[knobMap.param];
                "  Knob %: % = %".format(knobMap.pos, knobMap.param, currentValue).postln;
            };
        } {
            "Row %: DISABLED".format(rowNum).postln;
        };
    };
    
    if (~groupControlParams.size > 0) {
        "Group-specific parameters:".postln;
        ~groupControlParams.keysValuesDo { |groupName, params|
            "  %: %".format(groupName, params).postln;
        };
    };
    
    "MIDIController mapping mode: %".format(if(~midiController.notNil, { ~midiController.mappingMode }, { "N/A" })).postln;
    "================================".postln;
};

"~showMIDIControlMappingStatus function defined".postln;

// Try to load saved mappings
"Attempting to load saved mappings...".postln;
~loadMIDIControlMappings.();
"Load attempt completed, continuing initialization...".postln;

// Initialize integration
~initializeMIDIControlMappingIntegration.();

// Initialize with current system state
"MIDI Control Mapping system initialized with unified MIDIController integration".postln;
"Row 1 defaults to current ~ccControl behavior".postln;
"".postln;
"Available functions:".postln;
"• ~createMIDIControlMappingGUI.() - Open the control interface".postln;
"• ~showMIDIControlMappingStatus.() - See current mappings and system status".postln;
"• ~disconnectMIDIRow.(rowNum) - Disconnect specific row programmatically".postln;
"• ~clearAllMIDIRows.() - Clear all rows".postln;
"• ~refreshMIDIControllerMappings.() - Refresh MIDIController configuration".postln;
"".postln;
"GUI Features:".postln;
"• Remove buttons - Disconnect individual rows instantly".postln;
"• Clear All button - Clear all mappings".postln;
"• Status display - Shows active mappings".postln;

"MIDI Control Mapping setup complete!".postln;

// Define function to create GUI when MIDI Controller is ready
~createMIDIControlMappingGUIWhenReady = {
    if (~midiController.notNil) {
        "MIDIController is ready, creating MIDI Control Mapping GUI...".postln;
        AppClock.sched(0, {
            ~createMIDIControlMappingGUI.();
        });
    } {
        "MIDIController not ready yet, scheduling retry...".postln;
        AppClock.sched(1.0, {
            ~createMIDIControlMappingGUIWhenReady.();
        });
    };
};

"Use ~createMIDIControlMappingGUIWhenReady.() to create GUI when MIDIController is ready".postln; 