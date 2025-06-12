// VSTManager.sc
VSTManager {
    classvar <instance;
    var <vstInstances, <groups, <server, <initialized;
    var <activeGroup;  // Currently active group
    var <defaultGroup; // Default group (optional)
    
    *initClass {
        instance = nil;
    }

    *new { |server|
        if (instance.isNil) {
            instance = super.new.init(server);
        }
        ^instance;
    }

    *current { ^instance }

    init { |srvr|
        "VSTManager: Initializing... Server: %".postln.format(srvr);
        server = srvr ? Server.default;
        vstInstances = Dictionary.new;
        groups = Dictionary.new;
        activeGroup = nil;
        defaultGroup = nil;
        
        this.prInitVST();
        "VSTManager: Initialization complete.".postln;
        ^this;
    }

    prInitVST {
        if (VSTPlugin.plugins.size == 0) {
            "VSTManager: Performing initial VST search...".postln;
            VSTPlugin.search(completion: {
                "VSTManager: VST search complete. Found % plugins.".format(VSTPlugin.plugins.size).postln;
            });
        };
        initialized = true;
    }

    // VST Instance Management
    
    // Get a VST instance by name
    // Note: This returns the raw instance with controller, params, etc.
    // Use getController() if you just need the VSTPluginControllers a dictionary of name -> controller
    getInstances {
        var instances = Dictionary.new;
        vstInstances.keysValuesDo { |name, instance|
            instances[name] = instance.controller;
        };
        ^instances;
    }
    
    // Get VST instances by target group (nil = all instances, "All"/"ALL"/"all" = all instances, groupName = specific group)
    // Returns same format as getInstances: Dictionary with name -> controller
    getTargetInstances { |groupName=nil|
        var instances = Dictionary.new;
        var isAllInstances = false;
        
        // Check for "all instances" conditions
        if (groupName.isNil) {
            // Failsafe: nil means all instances
            isAllInstances = true;
        }, {
            // Check for clean "All" syntax (case insensitive)
            if (groupName.isKindOf(String) || groupName.isKindOf(Symbol)) {
                var groupStr = groupName.asString.toLower;
                if (groupStr == "all") {
                    isAllInstances = true;
                };
            };
        };
        
        if (isAllInstances) {
            // Return all instances (delegate to existing method)
            ^this.getInstances();
        }, {
            // Return instances from specific group
            if (groups[groupName].notNil) {
                groups[groupName].do { |name|
                    var instance = vstInstances[name];
                    if (instance.notNil) {
                        instances[name] = instance.controller;
                    };
                };
                ^instances;
            }, {
                ("VSTManager: Group '%' not found, returning empty collection".format(groupName)).warn;
                ^Dictionary.new;
            };
        };
    }
    
    addVST { |name, synth, vstPath, editor=true, groupName=nil, action|
        var vstCtrl, instance;
        
        if (vstInstances[name].notNil) {
            ("VSTManager: VST instance '" ++ name ++ "' already exists").warn;
            ^vstInstances[name];
        };
        
        this.prAddVSTInstance(name, synth, vstPath, editor, groupName, action);
    }
    
    prAddVSTInstance { |name, synth, vstPath, editor=true, groupName=nil, action|
        var vstCtrl = VSTPluginController(synth, \vsti); // Use fixed ID
        var instance = (
            name: name,
            controller: vstCtrl,
            synth: synth,
            path: vstPath,
            group: groupName,
            params: Dictionary.new
        );
        
        vstInstances[name] = instance;
        
        if (groupName.notNil) {
            this.addToGroup(groupName, name);
        };
        
        vstCtrl.open(vstPath, editor: editor, action: {
            this.prUpdateParameters(name);
            ("VSTManager: VST loaded: " ++ name).postln;
            action.value(instance.controller); // Pass controller to action
        });
        
        ^instance;
    }

    removeVST { |name|
        var instance = vstInstances[name];
        if (instance.notNil) {
            var group = instance[\group];  // Access group using Symbol key
            var controller = instance[\controller];
            var synth = instance[\synth];
            
            // Remove from group first if in one
            if (group.notNil) {
                this.removeFromGroup(group, name);
            };
            
            // Close the VST controller if it exists
            if (controller.notNil) {
                controller.close;
            };
            
            // Free the synth if it exists
            if (synth.notNil) {
                synth.free;
            };
            
            // Remove from instances
            vstInstances.removeAt(name);
            "VSTManager: VST removed: %".format(name).postln;
            ^true;
        };
        "VSTManager: VST % not found for removal.".format(name).warn;
        ^false;
    }

    // Active Group Management
    
    // Set the active group
    setActiveGroup { |groupName|
        if (groups.includesKey(groupName)) {
            activeGroup = groupName;
            ^true;
        }, {
            ("VSTManager: Group not found: " ++ groupName).warn;
            ^false;
        };
    }
    
    // Get the name of the currently active group
    getActiveGroupName {
        ^activeGroup;
    }

    // Get all group names
    getGroupNames {
        ^groups.keys.asArray.sort; // Return sorted array for consistent UI
    }
    
    // Get instances in a group
    getGroupInstances { |groupName|
        ^if (groups[groupName].notNil) {
            groups[groupName].collect { |name| vstInstances[name] };
        }, {
            [];
        };
    }
    
    // Get instance by index from a specific group
    getInstanceAt { |groupName, index=0|
        var instances = this.getGroupInstances(groupName);
        if (instances.size > 0) {
            ^instances.wrapAt(index);
        }, {
            ("VSTManager: No instances found in group: " ++ groupName).warn;
            ^nil;
        };
    }
    
    // Get instances from the active group
    getActiveInstances {
        if (activeGroup.notNil) {
            ^this.getGroupInstances(activeGroup) ? [];
        }, {
            ^[];
        };
    }
    
    // Get instance by index from the active group
    getActiveInstanceAt { |index=0|
        var instances = this.getActiveInstances;
        if (instances.size > 0) {
            ^instances.wrapAt(index);
        }, {
            "VSTManager: No active instances available".warn;
            ^nil;
        };
    }
    
    // Get any VST instance by index (from all instances)
    getInstanceByIndex { |index=0|
        var instanceNames = vstInstances.keys.asArray.sort; // Sort for consistent ordering
        if (instanceNames.size > 0) {
            var instanceName = instanceNames.wrapAt(index);
            ^vstInstances[instanceName];
        }, {
            "VSTManager: No VST instances available".warn;
            ^nil;
        };
    }
    
    // Get VST controller by index (from all instances) - returns just the controller
    getControllerByIndex { |index=0|
        var instance = this.getInstanceByIndex(index);
        if (instance.notNil) {
            ^instance.controller;
        }, {
            ^nil;
        };
    }
    
    // Get list of all instance names (sorted for consistent indexing)
    getInstanceNames {
        ^vstInstances.keys.asArray.sort;
    }
    
    // Helper method to find program index by name for a VST instance
    findProgramByName { |vstName, programName|
        var controller, programCache;
        
        // Use getInstances to get the correct controller
        controller = this.getInstances[vstName];
        if (controller.notNil && controller.isOpen) {
            programCache = controller.programCache;
            if (programCache.notNil) {
                // Manual search through the array (indexOf doesn't work reliably)
                programCache.do { |name, index|
                    if (name.notNil && name.asString == programName.asString) {
                        ^index;
                    };
                };
                "Program '%' not found in VST '%'. Available programs: %".format(
                    programName, vstName, programCache
                ).warn;
                ^nil;
            }, {
                "Program cache not available for VST '%'".format(vstName).warn;
                ^nil;
            }
        }, {
            "VST '%' is not open or controller not available".format(vstName).warn;
            ^nil;
        }
    }
    
    // Set program by name for a VST instance
    setProgramByName { |vstName, programName|
        var index, controller;
        
        index = this.findProgramByName(vstName, programName);
        if (index.notNil) {
            // Use getInstances to get the correct controller
            controller = this.getInstances[vstName];
            if (controller.notNil) {
                controller.program_(index);
                "Set program '%' (index %) for VST '%'".format(programName, index, vstName).postln;
                ^true;
            }, {
                "No controller available for VST '%'".format(vstName).warn;
                ^false;
            };
        }, {
            ^false;
        }
    }
    
    // Set default group (optional)
    setDefaultGroup { |groupName|
        if (groups.includesKey(groupName)) {
            defaultGroup = groupName;
            // Optionally set as active if not already set
            if (activeGroup.isNil) {
                this.setActiveGroup(groupName);
            };
            ^true;
        }, {
            ("VSTManager: Cannot set default group, not found: " ++ groupName).warn;
            ^false;
        };
    }
    
    // Group Management
    
    createGroup { |name, vstNames|
        groups[name] = vstNames.select { |n| vstInstances[n].notNil };
        "VSTManager: Group '%' created with members: %".format(name, groups[name]).postln;
        
        // If this is the first group or default group is not set, make it active
        if (activeGroup.isNil || (defaultGroup.isNil && groups.size == 1)) {
            this.setActiveGroup(name);
            if (defaultGroup.isNil) { defaultGroup = name };
        };
        
        ^groups[name];
    }

    addToGroup { |groupName, vstName|
        var instance = vstInstances[vstName];
        if (instance.notNil) {
            var currentGroup = instance[\group];  // Access group using Symbol key
            if (currentGroup.notNil) {
                this.removeFromGroup(currentGroup, vstName);
            };
            groups[groupName] = (groups[groupName] ? #[]).add(vstName).asSet.asArray; // Ensure unique, then array
            instance[\group] = groupName;  // Update group using Symbol key
            "VSTManager: VST '%' added to group '%'. Current group: %".format(vstName, groupName, groups[groupName]).postln;
            ^true;
        };
        "VSTManager: VST '%' not found, cannot add to group '%' .".format(vstName, groupName).warn;
        ^false;
    }

    removeFromGroup { |groupName, vstName|
        var group = groups[groupName];
        if (group.notNil) {
            var instance = vstInstances[vstName];
            if (instance.notNil) {
                var index = groups[groupName].indexOf(vstName);
                if (index.notNil) {
                    groups[groupName].removeAt(index);
                    instance[\group] = nil;  // Update group using Symbol key
                    "VSTManager: VST '%' removed from group '%'. Remaining in group: %".format(
                        vstName, groupName, groups[groupName]
                    ).postln;
                    ^true;
                }, {
                    "VSTManager: VST '%' not found in group '%'.".format(vstName, groupName).warn;
                    ^false;
                };
            }, {
                "VSTManager: VST instance '%' not found.".format(vstName).warn;
                ^false;
            };
        }, {
            "VSTManager: Group '%' not found.".format(groupName).warn;
            ^false;
        };
    }

    // Parameter Control
    setParameter { |target, param, value|
        var instances = this.resolveTarget(target);
        instances.do { |name|
            var instance = vstInstances[name];
            if (instance.notNil) {
                instance.controller.set(param, value);
                instance.params[param] = value;
            };
        };
    }

    getParameter { |target, param, action|
        var instance = vstInstances[target];
        if (instance.notNil) {
            instance.controller.get(param, { |val|
                instance.params[param] = val;
                action.value(val);
            });
        };
    }

    // Private Methods
    prUpdateParameters { |name|
        var instance = vstInstances[name];
        if (instance.notNil) {
            instance.controller.getn(0, -1, { |values|
                values.do { |value, index|
                    instance.params[index] = value;
                };
                ("VSTManager: Updated " + values.size + " parameters for " + name).postln;
            });
        };
    }

    resolveTarget { |target|
        ^if (groups[target].notNil) {
            groups[target]
        }, {
            if (vstInstances[target].notNil) {
                [target]
            }, {
                #[] // Return empty array literal
            };
        };
    }

    // VST Information
    // Get information about a specific VST instance
    getVSTInfo { |name|
        var instance = vstInstances[name];
        if (instance.notNil) {
            var controller = instance.controller;
            var numParams = 0;
            var isLoaded = false;
            var groupName = nil;
            
            if (controller.respondsTo('numParameters')) {
                numParams = controller.numParameters ? 0;
                isLoaded = numParams.notNil; // A bit simplistic, but ok for now
            };
            
            if (instance.group.notNil) {
                groupName = if (instance.group.isKindOf(String) || instance.group.isKindOf(Symbol)) {
                    instance.group;
                }, {
                    instance.group.name; // Assuming group might be an object with a name
                };
            };
            
            ^( name: name, path: instance.path, group: groupName, isLoaded: isLoaded, numParameters: numParams );
        };
        ^nil;
    }

    // Get information about all VST instances
    getAllVSTInfo {
        var info = ();
        vstInstances.keysDo { |name|
            var instance = vstInstances[name];
            if (instance.notNil) {
                info[name] = this.getVSTInfo(name);
            };
        };
        ^info;
    }

    // Utility
    getState {
        var state = ( instances: Dictionary.new, groups: groups.copyDeep ); // Ensure deep copy of groups
        vstInstances.keysValuesDo { |name, inst|
            state.instances[name] = (
                name: name,
                path: inst.path,
                group: inst.group,
                params: inst.params.copy // shallow copy of params is usually fine
            );
        };
        ^state;
    }

    // Set program by name for all VST instances
    setProgramByNameAll { |programName|
        var successCount = 0, totalCount = 0, found;
        
        // Get all active instances
        this.getActiveInstances.do { |instance|
            var controller;
            totalCount = totalCount + 1;
            found = false;
            
            // Use getInstances to get the correct controller
            controller = this.getInstances[instance.name];
            
            if (controller.notNil && controller.isOpen) {
                var programCache = controller.programCache;
                if (programCache.notNil) {
                    // Manual search for the program
                    programCache.do { |name, index|
                        if (name.notNil && name.asString == programName.asString && found.not) {
                            controller.program_(index);
                            "Set program '%' (index %) for VST '%'".format(programName, index, instance.name).postln;
                            successCount = successCount + 1;
                            found = true; // Mark as found to exit search
                        };
                    };
                    if (found.not) {
                        "Program '%' not found in VST '%'".format(programName, instance.name).warn;
                    };
                }, {
                    "Program cache not available for VST '%'".format(instance.name).warn;
                };
            }, {
                "VST '%' is not open".format(instance.name).warn;
            };
        };
        
        "Set program '%' on % of % VST instances".format(programName, successCount, totalCount).postln;
        ^successCount;
    }
    
    // Set program by name for all VST instances in all groups
    setProgramByNameAllInstances { |programName|
        var successCount = 0, totalCount = 0, found;
        
        // Iterate through all VST instances
        vstInstances.keysValuesDo { |vstName, instance|
            var controller;
            totalCount = totalCount + 1;
            found = false;
            
            // Use getInstances to get the correct controller
            controller = this.getInstances[vstName];
            
            if (controller.notNil && controller.isOpen) {
                var programCache = controller.programCache;
                if (programCache.notNil) {
                    // Manual search for the program
                    programCache.do { |name, index|
                        if (name.notNil && name.asString == programName.asString && found.not) {
                            controller.program_(index);
                            "Set program '%' (index %) for VST '%'".format(programName, index, vstName).postln;
                            successCount = successCount + 1;
                            found = true; // Mark as found to exit search
                        };
                    };
                    if (found.not) {
                        "Program '%' not found in VST '%'".format(programName, vstName).warn;
                    };
                }, {
                    "Program cache not available for VST '%'".format(vstName).warn;
                };
            }, {
                "VST '%' is not open".format(vstName).warn;
            };
        };
        
        "Set program '%' on % of % total VST instances".format(programName, successCount, totalCount).postln;
        ^successCount;
    }
}