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
~global = ();
o = Server.default.options;
// o.inDevice = "Built-in Microph";
// o.outDevice = "Built-in Output";
// o.device = "Universal Audio Thunderbolt";
// o.inDevice = "nexusMac";
// o.outDevice = "nexusMac";
// o.device = "nexusStudio";
o.device = "nexus + 2chan";
// o.inDevice = "Universal Audio Thunderbolt";
// o.outDevice = "nexusStudio";

o.hardwareBufferSize = 128;
o.memSize = 2**21;

(o.inDevice == "Built-in Microph").if({
	~global.mic = ( 1: 0, 2: 1 );
	~global.hardChans = (\in: 2, \out: 2);
});
((o.outDevice == "nexusMac") || (o.outDevice == "nexus + 2chan")).if({
	~global.hardChans = (\in: 2, \out: 2);
	~global.mic = ( 1: 24, 2: 25 );
});
(o.outDevice == "nexusStudio").if({
	~global.hardChans = (\in: 8, \out: 8);
	~global.mic = ( 1: 24, 2: 25 );
});


o.numInputBusChannels = 24 + ~global.hardChans.in;
o.numOutputBusChannels = 24 + ~global.hardChans.out;

s.reboot;


s.doWhenBooted({
	MIDIClient.init; MIDIIn.connectAll;
	s.plotTree;
	s.meter;
	thisProcess.openUDPPort(8000);
("./toLoad/*").loadRelative;
});

)


// ("/Users/mmusick/mm_GD/creative_improv/toLoad/*").loadPaths;


