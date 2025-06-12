// vstplugin-setup.scd - VST Manager Setup

// 1. Search for VSTs
"Searching for VST plugins...".postln;
VSTPlugin.search(options: (exclude: ["/Library/Audio/Plug-Ins/VST3/Komplete Kontrol.vst3"]));
"VST plugin search complete.".postln;

// 2. Create synths for each VST instance with unique IDs
~synth1 = Synth(\vstHost, [\bus, 0, \out, 2]);  // First instance
~synth2 = Synth(\vstHost, [\bus, 0, \out, 4]);  // Second instance
~synth3 = Synth(\vstHost, [\bus, 0, \out, 6]);  // Third instance
// ~synth4 = Synth(\vstHost, [\bus, 0, \out, 2]);  // Fourth instance

// 3. Initialize VSTManager
~vstManager = VSTManager.new(s);
"VSTManager initialized.".postln;

// Notify that VST manager is ready
~vstManagerInitialized = true;
"VSTManager is ready for use.".postln;

// Function to load VSTs with a callback
~loadVSTs = { |callback|
    fork {
        "Starting VST instance loading...".postln;

        // Initial 5-second wait to ensure VST search completes
        "Waiting for VST search to complete (5 seconds)...".postln;
        5.wait;

        "Adding VST instances...".postln;

        // Add VSTs with unique names
        ~vstManager.addVST("Alto Flute 01", ~synth1, "/Library/Audio/Plug-Ins/VST3/SWAM Alto Flute 3.vst3", true);
        ~vstManager.addVST("Alto Flute 02", ~synth2, "/Library/Audio/Plug-Ins/VST3/SWAM Alto Flute 3.vst3", true);
        ~vstManager.addVST("Alto Flute 03", ~synth3, "/Library/Audio/Plug-Ins/VST3/SWAM Alto Flute 3.vst3", true);
        // ~vstManager.addVST("Euphonium 01", ~synth3, "/Library/Audio/Plug-Ins/VST3/SWAM Euphonium.vst3", true);
        // ~vstManager.addVST("Euphonium 02", ~synth4, "/Library/Audio/Plug-Ins/VST3/SWAM Euphonium.vst3", true);

        // Create a group for all VSTs
        ~vstManager.createGroup('Alto Flute', ["Alto Flute 01", "Alto Flute 02", "Alto Flute 03"]);
        // ~vstManager.createGroup('Euphonium', ["Euphonium 01", "Euphonium 02"]);

        // Explicitly schedule a group UI refresh
        AppClock.sched(0.2, { // Short delay for UI readiness
            if(~refreshVSTManagerGroupsUI.notNil) {
                "vstplugin-setup: Explicitly refreshing VST Manager group UI.".postln;
                ~refreshVSTManagerGroupsUI.value();
            } {
                "vstplugin-setup: ~refreshVSTManagerGroupsUI not (yet) available for explicit refresh.".warn;
            }
        });

        "VST instances added. Waiting for initialization to complete...".postln;

        // Update the UI if callback is provided
        if (callback.notNil) { callback.() };
        
        // Initialize MIDI setup now that VST Manager is ready
        if (~initMIDISetup.notNil) {
            "Calling ~initMIDISetup.() now that VST Manager is ready...".postln;
            ~initMIDISetup.();
        } {
            "WARNING: ~initMIDISetup function not available".warn;
        };

        // Open editors after delay
        SystemClock.sched(5, {
            fork {
                "Opening VST editors...".postln;
                ~vstManager.vstInstances.do { |inst|
                    inst.controller.editor;
                    0.5.wait; // Slightly longer delay between opening editors
                };
                "VST editors opened.".postln;
                2.wait;
                ~vstManager.setProgramByNameAllInstances("control-group-1");
            };
            nil;
        });

        "VSTManager setup complete with % SWAM instrument instances".format(~vstManager.vstInstances.size).postln;
    };
};

// Start loading VSTs with a callback to update the UI
~loadVSTs.({
    "VSTs loaded, updating UI...".postln;
    ~updateAllVSTManagers.();
});
