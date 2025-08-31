// InputRouter.sc
// Routes input from multiple sources (MIDI, OSC, etc.) to parameters
// Handles input source priorities and conflict resolution

LiveInputRouter {
    var <parameterRegistry;
    var <inputSources;       // Dictionary of registered input sources
    var <sourcePriorities;   // Dictionary of source priorities (higher = more priority)
    var <activeInputs;       // Dictionary tracking active inputs per parameter
    var <debugMode;
    
    *new { |parameterRegistry, debug=false|
        ^super.new.init(parameterRegistry, debug);
    }
    
    init { |registry, inDebug|
        parameterRegistry = registry;
        debugMode = inDebug;
        inputSources = Dictionary.new;
        sourcePriorities = Dictionary.new;
        activeInputs = Dictionary.new;
        
        this.debugLog("LiveInputRouter initialized");
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         INPUT SOURCE MANAGEMENT                             │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Register an input source with handler and priority
    registerInputSource { |sourceName, handler, priority=0|
        inputSources[sourceName] = (
            handler: handler,
            priority: priority,
            enabled: true
        );
        sourcePriorities[sourceName] = priority;
        
        this.debugLog("Registered input source: % (priority: %)".format(sourceName, priority));
        ^sourceName;
    }
    
    // Unregister an input source
    unregisterInputSource { |sourceName|
        var keysToRemove = [];
        
        inputSources.removeAt(sourceName);
        sourcePriorities.removeAt(sourceName);
        
        // Clean up active inputs for this source
        activeInputs.keysValuesDo { |paramId, sourceInfo|
            if (sourceInfo.source == sourceName) {
                keysToRemove = keysToRemove.add(paramId);
            };
        };
        keysToRemove.do { |key| activeInputs.removeAt(key) };
        
        this.debugLog("Unregistered input source: %".format(sourceName));
    }
    
    // Enable/disable an input source
    enableInputSource { |sourceName, enabled=true|
        var source = inputSources[sourceName];
        if (source.notNil) {
            source.enabled = enabled;
            this.debugLog("Input source % %".format(sourceName, if(enabled, "enabled", "disabled")));
            ^true;
        } {
            this.debugLog("Warning: Attempted to modify unknown input source: %".format(sourceName));
            ^false;
        };
    }
    
    // Set priority for an input source
    setSourcePriority { |sourceName, priority|
        var source = inputSources[sourceName];
        if (source.notNil) {
            source.priority = priority;
            sourcePriorities[sourceName] = priority;
            this.debugLog("Set priority for source % to %".format(sourceName, priority));
            ^true;
        } {
            this.debugLog("Warning: Attempted to set priority for unknown input source: %".format(sourceName));
            ^false;
        };
    }
    
    // Get list of registered input sources
    getInputSources {
        ^inputSources.keys.asArray.sort;
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         INPUT ROUTING                                       │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Route input from a source to a parameter
    routeInput { |sourceName, addressType, address, value, timestamp=nil|
        var parameterId, source, currentInput, shouldUpdate;
        
        // Check if source is registered and enabled
        source = inputSources[sourceName];
        if (source.isNil) {
            this.debugLog("Warning: Input from unregistered source: %".format(sourceName));
            ^false;
        };
        
        if (source.enabled.not) {
            this.debugLog("Input from disabled source ignored: %".format(sourceName));
            ^false;
        };
        
        // Find parameter ID by address
        parameterId = parameterRegistry.getParameterByAddress(addressType, address);
        if (parameterId.isNil) {
            this.debugLog("Warning: No parameter found for address %:%".format(addressType, address));
            ^false;
        };
        
        // Check input source conflict resolution
        shouldUpdate = this.resolveParameterConflict(parameterId, sourceName, timestamp);
        
        if (shouldUpdate) {
            // Update parameter value
            var success = parameterRegistry.updateParameter(parameterId, value, sourceName);
            if (success) {
                // Track this input as active
                activeInputs[parameterId] = (
                    source: sourceName,
                    timestamp: timestamp ?? { Main.elapsedTime },
                    priority: source.priority
                );
                this.debugLog("Routed input: %:% -> % = % (source: %)".format(
                    addressType, address, parameterId, value, sourceName
                ));
            };
            ^success;
        } {
            this.debugLog("Input ignored due to conflict resolution: %:%".format(addressType, address));
            ^false;
        };
    }
    
    // Direct parameter update (bypasses address lookup)
    updateParameterDirect { |parameterId, value, sourceName, timestamp=nil|
        var source, shouldUpdate, success;
        
        // Check if source is registered and enabled
        source = inputSources[sourceName];
        if (source.isNil) {
            this.debugLog("Warning: Direct input from unregistered source: %".format(sourceName));
            ^false;
        };
        
        if (source.enabled.not) {
            this.debugLog("Direct input from disabled source ignored: %".format(sourceName));
            ^false;
        };
        
        // Check input source conflict resolution
        shouldUpdate = this.resolveParameterConflict(parameterId, sourceName, timestamp);
        
        if (shouldUpdate) {
            success = parameterRegistry.updateParameter(parameterId, value, sourceName);
            if (success) {
                activeInputs[parameterId] = (
                    source: sourceName,
                    timestamp: timestamp ?? { Main.elapsedTime },
                    priority: source.priority
                );
                this.debugLog("Direct parameter update: % = % (source: %)".format(
                    parameterId, value, sourceName
                ));
            };
            ^success;
        } {
            ^false;
        };
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         CONFLICT RESOLUTION                                 │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Resolve conflicts when multiple sources try to control the same parameter
    resolveParameterConflict { |parameterId, sourceName, timestamp=nil|
        var currentInput, newPriority, currentPriority, timeDiff;
        var conflictTimeoutSec = 2.0;  // Time before lower priority input can override
        
        currentInput = activeInputs[parameterId];
        
        // No current input - allow this input
        if (currentInput.isNil) {
            ^true;
        };
        
        // Same source - always allow
        if (currentInput.source == sourceName) {
            ^true;
        };
        
        // Check priorities
        newPriority = sourcePriorities[sourceName] ? 0;
        currentPriority = currentInput.priority ? 0;
        
        // Higher priority always wins
        if (newPriority > currentPriority) {
            this.debugLog("Higher priority input overrides: % (%) > % (%)".format(
                sourceName, newPriority, currentInput.source, currentPriority
            ));
            ^true;
        };
        
        // Lower priority - check timeout
        if (newPriority < currentPriority) {
            timeDiff = (timestamp ?? { Main.elapsedTime }) - currentInput.timestamp;
            if (timeDiff > conflictTimeoutSec) {
                this.debugLog("Lower priority input allowed after timeout: % seconds".format(timeDiff));
                ^true;
            } {
                this.debugLog("Lower priority input blocked (timeout: %/% seconds)".format(
                    timeDiff.round(0.1), conflictTimeoutSec
                ));
                ^false;
            };
        };
        
        // Equal priority - allow (last wins)
        ^true;
    }
    
    // Clear active input for a parameter (allows any source to control it)
    clearActiveInput { |parameterId|
        activeInputs.removeAt(parameterId);
        this.debugLog("Cleared active input for parameter: %".format(parameterId));
    }
    
    // Get current active input source for a parameter
    getActiveInputSource { |parameterId|
        var input = activeInputs[parameterId];
        ^if(input.notNil, { input.source }, { nil });
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UTILITY METHODS                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Debug logging
    debugLog { |message|
        if (debugMode) {
            "[LiveInputRouter] %".format(message).postln;
        };
    }
    
    // Print current router state
    printState {
        "=== InputRouter State ===".postln;
        
        "Input Sources: %".format(inputSources.size).postln;
        inputSources.keysValuesDo { |name, info|
            "  %: priority=%, enabled=%".format(name, info.priority, info.enabled).postln;
        };
        
        "Active Inputs: %".format(activeInputs.size).postln;
        activeInputs.keysValuesDo { |paramId, info|
            var timeSince = (Main.elapsedTime - info.timestamp).round(0.1);
            "  %: source=%, priority=%, age=%s".format(
                paramId, info.source, info.priority, timeSince
            ).postln;
        };
        
        "=========================".postln;
    }
    
    // Cleanup method
    free {
        inputSources.clear;
        sourcePriorities.clear;
        activeInputs.clear;
        this.debugLog("InputRouter freed");
    }
}