// OSCInterface.sc
// Handles OSC communication between SuperCollider and the Electron app (or other OSC controllers)

OSCInterface {
    var vstManager;
    var oscServer; // This variable is declared but not explicitly used to create an OSCServer object.
                   // OSCFuncs register with the default server or one specified by NetAddr.
    var electronAddr;
    var isInitialized;
    var oscPort = 57120;  // Default OSC port
    var <oscFunc; // Made readable for debugging
    var cmdHandlers; // Dispatch table for OSC commands
    
    *new { |vstManagerInstance, port| // Changed argument name for clarity
        ^super.new.init(vstManagerInstance, port);
    }
    
    init { |manager, port|
        "OSCInterface: Initializing with VSTManager: %\n".format(manager).postln;
        vstManager = manager;
        oscPort = port ? oscPort; // Use provided port or default
        isInitialized = false;
        electronAddr = nil; // Address of the last client that sent a message
        
        this.prInitCmdHandlers(); // Initialize the command handlers
        this.setupOSC();
    }
    
    prInitCmdHandlers {
        cmdHandlers = IdentityDictionary.new;
        cmdHandlers.put(\list,            {|args, path, msg| this.prHandleList(args, path, msg)});
        cmdHandlers.put(\info,            {|args, path, msg| this.prHandleInfo(args, path, msg)});
        cmdHandlers.put(\add,             {|args, path, msg| this.prHandleAdd(args, path, msg)});
        cmdHandlers.put(\remove,          {|args, path, msg| this.prHandleRemove(args, path, msg)});
        cmdHandlers.put(\groupCreate,     {|args, path, msg| this.prHandleGroupCreate(args, path, msg)});
        cmdHandlers.put(\groupAddVst,    {|args, path, msg| this.prHandleGroupAddVst(args, path, msg)});
        cmdHandlers.put(\groupRemoveVst, {|args, path, msg| this.prHandleGroupRemoveVst(args, path, msg)});
        "OSCInterface: Command handlers initialized: %\n".format(cmdHandlers.keys).postln;
    }
    
    setupOSC {
        "OSCInterface: setupOSC called. Current oscFunc: %\n".format(oscFunc).postln;
        this.cleanup(); // Clean up any existing OSCFunc
        
        oscFunc = OSCFunc({ |msg, time, addr, recvPort|
            "OSCInterface: Message received by /vst OSCFunc. From: %, Msg: %\n".format(addr, msg).postln;
            electronAddr = addr;
            this.handleOSCMessage(msg);
        }, '/vst', srcID: nil, argTemplate: nil);

        "OSCInterface: OSCFunc registered for /vst. oscFunc: %\n".format(oscFunc).postln;
        "OSCInterface: isInitialized: false -> true\n".postln;
        isInitialized = true;
    }
    
    handleOSCMessage { |msg|
        var actualCmdSymbol, firstArgIndex, cmdArgs, fullReplyPath, handlerFunc;

        if (msg.size < 2) {
            "OSCInterface: Message too short. Expected matched path and a command. Msg: %".format(msg).warn;
            this.sendResponse('/vst/error', (status: "error", message: "Message too short, command unclear"));
            ^this;
        };

        actualCmdSymbol = msg[1].asSymbol;
        firstArgIndex = 2;
        cmdArgs = if (msg.size > firstArgIndex) { msg.copyRange(firstArgIndex, msg.size-1) } { #[] };
        fullReplyPath = ("/vst/" ++ actualCmdSymbol.asString).asSymbol;

        "OSCInterface: Matched Path: '%', Handling Command: '%', Args: %, Reply Path: %".format(msg[0], actualCmdSymbol, cmdArgs, fullReplyPath).postln;

        handlerFunc = cmdHandlers.at(actualCmdSymbol);

        if (handlerFunc.isNil) {
            "OSCInterface: Unknown command '%'. Original matched path: '%', Args: %".format(actualCmdSymbol, msg[0], cmdArgs).warn;
            this.sendResponse(('/vst/error/' ++ actualCmdSymbol).asSymbol, (status: "error", message: "Unknown command", command: actualCmdSymbol));
        } {
            // Execute the handler function, passing arguments, the constructed reply path, and the original message
            handlerFunc.value(cmdArgs, fullReplyPath, msg);
        }
    }
    
    // --- Private Handler Methods ---
    
    prHandleList { |cmdArgs, replyPath, originalMsg|
        var vstInfo = vstManager.getAllVSTInfo();
        this.sendResponse(replyPath, (status: "success", data: vstInfo));
    }
    
    prHandleInfo { |cmdArgs, replyPath, originalMsg|
        var vstName, info;
        if (cmdArgs.size >= 1) {
            vstName = cmdArgs[0].asSymbol;
            "OSCInterface: Requesting info for VST: %".format(vstName).postln;
            info = vstManager.getVSTInfo(vstName);
            if (info.notNil) {
                this.sendResponse(replyPath, (status: "success", data: info));
            } {
                "OSCInterface: VST not found for info request: %".format(vstName).warn;
                this.sendResponse(replyPath, (status: "error", message: "VST not found", name: vstName));
            };
        } {
            "OSCInterface: Missing VST name for info request. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Missing VST name for info request"));
        };
    }
    
    prHandleAdd { |cmdArgs, replyPath, originalMsg|
        var vstName, vstPath, editorFlag = false, result;

        if (~synth.isNil) {
            "OSCInterface: ~synth is not initialized. Cannot add VST. Command: add".warn;
            this.sendResponse(replyPath, (status: "error", message: "~synth not initialized"));
            ^this;
        };

        if (cmdArgs.size >= 2) {
            vstName = cmdArgs[0].asSymbol;
            vstPath = cmdArgs[1].asString;
            if (cmdArgs.size >= 3) { editorFlag = cmdArgs[2].asBoolean; };

            "OSCInterface: Attempting to add VST: Name: %, Path: %, Editor: %".format(vstName, vstPath, editorFlag).postln;
            result = vstManager.addVST(vstName, ~synth, vstPath, editorFlag);

            if (result.notNil) {
                "OSCInterface: VST added successfully: %".format(vstName).postln;
                this.sendResponse(replyPath, (status: "success", name: vstName, message: "VST added."));
                // vstManager.getVSTInfo(vstName).postln; // Optional: confirm info after add
            } {
                "OSCInterface: Failed to add VST (or already exists): %".format(vstName).warn;
                this.sendResponse(replyPath, (status: "error", name: vstName, message: "Failed to add VST or already exists. Check server console."));
            };
        } {
            "OSCInterface: Insufficient arguments for /vst/add. Expected: vstName, vstPath, [editorFlag]. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Insufficient arguments for add. Expected: vstName, vstPath, [editorFlag]."));
        };
    }
    
    prHandleRemove { |cmdArgs, replyPath, originalMsg|
        var vstName, result;
        if (cmdArgs.size >= 1) {
            vstName = cmdArgs[0].asSymbol;
            "OSCInterface: Attempting to remove VST: %".format(vstName).postln;
            result = vstManager.removeVST(vstName);
            if (result) {
                "OSCInterface: VST removed successfully: %".format(vstName).postln;
                this.sendResponse(replyPath, (status: "success", name: vstName, message: "VST removed."));
            } {
                "OSCInterface: Failed to remove VST (or not found): %".format(vstName).warn;
                this.sendResponse(replyPath, (status: "error", name: vstName, message: "Failed to remove VST or not found."));
            };
        } {
            "OSCInterface: Insufficient arguments for /vst/remove. Expected: vstName. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Insufficient arguments for remove. Expected: vstName."));
        };
    }
    
    prHandleGroupCreate { |cmdArgs, replyPath, originalMsg|
        var groupName, vstNamesArray, result;
        // Expects: groupName, vstName1, vstName2, ...
        // So cmdArgs must have at least groupName (cmdArgs[0]) and one VST (cmdArgs[1])
        // if (cmdArgs.size >= 2) { // Original check
        // Let's allow creating an empty group, groupName is cmdArgs[0]
        if (cmdArgs.size >= 1) {
            groupName = cmdArgs[0].asSymbol;
            // VST names start from cmdArgs[1] if present
            vstNamesArray = if(cmdArgs.size > 1) {
                cmdArgs.copyRange(1, cmdArgs.size-1).collect(_.asSymbol);
            } {
                #[] // Empty array for no initial VSTs
            };

            "OSCInterface: Attempting to create group: Name: %, VSTs: %".format(groupName, vstNamesArray).postln;
            result = vstManager.createGroup(groupName, vstNamesArray); // Assuming createGroup can handle empty array

            if (result.notNil) {
                "OSCInterface: Group created successfully: %".format(groupName).postln;
                this.sendResponse(replyPath, (status: "success", name: groupName, members: result, message: "Group created."));
            } {
                "OSCInterface: Failed to create group: %".format(groupName).warn;
                this.sendResponse(replyPath, (status: "error", name: groupName, message: "Failed to create group. Check VSTManager logs."));
            };
        } {
            "OSCInterface: Insufficient arguments for groupCreate. Expected: groupName, [vstNameArray]. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Insufficient arguments for groupCreate. Expected: groupName, [vstNameArray]."));
        };
    }
    
    prHandleGroupAddVst { |cmdArgs, replyPath, originalMsg|
        var groupName, vstName, result;
        if (cmdArgs.size >= 2) {
            groupName = cmdArgs[0].asSymbol;
            vstName = cmdArgs[1].asSymbol;
            "OSCInterface: Attempting to add VST % to group %".format(vstName, groupName).postln;
            result = vstManager.addToGroup(groupName, vstName);
            if (result) {
                "OSCInterface: VST % added to group % successfully.".format(vstName, groupName).postln;
                this.sendResponse(replyPath, (status: "success", group: groupName, vst: vstName, message: "VST added to group."));
            } {
                "OSCInterface: Failed to add VST % to group %.".format(vstName, groupName).warn;
                this.sendResponse(replyPath, (status: "error", group: groupName, vst: vstName, message: "Failed to add VST to group. Check group/VST names and VSTManager logs."));
            };
        } {
            "OSCInterface: Insufficient arguments for groupAddVst. Expected: groupName, vstName. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Insufficient arguments for groupAddVst. Expected: groupName, vstName."));
        };
    }
    
    prHandleGroupRemoveVst { |cmdArgs, replyPath, originalMsg|
        var groupName, vstName, result;
        if (cmdArgs.size >= 2) {
            groupName = cmdArgs[0].asSymbol;
            vstName = cmdArgs[1].asSymbol;
            "OSCInterface: Attempting to remove VST % from group %".format(vstName, groupName).postln;
            result = vstManager.removeFromGroup(groupName, vstName);
            if (result) {
                "OSCInterface: VST % removed from group % successfully.".format(vstName, groupName).postln;
                this.sendResponse(replyPath, (status: "success", group: groupName, vst: vstName, message: "VST removed from group."));
            } {
                "OSCInterface: Failed to remove VST % from group %.".format(vstName, groupName).warn;
                this.sendResponse(replyPath, (status: "error", group: groupName, vst: vstName, message: "Failed to remove VST from group. Check group/VST names and VSTManager logs."));
            };
        } {
            "OSCInterface: Insufficient arguments for groupRemoveVst. Expected: groupName, vstName. Args: %".format(cmdArgs).warn;
            this.sendResponse(replyPath, (status: "error", message: "Insufficient arguments for groupRemoveVst. Expected: groupName, vstName."));
        };
    }
    
    sendResponse { |path, data|
        var jsonString;
        var responseData = if (data.isKindOf(SequenceableCollection)) { data.asDict } { data };
        
        if (electronAddr.notNil) {
            if (responseData.isNil) {
                "OSCInterface: Warning: Response data is nil for path %. Sending empty JSON.".format(path).warn;
                jsonString = "{}";
            } {
                try {
                    jsonString = responseData.asJSON;
                } { |error|
                    "OSCInterface: Error converting response data to JSON for path %: %. Data: %".format(path, error.errorString, responseData).error;
                    jsonString = (status: "error", message: "JSON conversion failed on server", originalPath: path).asJSON;
                };
            };
            "OSCInterface: Sending response to % on path '%': %".format(electronAddr, path, jsonString).postln;
            electronAddr.sendMsg(path, jsonString);
        } {
            "OSCInterface: No client address stored (electronAddr is nil). Cannot send response for path %.".format(path).warn;
        };
    }
    
    cleanup {
        "OSCInterface: cleanup called. Current oscFunc: %\n".format(oscFunc).postln;
        if (oscFunc.notNil) {
            var wasEnabled = oscFunc.isEnabled;
            oscFunc.free;
            "OSCInterface: OSCFunc on /vst freed. Was enabled: %\n".format(wasEnabled).postln;
            oscFunc = nil;
        };
        electronAddr = nil;
        if(isInitialized) { "OSCInterface: isInitialized: true -> false\n".postln; };
        isInitialized = false;
        // cmdHandlers does not need explicit cleanup beyond the instance being freed.
    }
    
    free {
        "OSCInterface: free called.\n".postln;
        this.cleanup();
        vstManager = nil; // Release reference
        cmdHandlers = nil; // Release reference
        "OSCInterface: Instance freed.\n".postln;
    }
}