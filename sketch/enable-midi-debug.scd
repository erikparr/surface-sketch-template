// Enable debug mode on the existing MIDI controller
(
"=== Enabling MIDI Controller Debug Mode ===".postln;

if(~midiController.notNil) {
    "✓ ~midiController exists".postln;
    "Current debug state: %".format(~midiController.debug).postln;
    
    // Enable debug mode
    ~midiController.debug = true;
    "✓ Debug mode enabled".postln;
    
    "Now play a MIDI note to see debug output...".postln;
} {
    "✗ ~midiController is nil!".postln;
    "Check if setup system has been loaded.".postln;
};
)