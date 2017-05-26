/**************************************************************

 Project: Sonic Improv Environment #2
    File: sie2_combFeedback.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-10-21 14:59:08
Modified: 2015-10-21 15:29:24


   Notes: comb feedback network
   		First used in "Sonic Environment No 1:
   						Adorable Picture of a Gorilla"
s.plotTree

**************************************************************/
//
// Server.killAll
// o = Server.default.options;
// o.numInputBusChannels = 4;
// o.numOutputBusChannels = 4;
// o.memSize = 2**19;
//
// s.reboot;

(
SynthDef(\comb_feedback, {
	arg output = 0, input = 0, in_fb = 0, input_gain = 0,
		out_main = 0, panPos = 0, amp_main = 0,
		delayTime = 0, delayTimeMod = 1,
		decayTime = 0, delayLag = 0.5,
		pitchShiftOnOff = 0, pitchEffect = 0,
		delayTimeMax = 0.05, smallDelayOnOff = 0;
	var inSig, delaySig, sigOut_main, delay_t;
	var pitchShift;
	var rms, rawRMS, rmsMin, rmsMax, delayMax, variDelayTime;
	var smallDelay, gainRed;

	// get the sound input from the mic
	inSig = SoundIn.ar(input, input_gain.lag(0.01));

	// get the RMS value from the mic signal
	rms = RunningSum.rms( inSig, 2048 );
	rawRMS = rms;
	// map this to gain reduction value
    gainRed = rms.linexp( inMin: 0.01, inMax: 0.7, outMin: 1, outMax: 0.0001 );

	// smooth the RMS signal by 60"
	rms = rms.lag3( 3, 9 );

	//  get the Min RMS for the rmsGate and the delayTime mapping
	rmsMin = rms.lag2(6, 5).clip(0, 0.5);
	// get the Max RMS value. Set immediatly, but hold onto for 3 minutes.
	rmsMax = rms.lag(2, 8);

	// adjust the max delayTime,
	// this creates a more harmonically dynamic composition
	delayMax = rmsMax.linexp(0, 0.6, 0.01, delayTimeMax).lag2(15);

	// set the RMS value according to the minRMS.
	// This means RMS is only passed when it is above minRMS
	// This has the effect of stasis in the system.
	rms = Gate.kr( rms, rms - rmsMin ).lag3(5, 7);
	variDelayTime = rms.linlin(
		rmsMin,
		rmsMax,
		0,
		delayMax
	).clip(0, delayTimeMax);

	// variable comb filter (Comb Delay)
	smallDelay = DelayC.ar(
		in: inSig,
		maxdelaytime: delayTimeMax,
		delaytime: variDelayTime
	);

	// Turn Small Delay on or Off
	smallDelay = smallDelay * smallDelayOnOff.lag(4);
	inSig = inSig * (1 - smallDelayOnOff.lag(4));

	inSig = Mix([inSig, smallDelay]);

	// comb delay filter
	// this is where all the fun happens
	// TODO: this was originally CombL. Check which is better.
	delay_t = delayTime.lag(delayLag);
	// delay_t = delay_t;
	delaySig = CombC.ar(
		in: inSig,
		maxdelaytime: 36,
		delaytime: delay_t,
		decaytime: decayTime.lag(0.5)
	);


	pitchShift = PitchShift.ar(
		in: delaySig,
		windowSize: 0.2,
		pitchRatio: 1,
		pitchDispersion: pitchEffect,
		timeDispersion: pitchEffect
	);
	pitchShift = pitchShift * pitchShiftOnOff.lag(0.1);

	sigOut_main = Mix( [delaySig, pitchShift]);
	sigOut_main = sigOut_main * pitchShiftOnOff.linlin(0, 1, 1, 0.5).lag(0.1);


    // reduce signal volume based on rms
    smallDelay = (sigOut_main * gainRed) * smallDelayOnOff.lag(4);
	sigOut_main = sigOut_main * (1 - smallDelayOnOff.lag(10));
	sigOut_main = Mix([sigOut_main, smallDelay*4]);

	// send the signal out the main outs
	sigOut_main = Limiter.ar(sigOut_main, 0.97, 0.005);
	sigOut_main = Pan2.ar(sigOut_main, panPos.lag(0.2));
	sigOut_main = sigOut_main * amp_main.lag(0.1);
	sigOut_main = LeakDC.ar(sigOut_main);

	// Amplitude.kr(sigOut_main).poll;
	Out.ar(output, sigOut_main);

}).add;

~cFB = ();
~cFB.sdef  = Array.newClear(3);
~cFB.in = [0,1,2,3];
~cFB.inPtr = [0,0,0];
~cFB.inGainCC = 60;
~cFB.mainAmpCC = 14;
~cFB.panCC = 17;
~cFB.inputChan = 29;
~cFB.decayTimeCC = 8;
~cFB.delayLagCC = 32;
~cFB.delayTimeCC = 70;
~cFB.pitchEffect = 26;
~cFB.pitchFXAmt = 20;
~cFB.smlDlyEffect = 35;




MIDIdef.cc(\combFB_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;

		ccNum = ccNum - 23;
		if(val==1, {
			if(~cFB.sdef[ccNum].notNil,
				{~cFB.sdef[ccNum].free; ~cFB.sdef[ccNum] = nil;});

			~cFB.sdef[ccNum] = Synth(\comb_feedback);
			("START Comb Feedback V - " ++ ccNum).postln;
		});

		if(val==0, {
			if(~cFB.sdef[ccNum].notNil,
				{
					~cFB.sdef[ccNum].set(\amp_main, 0);
					~cFB.sdef[ccNum].set(\amp_fb, 0);
					~cFB.sdef[ccNum].free; ~cFB.sdef[ccNum] = nil;
					("Kill Comb Feedback V - " ++ ccNum).postln;
			});

		});

	},
	ccNum: [23,24,25],
	chan: 0
);

