/**************************************************************

 Project: ss8
    File: combFun.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-07-28 17:59:45
Modified: 2015-08-01 14:52:37


   Notes:


**************************************************************/

/*
s.scope
~combFun = Synth(\combFun)
~combFun.set(\inMul, 0);
*/

"\'Loading combFun\'".postln;

(
~combFun = ();
~combFun2 = ();
);

(
SynthDef(\combFun, {
	arg input1 = 0, input3 = 0, input4 = 0, output = 2,
		inMul = 1, outMul = 1;
	var sig, sig1, sig2, sigL, sigR, delay0, decay0, delay1, decay1;
	var pitch, pitch1, slope, env, dead, amp, fft;

	sig1 = SoundIn.ar( input1 );
	// sig1 = Mix(sig1);
	amp = Amplitude.kr(sig1);
	env = Env.perc(0.01, 0.4);
	env = EnvGen.kr(env, amp.linlin(0,0.04,-0.3,0.001).clip(0,1));
	sig = SoundIn.ar( [ input3, input4 ] );
	sig = sig * 6 * inMul.lag(2);
	sig = Limiter.ar( sig, 0.95 );
	sig = sig * amp.linlin(0.0001,0.1,1,0).clip(0,1).lag(2);
	sig = Mix(sig) * env;


	fft = FFT(LocalBuf(2048), sig);
	fft = PV_MagBelow(fft, 20);
	fft = PV_MagAbove(fft, 19);
	sig2 = IFFT(fft) * 10;
	sig = Mix([sig, sig2]) * amp.linlin(0.0001,0.03,1,0).clip(0,1).lag(2);
	sig = Limiter.ar(sig, 0.9, 0.1);


	// cut out parts of the signal
	sig = sig * (1 - Dust.kr(
		amp.linlin(0.0001,0.01,8,0).clip(0,6).lag(2)
	).lag(0.05, 0.01));

	sig = Mix([
		sig,
		LocalIn.ar(1) * amp.linlin(0.0001,0.13,1,0).clip(0,1).lag(4)
	]);

	// randomly move the signal between two buses
	sig = Pan2.ar( sig,
		pos: LFNoise1.kr(LFNoise0.kr(5).linlin(-1,1,0.1,10)) );


	sigL = sig[0];
	# pitch, dead = Pitch.kr(sig1);
	// pitch.poll;
	env = Env.adsr(10, 3, 0.7, 4);
	env = EnvGen.kr(env, pitch.lag(1).linlin(100,600,-0.1,0.1).clip(0,1));
	env = env.linlin(0,1,0.5,8).lag(0.1);
	delay0 = env;
	decay0 = 10 * delay0;
	sigL = CombC.ar( sigL, 8, delay0, decay0 );

	sigR = sig[1];
	# pitch1, dead = Pitch.kr(sigR);
	// pitch1.poll;
	env = Env.adsr(4, 1, 0.8, 2);
	env = EnvGen.kr(env, pitch1.linlin(100,400,-0.1,0.1).clip(0,1));
	env = env.linlin(0,1,1,8).lag(0.1);
	delay1 = env;
	decay1 = 9 * delay1;
	sigR = CombC.ar( sigR, 9, delay1, decay1 );




	// Mix them togather and send them out
	sig = Mix([sigL, sigR]);
	LocalOut.ar( CombN.ar(sig, 10,
		LFNoise2.kr(0.2).linlin(-1,1,0.4,10), 10)
		* amp.linlin(0.0001,0.02,1,0).clip(0,1).lag(0.5)
	);




	sigL = Limiter.ar(sigL,
		0.99 * amp.linlin(0.0001,0.0707,1,0).clip(0,1).lag(0.5),
		0.1);
	sigL = PanAz.ar(2,
		sigL,
		pos: pitch.linlin(40,400,0,2)
			+ LFNoise1.kr(LFNoise0.kr(0.3).linlin(-1,1,0.001,5)),
		width: pitch1.linlin(100,2000,2,0.01),
		orientation: 4.0
	);


	sigR = Limiter.ar(sigR,
		0.99 * amp.linlin(0.0001,0.0707,1,0).clip(0,1).lag(0.5),
		0.1);
	sigR = PanAz.ar(2,
		sigR,
		pos: pitch.linlin(100,400,2,0)
			+ LFNoise1.kr(LFNoise0.kr(0.3).linlin(-1,1,0.001,5)),
		width: pitch1.linlin(100,2000,2,0.01),
		orientation: 4.0
	);

	sig = [sigL, sigR];
	sig = sig * outMul.lag(0.1);

	// Limit signal so it does not blow up
	sig = Limiter.ar( sig, level: (-6).dbamp, dur: 0.01 );
	//  Insert high and low pass filters to protect speakers
	sig = LPF.ar( sig, freq: s.sampleRate*0.5 );
	sig = HPF.ar( sig, freq: 40 );

	// start from 0 gain and work up.
	// This prevents initial screeches
	sig = sig * Line.kr(0, 1, 5);
	sig = LeakDC.ar(sig);

	Out.ar( output, sig );

}).add;
);

