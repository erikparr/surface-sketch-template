	SynthDef(\insert, { arg bus ;
		var input, output;
		input = In.ar(bus, 2);  // Read 2 channels from the bus
		output = VSTPlugin.ar(input, 2, id: \vsti0);  // Process through VST with 2 output channels
		ReplaceOut.ar(bus, output);  // Output 2 channels back to the bus
	}).add;

	// synthdef for creating two synths in parallel
	SynthDef(\insert2, { arg bus1, bus2;
		var sig1, sig2;
		sig1 = In.ar(bus1, 2);
		sig2 = In.ar(bus2, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);

		ReplaceOut.ar(bus1, Mix.new([sig1, sig2]));
	}).add;


	// Simple VST host for a single instance
	// bus: input bus to read from
	// out: output bus to write to (default: 2 for ADAT 3/4)
	SynthDef(\vstHost, { |bus=0, out=2|
		var sig = Silent.ar(2);
		sig = VSTPlugin.ar(sig, 2, id: \vsti);
		Out.ar(out, sig);
	}).add;

	SynthDef(\insert3, { arg bus;
		var sig1, sig2, sig3;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);

		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, sig1);  // ADAT 3/4
		ReplaceOut.ar(4, sig2);  // ADAT 5/6
		ReplaceOut.ar(6, sig3);  // ADAT 7/8
	}).add;


	SynthDef(\insertStrings4, { arg bus;
		var sig1, sig2, sig3, sig4;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig4 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
		sig4 = VSTPlugin.ar(sig4, 2, id: \vsti3);

		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, sig1);  // ADAT 3/4
		ReplaceOut.ar(2, sig2);  // ADAT 5/6
		ReplaceOut.ar(4, sig3);  // ADAT 7/8
		ReplaceOut.ar(4, sig4);  // ADAT 7/8
	}).add;

	SynthDef(\insertStrings, { arg bus;
		var sig1, sig2, sig3, sig4, sig5, sig6;
		sig1 = In.ar(bus, 2);
		sig2 = In.ar(bus, 2);
		sig3 = In.ar(bus, 2);
		sig4 = In.ar(bus, 2);
		sig5 = In.ar(bus, 2);
		sig6 = In.ar(bus, 2);
		sig1 = VSTPlugin.ar(sig1, 2, id: \vsti0);
		sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
		sig3 = VSTPlugin.ar(sig3, 2, id: \vsti2);
		sig4 = VSTPlugin.ar(sig4, 2, id: \vsti3);
		sig5 = VSTPlugin.ar(sig5, 2, id: \vsti4);
		sig6 = VSTPlugin.ar(sig6, 2, id: \vsti5);
		// Output to ADAT channels as defined in Babyface Pro manual
		ReplaceOut.ar(2, Mix.new([sig1, sig4]));  // ADAT 3/4
		ReplaceOut.ar(4, Mix.new([sig2, sig5]));  // ADAT 5/6
		ReplaceOut.ar(6, Mix.new([sig3, sig6]));  // ADAT 7/8
	}).add;

	SynthDef(\singleVST, { arg bus, sig;
			sig = In.ar(bus, 2);
			sig = VSTPlugin.ar(sig, 2, id: \vsti0);
		ReplaceOut.ar(bus,sig);
	}).add;

	SynthDef(\doubleVST, { arg bus, sig, sig2;
			sig = In.ar(bus, 2);
			sig = VSTPlugin.ar(sig, 2, id: \vsti0);
			sig2 = In.ar(bus, 2);
			sig2 = VSTPlugin.ar(sig2, 2, id: \vsti1);
			ReplaceOut.ar(2, sig);
			ReplaceOut.ar(4, sig2);
	}).add;


	~bend1 = Bus.control;

// Enhanced SynthDef for three-node bend envelope (start -> peak -> end)
SynthDef(\BendEnvelope, {
    arg start = 8192, peak = 8192, end = 8192,
        peakTime = 1, returnTime = 1,
        chanIndex = 0, peakCurve = \lin, returnCurve = \lin;

    var env = EnvGen.kr(
        Env(
            [start, peak, end],  // Three level points: start -> peak -> end
            [peakTime, returnTime],  // Two segments: reach peak, then return
            [peakCurve, returnCurve]  // Curve for each segment
        ),
        doneAction: 2
    );

    // Debug message at start
    SendTrig.kr(Impulse.kr(0), chanIndex, start);

    // Send values to OSC at high rate
    SendReply.kr(
        Impulse.kr(100),
        '/bend',
        [chanIndex, env],
        replyID: chanIndex
    );
}).add;

// Looping version of the bend envelope
SynthDef(\BendEnvelopeLoop, {
    arg start = 8192, peak = 8192, end = 8192,
        delayTime = 0, peakTime = 1, returnTime = 1, loopDuration = 2,
        chanIndex = 0, peakCurve = \lin, returnCurve = \lin, delayCurve = \lin,
        timeOffset = 0;  // Added parameter for instance-specific time offset
    
    var trigRate = 1 / loopDuration;  // Calculate trigger frequency from duration
    var trig = Impulse.kr(trigRate);  // Create trigger at specified rate
    var totalDelay = delayTime + timeOffset;  // Add offset to delay time
    var env = EnvGen.kr(
        Env(
            [start, start, peak, end],  // Four level points: start -> start -> peak -> end
            [totalDelay, peakTime, returnTime],  // Three segments: delay, reach peak, then return
            [delayCurve, peakCurve, returnCurve]  // Curve for each segment
        ),
        gate: Trig.kr(trig, totalDelay + peakTime + returnTime),  // Trigger envelope with proper duration
        doneAction: 0  // Don't free when done - keep looping
    );
    
    // Send debug trigger at start of each loop
    SendTrig.kr(trig, chanIndex, start);
    
    // Send values to OSC at high rate
    SendReply.kr(
        Impulse.kr(100),  // 100 Hz control rate
        '/bend',
        [chanIndex, env],
        replyID: chanIndex
    );
}).add;



