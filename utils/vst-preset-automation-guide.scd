//////
// vst automation guide
/////

// to save preset for VST program automation:
// first open the gui to see a list of the available presets saved in the VST
~vstManager.getActiveInstanceAt(0).controller.gui;

// find the number associated with the program you want to use
~vstManager.getActiveInstanceAt(0).controller.info.printPrograms;
// set that as the program to test that it works
~vstManager.getActiveInstanceAt(1).controller.program_(6);

// if it works as expected, go ahead and save it as a preset
~vstManager.getActiveInstanceAt(1).controller.savePreset("sc-control");

//whenever you want to load that (automatically when vst is created) use loadPreset:
~vstManager.getActiveInstanceAt(1).controller.loadPreset("sc-control");