MIDIdef.cc(\combFun_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~combFun.sdef.notNil,
				{~combFun.sdef.free; ~combFun.sdef = nil;});
			"Starting \combFun".postln;
			~combFun.sdef = Synth(\combFun);
		});

		if(val==0, {
			if(~combFun.sdef.notNil,
				{
					"KILL \combFun".postln;
					~combFun.sdef.set(\inMul, 0);
					~combFun.sdef.free; ~combFun.sdef = nil;
			});

		});

	},
	ccNum: 21,
	chan: 1
);

// set the input gain
MIDIdef.cc(\combFun_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,4.0);

		("combFun - MicGain: ").post;
		val.round(0.01).postln;
		~combFun.sdef.set(\inMul, val);
	},
	ccNum: 1,
	chan: 1
);

// set the output gain
MIDIdef.cc(\combFun_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("combFun - Out Gain: ").post;
		val.round(0.01).postln;
		~combFun.sdef.set(\outMul, val);
	},
	ccNum: 11,
	chan: 1
);

// set the output gain
MIDIdef.cc(\combFun_changeChanIns,
	{
		arg val, ccNum, chan, id;
		var mic1, mic2, mic3, chans;
		// val.postln;
		if( val > 0, {

			chans = [0,1,2,3];
			mic1 = chans[4.rand];
			mic2 = chans[4.rand];
			mic3 = chans[4.rand];

			("combFun - MicIns: ").post;
			[mic1, mic2, mic3].postln;
			~combFun.sdef.set(\input1, mic1);
			~combFun.sdef.set(\input3, mic2);
			~combFun.sdef.set(\input4, mic3);
		});
	},
	ccNum: 31,
	chan: 1
);

MIDIdef.cc(\combFun2_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~combFun2.sdef.notNil,
				{~combFun2.sdef.free; ~combFun2.sdef = nil;});
			"Starting \combFun2".postln;
			~combFun2.sdef = Synth(\combFun);
		});

		if(val==0, {
			if(~combFun2.sdef.notNil,
				{
					"KILL \combFun2".postln;
					~combFun2.sdef.set(\inMul, 0);
					~combFun2.sdef.free; ~combFun2.sdef = nil;
			});

		});

	},
	ccNum: 22,
	chan: 1
);

// set the input gain
MIDIdef.cc(\combFun2_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,4.0);

		("combFun2 - MicGain: ").post;
		val.round(0.01).postln;
		~combFun2.sdef.set(\inMul, val);
	},
	ccNum: 2,
	chan: 1
);

// set the output gain
MIDIdef.cc(\combFun2_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("combFun2 - Out Gain: ").post;
		val.round(0.01).postln;
		~combFun2.sdef.set(\outMul, val);
	},
	ccNum: 12,
	chan: 1
);

// set the output gain
MIDIdef.cc(\combFun2_changeChanIns,
	{
		arg val, ccNum, chan, id;
		var mic1, mic2, mic3, chans;
		// val.postln;
		if( val > 0, {

			chans = [0,1,2,3];
			mic1 = chans[4.rand];
			mic2 = chans[4.rand];
			mic3 = chans[4.rand];

			("combFun2 - MicIns: ").post;
			[mic1, mic2, mic3].postln;
			~combFun2.sdef.set(\input1, mic1);
			~combFun2.sdef.set(\input3, mic2);
			~combFun2.sdef.set(\input4, mic3);
		});
	},
	ccNum: 32,
	chan: 1
);