// Check if setup has already been loaded
if (~setupAlreadyLoaded == true) {
    "Setup already loaded, skipping...".postln;
} {
    // Set flag to prevent double-loading
    ~setupAlreadyLoaded = true;

    // Define the setup directory path relative to this file
    ~setupDir = PathName(thisProcess.nowExecutingPath).pathOnly;

    // Define the correct loading order with dependencies
    ~loadWithDependencies = {
        var filesInOrder = [
            "synths-setup.scd",      // 1. Load synthdefs first
            "vstplugin-setup.scd",   // 2. Then VST manager and plugins
            "vst-management.scd",    // 3. Then VST management UI
            "midi-setup.scd",        // 4. Then MIDI setup (depends on VST manager)
            "osc-setup.scd",         // 5. Finally OSC setup (depends on VST manager)
            "melody-management.scd"  // 6. Finally melody management (depends on VST manager)
        ];
        
        // Load each file in order with error handling
        filesInOrder.do { |filename|
            var filepath = ~setupDir +/+ filename;
            if (File.exists(filepath)) {
                try {
                    ("Loading setup file: " ++ filename).postln;
                    filepath.load;
                    0.2.wait; // Slightly longer wait between critical files
                } { |error|
                    ("Error loading " ++ filename ++ ": " ++ error.errorString).error;
                };
            } {
                ("Warning: Setup file not found: " ++ filename).warn;
            };
        };
        
        "All setup files loaded successfully!".postln;
    };

    // Start the loading process
    Routine({
        ~loadWithDependencies.();
    }).play;
};
