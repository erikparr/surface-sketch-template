/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                          CLIP FILE MANAGEMENT                                ║
║                          Save and load individual clips                      ║
║                          and manage clip libraries                           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                          CONFIGURATION & PATHS                             │
// └─────────────────────────────────────────────────────────────────────────────┘

// Clip file management configuration
~clipFileConfig = (
    // Default directories (relative to main project)
    clipsDir: "data/clips/",
    backupDir: "data/clips/backups/",
    libraryDir: "data/clips/libraries/",
    
    // File extensions
    clipExtension: ".json",
    backupExtension: ".backup.json",
    
    // Metadata
    formatVersion: "1.0",
    maxBackups: 5,
    
    // Naming patterns
    timestampFormat: "%Y%m%d_%H%M%S",
    clipNamePattern: "clip_%",
    libraryNamePattern: "library_%"
);

// Ensure clip directories exist
~ensureClipDirectories = {
    var baseDir, clipsDir, backupDir, libraryDir;
    
    // Use stored clip system directory path to find project root
    if (~clipSystemDir.notNil) {
        baseDir = ~clipSystemDir.dirname.dirname; // From clip-system/ up to project root
    } {
        // Fallback: use current working directory
        baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
        "Warning: Using fallback base directory: %".format(baseDir).postln;
    };
    
    clipsDir = baseDir +/+ ~clipFileConfig.clipsDir;
    backupDir = baseDir +/+ ~clipFileConfig.backupDir;
    libraryDir = baseDir +/+ ~clipFileConfig.libraryDir;
    
    // Create directories if they don't exist
    File.mkdir(clipsDir);
    File.mkdir(backupDir);
    File.mkdir(libraryDir);
    
    "Clip directories ensured: %".format(clipsDir).postln;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           INDIVIDUAL CLIP SAVE/LOAD                        │
// └─────────────────────────────────────────────────────────────────────────────┘

// Save individual clip to dedicated file
~saveClip = { |clipKey, filename=nil|
    var melody, clipData, saveData, filepath, baseDir, timestamp, result = false;
    
    if (clipKey.isNil) {
        "ERROR: No clip key provided for save".postln;
    } {
        // Find the clip in melody data
        melody = ~melodyData[\melodies].detect({ |m| m[\key] == clipKey });
        
        if (melody.isNil) {
            "ERROR: Clip not found: %".format(clipKey).postln;
        } {
            if (~isValidClip.(melody).not) {
                "ERROR: Invalid clip data for %".format(clipKey).postln;
            } {
                // Generate filename if not provided
                if (filename.isNil) {
                    timestamp = Date.getDate.format(~clipFileConfig.timestampFormat);
                    filename = ~clipFileConfig.clipNamePattern.format(clipKey ++ "_" ++ timestamp);
                };
                
                // Ensure .json extension
                if (filename.endsWith(~clipFileConfig.clipExtension).not) {
                    filename = filename ++ ~clipFileConfig.clipExtension;
                };
                
                // Build complete file path
                if (~clipSystemDir.notNil) {
                    baseDir = ~clipSystemDir.dirname.dirname;
                } {
                    baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
                };
                filepath = baseDir +/+ ~clipFileConfig.clipsDir +/+ filename;
                
                // Prepare save data with metadata
                saveData = (
                    formatVersion: ~clipFileConfig.formatVersion,
                    savedAt: Date.getDate.stamp,
                    clipData: melody,
                    metadata: (
                        originalKey: clipKey,
                        savedBy: "clip-system",
                        systemVersion: "2.0",
                        originalDuration: melody[\clipData][\duration],
                        noteCount: melody[\clipData][\notePairs].size
                    )
                );
                
                // Ensure directories exist
                ~ensureClipDirectories.();
                
                // Save to file
                try {
                    var jsonString;
                    if (JSONlib.notNil) {
                        jsonString = JSONlib.convertToJSON(saveData);
                    } {
                        jsonString = saveData.asCompileString;
                    };
                    File.use(filepath, "w", { |file|
                        file.write(jsonString);
                    });
                    
                    "✅ Clip saved: % → %".format(clipKey, filename).postln;
                    "   Path: %".format(filepath).postln;
                    "   Duration: %s, Notes: %".format(
                        melody[\clipData][\duration].round(~clipSystemConfig.displayPrecision),
                        melody[\clipData][\notePairs].size
                    ).postln;
                    
                    result = true;
                } { |error|
                    "ERROR: Failed to save clip %: %".format(clipKey, error).postln;
                };
            };
        };
    };
    
    result;
};

// Load individual clip from file
~loadClip = { |filename, addToMelodyData=true|
    var filepath, baseDir, loadedData, clipData, result = nil, existingIndex;
    
    if (filename.isNil) {
        "ERROR: No filename provided for clip load".postln;
    } {
        // Ensure .json extension
        if (filename.endsWith(~clipFileConfig.clipExtension).not) {
            filename = filename ++ ~clipFileConfig.clipExtension;
        };
        
        // Build complete file path
        if (~clipSystemDir.notNil) {
            baseDir = ~clipSystemDir.dirname.dirname;
        } {
            baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
        };
        filepath = baseDir +/+ ~clipFileConfig.clipsDir +/+ filename;
        
        // Load from file
        if (File.exists(filepath)) {
            try {
                File.use(filepath, "r", { |file|
                    var jsonString = file.readAllString;
                    if (JSONlib.notNil) {
                        loadedData = JSONlib.convertToDict(jsonString);
                    } {
                        loadedData = jsonString.interpret;
                    };
                });
                
                if (loadedData.notNil and: { loadedData[\clipData].notNil }) {
                    clipData = loadedData[\clipData];
                    
                    // Validate loaded clip
                    if (~isValidClip.(clipData)) {
                        if (addToMelodyData) {
                            // Add to current melody data
                            if (~melodyData.isNil) {
                                ~melodyData = (melodies: []);
                            };
                            
                            // Check if clip already exists (by key)
                            existingIndex = ~melodyData[\melodies].detectIndex({ |m| 
                                m[\key] == clipData[\key] 
                            });
                            
                            if (existingIndex.notNil) {
                                "Replacing existing clip: %".format(clipData[\key]).postln;
                                ~melodyData[\melodies][existingIndex] = clipData;
                            } {
                                "Adding new clip: %".format(clipData[\key]).postln;
                                ~melodyData[\melodies] = ~melodyData[\melodies] ++ [clipData];
                            };
                            
                            // Update the current sequence to include this clip
                            if (~refreshClipSequence.notNil) {
                                "Updating sequence to include loaded clip...".postln;
                                ~refreshClipSequence.();
                            };
                        };
                        
                        "✅ Clip loaded: % (% → %)".format(
                            filename, 
                            clipData[\key], 
                            clipData[\name]
                        ).postln;
                        "   Duration: %s, Notes: %".format(
                            clipData[\clipData][\duration].round(~clipSystemConfig.displayPrecision),
                            clipData[\clipData][\notePairs].size
                        ).postln;
                        
                        result = clipData;
                    } {
                        "ERROR: Invalid clip data in file: %".format(filename).postln;
                    };
                } {
                    "ERROR: No clip data found in file: %".format(filename).postln;
                };
            } { |error|
                "ERROR: Failed to load clip %: %".format(filename, error).postln;
            };
        } {
            "ERROR: Clip file not found: %".format(filepath).postln;
        };
    };
    
    result;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           CLIP LIBRARY MANAGEMENT                          │
// └─────────────────────────────────────────────────────────────────────────────┘

// Save collection of clips as a library
~saveClipLibrary = { |libraryName, clipKeys=nil|
    var library, filepath, baseDir, timestamp, result = false;
    
    if (libraryName.isNil) {
        timestamp = Date.getDate.format(~clipFileConfig.timestampFormat);
        libraryName = ~clipFileConfig.libraryNamePattern.format(timestamp);
    };
    
    // Get clips to save (all clips if none specified)
    if (clipKeys.isNil) {
        clipKeys = ~melodyData[\melodies].select({ |m| ~isValidClip.(m) }).collect({ |m| m[\key] });
    };
    
    if (clipKeys.size == 0) {
        "ERROR: No clips found to save in library".postln;
    } {
        // Collect clip data
        library = (
            formatVersion: ~clipFileConfig.formatVersion,
            libraryName: libraryName,
            savedAt: Date.getDate.stamp,
            clipCount: clipKeys.size,
            clips: clipKeys.collect({ |key|
                ~melodyData[\melodies].detect({ |m| m[\key] == key })
            }).select({ |clip| clip.notNil })
        );
        
        // Build file path
        if (~clipSystemDir.notNil) {
            baseDir = ~clipSystemDir.dirname.dirname;
        } {
            baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
        };
        filepath = baseDir +/+ ~clipFileConfig.libraryDir +/+ libraryName ++ ~clipFileConfig.clipExtension;
        
        // Ensure directories exist
        ~ensureClipDirectories.();
        
        // Save library
        try {
            var jsonString;
            if (JSONlib.notNil) {
                jsonString = JSONlib.convertToJSON(library);
            } {
                jsonString = library.asCompileString;
            };
            File.use(filepath, "w", { |file|
                file.write(jsonString);
            });
            
            "✅ Clip library saved: % (% clips)".format(libraryName, library[\clips].size).postln;
            "   Path: %".format(filepath).postln;
            
            result = true;
        } { |error|
            "ERROR: Failed to save clip library %: %".format(libraryName, error).postln;
        };
    };
    
    result;
};

// Load clip library
~loadClipLibrary = { |libraryName, addToMelodyData=true|
    var filepath, baseDir, library, result = nil;
    
    if (libraryName.isNil) {
        "ERROR: No library name provided".postln;
    } {
        // Ensure .json extension
        if (libraryName.endsWith(~clipFileConfig.clipExtension).not) {
            libraryName = libraryName ++ ~clipFileConfig.clipExtension;
        };
        
        // Build file path
        if (~clipSystemDir.notNil) {
            baseDir = ~clipSystemDir.dirname.dirname;
        } {
            baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
        };
        filepath = baseDir +/+ ~clipFileConfig.libraryDir +/+ libraryName;
        
        // Load library
        if (File.exists(filepath)) {
            try {
                File.use(filepath, "r", { |file|
                    var jsonString = file.readAllString;
                    if (JSONlib.notNil) {
                        library = JSONlib.convertToDict(jsonString);
                    } {
                        library = jsonString.interpret;
                    };
                });
                
                if (library.notNil and: { library[\clips].notNil }) {
                    if (addToMelodyData) {
                        if (~melodyData.isNil) {
                            ~melodyData = (melodies: []);
                        };
                        
                        library[\clips].do({ |clip|
                            if (~isValidClip.(clip)) {
                                // Check if clip already exists
                                var existingIndex = ~melodyData[\melodies].detectIndex({ |m| 
                                    m[\key] == clip[\key] 
                                });
                                
                                if (existingIndex.notNil) {
                                    ~melodyData[\melodies][existingIndex] = clip;
                                } {
                                    ~melodyData[\melodies] = ~melodyData[\melodies] ++ [clip];
                                };
                            };
                        });
                    };
                    
                    "✅ Clip library loaded: % (% clips)".format(
                        library[\libraryName], 
                        library[\clips].size
                    ).postln;
                    
                    result = library;
                } {
                    "ERROR: Invalid library format: %".format(libraryName).postln;
                };
            } { |error|
                "ERROR: Failed to load library %: %".format(libraryName, error).postln;
            };
        } {
            "ERROR: Library file not found: %".format(filepath).postln;
        };
    };
    
    result;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            UTILITY FUNCTIONS                               │
// └─────────────────────────────────────────────────────────────────────────────┘

// List available clips in directory
~listClipFiles = {
    var baseDir, clipsDir, pattern, files = [];
    
    if (~clipSystemDir.notNil) {
        baseDir = ~clipSystemDir.dirname.dirname;
    } {
        baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
    };
    clipsDir = baseDir +/+ ~clipFileConfig.clipsDir;
    pattern = "*" ++ ~clipFileConfig.clipExtension;
    
    if (File.exists(clipsDir)) {
        files = (clipsDir +/+ pattern).pathMatch;
        
        "=== AVAILABLE CLIP FILES ===".postln;
        if (files.size > 0) {
            files.do({ |filepath, i|
                var filename = PathName(filepath).fileName;
                "% - %".format(i + 1, filename).postln;
            });
        } {
            "No clip files found in %".format(clipsDir).postln;
        };
        "============================".postln;
    } {
        "Clips directory not found: %".format(clipsDir).postln;
    };
    
    files;
};

// List available clip libraries
~listClipLibraries = {
    var baseDir, libraryDir, pattern, files = [];
    
    if (~clipSystemDir.notNil) {
        baseDir = ~clipSystemDir.dirname.dirname;
    } {
        baseDir = Platform.userHomeDir +/+ "surfacing/surfacing";
    };
    libraryDir = baseDir +/+ ~clipFileConfig.libraryDir;
    pattern = "*" ++ ~clipFileConfig.clipExtension;
    
    if (File.exists(libraryDir)) {
        files = (libraryDir +/+ pattern).pathMatch;
        
        "=== AVAILABLE CLIP LIBRARIES ===".postln;
        if (files.size > 0) {
            files.do({ |filepath, i|
                var filename = PathName(filepath).fileName;
                "% - %".format(i + 1, filename).postln;
            });
        } {
            "No library files found in %".format(libraryDir).postln;
        };
        "================================".postln;
    } {
        "Library directory not found: %".format(libraryDir).postln;
    };
    
    files;
};

// Quick save current active clips
~quickSaveActiveClips = {
    var activeClips, timestamp, result = false;
    
    if (~melodyData.notNil and: { ~melodyData[\melodies].notNil }) {
        activeClips = ~melodyData[\melodies].select({ |m| 
            ~isValidClip.(m) and: { m[\active] == true }
        }).collect({ |m| m[\key] });
        
        if (activeClips.size > 0) {
            timestamp = Date.getDate.format(~clipFileConfig.timestampFormat);
            result = ~saveClipLibrary.("active_clips_" ++ timestamp, activeClips);
            
            if (result) {
                "Quick save completed: % active clips".format(activeClips.size).postln;
            };
        } {
            "No active clips found to save".postln;
        };
    } {
        "No melody data available".postln;
    };
    
    result;
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            INITIALIZATION                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Initialize file management system
~initializeClipFileManager = {
    "Initializing clip file management system...".postln;
    
    // Ensure directories exist
    ~ensureClipDirectories.();
    
    "Clip file management ready".postln;
    "- Individual clips: data/clips/".postln;
    "- Clip libraries: data/clips/libraries/".postln;
    "- Backups: data/clips/backups/".postln;
};

"Clip file management system loaded".postln;