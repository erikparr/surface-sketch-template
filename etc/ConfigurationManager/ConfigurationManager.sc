// ConfigurationManager.sc - VST Configuration Save/Load System

ConfigurationManager {
	var <configDir, <defaultConfigPath, <vstManager;

	*new { |vstManager|
		^super.new.init(vstManager);
	}

	init { |argVSTManager|
		var baseDir;
		vstManager = argVSTManager;
		baseDir = thisProcess.nowExecutingPath.dirname.dirname;
		configDir = baseDir +/+ "data" +/+ "vst-configurations";
		defaultConfigPath = configDir +/+ "default.json";

		// Create directory if it doesn't exist
		this.ensureConfigDirectory;
	}

	ensureConfigDirectory {
		var dir;
		dir = PathName(configDir);
		if(dir.isFolder.not) {
			("mkdir -p" + configDir.quote).unixCmd;
			("Created configuration directory: " ++ configDir).postln;
		};
	}

	saveVSTConfiguration { |name, description|
		var config, filePath, instances, groups, midiSettings;
		var instanceData, groupData;

		if(name.isNil or: { name.isEmpty }) {
			"Configuration name cannot be empty".error;
			^false;
		};

		if(vstManager.isNil) {
			"VSTManager not available".error;
			^false;
		};

		// Serialize current VST instances
		instances = vstManager.vstInstances;
		instanceData = [];

		instances.keysValuesDo { |instanceName, vstInstance|
			var instanceConfig, outputBus, groupName;

			// Get output bus from synth - try to get actual bus or use reasonable default
			outputBus = if(vstInstance.synth.notNil) {
				// For VST synths, the output bus is typically stored as 'out' parameter
				// Since we can't easily query synth args, use a calculated default based on instance count
				var instanceIndex = instances.keys.asArray.indexOf(instanceName);
				instanceIndex.notNil.if({
					2 + (instanceIndex * 2); // Start at bus 2, increment by 2
				}, {
					2; // Fallback
				});
			} { 2 };

			// Find which group this instance belongs to
			groupName = nil;
			vstManager.groups.keysValuesDo { |gName, groupConfig|
				if(groupConfig.members.includes(instanceName)) {
					groupName = gName;
				};
			};

			instanceConfig = (
				name: instanceName,
				pluginPath: vstInstance.path ? "",
				outputBus: outputBus,
				group: groupName
			);

			instanceData = instanceData.add(instanceConfig);
		};

		// Serialize groups with type information
		groupData = ();
		if(vstManager.groups.notNil) {
			vstManager.groups.keysValuesDo { |groupName, groupConfig|
				groupData.put(groupName, (
					members: groupConfig.members.copy,
					type: groupConfig.type
				));
			};
		};

		// Get MIDI settings (these will need to be tracked by the GUI)
		midiSettings = (
			expressionKnobEnabled: false, // Will be updated from GUI state
			manualVelocityEnabled: false, // Will be updated from GUI state
			activeKeyboardGroup: vstManager.activeGroup
		);

		// Get MIDI row overrides
		var midiRowMappings = Dictionary.new;
		if (~midiRowOverrides.notNil) {
			~midiRowOverrides.keysValuesDo { |groupName, rowNum|
				midiRowMappings[groupName] = rowNum;
			};
		};

		// Create configuration object
		config = (
			configName: name,
			description: description ? "",
			isDefault: false,
			timestamp: Date.getDate.stamp,
			vstInstances: instanceData,
			groups: groupData,
			midiSettings: midiSettings,
			midiRowMappings: midiRowMappings  // NEW
		);

		// Save to file
		filePath = configDir +/+ (name.asString.toLower.replace(" ", "-") ++ ".json");

		^this.writeConfigToFile(config, filePath);
	}

	loadVSTConfiguration { |name, callback|
		var filePath, config, success;

		if(name.isNil or: { name.isEmpty }) {
			"Configuration name cannot be empty".error;
			^false;
		};

		filePath = configDir +/+ (name.asString.toLower.replace(" ", "-") ++ ".json");

		if(File.exists(filePath).not) {
			("Configuration file not found: " ++ filePath).error;
			^false;
		};

		config = this.readConfigFromFile(filePath);
		if(config.isNil) {
			("Failed to read configuration: " ++ name).error;
			^false;
		};

		("Loading VST configuration: " ++ config["configName"]).postln;

		// Clear current VST state
		this.clearCurrentVSTState;

		// Load configuration in a fork to handle timing
		fork {
			success = this.applyConfiguration(config, callback);
			if(success.not) {
				("Failed to apply configuration: " ++ name).error;
			};
		};

		^true;
	}

	listVSTConfigurations {
		var configs, dir, files;

		configs = [];
		dir = PathName(configDir);

		("ConfigurationManager: Looking for configs in: " ++ configDir).postln;

		if(dir.isFolder) {
			files = dir.entries;
			("Found " ++ files.size ++ " files in config directory").postln;
			files.do { |file|
				var config;
				("Checking file: " ++ file.fileName ++ " (extension: " ++ file.extension ++ ")").postln;
				if(file.extension == "json" and: { file.fileName != "default.json" }) {
					("Reading config file: " ++ file.fullPath).postln;
					config = this.readConfigFromFile(file.fullPath);
					if(config.notNil) {
						("Config loaded successfully, name: " ++ config["configName"]).postln;
						configs = configs.add((
							name: config["configName"],
							description: config["description"],
							filePath: file.fullPath,
							isDefault: this.isDefaultConfiguration(config["configName"])
						));
					} {
						("Failed to load config from: " ++ file.fullPath).warn;
					};
				};
			};
		} {
			("Config directory does not exist: " ++ configDir).warn;
		};

		("Found " ++ configs.size ++ " valid configurations").postln;
		^configs;
	}

	setDefaultVSTConfiguration { |name|
		var configPath, defaultData;

		if(name.isNil) {
			// Remove default
			if(File.exists(defaultConfigPath)) {
				("rm" + defaultConfigPath.quote).unixCmd;
				"Default configuration cleared".postln;
			};
			^true;
		};

		configPath = configDir +/+ (name.asString.toLower.replace(" ", "-") ++ ".json");

		if(File.exists(configPath).not) {
			("Configuration not found: " ++ name).error;
			^false;
		};

		// Create default marker file
		defaultData = (defaultConfigName: name);
		^this.writeConfigToFile(defaultData, defaultConfigPath);
	}

	getDefaultConfiguration {
		var defaultData, configName;

		if(File.exists(defaultConfigPath).not) {
			^nil;
		};

		defaultData = this.readConfigFromFile(defaultConfigPath);
		if(defaultData.isNil) {
			^nil;
		};

		configName = defaultData["defaultConfigName"];
		if(configName.isNil) {
			^nil;
		};

		^configName;
	}

	isDefaultConfiguration { |name|
		var defaultName;
		defaultName = this.getDefaultConfiguration;
		^(defaultName.notNil and: { defaultName == name });
	}

	// Private methods

	writeConfigToFile { |config, filePath|
		var file, jsonString;

		try {
			jsonString = config.asJSON;
			file = File.open(filePath, "w");
			file.write(jsonString);
			file.close;
			("Configuration saved: " ++ filePath).postln;
			^true;
		} { |error|
			("Failed to save configuration: " ++ error.message).error;
			if(file.notNil) { file.close };
			^false;
		};
	}

	readConfigFromFile { |filePath|
		var file, jsonString, config;

		try {
			file = File.open(filePath, "r");
			jsonString = file.readAllString;
			file.close;
			config = jsonString.parseJSON;
			^config;
		} { |error|
			("Failed to read configuration file " ++ filePath ++ ": " ++ error.message).error;
			if(file.notNil) { file.close };
			^nil;
		};
	}

	clearCurrentVSTState {
		if(vstManager.notNil) {
			"Clearing current VST state...".postln;
			// Remove all current VST instances
			vstManager.vstInstances.keys.copy.do { |instanceName|
				vstManager.removeVST(instanceName);
			};
		};
	}

	applyConfiguration { |config, callback|
		var instances, groups, success, validatedInstances, missingPlugins;
		var loadedVSTNames, layerGroups;

		instances = config["vstInstances"];
		groups = config["groups"];
		success = true;
		validatedInstances = [];
		missingPlugins = [];

		// Validate VST plugins exist before attempting to load
		if(instances.notNil) {
			instances.do { |instanceConfig|
				var pluginPath = instanceConfig["pluginPath"];
				if(pluginPath.notNil and: { File.exists(pluginPath) }) {
					validatedInstances = validatedInstances.add(instanceConfig);
				} {
					missingPlugins = missingPlugins.add(instanceConfig["name"] ++ " (" ++ pluginPath ++ ")");
				};
			};

			if(missingPlugins.notEmpty) {
				("Warning: The following VST plugins were not found:").warn;
				missingPlugins.do { |plugin| ("  - " ++ plugin).warn; };
			};

			instances = validatedInstances;
		};

		if(instances.notNil) {
			var usedBuses = [];

			"Loading VST instances...".postln;
			instances.do { |instanceConfig|
				var synth, instanceName, pluginPath, outputBus, finalOutputBus, instanceGroup;

				instanceName = instanceConfig["name"];
				pluginPath = instanceConfig["pluginPath"];
				outputBus = instanceConfig["outputBus"] ? 2;
				instanceGroup = instanceConfig["group"];

				// Check for bus conflicts and resolve them
				finalOutputBus = outputBus;
				while({ usedBuses.includes(finalOutputBus) }) {
					finalOutputBus = finalOutputBus + 2; // Move to next stereo pair
				};

				if(finalOutputBus != outputBus) {
					("Bus conflict resolved for " ++ instanceName ++ ": " ++ outputBus ++ " -> " ++ finalOutputBus).postln;
				};

				usedBuses = usedBuses.add(finalOutputBus);

				if(File.exists(pluginPath)) {
					// Create synth for this instance
					synth = Synth(\vstHost, [\bus, 0, \out, finalOutputBus]);

					// Add VST with callback
					vstManager.addVST(
						instanceName,
						synth,
						pluginPath,
						true, // Enable editor
						instanceGroup,  // Assign to proper group
						{ |controller|
							("Loaded VST instance: " ++ instanceName ++ " on bus " ++ finalOutputBus).postln;

							// Explicit editor opening fallback - same as manual loading
							{
								var inst = vstManager.vstInstances[instanceName];
								if (inst.notNil && inst.controller.notNil && { inst.controller.isOpen }) {
									("Opening VST editor: " ++ instanceName).postln;
									inst.controller.editor;
								} {
									("VST failed to load properly: " ++ instanceName).postln;
								};
							}.defer(0.5);
						}
					);

					0.2.wait; // Wait between VST loads
				} {
					("VST plugin not found: " ++ pluginPath).warn;
					success = false;
				};
			};
		};

		// Wait for VSTs to initialize
		2.wait;

		// Restore groups from configuration
		if(success and: { groups.notNil }) {
			"Restoring groups from configuration...".postln;

			groups.keysValuesDo { |groupName, groupData|
				var members, groupType;

				members = groupData["members"];
				groupType = groupData["type"].asSymbol;

				vstManager.createGroup(groupName, members, groupType);
				("Group '%' restored (type: %, members: %)").format(
					groupName, groupType, members
				).postln;
			};
		};

		// Apply MIDI settings (will be expanded when GUI integration is added)

		// Restore MIDI row mappings
		if (config["midiRowMappings"].notNil) {
			~midiRowOverrides.clear;
			config["midiRowMappings"].keysValuesDo { |groupName, rowNum|
				~midiRowOverrides[groupName] = rowNum;
			};
			("Restored MIDI row mappings for " ++ ~midiRowOverrides.size ++ " groups").postln;

			// Trigger dynamic layers refresh to apply new MIDI mappings
			if (~refreshDynamicLayersMIDI.notNil) {
				~refreshDynamicLayersMIDI.();
			};
		};

		// Sync OSC layers system with loaded VST configuration
		if(success and: { ~oscLayers.notNil }) {
			"Synchronizing OSC layers with VST configuration...".postln;
			this.syncOSCLayersWithVSTs();

			// Update chord group indices for /chord endpoint
			if(~updateChordGroupIndices.notNil) {
				"Updating chord group indices...".postln;
				~updateChordGroupIndices.();
			};

			// Initialize dynamic layers system after VST groups are created
			if(~initDynamicLayersSystem.notNil) {
				~initDynamicLayersSystem.();
			};
		};

		// Sync MIDI controller with loaded VST configuration
		if(success and: { ~updateMIDIController.notNil }) {
			"Synchronizing MIDI controller with VST configuration...".postln;
			~updateMIDIController.value();
		};

		if(callback.notNil) {
			callback.value(success);
		};

		^success;
	}

	// Sync OSC layers system with loaded VST configuration
	syncOSCLayersWithVSTs {
		var groupNames, defaultMelody;

		if(vstManager.isNil) {
			"VSTManager not available for OSC sync".warn;
			^false;
		};

		if(~oscLayers.isNil) {
			"OSC Layers system not available for sync".warn;
			^false;
		};

		// Get VST group names
		groupNames = vstManager.getGroupNames();
		if(groupNames.size == 0) {
			"No VST groups found for OSC sync".warn;
			^false;
		};

		"Syncing % OSC layers with % VST groups".format(3, groupNames.size).postln;

		// Create default melody if needed
		if(~melodyDict.isNil or: { ~melodyDict.size == 0 }) {
			"Creating default melody for OSC layers...".postln;
			if(~melodyDict.isNil) { ~melodyDict = Dictionary.new };
			~melodyDict[\defaultMelody] = (
				patterns: [[60, 62, 64, 65]],
				velocities: [100, 100, 100, 100],
				noteDurations: [0.5, 0.5, 0.5, 0.5],
				metadata: (
					totalDuration: 2,
					scale: 'major',
					key: 'C',
					durationType: 'fixed'
				)
			);
		};

		// Get first available melody
		defaultMelody = ~melodyDict.keys.asArray.first;

		// Legacy layer sync removed - dynamic layers are initialized separately
		"Legacy OSC layer sync skipped (using dynamic layers only)".postln;

		// Refresh GUI if available
		if(~refreshLayerVSTGroups.notNil) {
			~refreshLayerVSTGroups.();
		};

		^true;
	}
}