// set the input gain
MIDIdef.cc(\combFB_inGain,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.inGainCC;
		val = val.linlin(0,127.0,0,4.0);

		("V"++ccNum++" - MicGain: ").post;
		val.round(0.01).postln;
		~cFB.sdef[ccNum].set(\input_gain, val);
	},
	ccNum: (~cFB.inGainCC..~cFB.inGainCC+2),
	chan: 0
);


// set the main output amplitude
MIDIdef.cc(\combFB_mainAmp,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.mainAmpCC;
		val = val.linlin(0,127.0,0,1.0);

		("V"++ccNum++" - OutGain: ").post;
		val.round(0.01).postln;
		~cFB.sdef[ccNum].set(\amp_main, val);
	},
	ccNum: (~cFB.mainAmpCC..~cFB.mainAmpCC+2),
	chan: 0
);

// set the pan position
MIDIdef.cc(\combFB_panPos,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.panCC;
		val = val.linlin(0,127.0,-1,1);

		("V"++ccNum++" - Pan_Pos: ").post;
		val.round(0.01).postln;
		~cFB.sdef[ccNum].set(\panPos, val);
	},
	ccNum: (~cFB.panCC..~cFB.panCC+2),
	chan: 0
);


// Set the input channel
MIDIdef.cc(\combFB_inChan,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.inputChan;

		~cFB.inPtr[ccNum] = (~cFB.inPtr[ccNum] + 1).mod(~cFB.in.size);
		~cFB.sdef[ccNum].set(\input, ~cFB.in[~cFB.inPtr[ccNum]]);

		("V"++ccNum++" - In_Chan: ").post;
		~cFB.in[~cFB.inPtr[ccNum]].postln;
	},
	ccNum: (~cFB.inputChan..~cFB.inputChan+2),
	chan: 0
);

// Set the decay time
MIDIdef.cc(\combFB_delayLag,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.decayTimeCC;

		if(val>122, {val=100000},
			{
				val = val+1;
				val = val.linexp(1,127,1,240);
				val = val-1;
			}
		);

		("V"++ccNum++" - delayLag: ").post;
		val.round(0.01).postln;

		~cFB.sdef[ccNum].set(\delayLag, val);
	},
	ccNum: (~cFB.decayTimeCC..~cFB.decayTimeCC+2),
	chan: 0
);

// Set the delay lag
MIDIdef.cc(\combFB_decayTime,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.delayLagCC;
		val = val+1;
		val = val.linlin(1,127,1,1000);
		val = val-1;

		("V"++ccNum++" - decayTime: ").post;
		val.round(0.01).postln;

		~cFB.sdef[ccNum].set(\decayTime, val);
	},
	ccNum: (~cFB.delayLagCC..~cFB.delayLagCC+2),
	chan: 0
);

// Set the delay time
MIDIdef.cc(\combFB_delayTime,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.delayTimeCC;

		if(val==0, {val=0});

		if((val<69).and(val>0), {
			val = 1 / (((68-val)*0.5)+36).midicps;
		});

		if((val>68).and(val<99), {
			val = val.linexp(49,98,0.1,3);
		});

		if((val>98), {
			val = val.linlin(99,127,3,18);
		});

		("V"++ccNum++" - delayTime: ").post;
		val.round(0.0001).postln;

		~cFB.sdef[ccNum].set(\delayTime, val);
	},
	ccNum: (~cFB.delayTimeCC..~cFB.delayTimeCC+2),
	chan: 0
);



// Set the pitchShift On/Off
MIDIdef.cc(\combFB_pitchOnOff,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.pitchEffect;
		if(val==1, {
			~cFB.sdef[ccNum].set(\pitchShiftOnOff, 1);
			("V"++ccNum++" - PitchFX: ON").postln;
		});

		if(val==0, {
			~cFB.sdef[ccNum].set(\pitchShiftOnOff, 0);
			("V"++ccNum++" - PitchFX: OFF").postln;
		});

	},
	ccNum: (~cFB.pitchEffect..~cFB.pitchEffect+2),
	chan: 0
);
// Set the pitchShift Effect Amount
MIDIdef.cc(\combFB_pitchEffectAmt,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.pitchFXAmt;
		val = val+1;
		val = val.linexp(1,128,1,11);
		val = val-1;

		("V"++ccNum++" - PitchFX Amt: ").post;
		val.round(0.01).postln;

		~cFB.sdef[ccNum].set(\pitchEffect, val);
	},
	ccNum: (~cFB.pitchFXAmt..~cFB.pitchFXAmt+2),
	chan: 0
);


// Set the Small Delay Effect On/Off
MIDIdef.cc(\combFB_smallDelayOnOff,
	{
		arg val, ccNum, chan, id;
		ccNum = ccNum - ~cFB.smlDlyEffect;
		if(val==1, {
			~cFB.sdef[ccNum].set(\smallDelayOnOff, 1);
			("V"++ccNum++" - SmallDelayFX: ON").postln;
		});

		if(val==0, {
			~cFB.sdef[ccNum].set(\smallDelayOnOff, 0);
			("V"++ccNum++" - SmallDelayFX: OFF").postln;
		});

	},
	ccNum: (~cFB.smlDlyEffect..~cFB.smlDlyEffect+2),
	chan: 0
);

);

