// VST Management GUI
// Provides a simple interface to load VST instruments from a predefined list

// Global variables for manual velocity control
~manualVelocityCCModeEnabled = false;
~manualVelocityMIDIFunc = nil;

// Global variable to store the update function
~updateVSTManagerUI = nil;
~refreshVSTManagerGroupsUI = nil; // For refreshing the group selector menu

// Function to update all VST manager UIs
~updateAllVSTManagers = {
    "Updating all VST manager UIs...".postln;
    if (~updateVSTManagerUI.notNil) {
        ~updateVSTManagerUI.();
    } {
        "Warning: No VST manager UI update function registered".warn;
    };
};

// Function to refresh the VST manager UI
~refreshVSTManager = {
    if (~vstManager.notNil) {
        "Refreshing VST manager UI...".postln;
        ~updateAllVSTManagers.();
    } {
        "VST Manager not initialized".warn;
    };
};

// Main function to create the VST Manager UI
~createVSTManagerUI = {
    var vstListPath, vstList, win, layout, instances, pathForCallback, synth;
    var statusText, instanceNameField, vstListBox, buttonLayout, loadButton, removeButton;
    var instancesList, updateVSTInstancesList;
    var localInstances, localStatusText, instanceNames, instanceInfo, index, name, inst, vstName;
    var groupSelectorMenu, assignKeyboardButton, keyboardGroupHLayout, groupMenuItems, refreshGroupsButton; // <-- New UI variables
    var expressionKnobToggle, midiControlOverridesLayout, expressionKnobMIDIFunc; // <-- For Expression Knob toggle and its MIDIFunc
    var manualVelocityToggle; // <-- For Manual Velocity toggle
    var multiInstrumentToggle; // <-- For Multi-Instrument Mode toggle
    var groupMgmtLayout, addToGroupLayout, addToGroupButton, existingGroupMenu;
    var createGroupLayout, newGroupNameField, createNewGroupButton;

    // Check if VSTManager is available
    if (~vstManager.isNil) {
        "VSTManager not found. Please initialize it first.".postln;
        ^nil;
    };

    // Read VST list from file - using hardcoded path to avoid path resolution issues
    vstListPath = "/Users/erikparr/surfacing/surfacing/data/vst-list.txt";
    vstList = if (File.exists(vstListPath)) {
        File.use(vstListPath, "r", { |f| f.readAllString.split($\n).reject(_.isEmpty) });
    } {
        "WARNING: Could not find vst-list.txt at: %".format(vstListPath).postln;
        [];
    };

    if (vstList.isEmpty) {
        "No VSTs found in the list.".postln;
        ^nil;
    };

    // Create the window and UI elements
    win = Window("VST Manager", Rect(100, 100, 400, 500));
    layout = VLayout();
    instances = [];

    // Status text
    statusText = StaticText()
        .string_("Select a VST to load")
        .maxHeight_(40);
    layout.add(statusText);

    // VST Selection
    layout.add(StaticText().string_("Select VST:"));
    vstListBox = ListView()
        .items_(vstList.collect { |path| path.basename })
        .selectionMode_(\single);

    // Update status when VST is selected
    vstListBox.action = { |v|
        var path = vstList[v.value];
        statusText.string = "Selected: %".format(path.basename);
    };

    // Initial selection
    if (vstList.notEmpty) {
        vstListBox.value = 0;
        // Trigger the action to update the instance name
        vstListBox.doAction;
    };

    layout.add(vstListBox, stretch: 1);

    // Buttons
    buttonLayout = HLayout();

    loadButton = Button()
        .states_([["Load VST"]])
        .action_({ |btn|
            var index = vstListBox.value;
            var existingInstances, outputBus, synthVar;
            var numOutputChannels = 6;
            existingInstances = ~vstManager.vstInstances.size;
            if (index.notNil) {
                var vstPath = vstList[index];
                var baseName = vstPath.basename.splitext[0]; // Remove extension
                var counter = existingInstances;
                var instanceName = baseName;
                // Make sure the name is unique
                    instanceName = baseName ++ " 0" ++ counter; // Use space instead of underscore for cleaner look
                    counter = counter + 1;

                "Auto-generated instance name: %".format(instanceName).postln;

                statusText.string = "Loading %...".format(vstPath.basename);

                // Store vstPath in a variable for the callback
                pathForCallback = vstPath;

                // Create a new synth with the vstHost SynthDef
                // Dynamically assign output bus based on existing instances
                "existingInstances: %".format(existingInstances).postln;
                 outputBus = 2 + ((existingInstances * 2)%numOutputChannels);  // Start at bus 2, increment by 2 for each new instance, wrap around to 0 after 8
                "outputBus: %".format(outputBus).postln;
                synthVar = ("synth_" ++ instanceName).asSymbol;  // Create unique synth variable name

                // Create synth and store in unique global variable
                currentEnvironment.put(synthVar, Synth(\vstHost, [
                    \bus, 0,    // Input bus (not used in this setup)
                    \out, outputBus     // Dynamic output bus assignment (2, 4, 6, 8, etc.)
                ]));

                "Creating synth % with output bus % (ADAT %/%)".format(
                    synthVar,
                    outputBus,
                    outputBus + 1,
                    outputBus + 2
                ).postln;

                // Add VST instance with editor enabled
                ~vstManager.addVST(
                    instanceName,
                    currentEnvironment.at(synthVar),  // Reference the unique synth variable
                    vstPath,
                    true,   // Enable editor
                    nil,    // no group by default
                    { |controller|
                        var path = pathForCallback;  // Local copy for the closure
                        {
                            statusText.string = "Loaded: %".format(path.basename);
                            updateVSTInstancesList.(instancesList);

                            // // Update MIDI controller with current VST instances
                            // if (~updateMIDIController.notNil) {
                            //     ~updateMIDIController.();
                            // } {
                            //     "WARNING: MIDI controller update function not found".postln;
                            // };

                            // Verify the plugin is open before showing editor
                            if (controller.isOpen) {
                                // Open the editor after a short delay
                                {
                                    controller.editor;
                                }.defer(0.5);
                            } {
                                "Failed to open VST editor: Plugin not properly loaded".postln;
                                statusText.string = "Error: Failed to load VST";
                            };
                        }.defer;
                    }
                );

                // Fallback check to ensure editor opens
                {
                    var inst = ~vstManager.vstInstances[instanceName];
                    if (inst.notNil && inst.controller.notNil && { inst.controller.isOpen }) {
                        if (inst.controller.editor.isNil) {
                            "Opening VST editor (fallback)...".postln;
                            inst.controller.editor;
                        };
                    } {
                        "VST failed to load properly".postln;
                        statusText.string = "Error: VST failed to load";
                    };
                }.defer(1.0);
            };
        });

    removeButton = Button()
        .states_([["Remove Selected"]])
        .action_({ |btn|
            var selectedIndex = instancesList.value;
            if (selectedIndex.notNil && instances.notNil && (selectedIndex < instances.size)) {
                var instanceName = instances[selectedIndex];
                if (instanceName.notNil && ~vstManager.vstInstances[instanceName].notNil) {
                    if (~vstManager.removeVST(instanceName)) {
                        statusText.string = "Removed: %".format(instanceName);
                        updateVSTInstancesList.(instancesList);

                        // Update MIDI controller with current VST instances
                        if (~updateMIDIController.notNil) {
                            ~updateMIDIController.();
                        } {
                            "WARNING: MIDI controller update function not found".postln;
                        };
                    } {
                        "Instance not found: %".format(instanceName).postln;
                        updateVSTInstancesList.(instancesList); // Refresh the list
                    };
                } {
                    "Instance not found in VST manager: %".format(instanceName).postln;
                    updateVSTInstancesList.(instancesList); // Refresh the list
                };
            };
        });

    buttonLayout.add(loadButton, stretch: 1);
    buttonLayout.add(removeButton, stretch: 1);
    layout.add(buttonLayout);

    // Current Instances
    layout.add(StaticText().string_("Loaded VSTs:"));
    instancesList = ListView()
        .selectionMode_(\single);
    layout.add(instancesList, stretch: 1);

    // --- Group Management Section ---
    layout.add(StaticText().string_("Group Management:"));
    groupMgmtLayout = VLayout();

    // Row 1: Add to existing group
    addToGroupLayout = HLayout();
    addToGroupLayout.add(StaticText().string_("Add to Group:"));
    existingGroupMenu = PopUpMenu().items_(["Select Group..."] ++ (~vstManager.getGroupNames().sort ? []));
    addToGroupLayout.add(existingGroupMenu, stretch: 1);
    addToGroupButton = Button().states_([["Add"]]);
    addToGroupLayout.add(addToGroupButton);
    groupMgmtLayout.add(addToGroupLayout);

    // Row 2: Create new group
    createGroupLayout = HLayout();
    createGroupLayout.add(StaticText().string_("New Group:"));
    newGroupNameField = TextField().string_("");
    createGroupLayout.add(newGroupNameField, stretch: 1);
    createNewGroupButton = Button().states_([["Create Group"]]);
    createGroupLayout.add(createNewGroupButton);
    groupMgmtLayout.add(createGroupLayout);

    layout.add(groupMgmtLayout);
    // --- End Group Management Section ---

    // --- Keyboard Group Assignment UI ---
    keyboardGroupHLayout = HLayout();
    layout.add(keyboardGroupHLayout);

    // Group Selector PopUpMenu
    groupSelectorMenu = PopUpMenu();
    // Populate group selector items
    groupMenuItems = ["All"] ++ (~vstManager.getGroupNames().sort ? []); // Ensure getGroupNames returns an array or handle nil
    groupSelectorMenu.items = groupMenuItems;
    if(groupMenuItems.notEmpty) { groupSelectorMenu.value = 0 }; // Default to "All"

    keyboardGroupHLayout.add(StaticText().string_("KB Group:"));
    keyboardGroupHLayout.add(groupSelectorMenu, stretch:1);

    // Assign Keyboard Button
    assignKeyboardButton = Button().states_([["Assign KB"]])
    .action_({ |btn|
        var selectedIndex, selectedItemName, targetGroupName;
        selectedIndex = groupSelectorMenu.value;
        if(selectedIndex.notNil) {
            selectedItemName = groupMenuItems[selectedIndex];
            if(selectedItemName == "All") {
                targetGroupName = nil; // VSTManager uses nil for 'all' or 'no specific group'
                statusText.string = "Keyboard assigned to: All VSTs";
            } {
                targetGroupName = selectedItemName;
                statusText.string = "Keyboard assigned to group: %".format(targetGroupName);
            };

            // Set the active group in VSTManager
            ~vstManager.setActiveGroup(targetGroupName);

            // Update the MIDIController to target this group
            if(~updateMIDIController.notNil) {
                ~updateMIDIController.value();
            } {
                "ERROR: ~updateMIDIController function not found. Cannot assign keyboard.".error;
                statusText.string = "Error: ~updateMIDIController missing.";
            };
        } {
            statusText.string = "No group selected for keyboard assignment.";
        };
    });
    keyboardGroupHLayout.add(assignKeyboardButton);

    refreshGroupsButton = Button().states_([["Refresh Groups"]])
    .action_({
        if(~refreshVSTManagerGroupsUI.notNil) { ~refreshVSTManagerGroupsUI.value() };
        statusText.string = "Group list refreshed.";
    });
    keyboardGroupHLayout.add(refreshGroupsButton);
    layout.add(keyboardGroupHLayout); // Add the keyboard group layout to the main layout
    // --- End Keyboard Group Assignment UI ---

    // --- MIDI Control Overrides UI ---
    midiControlOverridesLayout = HLayout();
    expressionKnobToggle = CheckBox()
        .string_("Expression Knob (CC16)") // Set the label for the CheckBox
        .value_(0) // Default to unchecked
        .action_({ |checkbox|
            var isChecked, statusMsg, selectedGroupIndex, currentTargetGroupName, vstsToControl;

            "--- Expression Knob Toggle Action ---".postln;
            isChecked = checkbox.value;
            "Checkbox value: %, isChecked: %".format(checkbox.value, isChecked).postln;

            if(expressionKnobMIDIFunc.notNil) { // Check if it's not nil before freeing
                expressionKnobMIDIFunc.free;
            };
            expressionKnobMIDIFunc = nil;

            // Determine the target group based on the UI selector
            selectedGroupIndex = groupSelectorMenu.value;
            if(selectedGroupIndex.notNil and: {groupMenuItems.notNil and: {selectedGroupIndex < groupMenuItems.size}}) {
                currentTargetGroupName = groupMenuItems[selectedGroupIndex];
                if(currentTargetGroupName == "All") { currentTargetGroupName = nil };
            } {
                currentTargetGroupName = nil; // Default to all if somehow no selection
            };

            if(isChecked) {
                expressionKnobMIDIFunc = MIDIFunc.cc({ |val, num, chan, src|
                    // Send to all VST instances, using the method confirmed by VSTManager.sc to get actual controllers.
                    var vstsToTarget = ~vstManager.getTargetInstances(nil).values; // Get all VSTPluginController objects
                    var activeGroupName = ~vstManager.activeGroup; // Still get for debug post, though targeting is 'all'

                    if(vstsToTarget.notNil) {
                        vstsToTarget.do { |vst|
                            // Minimal check: if vst object is not nil, attempt to send MIDI.
                            if(vst.notNil) {
                                vst.midi.control(chan, 16, val); // Send CC 16
                            }
                            // Further error handling or warnings removed for simplicity as per user request.
                        };
                    };
                    if(~midiController.debug) { ("Expression Knob (CC16 via dedicated MIDIFunc): val % to VSTs in group '%' (Chan: %, Src: %)").format(val, activeGroupName ? "All", chan, src).postln; };
                }, 16); // Specifically listen for CC 16

                statusMsg = "Expression Knob (CC16) ACTIVE for group: %".format(currentTargetGroupName ? "All");
                (statusMsg + " (Dedicated MIDIFunc created)").postln;
            } {
                statusMsg = "Expression Knob (CC16) INACTIVE";
                (statusMsg + " (Dedicated MIDIFunc freed)").postln;
            };
            statusText.string = statusMsg;
        });
    midiControlOverridesLayout.add(expressionKnobToggle);

    // Manual Velocity Toggle (CC17)
    manualVelocityToggle = CheckBox()
        .string_("Manual Velocity (CC17)")
        .value_(~manualVelocityCCModeEnabled.asInteger) // Reflect current state
        .action_({ |checkbox|
            ~manualVelocityCCModeEnabled = checkbox.value.asBoolean;
            if(~midiController.notNil) {
                ~midiController.setManualVelocityMode(~manualVelocityCCModeEnabled);
                if(~manualVelocityCCModeEnabled) {
                    // Free existing func if any, to prevent duplicates
                    if(~manualVelocityMIDIFunc.notNil) { ~manualVelocityMIDIFunc.free; };
                    ~manualVelocityMIDIFunc = MIDIFunc.cc({
                        |val, num, chan, src|
                        // Assuming ~midiController is accessible
                        ~midiController.setManualVelocity(val);
                    }, 17); // CC 17 for manual velocity value
                    "Manual Velocity Mode ON (CC 17 controls velocity)".postln;
                } {
                    if(~manualVelocityMIDIFunc.notNil) {
                        ~manualVelocityMIDIFunc.free;
                        ~manualVelocityMIDIFunc = nil;
                    };
                    "Manual Velocity Mode OFF (MIDI input velocity used)".postln;
                };
            } {
                "MIDIController not available for manual velocity setup.".warn;
            };
        });
    midiControlOverridesLayout.add(manualVelocityToggle);

    // Multi-Instrument Mode Toggle
    multiInstrumentToggle = CheckBox()
        .string_("Multi-Instrument Mode")
        .value_(0) // Default to unchecked
        .action_({ |checkbox|
            var isEnabled = checkbox.value.asBoolean;
            
            if(~midiController.notNil) {
                if(isEnabled) {
                    ~midiController.setMultiChannelMode(true);
                    ~midiController.setMultiInstrumentMode(true);
                    statusText.string = "Multi-Instrument Mode ON";
                } {
                    ~midiController.setMultiInstrumentMode(false);
                    statusText.string = "Multi-Instrument Mode OFF";
                };
            } {
                "MIDIController not available for multi-instrument setup.".warn;
            };
        });
    midiControlOverridesLayout.add(multiInstrumentToggle);

    layout.add(midiControlOverridesLayout); // Add MIDI overrides layout to main VLayout
    // --- End MIDI Control Overrides UI ---

    // --- Group Management Actions ---
    // Add to existing group action
    addToGroupButton.action = { |btn|
        var selectedInstanceIndex, selectedGroupIndex, instanceName, groupName;
        selectedInstanceIndex = instancesList.value;
        selectedGroupIndex = existingGroupMenu.value;
        
        if(selectedInstanceIndex.notNil && selectedGroupIndex.notNil && selectedGroupIndex > 0) {
            instanceName = instances[selectedInstanceIndex];
            groupName = existingGroupMenu.items[selectedGroupIndex];
            
            ~vstManager.addToGroup(groupName, instanceName);
            statusText.string = "Added % to group: %".format(instanceName, groupName);
            ~refreshVSTManagerGroupsUI.();
        } {
            statusText.string = "Please select both an instance and a group";
        };
    };

    // Create new group action
    createNewGroupButton.action = { |btn|
        var selectedInstanceIndex, instanceName, newGroupName, groupMembers;
        selectedInstanceIndex = instancesList.value;
        newGroupName = newGroupNameField.string.stripWhiteSpace;
        
        if(newGroupName.notEmpty) {
            // If VST selected, add it to the group; otherwise create empty group
            if(selectedInstanceIndex.notNil) {
                instanceName = instances[selectedInstanceIndex];
                groupMembers = [instanceName];
                statusText.string = "Created group '%' with %".format(newGroupName, instanceName);
            } {
                groupMembers = [];
                statusText.string = "Created empty group: %".format(newGroupName);
            };
            
            ~vstManager.createGroup(newGroupName, groupMembers);
            newGroupNameField.string = ""; // Clear the text field
            ~refreshVSTManagerGroupsUI.();
        } {
            statusText.string = "Please enter a group name";
        };
    };
    // --- End Group Management Actions ---

    // Status
    statusText = StaticText()
        .string_("Ready. % VSTs available".format(vstList.size));
    layout.add(statusText);

    // Store the group refresh function globally, ensure it runs on AppClock.
    // This function needs access to win, groupSelectorMenu, and groupMenuItems,
    // so it's defined after they are created.
    ~refreshVSTManagerGroupsUI = {
        // Local variables for this specific function block
        var currentSelectedIndex, currentSelectedItem, newIndex;
        {
            if(win.notNil and: {win.isClosed.not}) { // Only update if window is open
                currentSelectedIndex = groupSelectorMenu.value;
                currentSelectedItem = if(currentSelectedIndex.notNil and: {groupMenuItems.notNil and: {currentSelectedIndex < groupMenuItems.size}}) {
                    groupMenuItems[currentSelectedIndex];
                } { nil };

                // Repopulate groupMenuItems and update the PopUpMenu
                groupMenuItems = ["All"] ++ (~vstManager.getGroupNames().sort ? []);
                groupSelectorMenu.items = groupMenuItems;

                // Update existing group menu for "Add to Group" functionality
                existingGroupMenu.items = ["Select Group..."] ++ (~vstManager.getGroupNames().sort ? []);
                if(existingGroupMenu.items.size > 1) { existingGroupMenu.value = 0 }; // Reset to "Select Group..."

                // Try to restore previous selection
                if(currentSelectedItem.notNil) {
                    newIndex = groupMenuItems.indexOf(currentSelectedItem);
                    if(newIndex.notNil) {
                        groupSelectorMenu.value = newIndex;
                    } {
                        if(groupMenuItems.notEmpty) { groupSelectorMenu.value = 0 }; // Default to "All" if old selection not found
                    };
                } {
                    if(groupMenuItems.notEmpty) { groupSelectorMenu.value = 0 }; // Default to "All"
                };
                "VST Manager: Group selector refreshed.".postln;
            } {
                "VST Manager UI for group refresh not available or closed.".warn;
            };
        }.defer; // Defer to ensure UI updates happen on the AppClock
    };

    // Helper method to update instances list
    updateVSTInstancesList = { |listView|
        localInstances = ~vstManager.vstInstances;
        localStatusText = statusText;

        { // This block runs on the AppClock
            instanceNames = localInstances.keys.asArray.sort;
            instanceInfo = instanceNames.collect { |name|
                // Just show the instance name since it's now based on the VST file
                name;
            };

            instances = instanceNames; // Update the instances array

            listView.items = instanceInfo;
            if (instanceNames.size > 0) {
                listView.value = 0; // Select first item by default
                localStatusText.string = "Loaded: % VSTs".format(instanceNames.size);
            };

            listView.action = { |v|
                index = v.value;
                if (index.notNil && (index < instanceNames.size)) {
                    name = instanceNames[index];
                    localStatusText.string = "Selected: %".format(name);
                };
            };
        }.defer;
    };

    // Store the update function globally
    ~updateVSTManagerUI = {
        "Updating VST manager UI...".postln;
        updateVSTInstancesList.(instancesList);
        if(~refreshVSTManagerGroupsUI.notNil) { ~refreshVSTManagerGroupsUI.value() }; // Also refresh groups
    };

    // Initial update
    ~updateVSTManagerUI.();

    // Set the layout
    win.layout = layout;

    // Initialize the instances list
    updateVSTInstancesList.(instancesList);

    // Cleanup on close
    win.onClose = {
        // No need to set to nil as these are local variables
    };

    // Show the window
    win.front;

    // Return the window for reference
    win;
};

// Initialize the UI in the AppClock
AppClock.sched(0, {
    ~createVSTManagerUI.();
});