// Synth definition for ADSR expression envelope
// Sends CC 17 (expression) by default to control VST parameters

// Synth definition for ADSR expression envelope
SynthDef(\ccEnvelope, {
    arg start=0, peak=100, end=0, 
        attackTime=0.5, releaseTime=0.5,
        chanIndex=0, ccNum=11, attackCurve=\sin, releaseCurve=\sin;
    var env;
    
    // Create a simpler three-point envelope like BendEnvelope
    env = EnvGen.kr(
        Env(
            [start, peak, end],  // Three level points: start -> peak -> end
            [attackTime, releaseTime],  // Two segments: reach peak, then release
            [attackCurve, releaseCurve]  // Curve for each segment
        ),
        doneAction: 2
    );
    
    // Debug message at start
    // SendTrig.kr(Impulse.kr(0), chanIndex + 100, start);
    
    // Send the control signal via OSC at same rate as bend
    SendReply.kr(
        Impulse.kr(100),  // Send 100 times per second
        '/expression',
        [chanIndex, ccNum, env.round(1).clip(0, 127)]  // Round to integer and clip for MIDI CC
    );
}).add;
// Looping version of the expression envelope
// Sends CC 17 (expression) by default to control VST parameters
SynthDef(\ccEnvelopeLoop, {
    arg start = 0, peak = 100, end = 0,
        delayTime = 0, attackTime = 0.5, releaseTime = 0.5, loopDuration = 2,
        chanIndex = 0, ccNum = 17, attackCurve = \sin, releaseCurve = \sin, delayCurve = \lin,  // Default to CC 17 for expression
        timeOffset = 0;  // Added parameter for instance-specific time offset
    
    var trigRate = 1 / loopDuration;  // Calculate trigger frequency from duration
    var trig = Impulse.kr(trigRate);  // Create trigger at specified rate
    var totalDelay = delayTime + timeOffset;  // Add offset to delay time
    var env = EnvGen.kr(
        Env(
            [start, start, peak, end],  // Four level points: start -> start -> peak -> end
            [totalDelay, attackTime, releaseTime],  // Three segments: delay, reach peak, then release
            [delayCurve, attackCurve, releaseCurve]  // Curve for each segment
        ),
        gate: Trig.kr(trig, totalDelay + attackTime + releaseTime),  // Trigger envelope with proper duration
        doneAction: 0  // Don't free when done - keep looping
    );
    
    // Scale the envelope to 0-127 range for MIDI CC
    env = env.round(1).clip(0, 127);
    
    // Send debug trigger at start of each loop
    SendTrig.kr(trig, chanIndex + 100, start);
    
    // Send the control signal via OSC
    // Format: ["/expression", replyID, vstIndex, ccNum, value]
    // Note: We're using chanIndex as the vstIndex here
    SendReply.kr(
        Impulse.kr(100),  // Send 100 times per second
        '/expression',
        [chanIndex, ccNum, env],  // Values array: [vstIndex, ccNum, value]
        replyID: chanIndex  // Reply ID (will be the first value in the message)
    );
    
    // Debug output for the first instance
    SendTrig.kr(
        Impulse.kr(1),  // Once per second
        chanIndex + 200,  // Different ID for debug messages
        env  // Send the current envelope value
    );
}).add;

// ===== NEW: Alternate expression envelope that reports to /expression2 =====

SynthDef(\ccEnvelope2, {
    arg start=0, peak=100, end=0,
        attackTime=0.5, releaseTime=0.5,
        chanIndex=0, ccNum=11, attackCurve=\sin, releaseCurve=\sin;
    var env;

    env = EnvGen.kr(
        Env([start, peak, end], [attackTime, releaseTime], [attackCurve, releaseCurve]),
        doneAction: 2
    );

    SendReply.kr(
        Impulse.kr(100),
        '/expression2',   // alternate OSC path
        [chanIndex, ccNum, env.round(1).clip(0, 127)],
        replyID: chanIndex
    );
}).add;

SynthDef(\ccEnvelopeLoop2, {
    arg start = 0, peak = 100, end = 0,
        delayTime = 0, attackTime = 0.5, releaseTime = 0.5, loopDuration = 2,
        chanIndex = 0, ccNum = 17, attackCurve = \sin, releaseCurve = \sin, delayCurve = \lin,
        timeOffset = 0;

    var trigRate = 1 / loopDuration;
    var trig = Impulse.kr(trigRate);
    var totalDelay = delayTime + timeOffset;
    var env = EnvGen.kr(
        Env([start, start, peak, end], [totalDelay, attackTime, releaseTime], [delayCurve, attackCurve, releaseCurve]),
        gate: Trig.kr(trig, totalDelay + attackTime + releaseTime),
        doneAction: 0
    );

    env = env.round(1).clip(0, 127);

    SendReply.kr(
        Impulse.kr(100),
        '/expression2',
        [chanIndex, ccNum, env],
        replyID: chanIndex
    );
}).add;































