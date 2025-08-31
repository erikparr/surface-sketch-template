// Simple OSC test - just send one message

"=== Simple OSC Test ===".postln;

if (~midiController.isNil) {
    "❌ MIDIController not available".postln;
} {
    if (~midiController.oscEnabled.not) {
        "❌ OSC not enabled on MIDIController".postln;
    } {
        var parameterId, address, netAddr;
        
        parameterId = "midi_row1_pos1";
        address = ~midiController.getParameterOSCAddress(parameterId);
        
        if (address.notNil) {
            netAddr = NetAddr("127.0.0.1", NetAddr.langPort);
            netAddr.sendMsg(address, 100);
            "🚀 Sent OSC: % = 100".format(address).postln;
            
            // Check result
            {
                var newValue = ~midiController.parameterRegistry.getParameterValue(parameterId);
                "📊 Parameter value: %".format(newValue).postln;
            }.defer(0.1);
        } {
            "❌ No OSC address for midi_row1_pos1".postln;
        };
    };
};