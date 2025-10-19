ORDER OF OPERATIONS:

1. SUPERCOLLIDER BOOTS AUTOMATICALLY using @etc/startup/startup.scd which configures audio hardware and MIDI
2. STARTUP FILE AUTOMATICALLY LOADS THE SETUP FILES via @setup/_setup-loader.scd
3. STARTUP FILE AUTOMATICALLY LOADS THE LAYERS SYSTEM via @layers/load-layers.scd

OSC-BASED DYNAMIC LAYERS SYSTEM:
The project uses a pure OSC-based dynamic layers system with chord groups:
1. System loads automatically on startup via @layers/load-layers.scd
2. Dynamic layers created per VST group (no 3-layer limit)
3. Chord groups support multi-instrument routing (round-robin: each note to different VST)
4. MIDI parameters auto-update via ParameterRegistry integration
5. Expression envelopes use MIDI-controlled min/max/duration values

MIDI INTEGRATION:
Dynamic layers automatically map to MIDI controller rows (modulo 3 for 4+ groups):
- Row 1 Knob 2: Note duration scalar (1-100%)
- Row 1 Knob 4: Expression duration scalar (0.1-100%)
- Row 1 Knob 5: Expression min (0-127)
- Row 1 Knob 6: Expression max (0-127)
- Row 1 Knob 8: Global BPM (60-400)
(Repeat for Rows 2-3 for additional groups)

Parameters update automatically when knobs change via ParameterRegistry callbacks.

OSC API (Port 7000):
- /chord - Send JSON chord with per-note velocity/duration to chord group by index
  - Automatically applies MIDI note duration scalar (Row X Knob 2)
  - Triggers expression envelope with MIDI parameters (Row X Knobs 4/5/6)
  - Updates parameters from MIDI before each chord
- /melody - Send JSON melody to any group
- /group/<name>/note - Trigger notes on specific groups (routes per group type)
- /group/<name>/expression - Trigger expression envelope with MIDI parameters
- /system/start, /system/stop - System control

CHORD GROUP ROUTING:
Regular groups: All VSTs play the same notes (broadcast)
Chord groups: Each note routed to different VST (round-robin)

Example chord message:
{
  "notes": [
    {"midi": 60, "vel": 0.5, "dur": 1.0},
    {"midi": 64, "vel": 0.6, "dur": 1.0}
  ],
  "metadata": {"targetGroup": 0}
}

MIDI CONTROL FOR CHORD PLAYBACK:
When sending /chord messages, the following MIDI parameters are automatically applied:
- Row 1 Knob 2: Scales note duration (e.g., 50% = half the JSON duration)
- Row 1 Knob 4: Expression envelope duration scalar
- Row 1 Knob 5: Expression envelope minimum CC value
- Row 1 Knob 6: Expression envelope maximum CC value
- Expression envelope triggers automatically if ccControl.enabled = true

