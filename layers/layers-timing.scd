/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                          LAYERS TIMING UTILITIES                              ║
║                   Timing data support for layer melodies                      ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

(
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                        TIMING CALCULATION FUNCTIONS                         │
// └─────────────────────────────────────────────────────────────────────────────┘

/*
Calculate absolute start times for notes based on timing data.

Args:
  melodyData - Dictionary containing melody information with optional 'timing' array
  totalDuration - Total duration for the melody in seconds
  
Returns:
  Dictionary with:
    - startTimes: Array of absolute start times for each note
    - durations: Array of durations for each note
    - waitTimes: Array of wait times between notes (for playback)
*/
~calculateLayerTiming = { |melodyData, totalDuration|
    var pattern, noteCount, timing, startTimes, durations, waitTimes;
    var noteDurations, durationType;
    
    // Get pattern (array of MIDI notes)
    pattern = melodyData.patterns[0];
    noteCount = pattern.size;
    
    // Get timing data if available
    timing = melodyData.timing;
    noteDurations = melodyData.noteDurations;
    durationType = melodyData.durationType ? "absolute";
    
    if (timing.notNil and: { timing.size == (noteCount + 1) }) {
        // Use provided timing data
        var currentTime = 0;
        startTimes = Array.newClear(noteCount);
        
        // timing[0] is the wait before first note
        currentTime = timing[0] * totalDuration;
        
        // Calculate start times for each note
        noteCount.do { |i|
            startTimes[i] = currentTime;
            if (i < (noteCount - 1)) {
                // Add inter-onset interval to get next note's start time
                currentTime = currentTime + (timing[i + 1] * totalDuration);
            };
        };
        
        // Calculate wait times between notes for playback
        waitTimes = Array.newClear(noteCount);
        noteCount.do { |i|
            if (i == 0) {
                // Wait before first note
                waitTimes[i] = startTimes[i];
            } {
                // Wait between notes
                waitTimes[i] = startTimes[i] - startTimes[i - 1];
            };
        };
        
        "Using timing data for % notes: start times = %".format(
            noteCount, startTimes.collect(_.round(0.001))
        ).postln;
        
    } {
        // Fall back to equal spacing (backward compatibility)
        var noteInterval = totalDuration / noteCount;
        startTimes = Array.fill(noteCount, { |i| i * noteInterval });
        waitTimes = Array.fill(noteCount, noteInterval);
        
        "Using equal spacing for % notes: interval = %s".format(
            noteCount, noteInterval.round(0.001)
        ).postln;
    };
    
    // Handle note durations
    if (noteDurations.notNil and: { noteDurations.size == noteCount }) {
        if (durationType == "fractional") {
            // Convert fractional durations to absolute
            durations = noteCount.collect { |i|
                var availableTime;
                if (i < (noteCount - 1)) {
                    availableTime = startTimes[i + 1] - startTimes[i];
                } {
                    // Last note: use remaining time
                    availableTime = totalDuration - startTimes[i];
                    if (timing.notNil) {
                        // Subtract the final wait time if using timing data
                        availableTime = availableTime - (timing.last * totalDuration);
                    };
                };
                noteDurations[i] * availableTime
            };
        } {
            // Use absolute durations directly
            durations = noteDurations;
        };
    } {
        // Default duration (could be made configurable)
        durations = Array.fill(noteCount, 0.2);
    };
    
    // Return timing information
    (
        startTimes: startTimes,
        durations: durations,
        waitTimes: waitTimes,
        noteCount: noteCount
    )
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                            JSON IMPORT FUNCTIONS                            │
// └─────────────────────────────────────────────────────────────────────────────┘

/*
Import layer melody data from JSON file.

Args:
  jsonPath - Path to JSON file
  
Returns:
  Dictionary of melodies keyed by layer name, or nil on error
*/
~importLayerMelodyFromJSON = { |jsonPath|
    var jsonData, melodies;
    
    // Check if file exists
    if (File.exists(jsonPath).not) {
        "JSON file not found: %".format(jsonPath).error;
        nil
    } {
        try {
            // Parse JSON using JSONlib
            jsonData = JSONlib.parseFile(jsonPath, useEvent: true);
            
            // Convert to melody dictionary format
            melodies = Dictionary.new;
            
            // JSONlib with useEvent: true converts string keys to symbols
            jsonData[\layers].keysValuesDo { |layerName, layerData|
                var notes, timing, metadata;
                var patterns, velocities, durations;
                
                notes = layerData[\notes];
                timing = layerData[\timing];
                metadata = layerData[\metadata];
                
                // Extract MIDI notes and velocities (they're also symbols now)
                patterns = notes.collect { |note| note[\midi] };
                velocities = notes.collect { |note| note[\vel] };
                durations = notes.collect { |note| note[\dur] };
                
                // Create melody entry
                melodies[layerName.asSymbol] = (
                    name: "Imported % (%)".format(layerName, metadata[\key] ? ""),
                    patterns: [patterns],  // Wrap in array for compatibility
                    velocities: velocities,
                    timing: timing,
                    noteDurations: durations,
                    durationType: metadata[\durationType] ? "absolute",
                    totalDuration: metadata[\totalDuration],
                    metadata: metadata
                );
                
                "Imported % with % notes, timing: %".format(
                    layerName, patterns.size, timing.notNil
                ).postln;
            };
            
            "Successfully imported % layers from JSON".format(melodies.size).postln;
            melodies
            
        } { |error|
            "Error parsing JSON file: %".format(error).error;
            nil
        };
    };
};

/*
Add imported melodies to the global melody dictionary.

Args:
  importedMelodies - Dictionary returned by ~importLayerMelodyFromJSON
  prefix - Optional prefix for melody keys (default: "imported_")
*/
~addImportedMelodiesToDict = { |importedMelodies, prefix="imported_"|
    if (importedMelodies.notNil) {
        // Ensure ~melodyDict exists
        if (~melodyDict.isNil) {
            ~melodyDict = Dictionary.new;
        };
        
        importedMelodies.keysValuesDo { |key, melody|
            var melodyKey = (prefix ++ key).asSymbol;
            ~melodyDict[melodyKey] = melody;
            "Added melody '%' to ~melodyDict".format(melodyKey).postln;
        };
        "Added % melodies to ~melodyDict".format(importedMelodies.size).postln;
    };
};

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                           UTILITY FUNCTIONS                                 │
// └─────────────────────────────────────────────────────────────────────────────┘

/*
Validate timing array for a given number of notes.

Args:
  timing - Array of timing fractions
  noteCount - Number of notes
  
Returns:
  true if valid, false otherwise
*/
~validateTiming = { |timing, noteCount|
    var sum;
    
    if (timing.isNil) {
        true  // No timing is valid (will use equal spacing)
    } {
        if (timing.size != (noteCount + 1)) {
            "Timing array size (%) doesn't match expected size (%) for % notes".format(
                timing.size, noteCount + 1, noteCount
            ).warn;
            false
        } {
            sum = timing.sum;
            if ((sum - 1.0).abs > 0.001) {
                "Timing array sum (%) is not 1.0".format(sum).warn;
                false
            } {
                true
            };
        };
    };
};

/*
Create a test melody with timing data.
*/
~createTimingTestMelody = {
    (
        name: "Timing Test Melody",
        patterns: [[60, 62, 64, 65, 67]],  // C D E F G
        timing: [0.1, 0.1, 0.2, 0.3, 0.2, 0.1],  // Uneven spacing
        noteDurations: [0.4, 0.4, 0.4, 0.4, 0.8],  // Last note longer
        durationType: "absolute",
        velocityMultipliers: (first: 1.2, last: 0.8)
    )
};

"Layers timing utilities loaded successfully".postln;
);