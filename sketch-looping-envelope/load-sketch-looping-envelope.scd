

// Sketch with Looping Envelope System - Main Loader
// Based on the original sketch system with integrated looping envelopes for expression and pitch bend

var sketchPath = PathName(thisProcess.nowExecutingPath).pathOnly;

// Load setup system first (from parent directory)
(sketchPath +/+ "../setup/_setup-loader.scd").load;

s.waitForBoot({
    // Wait for setup to complete
    2.wait;

    "=== Loading Sketch Looping Envelope System ===".postln;

    // Load core components in order
    (sketchPath +/+ "core-functions.scd").load;
    0.5.wait;

    (sketchPath +/+ "looping-envelope-system.scd").load;
    0.5.wait;

    (sketchPath +/+ "osc-envelope-setup.scd").load;
    0.5.wait;

    (sketchPath +/+ "vst-targeting.scd").load;
    0.5.wait;

    (sketchPath +/+ "control-systems.scd").load;
    0.5.wait;

    (sketchPath +/+ "musical-implementation.scd").load;
    0.5.wait;

    // Skip dual layer system for now since it's optional
    // (sketchPath +/+ "dual-layer-system.scd").load;
    // 0.5.wait;

    (sketchPath +/+ "initialization-startup.scd").load;
    0.5.wait;

    (sketchPath +/+ "sketch-gui.scd").load;

    "=== Sketch Looping Envelope System Loaded Successfully ===".postln;
});
