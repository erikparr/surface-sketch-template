// Quick check for looping state and what might be causing loops

(
"=== Checking Looping State ===".postln;
"".postln;

// Check global looping mode
"Global looping mode: %".format(~oscLayers.state.loopingMode).postln;

// Check if coordinator is running
if (~oscLayers.coordinator.notNil) {
    "Coordinator exists".postln;
    if (~oscLayers.coordinator.currentTask.notNil) {
        "Coordinator task is: %".format(
            if (~oscLayers.coordinator.currentTask.isPlaying) { "PLAYING" } { "STOPPED" }
        ).postln;
    } {
        "No coordinator task running".postln;
    };
} {
    "No coordinator".postln;
};

// Check legacy layer tasks
"".postln;
"Legacy layer tasks:".postln;
"  Layer1 task: %".format(if (~layer1_currentTask.notNil) { "exists" } { "nil" }).postln;
"  Layer2 task: %".format(if (~layer2_currentTask.notNil) { "exists" } { "nil" }).postln;
"  Layer3 task: %".format(if (~layer3_currentTask.notNil) { "exists" } { "nil" }).postln;

"".postln;

// To stop any looping
"To stop looping, run:".postln;
"  ~oscLayers.state.loopingMode = false;".postln;
"  ~stopLayersOSC.();".postln;
)