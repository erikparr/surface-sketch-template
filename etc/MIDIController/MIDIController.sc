MIDIController {
    var <sliderValues;
    var <knobValues;
    var <knobRanges;
    var <midiFuncs;
    var <vstList;
    var <oscNetAddr;
    var <glissandoMode;
    var <glissandoNoteMode;
    var <bendSynth;
    var <numNotesPlaying;
    var <velocity;
    var <manualVelocityMode;     // For toggling manual velocity override
    var <manualVelocityValue;    // Stores the manually set velocity
    var <numKnobs;
    var <startCC;
    var <controlRoutine;
    var <pollRate;
    var <debug;
    var <multiChannelMode;
    var <multiInstrumentMode;
    var <>activeNotes;
    var <noteHandlingEnabled;
    
    // Button toggle-related properties
    var <buttonStates;
    var <buttonCallbacks;
    
    // Bend-related properties
    var <bendEnabled;
    var <bendRange;
    var <bendDuration;
    var <bendCurve;
    var <bendEnvelopeSynth;
    
    // Snapshot-related properties
    var <snapshots;
    var <currentSnapshot;
    var <programmedMode;
    var <snapshotDataPath;
    
    // Controller preset properties
    var <controllerPresets;
    var <activePresetName;
    var <activePreset;
    var <disabledKnobCCs; // Added for toggling knob CC processing

    *new { |vstList, oscNetAddr, bendSynth = nil, numKnobs = 16, startCC = 0, debug = false|
        ^super.new.init(vstList, oscNetAddr, bendSynth, numKnobs, startCC, debug);
    }

    init { |inVstList, inOscNetAddr, inBendSynth, inNumKnobs, inStartCC, inDebug|
        debug = inDebug;
        disabledKnobCCs = Set.new; // Initialize the set for disabled knob CCs
        
        this.debug("Initializing MIDIController");
        
        // Initialize MIDI client if not already initialized
        MIDIClient.initialized.not.if {
            MIDIClient.init;
        };
        
        // Connect to all available MIDI sources and destinations
        MIDIIn.connectAll;
        MIDIClient.destinations.do { |dest|
            this.debug("Connected to MIDI destination: %".format(dest.name));
        };
        
        vstList = inVstList;
        oscNetAddr = inOscNetAddr;
        bendSynth = inBendSynth;
        numKnobs = inNumKnobs;
        startCC = inStartCC;
        
        // Initialize arrays for sliders and dictionary for knobs
        sliderValues = Array.fill(9, 0.0);
        knobValues = Dictionary.new;
        midiFuncs = IdentityDictionary.new;
        numNotesPlaying = 0;
        velocity = 100;
        manualVelocityMode = false;
        manualVelocityValue = 100; // Default manual velocity, can be changed via setManualVelocity
        
        // Initialize modes as false by default
        glissandoMode = false;
        glissandoNoteMode = false;
        multiChannelMode = true;
        multiInstrumentMode = false;
        activeNotes = Dictionary.new;
        noteHandlingEnabled = true;
        
        // Initialize button toggle-related properties
        buttonStates = Dictionary.new;
        buttonCallbacks = Dictionary.new;
        
        // Initialize bend-related properties
        bendEnabled = false;
        bendRange = 6;  // half octave up
        bendDuration = 1.5;  // seconds
        bendCurve = \sin;  // smooth curve
        bendEnvelopeSynth = nil;
        
        // Initialize snapshot-related properties
        snapshots = Dictionary.new;
        currentSnapshot = nil;
        programmedMode = false;
        snapshotDataPath = this.class.getSnapshotDataPath;
        
        // Initialize controller presets
        this.initControllerPresets;
        this.setControllerPreset(\midiMix); // Default to MIDIMix
        
    }

    // Class method to get the snapshot data path
    *getSnapshotDataPath {
        var snapshotDir, dir, projectPath;
        
        // Print diagnostic information
        "Current working directory: %".format(File.getcwd).postln;
        "User home directory: %".format(Platform.userHomeDir).postln;
        
        // Try to find the project directory by looking for the setup directory
        projectPath = Platform.userHomeDir ++ "/Documents/_Music/sc-projects/intro/first-light";
        snapshotDir = projectPath ++ "/snapshotData";
        
        "Using project path: %".format(projectPath).postln;
        "Using snapshot directory: %".format(snapshotDir).postln;
        
        dir = PathName(snapshotDir);
        
        if(dir.isFolder.not) {
            "Directory does not exist, attempting to create: %".format(snapshotDir).postln;
            try {
                File.mkdir(snapshotDir);
                "Directory created successfully".postln;
            } { |error|
                "Failed to create directory: %".format(error).postln;
                // If we can't create the directory, at least return the path
                "Returning path even though directory creation failed".postln;
            };
        } {
            "Directory already exists: %".format(snapshotDir).postln;
        };
        
        ^snapshotDir;
    }

    // Save current slider and knob values as a snapshot
    saveSnapshot { |name|
        var snapshot = Dictionary.new;
        var timestamp = Date.getDate.format("%Y-%m-%d %H:%M:%S");
        
        // Store slider values
        snapshot.put(\sliders, sliderValues.copy);
        
        // Store knob values
        snapshot.put(\knobs, knobValues.copy);
        
        // Store timestamp
        snapshot.put(\timestamp, timestamp);
        
        // Add to snapshots dictionary
        snapshots.put(name, snapshot);
        
        this.debug("Saved snapshot: %".format(name));
        ^snapshot;
    }

    // Load a snapshot
    loadSnapshot { |name|
        var snapshot = snapshots.at(name);
        
        if(snapshot.notNil) {
            // Restore slider values
            snapshot.at(\sliders).do { |val, i|
                sliderValues[i] = val;
            };
            
            // Restore knob values
            snapshot.at(\knobs).do { |cc, val|
                knobValues.put(cc, val);
            };
            
            this.debug("Loaded snapshot: %".format(name));
            ^true;
        } {
            this.debug("Snapshot not found: %".format(name));
            ^false;
        }
    }

    // List all available snapshots
    listSnapshots {
        this.debug("Available snapshots:");
        snapshots.keys.do { |name|
            var snapshot = snapshots.at(name);
            var timestamp = snapshot.at(\timestamp);
            "  % (saved: %)".format(name, timestamp).postln;
        };
    }

    // Delete a snapshot
    deleteSnapshot { |name|
        if(snapshots.includesKey(name)) {
            snapshots.removeAt(name);
            this.debug("Deleted snapshot: %".format(name));
            ^true;
        } {
            this.debug("Snapshot not found: %".format(name));
            ^false;
        }
    }

    // Save snapshots to a file in the snapshotData directory
    saveSnapshotsToFile { |filename|
        var fullPath = snapshotDataPath ++ "/" ++ filename;
        var file;
        
        // Ensure filename has .scd extension
        if(fullPath.endsWith(".scd").not) {
            fullPath = fullPath ++ ".scd";
        };
        
        file = File(fullPath, "w");
        if(file.isOpen) {
            file.write("~snapshots = ");
            file.write(snapshots.asCompileString);
            file.close;
            this.debug("Snapshots saved to %".format(fullPath));
            ^true;
        } {
            this.debug("Failed to open file for writing: %".format(fullPath));
            ^false;
        }
    }

    // Load snapshots from a file in the snapshotData directory
    loadSnapshotsFromFile { |filename|
        var fullPath = snapshotDataPath ++ "/" ++ filename;
        var file;
        var data;
        
        // Ensure filename has .scd extension
        if(fullPath.endsWith(".scd").not) {
            fullPath = fullPath ++ ".scd";
        };
        
        file = File(fullPath, "r");
        if(file.isOpen) {
            data = file.readAllString;
            file.close;
            
            // Execute the file content to load snapshots into the global ~snapshots variable
            data.interpret;
            
            // Update the MIDIController's snapshots dictionary with the global ~snapshots
            if(~snapshots.notNil) {
                snapshots = ~snapshots.copy;
                this.debug("Snapshots loaded from % and updated in MIDIController".format(fullPath));
            } {
                this.debug("Global ~snapshots variable is nil after loading file");
            };
            
            ^true;
        } {
            this.debug("Failed to open file for reading: %".format(fullPath));
            ^false;
        }
    }

    // List all available snapshot files
    listSnapshotFiles {
        var dir = PathName(snapshotDataPath);
        
        if(dir.isFolder) {
            var files = dir.files.select { |f| f.extension == "scd" };
            this.debug("Available snapshot files:");
            files.do { |f| "  %".format(f.fileName).postln };
            ^files;
        } {
            this.debug("No snapshotData directory found.");
            ^[];
        }
    }

    // Enable/disable programmed mode
    setProgrammedMode { |bool, snapshotName|
        if(bool) {
            if(snapshotName.notNil) {
                // First check if the snapshot exists
                if(snapshots.includesKey(snapshotName)) {
                    // Get the snapshot
                    var snapshot = snapshots.at(snapshotName);
                    
                    // Apply the snapshot values directly
                    snapshot.at(\sliders).do { |val, i|
                        sliderValues[i] = val;
                    };
                    
                    snapshot.at(\knobs).do { |cc, val|
                        knobValues.put(cc, val);
                    };
                    
                    // Set the current snapshot and enable programmed mode
                    currentSnapshot = snapshotName;
                    programmedMode = true;
                    
                    this.debug("Programmed mode enabled with snapshot: %".format(snapshotName));
                    this.debug("Applied slider values: %".format(sliderValues));
                    this.debug("Applied knob values: %".format(knobValues));
                    
                    ^true;
                } {
                    this.debug("Failed to enable programmed mode: snapshot '%' not found".format(snapshotName));
                    ^false;
                };
            } {
                this.debug("Failed to enable programmed mode: no snapshot specified");
                ^false;
            };
        } {
            currentSnapshot = nil;
            programmedMode = false;
            this.debug("Programmed mode disabled");
            ^true;
        }
    }

    // Get current snapshot name
    getCurrentSnapshot {
        ^currentSnapshot;
    }

    // Check if programmed mode is active
    isProgrammedMode {
        ^programmedMode;
    }

    // Get slider value with programmed mode support
    getSliderValue { |index|
        if(this.isProgrammedMode) {
            // In programmed mode, return the snapshot value
            var snapshot = snapshots.at(currentSnapshot);
            if(snapshot.notNil) {
                ^snapshot.at(\sliders).at(index);
            } {
                ^sliderValues.at(index);
            };
        } {
            // In normal mode, return the actual slider value
            ^sliderValues.at(index);
        }
    }

    // Get knob value with programmed mode support
    getKnobValueByCC { |ccNum| 
        if(programmedMode && currentSnapshot.notNil) {
            var snapshot = snapshots.at(currentSnapshot);
            // Assuming snapshots store knobs as a Dictionary mapping CCs to values
            if(snapshot.notNil && snapshot.at(\knobs).notNil && snapshot.at(\knobs).isKindOf(Dictionary) && snapshot.at(\knobs).includesKey(ccNum)) {
                ^snapshot.at(\knobs).at(ccNum);
            } {
                // Fallback to current live value if snapshot issue or CC not in snapshot's knob data
                ^knobValues.at(ccNum) ? 0.5; // Default if not found in live values
            };
        } {
            // In normal mode, return the actual live knob value
            ^knobValues.at(ccNum) ? 0.5; // Default if not found in live values
        }
    }

    // Generic method to get knob value by index (0-based for activePreset.knobs array/range)
    // Used for presets like nanoKONTROL2 which define a simple list/range of knob CCs.
    getKnob { |index=0|
        var ccNum;
        if (activePreset.notNil && activePreset.knobs.notNil) {
            // Check if activePreset.knobs is a collection and index is within bounds
            if (activePreset.knobs.isKindOf(SequenceableCollection)) {
                if (index >= 0 && index < activePreset.knobs.size) {
                    ccNum = activePreset.knobs.at(index); // Get CC from preset's flat list/range
                    ^this.getKnobValueByCC(ccNum); // Use the new method that takes CC num
                }  {
                    "Warning: getKnob index % out of range for preset '%' (size: %)".format(index, activePresetName, activePreset.knobs.size).warn;
                    ^0.5; // Default value
                }
            } {
                 "Warning: activePreset.knobs is not a SequenceableCollection for preset '%'.".format(activePresetName).warn;
                ^0.5;
            }
        } {
            "Warning: getKnob called with no active preset or knobs definition.".warn;
            ^0.5; // Default value
        };
    }

    initMIDIFuncs {
        // Note On
        midiFuncs[\noteOn] = MIDIFunc.noteOn({ |veloc, pitch, chan, src|
            var outChan, effectiveVelocity;
            
            // Skip processing if note handling is disabled
            if(noteHandlingEnabled) {
                var shouldProcessNote = true; // Flag to control processing
                
                // Determine channel based on mode
                if(multiChannelMode) {
                    // Check if this pitch is already in activeNotes (retriggered note)
                    if(activeNotes.includesKey(pitch)) {
                        if(multiInstrumentMode) {
                            // In multi-instrument mode, ignore retriggered notes to prevent stuck notes
                            if(debug) { "Multi-instrument mode: Ignoring retrigger for pitch %".format(pitch).postln; };
                            shouldProcessNote = false; // Skip processing this duplicate noteOn
                        } {
                            // In multi-channel mode only, allow retriggering
                            outChan = activeNotes[pitch];
                            if(debug) { "Retriggering existing note on channel %".format(outChan).postln; };
                        }
                    } {
                        // Find the first available channel (not currently in use)
                        var usedChannels = activeNotes.values.asSet;
                        var availableChannels = (0..15).difference(usedChannels);
                        
                        if(availableChannels.size > 0) {
                            // Use the first available channel
                            outChan = availableChannels.asArray.sort[0];
                        } {
                            // If all channels are in use, use a modulo approach
                            outChan = numNotesPlaying % 16;
                        };
                        
                        // Store the channel assignment
                        activeNotes[pitch] = outChan;
                    };
                } {
                    outChan = 0; // Single channel mode
                };
                
                // Only process the note if shouldProcessNote is true
                if(shouldProcessNote) {
                    // Use the incoming MIDI velocity instead of the fixed value
                    // Store it for potential future use
                    // Determine effective velocity based on manualVelocityMode
                    if(manualVelocityMode) {
                        effectiveVelocity = manualVelocityValue;
                    } {
                        effectiveVelocity = veloc; // Use incoming velocity from MIDI event
                    };

                    // Update the main 'velocity' instance variable to reflect the *effective* velocity used.
                    velocity = effectiveVelocity;

                    if(debug) {
                        ("NoteOn Received: pitch %, incoming vel %, effective vel %, chan %, src %")
                        .format(pitch, veloc, effectiveVelocity, chan, src).postln;
                    };
                    
                    if(glissandoMode) {
                        oscNetAddr.sendMsg('/glissOn', outChan, pitch);
                    } {
                        if(multiInstrumentMode && multiChannelMode && vstList.notNil) {
                            // In multi-instrument mode, send to the VST that corresponds to the channel
                            var vstIndex = outChan % vstList.size;
                            var vstKey = vstList.keys.asArray.sort[vstIndex]; // Use sorted keys for stable ordering
                            var vst = vstList[vstKey];
                            
                            if(vst.notNil) {
                                vst.midi.noteOn(0, pitch, effectiveVelocity); // Always use channel 0 for VST
                                if(debug) { "Note On: pitch % chan % vel % to VST %".format(pitch, outChan, veloc, vstKey).postln; };
                                
                                // Start bend if enabled
                                this.startBend(pitch, outChan);
                            };
                        } {
                            // Normal mode - send to all VSTs
                            vstList.do { |vst| 
                                vst.midi.noteOn(0, pitch, effectiveVelocity); // Always use channel 0 for VST
                            };
                            
                            // Start bend if enabled
                            this.startBend(pitch, outChan);
                        };
                        
                        if(oscNetAddr.notNil) {
                            oscNetAddr.sendMsg('/keyOn', outChan, pitch, effectiveVelocity); // Include effective velocity in OSC message
                        };
                    };
                    
                    numNotesPlaying = numNotesPlaying + 1;
                    if(debug && multiInstrumentMode.not) { "Note On: pitch % chan % vel %".format(pitch, outChan, veloc).postln; };
                } { 
                    // Note was skipped (retrigger in multi-instrument mode)
                    if(debug) { "Note On skipped - retrigger prevented".postln; };
                };
            } { 
                // Note handling is disabled, do nothing
                if(debug) { "Note On ignored - note handling disabled".postln; };
            };
        });

        // Note Off
        midiFuncs[\noteOff] = MIDIFunc.noteOff({ |veloc, pitch, chan|
            var outChan;
            
            // Skip processing if note handling is disabled
            if(noteHandlingEnabled) {
                // Retrieve the channel this note was assigned to
                if(multiChannelMode) {
                    if(activeNotes.includesKey(pitch)) {
                        outChan = activeNotes[pitch];
                        activeNotes.removeAt(pitch); // Remove tracking
                        
                        // Reset bend before note off
                        this.resetBend(outChan);
                        
                        if(multiInstrumentMode && multiChannelMode && vstList.notNil) {
                            // In multi-instrument mode, send to the VST that corresponds to the channel
                            var vstIndex = outChan % vstList.size;
                            var vstKey = vstList.keys.asArray.sort[vstIndex]; // Use sorted keys for stable ordering
                            var vst = vstList[vstKey];
                            
                            if(vst.notNil) {
                                vst.midi.noteOff(0, pitch, veloc); // Always use channel 0 for VST
                                if(debug) { "Note Off: pitch % chan % from VST %".format(pitch, outChan, vstKey).postln; };
                            };
                        } {
                            // Normal mode - send to all VSTs
                            vstList.do { |vst| 
                                vst.midi.noteOff(0, pitch, veloc); // Always use channel 0 for VST
                            };
                        };
                        
                        if(oscNetAddr.notNil) {
                            oscNetAddr.sendMsg('/keyOff', outChan, pitch);
                        };
                        
                        numNotesPlaying = max(0, numNotesPlaying - 1);
                        if(debug && multiInstrumentMode.not) { "Note Off: pitch % chan %".format(pitch, outChan).postln; };
                    } {
                        // This pitch is not tracked (already released or duplicate noteOff)
                        if(debug) { "Note Off ignored for pitch % (already released or duplicate)".format(pitch).postln; };
                    };
                } {
                    outChan = 0;
                    
                    // Reset bend before note off
                    this.resetBend(outChan);
                    
                    if(multiInstrumentMode && multiChannelMode && vstList.notNil) {
                        // In multi-instrument mode, send to the VST that corresponds to the channel
                        var vstIndex = outChan % vstList.size;
                        var vstKey = vstList.keys.asArray.sort[vstIndex]; // Use sorted keys for stable ordering
                        var vst = vstList[vstKey];
                        
                        if(vst.notNil) {
                            vst.midi.noteOff(0, pitch, veloc); // Always use channel 0 for VST
                            if(debug) { "Note Off: pitch % chan % from VST %".format(pitch, outChan, vstKey).postln; };
                        };
                    } {
                        // Normal mode - send to all VSTs
                        vstList.do { |vst| 
                            vst.midi.noteOff(0, pitch, veloc); // Always use channel 0 for VST
                        };
                    };
                    
                    if(oscNetAddr.notNil) {
                        oscNetAddr.sendMsg('/keyOff', outChan, pitch);
                    };
                    
                    numNotesPlaying = max(0, numNotesPlaying - 1);
                    if(debug && multiInstrumentMode.not) { "Note Off: pitch % chan %".format(pitch, outChan).postln; };
                };
            } {
                // Note handling is disabled, do nothing
                if(debug) { "Note Off ignored - note handling disabled".postln; };
            };
        });

        // Pitch Bend
        midiFuncs[\bend] = MIDIFunc.bend({ |bendval, channel|
            channel = 0; // Always use channel 0 for VSTs
            bendval.postln;
            vstList.do { |item| 
                item.midi.bend(0, bendval); // Always use channel 0 for VST
            };
        });

        // MIDI CC (Control Change)
        midiFuncs[\control] = MIDIFunc.cc({ |val, num, chan, src|
            var normalizedVal;

            // Slider handling (existing logic, ensure it's compatible or adjust if needed)
            if(activePreset.notNil && activePreset.sliders.notNil) {
                var sliderIndex = activePreset.sliders.indexOf(num);
                if(sliderIndex.notNil) {
                    normalizedVal = val / 127.0;
                    if(sliderIndex < sliderValues.size) {
                        sliderValues[sliderIndex] = normalizedVal;
                    };
                    if(debug) {
                        "MIDIController Slider CC: % val: % (norm: %) chan: % src: %".format(num, val, normalizedVal, chan, src).postln;
                    };
                    if(oscNetAddr.notNil) {
                        oscNetAddr.sendMsg("/slider", sliderIndex, normalizedVal);
                    };
                };
            };

            // Handle knobs for the active preset
            if(activePreset.notNil && activePreset.knobs.notNil) {
                // Check if the CC number 'num' is one of the defined knobs for the current preset
                // For nanoKONTROL2, activePreset.knobs is a Range. For midiMix, it's an Array.
                var isDefinedKnob = if(activePreset.knobs.isKindOf(SequenceableCollection)) {
                    activePreset.knobs.includes(num);   
                } { false };

                if(isDefinedKnob) {
                    // Check if processing for this knob CC is temporarily disabled
                    if (this.isPresetKnobProcessingDisabled(num).not) {
                        normalizedVal = val / 127.0;

                        // Store value in dictionary using CC number as key
                        knobValues.put(num, normalizedVal);

                        if(debug) {
                            "MIDIController Knob CC: % val: % (norm: %) chan: % src: %".format(num, val, normalizedVal, chan, src).postln;
                        };
                        
                        // Send OSC message if oscNetAddr is set, using CC number
                        if(oscNetAddr.notNil) {
                            oscNetAddr.sendMsg("/knob", num, normalizedVal);
                        };
                    } {
                        if(debug) { ("MIDIController: Ignored disabled preset knob CC %").format(num).postln; };
                    }
                }
            }
        });

        // Initialize Buttons from active preset
        activePreset.buttons.keysValuesDo { |ccNum, action|
            var buttonKey = ("button_" ++ ccNum).asSymbol;
            
            this.debug("Setting up button for CC %".format(ccNum));
            
            midiFuncs[buttonKey] = MIDIFunc.cc({ |val, num, chan, src|
                var state = val > 0;
                this.debug("Button CC % %".format(ccNum, if(state, "pressed", "released")));
                
                // Toggle button state on press (val > 0)
                if(state) {
                    this.setButtonState(ccNum, buttonStates[ccNum].not ? false);
                };
            }, ccNum);
        };

        // All Notes Off Button (handled by button system now)
        // The actual MIDI mapping is set up in the buttons section above
    }

    // New method to enable/disable note handling without freeing the handlers
    setNoteHandlingEnabled { |enabled|
        noteHandlingEnabled = enabled;
        if(debug) {
            if(enabled) {
                "MIDIController: Note handling ENABLED".postln;
            } {
                "MIDIController: Note handling DISABLED".postln;
            };
        };
    }

    // Method to process all knobs with a function
    processKnobs { |func|
        knobValues.keysValuesDo { |cc, val|
            func.value(cc, val);
        };
    }

    // Method to set a specific knob's value
    setKnob { |cc, value|
        knobValues.put(cc, value);
        oscNetAddr.sendMsg(("/knob" ++ cc).asSymbol, value);
    }

    free {
        this.freeBend;
        midiFuncs.do(_.free);
    }

    stop{ 
        controlRoutine.stop;
         }

    setGlissandoMode { |bool|
        glissandoMode = bool;
    }

    setGlissandoNoteMode { |bool|
        glissandoNoteMode = bool;
    }

    // Method to start continuous VST parameter mapping
    startVSTMapping { |vstMappings, ccMappings, rate = 0.02|
        this.debug("Starting VST mapping");
        
        pollRate = rate;
        controlRoutine.stop;
        
        // If old-style single VST mapping is provided, convert to new format
        if(vstMappings.isKindOf(Symbol)) {
            var vstKey = vstMappings;
            var mappings = ccMappings ?? {[
                [0, 16, 0],
                [0, 17, 1],
                [0, 18, 2]
            ]};
            vstMappings = Dictionary.new;
            vstMappings[vstKey] = mappings;
        };
        
        // Default mapping if none provided
        vstMappings = vstMappings ?? {Dictionary[\vsti -> [
            [0, 16, 0],
            [0, 17, 1],
            [0, 18, 2]
        ]]};
        
        if(debug) {
            "VST Mappings:".postln;
            vstMappings.keysValuesDo { |vstKey, mappings|
                "VST: %".format(vstKey).postln;
                mappings.do { |mapping|
                    "Channel: %, CC: %, Knob: % (current value: %)"
                    .format(mapping[0], mapping[1], mapping[2], knobValues[mapping[2]])
                    .postln;
                };
            };
        };
        
        controlRoutine = Routine({
            inf.do {
                vstMappings.keysValuesDo { |vstKey, mappings|
                    var vst = vstList.at(vstKey);
                    if(vst.notNil) {
                        mappings.do { |mapping|
                            var chan, cc, knobIndex;
                            #chan, cc, knobIndex = mapping;
                            
                            this.debug("Sending to VST '%': chan %, cc %, knobIndex %, value %"
                                .format(vstKey, chan, cc, knobIndex, knobValues[knobIndex]));
                            
                            vst.midi.control(
                                chan, 
                                cc, 
                                knobValues[knobIndex]
                            );
                        };
                    };
                };
                pollRate.wait;
            }
        }).play;
    }
    
    // Method to change polling rate while running
    setPollRate { |newRate|
        pollRate = newRate;
    }

    // Method to toggle debug mode
    setDebug { |bool|
        debug = bool;
        this.debug("Debug mode %".format(if(bool, "enabled", "disabled")));
    }

    // Method to toggle multi-channel mode
    setMultiChannelMode { |bool|
        multiChannelMode = bool;
        // Clear active notes when changing mode
        activeNotes.clear;
        this.debug("Multi-channel mode %".format(if(bool, "enabled", "disabled")));
        
        // Disable multi-instrument mode if multi-channel mode is disabled
        if(bool.not && multiInstrumentMode) {
            multiInstrumentMode = false;
            this.debug("Multi-instrument mode disabled (requires multi-channel mode)");
        };
    }
    
    // Method to toggle multi-instrument mode
    setMultiInstrumentMode { |bool|
        if(bool && multiChannelMode.not) {
            this.debug("Cannot enable multi-instrument mode without multi-channel mode");
            ^this;
        };
        
        multiInstrumentMode = bool;
        this.debug("Multi-instrument mode %".format(if(bool, "enabled", "disabled")));
    }

    // Method to update the list of VSTs the controller targets
    updateVSTList { |newVstList|
        vstList = newVstList;
        if(vstList.isNil) {
            this.debug("MIDIController: VST list updated with nil!");
        } {
            this.debug("MIDIController: VST list updated. Count: %. VST Names: %".format(vstList.size, vstList.keys.asArray));
        };
    }

    // Initialize controller presets
    initControllerPresets {
        controllerPresets = (
            midiMix: (
                name: "Akai MIDIMix",
                // 1-9 sliders (1-based index)
                sliders: [19,23,27,31,49,53,57,61,62],  // CC numbers for sliders 1-9 (Slider 9 is Master Fader)
                
                // Knobs organized by rows (1-8 columns x 3 rows)
                knobRows: [
                    // Row 1 (top row of knobs) - CC: 16,20,24,28,46,50,54,58
                    [16,20,24,28,46,50,54,58],
                    // Row 2 (middle row of knobs) - CC: 17,21,25,29,47,51,55,59
                    [17,21,25,29,47,51,55,59],
                    // Row 3 (bottom row of knobs) - CC: 18,22,26,30,48,52,56,60
                    [18,22,26,30,48,52,56,60]
                ],
                
                // For backward compatibility, provide a flat list of all knobs (0-23)
                knobs: { 
                    var allKnobs = Array.new(24);
                    // Flatten the rows into a single array
                    [
                        [16,17,18],  // Column 1 (top to bottom)
                        [20,21,22],  // Column 2
                        [24,25,26],  // Column 3
                        [28,29,30],  // Column 4
                        [46,47,48],  // Column 5
                        [50,51,52],  // Column 6
                        [54,55,56],  // Column 7
                        [58,59,60]   // Column 8
                    ].do { |col| allKnobs = allKnobs ++ col };
                    allKnobs;
                }.value,
                
                buttons: ()
            )
        );
    }
    
    // Set the active controller preset
    setControllerPreset { |presetName|
        var newPreset = controllerPresets[presetName];
        
        if (newPreset.notNil) {
            // Free existing MIDI funcs
            midiFuncs.do(_.free);
            midiFuncs = IdentityDictionary.new;
            
            // Set new preset
            activePreset = newPreset;
            activePresetName = presetName;
            this.debug("Controller preset set to: %".format(activePreset.name));
            
            // Reinitialize MIDI funcs with new preset
            this.initMIDIFuncs;
            ^true;
        } {
            this.debug("Controller preset not found: %".format(presetName));
            ^false;
        };
    }
    
    // Get the name of the current controller preset
    getControllerPreset {
        ^activePresetName;
    }
    
    // List all available controller presets
    listControllerPresets {
        this.debug("Available controller presets:");
        controllerPresets.keysValuesDo { |key, preset|
            "%: %".format(key, preset.name).postln;
        };
    }
    
    // ========== MIDIMix-Specific Access Methods (and general row/pos access) ==========    
    // Method to get knob value by row (1-3) and position (1-8)
    getKnobRow { |row=1, pos=1| // 1-based indexing for row and position (MIDIMix only)
        var midiMixRows = [
            [16,20,24,28,46,50,54,58],  // Row 1 CCs
            [17,21,25,29,47,51,55,59],  // Row 2 CCs
            [18,22,26,30,48,52,56,60]   // Row 3 CCs
        ];

        // Guard against out-of-range access; return neutral 0.5 on error
        if(row < 1 || row > 3 || pos < 1 || pos > 8) { ^0.5 };

        ^this.getKnobValueByCC(midiMixRows[row-1][pos-1]);
    }
    
    // Get knob value from row 1 (top row, knobs 1-8)
    getKnobRow1 { |pos=1| // Takes 1-based position
        ^this.getKnobRow(1, pos);
    }
    
    // Get knob value from row 2 (middle row, knobs 1-8)
    getKnobRow2 { |pos=1| // Takes 1-based position
        ^this.getKnobRow(2, pos);
    }
    
    // Get knob value from row 3 (bottom row, knobs 1-8)
    getKnobRow3 { |pos=1| // Takes 1-based position
        ^this.getKnobRow(3, pos);
    }

    // Bend calculation helper
    calcBendValue { |fromNote, toNote, currentBend=8192|
        var semitones = toNote - fromNote;
        var unitsPerSemitone = 682;  // 8192/12 = 682.666... units per semitone
        var bendOffset = semitones * unitsPerSemitone;
        var bendValue;

        // Calculate relative to current bend position
        bendValue = currentBend + bendOffset;
        bendValue = bendValue.clip(0, 16383).asInteger;

        // For debugging
        if(debug) {
            ["Bend calculation:",
                "From:", fromNote,
                "To:", toNote,
                "Semitones:", semitones,
                "Current:", currentBend,
                "Offset:", bendOffset,
                "Final:", bendValue
            ].postln;
        };

        ^bendValue;
    }

    // Bend control methods
    setBendEnabled { |bool|
        bendEnabled = bool;
        this.debug("Bend mode %".format(if(bool, "enabled", "disabled")));
    }

    setBendRange { |semitones|
        bendRange = semitones;
        this.debug("Bend range set to % semitones".format(semitones));
    }

    setBendDuration { |seconds|
        bendDuration = seconds;
        this.debug("Bend duration set to % seconds".format(seconds));
    }

    setBendCurve { |curve|
        bendCurve = curve;
        this.debug("Bend curve set to %".format(curve));
    }

    // Start bend for a note
    startBend { |pitch, outChan|
        var targetPitch, startBend, targetBend;
        
        if(bendEnabled.not) { ^this };
        
        targetPitch = pitch + bendRange;
        startBend = 8192;  // Center position
        targetBend = this.calcBendValue(pitch, targetPitch, startBend);
        
        if(debug) {
            ["Starting Bend:",
                "Channel:", outChan,
                "Current Pitch:", pitch,
                "Target Pitch:", targetPitch,
                "Start Bend:", startBend,
                "Target Bend:", targetBend
            ].postln;
        };
        
        // Start the bend envelope
        bendEnvelopeSynth = Synth(\BendEnvelope1, [
            \start, startBend,
            \end, targetBend,
            \dur, bendDuration,
            \chanIndex, outChan
        ]);
    }

    // Reset bend for a note
    resetBend { |outChan|
        var vstIndex, vstKey, vst;
        
        if(bendEnabled.not) { ^this };
        
        if(debug) {
            "Resetting bend for channel: %".format(outChan).postln;
        };
        
        // Reset bend to center
        if(multiInstrumentMode && multiChannelMode && vstList.notNil) {
            vstIndex = outChan % vstList.size;
            vstKey = vstList.keys.asArray.sort[vstIndex]; // Use sorted keys for stable ordering
            vst = vstList[vstKey];
            
            if(vst.notNil) {
                vst.midi.bend(0, 8192); // Always use channel 0 for VST
            };
        } {
            vstList.do { |vst| 
                vst.midi.bend(0, 8192); // Always use channel 0 for VST
            };
        };
    }

    // Free bend resources
    freeBend {
        if(bendEnvelopeSynth.notNil) {
            bendEnvelopeSynth.free;
            bendEnvelopeSynth = nil;
        };
    }

    // Register a button toggle with callback
    registerButtonToggle { |ccNum, initialState=false, description, callback|
        var buttonKey = ("button_cc" ++ ccNum).asSymbol;
        
        this.debug("Registering button toggle for CC % (%)"
            .format(ccNum, description ? "unnamed button"));
        
        // Store initial state
        buttonStates[ccNum] = initialState;
        
        // Store callback if provided
        if(callback.notNil) {
            buttonCallbacks[ccNum] = callback;
        };
        
        // Create CC handler if not already present
        if(midiFuncs[buttonKey].isNil) {
            midiFuncs[buttonKey] = MIDIFunc.cc({ |val, num, chan, src|
                var isOn = val > 0;
                
                // Only update if value changed (toggle occurred)
                if(isOn != buttonStates[ccNum]) {
                    this.debug("Button CC % toggled to %".format(ccNum, if(isOn, "ON", "OFF")));
                    
                    // Update state
                    buttonStates[ccNum] = isOn;
                    
                    // Execute callback if registered
                    buttonCallbacks[ccNum].value(isOn);
                };
            }, ccNum);
        };
        
        ^this;
    }
    
    // Get the current state of a button
    getButtonState { |ccNum|
        ^buttonStates[ccNum] ? false;
    }
    
    // Set button state programmatically
    setButtonState { |ccNum, state, executeCallback=true|
        if(buttonStates.includesKey(ccNum)) {
            buttonStates[ccNum] = state;
            
            if(executeCallback && buttonCallbacks.includesKey(ccNum)) {
                buttonCallbacks[ccNum].value(state);
            };
            
            this.debug("Button CC % set to %".format(ccNum, if(state, "ON", "OFF")));
        } {
            this.debug("Button CC % not registered".format(ccNum));
        };
    }
    
    // Debug method to print current slider and knob values
    printCurrentValues {
        this.debug("Current slider values: %".format(sliderValues));
        this.debug("Current knob values: %".format(knobValues));
        if(buttonStates.size > 0) {
            this.debug("Button states:");
            buttonStates.keysValuesDo { |ccNum, state|
                this.debug("  CC %: %".format(ccNum, if(state, "ON", "OFF")));
            };
        };
        if(programmedMode) {
            this.debug("Programmed mode is ACTIVE with snapshot: %".format(currentSnapshot));
            if(currentSnapshot.notNil) {
                var snapshot = snapshots.at(currentSnapshot);
                if(snapshot.notNil) {
                    this.debug("Snapshot values - Sliders: %, Knobs: %".format(
                        snapshot.at(\sliders), 
                        snapshot.at(\knobs)
                    ));
                };
            };
        } {
            this.debug("Programmed mode is INACTIVE");
        };
    }

    // Method to toggle manual velocity mode
    setManualVelocityMode { |bool|
        manualVelocityMode = bool.asBoolean;
        if(debug) {
            ("MIDIController: Manual velocity mode " ++ if(manualVelocityMode, "ENABLED", "DISABLED")).postln;
        };
        ^this;
    }

    // Method to set the manual velocity value
    setManualVelocity { |val|
        manualVelocityValue = val.asInteger.clip(0, 127); // Ensure velocity is within MIDI range 0-127
        if(debug) {
            ("MIDIController: Manual velocity value set to %").format(manualVelocityValue).postln;
        };
        // If manual mode is not active, the new value will take effect when it's enabled.
        ^this;
    }

    // Methods to enable/disable processing for specific preset-defined knob CCs
    enablePresetKnobProcessing { |ccNum|
        disabledKnobCCs.remove(ccNum);
        if(debug) { ("MIDIController: Enabled preset knob processing for CC: %").format(ccNum).postln; };
        ^this;
    }

    disablePresetKnobProcessing { |ccNum|
        disabledKnobCCs.add(ccNum);
        if(debug) { ("MIDIController: Disabled preset knob processing for CC: %").format(ccNum).postln; };
        ^this;
    }

    isPresetKnobProcessingDisabled { |ccNum|
        ^disabledKnobCCs.includes(ccNum);
    }
}
