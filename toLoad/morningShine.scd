/**************************************************************

 Project: ss8
    File: morningShine.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-07-30 09:56:49
Modified: 2015-08-01 14:21:39


   Notes:


**************************************************************/
/*
Synth(\morningShimmer, [\input, 8, \output, 1]);
Synth(\morningShimmer, [\input, 9, \output, 0]);
Synth(\morningShimmer, [\input, 10, \output, 5]);
Synth(\morningShimmer, [\input, 11, \output, 4]);
*/

"\'Loading morningShimmer\'".postln;

(
~mornShim = ();
~mornShim2 = ();

);

(
SynthDef(\morningShimmer, {
	arg input = 0, output = 14, inMul = 1, outMul = 1;
	var sig, fftChain, feedbackAmp, env;

	feedbackAmp = LocalIn.kr(1);
	sig = SoundIn.ar( input ) * inMul.lag(1) * feedbackAmp;
	sig = DelayC.ar( sig, 2, 0.2 );

	sig = HPF.ar(sig, 800);
	fftChain = FFT( LocalBuf(2048), sig );

	fftChain = PV_MagAbove(fftChain, 2);
	fftChain = PV_MaxMagN( fftChain, 3 );
	fftChain = PV_BinShift( fftChain, 2, 12, 1 );

	sig = IFFT(fftChain) * (XLine.kr( 1, 2, 4 ) - 1);

	sig = CombL.ar( sig, 2,
		SinOsc.kr(
			LFNoise0.kr(0.5).linlin(-1,1,0.001,0.01)
		).linlin(-1,1,0.05,2),
		8
	);

	env = Env.adsr( 1, 1, 1, 2 );
	env = EnvGen.kr( env, feedbackAmp.linlin(0, 1, 1, -0.2) );
	env = 1 - env;


	sig = sig * feedbackAmp * env;

	sig = FreeVerb.ar( sig, mix: 0.4, room: 0.8, damp: 0.01 );

	LocalOut.kr( Amplitude.kr( sig ).linlin(0, 0.05, 1, 0).clip(0,1) );

	sig = sig * outMul.lag(0.1);
	// Limit signal so it does not blow up
	sig = Limiter.ar( sig, level: (-3).dbamp, dur: 0.01 );
	//  Insert high and low pass filters to protect speakers
	sig = LPF.ar( sig, freq: s.sampleRate*0.5 );
	sig = HPF.ar( sig, freq: 40 );
	sig = sig * Line.kr(0, 1, 4);
	sig = LeakDC.ar(sig);

	Out.ar( output, sig.dup );

	// FreeSelf.kr( (0.0001 - inMul.lag(30)) );

}).add;

);

MIDIdef.cc(\mornShim_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~mornShim.sdef.notNil,
				{~mornShim.sdef.free; ~mornShim.sdef = nil;});
			"Starting \mornShim".postln;
			~mornShim.sdef = Synth(\morningShimmer, [\input, ~global.mic[1]]);
		});

		if(val==0, {
			if(~mornShim.sdef.notNil,
				{
					"KILL \mornShim".postln;
					~mornShim.sdef.set(\inMul, 0);
					~mornShim.sdef.free; ~mornShim.sdef = nil;
			});

		});

	},
	ccNum: 28,
	chan: 1
);

// set the input gain
MIDIdef.cc(\mornShim_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,4.0);

		("mornShim - MicGain: ").post;
		val.round(0.01).postln;
		~mornShim.sdef.set(\inMul, val);
	},
	ccNum: 8,
	chan: 1
);

// set the output gain
MIDIdef.cc(\mornShim_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("mornShim - Out Gain: ").post;
		val.round(0.01).postln;
		~mornShim.sdef.set(\outMul, val);
	},
	ccNum: 18,
	chan: 1
);


// set input chan
~mornShim.micChan = 0;
MIDIdef.cc(\mornShim_inChan,
	{
		arg val, ccNum, chan, id;

		~mornShim.micChan = ~mornShim.micChan + 1;
		~mornShim.micChan = (~mornShim.micChan).mod(2);

		("mornShim - In Chan: ").post;
		(~mornShim.micChan + ~global.mic[1]).postln;

		~mornShim.sdef.set(\input, ~mornShim.micChan + ~global.mic[1]);
	},
	ccNum: 38,
	chan: 1
);

MIDIdef.cc(\mornShim2_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~mornShim2.sdef.notNil,
				{~mornShim2.sdef.free; ~mornShim2.sdef = nil;});
			"Starting \mornShim2".postln;
			~mornShim2.sdef = Synth(\morningShimmer, [\input, ~global.mic[2]]);
		});

		if(val==0, {
			if(~mornShim2.sdef.notNil,
				{
					"KILL \mornShim2".postln;
					~mornShim2.sdef.set(\inMul, 0);
					~mornShim2.sdef.free; ~mornShim2.sdef = nil;
			});

		});

	},
	ccNum: 29,
	chan: 1
);

// set the input gain
MIDIdef.cc(\mornShim2_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,4.0);

		("mornShim2 - MicGain: ").post;
		val.round(0.01).postln;
		~mornShim2.sdef.set(\inMul, val);
	},
	ccNum: 9,
	chan: 1
);

// set the output gain
MIDIdef.cc(\mornShim2_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("mornShim2 - Out Gain: ").post;
		val.round(0.01).postln;
		~mornShim2.sdef.set(\outMul, val);
	},
	ccNum: 19,
	chan: 1
);


// set input chan
~mornShim2.micChan = 0;
MIDIdef.cc(\mornShim2_inChan,
	{
		arg val, ccNum, chan, id;

		~mornShim2.micChan = ~mornShim2.micChan + 1;
		~mornShim2.micChan = (~mornShim2.micChan).mod(2);

		("mornShim2 - In Chan: ").post;
		(~mornShim2.micChan + ~global.mic[1]).postln;

		~mornShim2.sdef.set(\input, ~mornShim2.micChan + ~global.mic[1]);
	},
	ccNum: 39,
	chan: 1
);