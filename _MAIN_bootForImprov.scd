/******************************************************************
      Author: Michael Musick
       Email: michael@michaelmusick.com


     Project: Creative Improve
        File: bootForImprov.scd

     Version: 1.0
      M&Year: Feb 2016

 Description: Booting and Server Values
       Notes:

******************************************************************/
/*********************************************
Server.killAll

*********************************************/

(
o = Server.default.options;
o.numInputBusChannels = 16;
o.numOutputBusChannels = 16;
// o.device = "Dante Via 16 Channel";
// o.inDevice = "USBPre2";
// o.inDevice = "Built-in Microphone";
o.inDevice = "nexusMac";
// o.outDevice = "Dante Via 16 Channel";
o.outDevice = "nexusMac";
// o.outDevice = "Built-in Output";
o.hardwareBufferSize = 128;

o.memSize = 2**21;

s.reboot;


s.doWhenBooted({
	MIDIClient.init; MIDIIn.connectAll;
	s.plotTree;
	s.meter;
("./toLoad/*").loadRelative;
});

)


// ("/Users/mmusick/mm_GD/creative_improv/toLoad/*").loadPaths;


