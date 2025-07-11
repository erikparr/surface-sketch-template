/*
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                         TEST LAYERS SYSTEM                                    ║
║                    Run this to test the layers system                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
*/

// Step 1: Run diagnostics
"STEP 1: Running diagnostics...".postln;
(thisProcess.nowExecutingPath.dirname +/+ "layers/debug-layers.scd").load;

// Wait for diagnostics to complete
SystemClock.sched(3, {
    "".postln;
    "STEP 2: Testing safe start...".postln;
    "==============================".postln;
    
    // Try the safe start
    ~startLayersSafe.();
    
    nil
});

// Additional commands to try manually:
"".postln;
"MANUAL COMMANDS TO TRY:".postln;
"======================".postln;
"".postln;
"1. Check VST groups:".postln;
"   ~vstManager.getGroupNames().postln;".postln;
"".postln;
"2. Refresh VST groups in GUI:".postln;
"   ~refreshLayerVSTGroups.();".postln;
"".postln;
"3. Try manual layer start:".postln;
"   ~startLayersSafe.();".postln;
"".postln;
"4. Check layer status:".postln;
"   ~printLayerStatus.();".postln;
"".postln;
"5. Stop layers:".postln;
"   ~stopLayers.();".postln;
"".postln;