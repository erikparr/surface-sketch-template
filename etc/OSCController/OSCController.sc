// OSCController.sc
// Manages OSC integration for parameter control
// Generates OSC addresses, handles OSC input, provides bidirectional sync

LiveOSCController {
    var <inputRouter;
    var <parameterRegistry;
    var <oscFuncs;           // Dictionary of OSC responder functions
    var <addressMappings;    // Dictionary of parameterId -> OSC address mappings
    var <enabledParameters;  // Set of parameters enabled for OSC control
    var <oscPort;
    var <debugMode;
    var <bidirectionalSync;  // Enable sending parameter changes back via OSC
    var <oscClients;         // List of OSC client addresses for broadcasting
    
    *new { |inputRouter, parameterRegistry, oscPort=57121, debug=false|
        ^super.new.init(inputRouter, parameterRegistry, oscPort, debug);
    }
    
    init { |router, registry, port, inDebug|
        inputRouter = router;
        parameterRegistry = registry;
        oscPort = port;
        debugMode = inDebug;
        
        oscFuncs = Dictionary.new;
        addressMappings = Dictionary.new;
        enabledParameters = Set.new;
        bidirectionalSync = false;
        oscClients = [];
        
        // Register as input source with medium priority
        inputRouter.registerInputSource(\osc, this, priority: 10);
        
        this.debugLog("LiveOSCController initialized on port %".format(oscPort));
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         OSC PARAMETER CONTROL                               │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Enable OSC control for a parameter
    enableParameter { |parameterId, oscAddress=nil|
        var address, oscFunc;
        
        if (parameterRegistry.getParameterSpec(parameterId).isNil) {
            this.debugLog("Warning: Cannot enable OSC for unregistered parameter: %".format(parameterId));
            ^false;
        };
        
        // Generate OSC address if not provided
        address = oscAddress ?? { this.generateOSCAddress(parameterId) };
        
        // Store the mapping
        addressMappings[parameterId] = address;
        enabledParameters.add(parameterId);
        
        // Add address to parameter registry
        parameterRegistry.addAddress(parameterId, \osc, address);
        
        // Create OSC responder
        oscFunc = OSCFunc({ |msg|
            var value = msg[1].asFloat;
            this.handleOSCInput(address, value);
        }, address.asSymbol);
        
        oscFuncs[parameterId] = oscFunc;
        
        this.debugLog("Enabled OSC control for parameter %: %".format(parameterId, address));
        ^address;
    }
    
    // Disable OSC control for a parameter
    disableParameter { |parameterId|
        var oscFunc, address;
        
        oscFunc = oscFuncs[parameterId];
        if (oscFunc.notNil) {
            oscFunc.free;
            oscFuncs.removeAt(parameterId);
        };
        
        address = addressMappings[parameterId];
        if (address.notNil) {
            parameterRegistry.removeAddress(parameterId, \osc, address);
            addressMappings.removeAt(parameterId);
        };
        
        enabledParameters.remove(parameterId);
        
        this.debugLog("Disabled OSC control for parameter %".format(parameterId));
        ^true;
    }
    
    // Check if parameter is enabled for OSC control
    isParameterEnabled { |parameterId|
        ^enabledParameters.includes(parameterId);
    }
    
    // Handle incoming OSC input
    handleOSCInput { |oscAddress, value|
        this.debugLog("Received OSC: % %".format(oscAddress, value));
        inputRouter.routeInput(\osc, \osc, oscAddress, value, Main.elapsedTime);
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         OSC ADDRESS MANAGEMENT                              │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Generate OSC address based on parameter ID
    generateOSCAddress { |parameterId|
        var parts, context, param, address;
        
        // Parse parameter ID format: "source_context_parameter"
        parts = parameterId.asString.split($_);
        
        if (parts.size >= 3) {
            var source = parts[0];
            context = parts[1];
            param = parts[2..].join("_");  // Handle multi-part parameter names
            
            address = case
                { source == "midi" } {
                    if (context.beginsWith("cc")) {
                        "/midi/cc/" ++ context[2..];  // "cc58" -> "/midi/cc/58"
                    } {
                        if (context.beginsWith("row")) {
                            "/midi/" ++ context ++ "/" ++ param;  // "row1_pos8" -> "/midi/row1/pos8"
                        } {
                            "/midi/" ++ context ++ "/" ++ param;
                        };
                    };
                }
                { source == "mapping" } {
                    "/mapping/" ++ context ++ "/" ++ param;
                }
                { source == "param" } {
                    "/param/" ++ context ++ "/" ++ param;
                }
                { source == "layer" } {
                    "/layer/" ++ context ++ "/" ++ param;
                }
                { // Default case
                    "/" ++ source ++ "/" ++ context ++ "/" ++ param;
                };
        } {
            // Fallback for simple parameter IDs
            address = "/param/" ++ parameterId;
        };
        
        ^address;
    }
    
    // Get OSC address for a parameter
    getOSCAddress { |parameterId|
        ^addressMappings[parameterId];
    }
    
    // Set custom OSC address for a parameter
    setCustomOSCAddress { |parameterId, address|
        var oldAddress = addressMappings[parameterId];
        
        if (oldAddress.notNil) {
            // Update existing mapping
            this.disableParameter(parameterId);
            this.enableParameter(parameterId, address);
        } {
            // Just store the custom address for future enablement
            addressMappings[parameterId] = address;
        };
        
        this.debugLog("Set custom OSC address for %: %".format(parameterId, address));
        ^address;
    }
    
    // Get all OSC addresses
    listOSCAddresses {
        var addresses = Dictionary.new;
        enabledParameters.do { |parameterId|
            addresses[parameterId] = addressMappings[parameterId];
        };
        ^addresses;
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         BIDIRECTIONAL SYNC                                  │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Enable/disable bidirectional sync
    setBidirectionalSync { |enabled|
        bidirectionalSync = enabled;
        
        if (enabled) {
            // Register for parameter change notifications
            parameterRegistry.getParameterIDs.do { |parameterId|
                parameterRegistry.onParameterChange(parameterId, { |id, oldVal, newVal, source|
                    if (source != \osc) {  // Don't echo back OSC changes
                        this.sendParameterUpdate(id, newVal);
                    };
                });
            };
        };
        
        this.debugLog("Bidirectional sync %".format(if(enabled, "enabled", "disabled")));
    }
    
    // Send parameter update via OSC
    sendParameterUpdate { |parameterId, value|
        var address;
        
        if (bidirectionalSync.not or: { this.isParameterEnabled(parameterId).not }) {
            ^this;
        };
        
        address = this.getOSCAddress(parameterId);
        if (address.notNil) {
            oscClients.do { |clientAddr|
                clientAddr.sendMsg(address, value);
            };
            this.debugLog("Sent parameter update: % %".format(address, value));
        };
    }
    
    // Add OSC client for bidirectional sync
    addOSCClient { |netAddr|
        oscClients = oscClients.add(netAddr);
        this.debugLog("Added OSC client: %:%".format(netAddr.hostname, netAddr.port));
    }
    
    // Remove OSC client
    removeOSCClient { |netAddr|
        oscClients.remove(netAddr);
        this.debugLog("Removed OSC client: %:%".format(netAddr.hostname, netAddr.port));
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         DISCOVERY & INTROSPECTION                           │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Send parameter list to OSC clients
    sendParameterList {
        var paramList = [];
        
        parameterRegistry.getParameterIDs.do { |parameterId|
            var spec = parameterRegistry.getParameterSpec(parameterId);
            var metadata = parameterRegistry.getParameterMetadata(parameterId);
            var oscAddress = this.getOSCAddress(parameterId);
            
            if (oscAddress.notNil) {
                paramList = paramList.add([
                    parameterId,
                    oscAddress,
                    spec.minval,
                    spec.maxval,
                    spec.default,
                    metadata.description ? ""
                ]);
            };
        };
        
        oscClients.do { |clientAddr|
            clientAddr.sendMsg("/osc/paramlist", *paramList.flat);
        };
        
        this.debugLog("Sent parameter list to % clients".format(oscClients.size));
    }
    
    // Send current parameter values
    sendAllParameterValues {
        enabledParameters.do { |parameterId|
            var value = parameterRegistry.getParameterValue(parameterId);
            this.sendParameterUpdate(parameterId, value);
        };
    }
    
    // Handle OSC discovery requests
    setupDiscoveryResponder {
        var discoveryFunc = OSCFunc({ |msg|
            var senderAddr = NetAddr(msg.ip, msg[1].asInteger);
            this.addOSCClient(senderAddr);
            this.sendParameterList();
            this.sendAllParameterValues();
            this.debugLog("Handled discovery request from %:%".format(msg.ip, msg[1]));
        }, '/osc/discover');
        
        oscFuncs[\discovery] = discoveryFunc;
        this.debugLog("OSC discovery responder active on /osc/discover");
    }
    
    // ┌─────────────────────────────────────────────────────────────────────────────┐
    // │                         UTILITY METHODS                                     │
    // └─────────────────────────────────────────────────────────────────────────────┘
    
    // Debug logging
    debugLog { |message|
        if (debugMode) {
            "[LiveOSCController] %".format(message).postln;
        };
    }
    
    // Print current state
    printState {
        "=== OSCController State ===".postln;
        "Port: %".format(oscPort).postln;
        "Enabled Parameters: %".format(enabledParameters.size).postln;
        enabledParameters.do { |parameterId|
            "  %: %".format(parameterId, addressMappings[parameterId]).postln;
        };
        "Bidirectional Sync: %".format(bidirectionalSync).postln;
        "OSC Clients: %".format(oscClients.size).postln;
        oscClients.do { |addr|
            "  %:%".format(addr.hostname, addr.port).postln;
        };
        "===========================".postln;
    }
    
    // Cleanup method
    free {
        // Free all OSC responders
        oscFuncs.values.do { |oscFunc|
            oscFunc.free;
        };
        oscFuncs.clear;
        
        // Clear state
        addressMappings.clear;
        enabledParameters.clear;
        oscClients.clear;
        
        // Unregister from input router
        inputRouter.unregisterInputSource(\osc);
        
        this.debugLog("OSCController freed");
    }
}