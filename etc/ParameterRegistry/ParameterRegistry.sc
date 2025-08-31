// ParameterRegistry.sc
// Central parameter storage and management system
// Supports multiple address types (MIDI CC, OSC, semantic) and input sources

LiveParameterRegistry {
    var <parameters;          // Dictionary of parameter definitions
    var <values;             // Dictionary of current parameter values  
    var <addresses;          // Dictionary mapping addresses to parameter IDs
    var <changeCallbacks;    // Parameter change notification system
    var <inputSources;       // Dictionary of enabled input sources per parameter
    var <metadata;           // Parameter metadata (ranges, types, descriptions)
    var <debugMode;
    
    *new { |debug=false|
        ^super.new.init(debug);
    }
    
    init { |inDebug|
        debugMode = inDebug;
        parameters = Dictionary.new;
        values = Dictionary.new;
        addresses = Dictionary.new;
        changeCallbacks = Dictionary.new;
        inputSources = Dictionary.new;
        metadata = Dictionary.new;
        
        this.debugLog("LiveParameterRegistry initialized");
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         CORE PARAMETER MANAGEMENT                           │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Register a new parameter with specification and metadata
    registerParameter { |id, spec=nil, paramMetadata=nil|
        var paramSpec, meta;
        
        paramSpec = spec ?? { ControlSpec(0, 1, \lin, 0, 0) };
        meta = paramMetadata ?? { Dictionary.new };
        
        parameters[id] = paramSpec;
        values[id] = paramSpec.default;
        metadata[id] = meta;
        inputSources[id] = Set.new;  // Empty set = all sources enabled
        changeCallbacks[id] = [];
        
        this.debugLog("Registered parameter: % with spec %".format(id, paramSpec));
        
        ^id;
    }
    
    // Update parameter value with source tracking and validation
    updateParameter { |id, value, source=\unknown, force=false|
        var paramSpec, oldValue, newValue, isEnabled;
        
        if (parameters[id].isNil) {
            this.debugLog("Warning: Attempted to update unregistered parameter: %".format(id));
            ^false;
        };
        
        // Check if this input source is enabled for this parameter
        isEnabled = this.isInputSourceEnabled(id, source);
        if (isEnabled.not and: { force.not }) {
            this.debugLog("Input source % is disabled for parameter %".format(source, id));
            ^false;
        };
        
        paramSpec = parameters[id];
        oldValue = values[id];
        
        // Validate and constrain value  
        newValue = paramSpec.constrain(value);
        
        if (newValue != oldValue or: { force }) {
            values[id] = newValue;
            this.notifyParameterChange(id, oldValue, newValue, source);
            this.debugLog("Parameter % updated: % -> % (source: %)".format(id, oldValue, newValue, source));
            ^true;
        } {
            ^false;  // No change
        };
    }
    
    // Get current parameter value
    getParameterValue { |id|
        ^values[id];
    }
    
    // Get parameter specification
    getParameterSpec { |id|
        ^parameters[id];
    }
    
    // Get parameter metadata
    getParameterMetadata { |id|
        ^metadata[id];
    }
    
    // Get all registered parameter IDs
    getParameterIDs {
        ^parameters.keys.asArray.sort;
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         ADDRESS MANAGEMENT                                  │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Add an address mapping for a parameter
    addAddress { |parameterId, addressType, address|
        var addressKey = this.makeAddressKey(addressType, address);
        
        if (parameters[parameterId].isNil) {
            this.debugLog("Warning: Cannot add address for unregistered parameter: %".format(parameterId));
            ^false;
        };
        
        addresses[addressKey] = parameterId;
        this.debugLog("Added address mapping: % -> %".format(addressKey, parameterId));
        ^true;
    }
    
    // Remove an address mapping
    removeAddress { |parameterId, addressType, address=nil|
        var addressKey;
        
        if (address.notNil) {
            addressKey = this.makeAddressKey(addressType, address);
            addresses.removeAt(addressKey);
            this.debugLog("Removed address mapping: %".format(addressKey));
        } {
            // Remove all addresses of this type for this parameter
            var keysToRemove = [];
            addresses.keysValuesDo { |key, paramId|
                if ((paramId == parameterId) and: { key.beginsWith(addressType.asString ++ ":") }) {
                    keysToRemove = keysToRemove.add(key);
                };
            };
            keysToRemove.do { |key| addresses.removeAt(key) };
            this.debugLog("Removed all % addresses for parameter %".format(addressType, parameterId));
        };
    }
    
    // Find parameter ID by address
    getParameterByAddress { |addressType, address|
        var addressKey = this.makeAddressKey(addressType, address);
        ^addresses[addressKey];
    }
    
    // Get all addresses for a parameter
    getParameterAddresses { |parameterId|
        var paramAddresses = Dictionary.new;
        addresses.keysValuesDo { |addressKey, paramId|
            if (paramId == parameterId) {
                var parts = addressKey.split($:);
                var addressType = parts[0].asSymbol;
                var address = parts[1];
                if (paramAddresses[addressType].isNil) {
                    paramAddresses[addressType] = [];
                };
                paramAddresses[addressType] = paramAddresses[addressType].add(address);
            };
        };
        ^paramAddresses;
    }
    
    // Helper method to create address keys
    makeAddressKey { |addressType, address|
        ^(addressType.asString ++ ":" ++ address.asString);
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         INPUT SOURCE CONTROL                                │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Enable an input source for a parameter (empty set = all sources enabled)
    enableInputSource { |parameterId, source|
        if (parameters[parameterId].isNil) {
            this.debugLog("Warning: Cannot enable input source for unregistered parameter: %".format(parameterId));
            ^false;
        };
        
        inputSources[parameterId].remove(source);  // Remove from disabled set
        this.debugLog("Enabled input source % for parameter %".format(source, parameterId));
        ^true;
    }
    
    // Disable an input source for a parameter
    disableInputSource { |parameterId, source|
        if (parameters[parameterId].isNil) {
            this.debugLog("Warning: Cannot disable input source for unregistered parameter: %".format(parameterId));
            ^false;
        };
        
        inputSources[parameterId].add(source);  // Add to disabled set
        this.debugLog("Disabled input source % for parameter %".format(source, parameterId));
        ^true;
    }
    
    // Check if input source is enabled (true if not explicitly disabled)
    isInputSourceEnabled { |parameterId, source|
        var disabledSources = inputSources[parameterId];
        if (disabledSources.isNil) { ^true };  // Parameter not found, assume enabled
        ^disabledSources.includes(source).not;
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         CHANGE NOTIFICATION                                 │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Register callback for parameter changes
    onParameterChange { |parameterId, callback|
        if (changeCallbacks[parameterId].isNil) {
            changeCallbacks[parameterId] = [];
        };
        changeCallbacks[parameterId] = changeCallbacks[parameterId].add(callback);
        this.debugLog("Registered change callback for parameter %".format(parameterId));
    }
    
    // Remove callback for parameter changes
    removeParameterChangeCallback { |parameterId, callback|
        if (changeCallbacks[parameterId].notNil) {
            changeCallbacks[parameterId].remove(callback);
        };
    }
    
    // Notify all callbacks of parameter change
    notifyParameterChange { |parameterId, oldValue, newValue, source|
        var callbacks = changeCallbacks[parameterId];
        if (callbacks.notNil) {
            callbacks.do { |callback|
                try {
                    callback.value(parameterId, oldValue, newValue, source);
                } { |error|
                    this.debugLog("Error in parameter change callback for %: %".format(parameterId, error.errorString));
                };
            };
        };
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UTILITY METHODS                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Debug logging
    debugLog { |message|
        if (debugMode) {
            "[LiveParameterRegistry] %".format(message).postln;
        };
    }
    
    // Print current registry state
    printState {
        "=== ParameterRegistry State ===".postln;
        "Parameters: %".format(parameters.size).postln;
        parameters.keysValuesDo { |id, spec|
            "  %: % = %".format(id, spec, values[id]).postln;
        };
        
        "Addresses: %".format(addresses.size).postln;
        addresses.keysValuesDo { |addressKey, paramId|
            "  % -> %".format(addressKey, paramId).postln;
        };
        
        "Input Sources:".postln;
        inputSources.keysValuesDo { |paramId, disabledSources|
            if (disabledSources.size > 0) {
                "  % (disabled: %)".format(paramId, disabledSources.asArray).postln;
            } {
                "  % (all sources enabled)".format(paramId).postln;
            };
        };
        "===============================".postln;
    }
    
    // Cleanup method
    free {
        parameters.clear;
        values.clear;
        addresses.clear;
        changeCallbacks.clear;
        inputSources.clear;
        metadata.clear;
        this.debugLog("ParameterRegistry freed");
    }
}