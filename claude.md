ORDER OF OPERATIONS:

1. SUPERCOLLIDER BOOTS AUTOMATICALLY using @etc/startup/startup.scd which configures audio hardware and MIDI
2. STARTUP FILE AUTOMATICALLY LOADS THE SETUP FILES via @setup/_setup-loader.scd
3. STARTUP FILE AUTOMATICALLY LOADS THE LAYERS SYSTEM via @layers/load-layers.scd

OSC-BASED LAYERS SYSTEM:
The project uses a pure OSC-based dynamic layers system with chord groups:
1. System loads automatically on startup via @layers/load-layers.scd
2. Dynamic layers created per VST group (no 3-layer limit)
3. Chord groups support multi-instrument routing (each note to different VST)

OSC API (Port 7000):
- /chord - Send JSON chord with per-note velocity/duration to chord group by index
- /melody - Send JSON melody to any group
- /group/<name>/note - Trigger notes on specific groups
- /system/start, /system/stop - System control

Example chord message:
{
  "notes": [
    {"midi": 60, "vel": 0.5, "dur": 1.0},
    {"midi": 64, "vel": 0.6, "dur": 1.0}
  ],
  "metadata": {"targetGroup": 0}
}

