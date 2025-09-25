// configuration-manager.scd - Initialize VST Configuration Manager

// The ConfigurationManager class should already be compiled with the class library
// If not available, show a warning and defer initialization

// Wait for VSTManager to be available before creating configuration manager
~initConfigurationManager = {
	if(~vstManager.notNil) {
		if(ConfigurationManager.notNil) {
			~configurationManager = ConfigurationManager.new(~vstManager);
			"Configuration Manager initialized.".postln;
		} {
			"WARNING: ConfigurationManager class not available. Configuration features disabled.".warn;
			~configurationManagerReady = false;
			^nil;
		};

		// Make configuration functions globally available
		~saveVSTConfiguration = { |name, description|
			~configurationManager.saveVSTConfiguration(name, description);
		};

		~loadVSTConfiguration = { |name, callback|
			~configurationManager.loadVSTConfiguration(name, callback);
		};

		~listVSTConfigurations = {
			~configurationManager.listVSTConfigurations;
		};

		~setDefaultVSTConfiguration = { |name|
			~configurationManager.setDefaultVSTConfiguration(name);
		};

		~getDefaultConfiguration = {
			~configurationManager.getDefaultConfiguration;
		};

		~configurationManagerReady = true;
		"VST Configuration functions ready.".postln;
	} {
		"VSTManager not yet available, configuration manager initialization deferred.".postln;
	};
};

// Try to initialize now, but also make it available for later initialization
~initConfigurationManager.();