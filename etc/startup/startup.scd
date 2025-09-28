/*
supercollider program has a builtin startup file. i included it here so
  you know how it works 
  */
// Define a function that initializes the SuperCollider server
Server.killAll;
Server.default = Server.local;
s.options.sampleRate = 48000;
s = Server.default;

// Set the SuperCollider server output device
ServerOptions.devices; // all devices
s.options.numInputBusChannels = 0;
s.options.numOutputBusChannels = 8;  // Increased to accommodate ADAT 3/4, 5/6, and 7/8
//Server.default.options.inDevice_("SC Route");
//enable when routing to loopback:
Server.default.options.outDevice_("Babyface Pro");

//It is a good idea to go ahead and clear the plugin cache, in case some quarantined plugins have been black-listed already.
// VSTPlugin.clear

// Wait for the server to finish booting
s.waitForBoot {

	// Initialize the MIDI client and connect to all MIDI inputs
	MIDIClient.init;
	MIDIIn.connectAll;
	MIDIClient.destinations.postln;
	n = NetAddr("127.0.0.1", 57120); // local machine


	("/Users/erikparr/surfacing/surfacing/layers/load-layers.scd").load;
};