# Proposed Directory Structure for Dependent Layers

## Current Structure
```
surfacing/
├── setup/
│   ├── _setup-loader.scd
│   ├── vstplugin-setup.scd      # Defines Layer1, Layer2, Layer3 groups
│   └── ... (other setup files)
├── sketch/
│   ├── load-sketch.scd          # Main sketch loader
│   ├── musical-implementation.scd # ProcMod patterns to follow
│   └── ... (other sketch files)
└── reference/
    └── procmod-reference/
```

## Proposed Addition
```
surfacing/
├── setup/                       # (unchanged)
├── sketch/                      # (unchanged)
├── layers/                      # NEW DIRECTORY
│   ├── load-layers.scd         # Main entry point
│   ├── layers-core.scd         # Data structures & initialization
│   ├── layers-playback.scd     # ProcMod creation & timing
│   ├── layers-control.scd      # API functions
│   └── layers-gui.scd          # GUI window
└── reference/                   # (unchanged)
```

## Integration Points

The layers system will use these existing components:
- `~melodyDict` - melody definitions from sketch
- `~ccControl` - timing parameters from sketch  
- `~setActiveVSTGroup` - VST routing from sketch
- `~processNote` - note processing from sketch
- ProcMod class - from reference

## Loading Sequence

1. Normal startup loads setup/ and sketch/ as usual
2. To add layer functionality:
   ```supercollider
   (thisProcess.nowExecutingPath.dirname +/+ "layers/load-layers.scd").load;
   ```
3. Open layer GUI:
   ```supercollider
   ~createLayersGUI.()
   ```

## Benefits

1. **No Risk**: Existing system untouched
2. **Optional**: Load only when needed
3. **Clean**: Clear separation of functionality
4. **Testable**: Can develop/test in isolation
5. **Maintainable**: Easy to understand structure