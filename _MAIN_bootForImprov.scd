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
o.numInputBusChannels = 4;
o.numOutputBusChannels = 8;
o.memSize = 2**21;

s.reboot;


s.doWhenBooted({
	MIDIClient.init; MIDIIn.connectAll;
	s.plotTree;
	s.meter;
});

)


("/Users/mmusick/mm_GD/Creative_Improv/toLoad/*").loadPaths;