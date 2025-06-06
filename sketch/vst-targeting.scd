/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                       VST GROUP TARGETING                                    ║
║                        Dynamic VST instance                                  ║
║                       routing and group control                              ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │                       VST GROUP TARGETING                                  │
// └─────────────────────────────────────────────────────────────────────────────┘

// Direct Group Control (use regular quotes):
~setActiveVSTGroup = { |groupName|
    var previousGroup, isAllInstances, groupStr, instances, groupExists, actualGroupKey, symbolKey, stringKey;

    previousGroup = ~activeVSTGroup;
    isAllInstances = false;
    groupExists = false;
    actualGroupKey = nil;

    // Check for "all instances" conditions
    if (groupName.isNil) {
        // Failsafe: nil means all instances
        isAllInstances = true;
    } {
        // Check for clean "All" syntax (case insensitive)
        if (groupName.isKindOf(String) || groupName.isKindOf(Symbol)) {
            groupStr = groupName.asString.toLower;
            if (groupStr == "all") {
                isAllInstances = true;
            };
        };
    };

    if (isAllInstances) {
        ~activeVSTGroup = nil;  // Internally still use nil for "all"
        ["VST Group targeting set to: ALL INSTANCES (was: %)".format(previousGroup ? "ALL")].postln;
    } {
        // Check if group exists (try both Symbol and String forms)

        // Try the input as-is first
        if (~vstManager.groups.includesKey(groupName)) {
            groupExists = true;
            actualGroupKey = groupName;
        } {
            // Try converting String to Symbol or Symbol to String
            if (groupName.isKindOf(String)) {
                symbolKey = groupName.asSymbol;
                if (~vstManager.groups.includesKey(symbolKey)) {
                    groupExists = true;
                    actualGroupKey = symbolKey;
                };
            } {
                if (groupName.isKindOf(Symbol)) {
                    stringKey = groupName.asString;
                    if (~vstManager.groups.includesKey(stringKey)) {
                        groupExists = true;
                        actualGroupKey = stringKey;
                    };
                };
            };
        };

        if (~vstManager.notNil && groupExists) {
            ~activeVSTGroup = actualGroupKey;
            instances = ~vstManager.getTargetInstances(actualGroupKey);
            ["VST Group targeting set to: % (% instances) (was: %)".format(
                actualGroupKey, instances.size, previousGroup ? "ALL"
            )].postln;
        } {
            // Enhanced debugging for group not found
            "DEBUG: Group not found - searching for '%'".format(groupName).postln;
            "DEBUG: Available groups: %".format(~vstManager.groups.keys.asArray).postln;
            "DEBUG: Group types: %".format(~vstManager.groups.keys.collect(_.class)).postln;
            "DEBUG: Search term class: %".format(groupName.class).postln;

            "VST Group '%' not found, keeping current setting: %".format(
                groupName, ~activeVSTGroup ? "ALL"
            ).warn;
        };
    };
};

// Convenience function for using all VSTs
~useAllVSTs = { ~setActiveVSTGroup.("All"); };

// Index-Based Control (Dynamic):
~useVSTGroup = { |index|
    var groups, groupName;

    if (index.isNil) {
        ~useAllVSTs.value;
    } {
        if (~vstManager.notNil) {
            groups = ~vstManager.groups.keys.asArray.sort;
            if (index >= 0 && index < groups.size) {
                groupName = groups[index];
                ~setActiveVSTGroup.(groupName);
            } {
                "VST Group index % out of range (0-%). Available groups: %".format(
                    index, groups.size - 1, groups
                ).warn;
            };
        } {
            "VSTManager not available".warn;
        };
    };
};

// Live Performance Cycling:
~nextVSTGroup = {
    var groups, currentIndex, nextIndex;

    if (~vstManager.notNil) {
        groups = ~vstManager.groups.keys.asArray.sort;
        if (groups.size > 0) {
            if (~activeVSTGroup.isNil) {
                // Currently using all, move to first group
                currentIndex = -1;
            } {
                currentIndex = groups.indexOf(~activeVSTGroup) ? -1;
            };

            nextIndex = (currentIndex + 1) % (groups.size + 1); // +1 to include "all"

            if (nextIndex == groups.size) {
                // Wrap to "all instances"
                ~useAllVSTs.value;
            } {
                ~setActiveVSTGroup.(groups[nextIndex]);
            };
        } {
            "No VST groups available".warn;
        };
    } {
        "VSTManager not available".warn;
    };
};

~prevVSTGroup = {
    var groups, currentIndex, prevIndex;

    if (~vstManager.notNil) {
        groups = ~vstManager.groups.keys.asArray.sort;
        if (groups.size > 0) {
            if (~activeVSTGroup.isNil) {
                // Currently using all, move to last group
                currentIndex = groups.size;
            } {
                currentIndex = groups.indexOf(~activeVSTGroup) ? groups.size;
            };

            prevIndex = (currentIndex - 1) % (groups.size + 1); // +1 to include "all"
            if (prevIndex < 0) { prevIndex = groups.size }; // Wrap around

            if (prevIndex == groups.size) {
                // Move to "all instances"
                ~useAllVSTs.value;
            } {
                ~setActiveVSTGroup.(groups[prevIndex]);
            };
        } {
            "No VST groups available".warn;
        };
    } {
        "VSTManager not available".warn;
    };
};

// Information & Status:
~showVSTTargeting = {
    var currentGroup, instances;

    if (~vstManager.notNil) {
        currentGroup = ~activeVSTGroup ? "ALL INSTANCES";
        instances = ~vstManager.getTargetInstances(~activeVSTGroup);

        "".postln;
        "┌─────────────────────────────────────────────────────────────────┐".postln;
        "│                     VST TARGETING STATUS                       │".postln;
        "└─────────────────────────────────────────────────────────────────┘".postln;
        "Current Target: %".format(currentGroup).postln;
        "Active Instances: %".format(instances.size).postln;
        "Instance Names: %".format(instances.keys.asArray.sort).postln;
        "".postln;
    } {
        "VSTManager not available".warn;
    };
};

~listVSTGroups = {
    var groups, instances, marker, allMarker;

    if (~vstManager.notNil) {
        groups = ~vstManager.groups.keys.asArray.sort;

        "".postln;
        "┌─────────────────────────────────────────────────────────────────┐".postln;
        "│                    AVAILABLE VST GROUPS                        │".postln;
        "└─────────────────────────────────────────────────────────────────┘".postln;

        if (groups.size > 0) {
            groups.do { |groupName, index|
                instances = ~vstManager.getTargetInstances(groupName);
                marker = if (~activeVSTGroup == groupName, "★", " ");
                "[%] %% (% instances)".format(index, marker, groupName, instances.size).postln;
            };
            allMarker = if (~activeVSTGroup.isNil, "★", " ");
            "[ALL] %ALL INSTANCES (% total)".format(
                allMarker, ~vstManager.getTargetInstances("All").size
            ).postln;
        } {
            "No groups available".postln;
        };
        "".postln;
        "★ = Currently active".postln;
        "".postln;
    } {
        "VSTManager not available".warn;
    };
}; 