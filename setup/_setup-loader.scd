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
            "synths-setup.scd",          // 1. Load synthdefs first
            "vstplugin-setup.scd",       // 2. Then VST manager and plugins
            "vst-management.scd",        // 3. Then VST management UI
            "midi-setup.scd",            // 4. Then MIDI setup (depends on VST manager)
            "midi-control-mapping.scd",  // 5. Then MIDI control mapping (depends on MIDI controller)
            "osc-setup.scd",             // 6. Then OSC setup (depends on VST manager)
            // "melody-management.scd"      // 7. Finally melody management (depends on VST manager)
        ];
        
        // Recursive function to load files in sequence
        ~loadNextFile = { |index|
            if (index < filesInOrder.size) {
                var filename = filesInOrder[index];
                var filepath = ~setupDir +/+ filename;
                if (File.exists(filepath)) {
                    try {
                        ("Loading setup file: " ++ filename).postln;
                        filepath.load;
                        // Schedule next file load with appropriate delay
                        if (["midi-setup.scd", "vstplugin-setup.scd"].includes(filename)) {
                            // Longer delay for async operations
                            { ~loadNextFile.(index + 1) }.defer(5.0);
                        } {
                            // Normal delay for other files
                            { ~loadNextFile.(index + 1) }.defer(0.2);
                        };
                    } { |error|
                        ("Error loading " ++ filename ++ ": " ++ error.errorString).error;
                        // Continue with next file even if there's an error
                        { ~loadNextFile.(index + 1) }.defer(0.1);
                    };
                } {
                    ("Warning: Setup file not found: " ++ filename).warn;
                    // Continue with next file
                    { ~loadNextFile.(index + 1) }.defer(0.1);
                };
            } {
                "All setup files loaded successfully!".postln;
                
                // Load clip system after setup is complete
                {
                    var clipLoaderPath = ~setupDir.dirname +/+ "clip-system/clip-loader.scd";
                    if (File.exists(clipLoaderPath)) {
                        "Loading clip system...".postln;
                        clipLoaderPath.load;
                    } {
                        "Clip system not found at: %".format(clipLoaderPath).postln;
                    };
                }.defer(1.0); // Give setup time to settle
            };
        };
        
        // Start loading the first file
        ~loadNextFile.(0);
    };

    // Start the loading process
    ~loadWithDependencies.();
};
