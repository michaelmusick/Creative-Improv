/**************************************************************

 Project: Sonic Space No. 8 -- One Deliberate Day
    File: pretty_synth.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-07-13 00:25:37
Modified: 2015-08-01 14:58:46


   Notes:


**************************************************************/


/*
~pretty1 = Synth( \ss8_prettyLong, [\input, 8] );
~pretty2 = Synth( \ss8_prettyLong, [\input, 9] );

*/

"\'Loading pretty_synth\'".postln;

(
~prettySynth = ();
~prettySynth2 = ();
);

(
SynthDef( \prettySynth,
	{
		arg maxDur = 30, amp = 0.8, rmsThresh = 0.03, input = 0,
			winType = 1, winSize = 2048,
			panPos = 0, panWidth = 2, inMul = 1, outMul = 1, output = 2;
		var sigIn, analysis, fft1, fft2, sig, env, contEnv, rmsThreshEnv;

		sigIn = SoundIn.ar( input ) * inMul.lag(1);

		rmsThreshEnv = Env.asr(0.1, 0.01, 3, 0 );
		rmsThreshEnv = EnvGen.kr(rmsThreshEnv, LocalIn.kr-rmsThresh);

		analysis = RunningSum.rms( sigIn, 2048 ); //.poll(label: \rms);
		LocalOut.kr(analysis);
		analysis = (rmsThreshEnv + analysis); //.poll(label: \analysis);
		analysis = (analysis-rmsThresh).clip(0,1);
		sigIn = Normalizer.ar( sigIn ) * inMul.lag(1);

		contEnv = Env.linen(0.01, 5, 1);
		contEnv = EnvGen.kr(contEnv, analysis);

		env = Env.asr( 0.5, 1, 0.7, -4 );
		env = EnvGen.kr( env,
			gate: analysis,
			doneAction: 0
		);

		env = (env * contEnv);

		sigIn = HPF.ar(sigIn, 400);
		fft1 = FFT(
			LocalBuf(winSize),
			sigIn,
			hop: 0.5,
			wintype: 1,
			active: winType,
			winsize: winSize
		);

		// fft = PV_LocalMax( fft, MouseX.kr(0, 100).poll );
		fft1 = PV_Compander( fft1, 34, 1, (2/1) );

		fft2 = PV_Copy(fft1, LocalBuf(winSize));
		fft2 = PV_LocalMax(fft2, 10);
		fft1 = PV_MagMinus( fft1, fft2, 100 );
		fft2 = PV_Copy(fft1, LocalBuf(winSize));
		fft2 = PV_LocalMax(fft2, 7);
		fft1 = PV_MagMinus( fft1, fft2, 100 );
		fft1 = PV_LocalMax(fft1, 12);

		fft1 = PV_Freeze( fft1, env );
		// fft1 = PV_MagSmear( fft1, bins: 10 );

		fft1 = PV_MagMulAdd(fft1, 100);

		sig = IFFT( fft1, winType, winSize );

		sig = BLowPass.ar( sig, 200, 1);

		sig = sig * 2 * env * amp.lag(2);

		sig = HPF.ar(sig, 30);
		sig = Limiter.ar( sig, (0.0707 * amp.lag(5)), 0.01 );

		// fucking around and adding a pos value
		panPos = analysis.linlin(0, 0.2, 1e-6, 0.1);
		panPos = SinOsc.ar(panPos);


		sig = Pan2.ar(sig, panPos);


		sig = sig * outMul.lag(0.1);
		// Limit signal so it does not blow up
		sig = Limiter.ar( sig, level: (-3).dbamp, dur: 0.01 );
		//  Insert high and low pass filters to protect speakers
		sig = LPF.ar( sig, freq: s.sampleRate*0.5 );
		sig = HPF.ar( sig, freq: 40 );
		sig = sig * Line.kr(0, 1, 8);
		sig = LeakDC.ar(sig);

		Out.ar( output, sig );

		// FreeSelf.kr( (0.0001 - inMul.lag(30)) );

	}
).add;
);


MIDIdef.cc(\prettySynth_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~prettySynth.sdef.notNil,
				{~prettySynth.sdef.free; ~prettySynth.sdef = nil;});
			"Starting \prettySynth".postln;
			~prettySynth.sdef = Synth(\prettySynth);
		});

		if(val==0, {
			if(~prettySynth.sdef.notNil,
				{
					"KILL \prettySynth".postln;
					~prettySynth.sdef.set(\inMul, 0);
					~prettySynth.sdef.free; ~prettySynth.sdef = nil;
			});

		});

	},
	ccNum: 26,
	chan: 1
);

// set the input gain
MIDIdef.cc(\prettySynth_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,10.0);

		("prettySynth - MicGain: ").post;
		val.round(0.01).postln;
		~prettySynth.sdef.set(\inMul, val);
	},
	ccNum: 6,
	chan: 1
);

// set the output gain
MIDIdef.cc(\prettySynth_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("prettySynth - Out Gain: ").post;
		val.round(0.01).postln;
		~prettySynth.sdef.set(\outMul, val);
	},
	ccNum: 16,
	chan: 1
);

// set input chan
~prettySynth.micChan = 0;
MIDIdef.cc(\prettySynth_inChan,
	{
		arg val, ccNum, chan, id;

		~prettySynth.micChan = ~prettySynth.micChan + 1;
		~prettySynth.micChan = (~prettySynth.micChan).mod(4);

		("prettySynth - In Chan: ").post;
		~prettySynth.micChan.postln;

		~prettySynth.sdef.set(\input, ~prettySynth.micChan);
	},
	ccNum: 36,
	chan: 1
);

MIDIdef.cc(\prettySynth2_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~prettySynth2.sdef.notNil,
				{~prettySynth2.sdef.free; ~prettySynth2.sdef = nil;});
			"Starting \prettySynth2".postln;
			~prettySynth2.sdef = Synth(\prettySynth);
		});

		if(val==0, {
			if(~prettySynth2.sdef.notNil,
				{
					"KILL \prettySynth2".postln;
					~prettySynth2.sdef.set(\inMul, 0);
					~prettySynth2.sdef.free; ~prettySynth2.sdef = nil;
			});

		});

	},
	ccNum: 27,
	chan: 1
);

// set the input gain
MIDIdef.cc(\prettySynth2_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,10.0);

		("prettySynth2 - MicGain: ").post;
		val.round(0.01).postln;
		~prettySynth2.sdef.set(\inMul, val);
	},
	ccNum: 7,
	chan: 1
);

// set the output gain
MIDIdef.cc(\prettySynth2_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("prettySynth2 - Out Gain: ").post;
		val.round(0.01).postln;
		~prettySynth2.sdef.set(\outMul, val);
	},
	ccNum: 17,
	chan: 1
);

// set input chan
~prettySynth2.micChan = 0;
MIDIdef.cc(\prettySynth2_inChan,
	{
		arg val, ccNum, chan, id;

		~prettySynth2.micChan = ~prettySynth2.micChan + 1;
		~prettySynth2.micChan = (~prettySynth2.micChan).mod(4);

		("prettySynth2 - In Chan: ").post;
		~prettySynth2.micChan.postln;

		~prettySynth2.sdef.set(\input, ~prettySynth2.micChan);
	},
	ccNum: 37,
	chan: 1
);