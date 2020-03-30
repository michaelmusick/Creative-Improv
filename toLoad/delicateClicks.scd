/**************************************************************

 Project: Sonic Space No. 8 -- One Deliberate Day
    File: delicateClicks.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-07-19 14:25:34
Modified: 2015-08-01 15:31:18


   Notes: scared clicks: These are very active and noise.
   			But hide with a transient.


**************************************************************/


/*
~d3= Synth(\scaredClicks, [\input, 0, \output, 0, \dustRate, 5])
*/

"\'Loading scaredClicks\'".postln;

(
~scaredClicks = ();
~scaredClicks.sdef = Array.newClear(~global.mic.size);
);

(
SynthDef(\scaredClicks, {
	arg input = 0, output = 12, panPos = 0, dustRate = 20, outMul = 1, inMul = 1;
	var sig, analysis, env, delay = 5, decay = 15;

	sig = SoundIn.ar(input);

	analysis = PeakFollower.kr(sig, 0.99);
	env = Env.asr(0.01, 1, 4, 10);
	env = EnvGen.kr( env,
		analysis.linlin(0, 0.2707, -0.5, 0.1).clip(0,1)
	);
	env = (env).clip(0,1);


	sig = DelayC.ar( sig, 1, 1 ) * inMul.lag(0.1);


	sig = PitchShift.ar(
		in: sig,
		windowSize: 0.2,
		pitchRatio: 2,
		pitchDispersion: 0.02,
		timeDispersion: 0.2
	);

	sig = sig * Dust.kr( dustRate*2*inMul.lag(0.1) ).lag(0.01, 0.05);

	delay = DelayN.kr(env.linlin(0, 1, 10, 0.1), 4, 4);
	sig = CombC.ar( sig, 10, delay.lag(0, 10), decay );

	sig = HPF.ar( sig, 2000+(env).linlin(0, 1, 0, 20000) );

	sig = sig * Dust.kr( dustRate ).lag(0.01, 0.05);

	// fucking around and adding a pos value
	panPos = analysis.linlin(0, 0.2, 1e-6, 10);
	panPos = SinOsc.ar(panPos);


	sig = sig * 500;
	sig = HighShelf.ar(sig, 5000, dbgain: -3 );

	sig = Limiter.ar( sig, analysis.linlin(0, 0.45, 1, 0), 0.01 );

	sig = Pan2.ar(sig, panPos);

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


MIDIdef.cc(\scareClicks_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~scaredClicks.sdef[0].notNil,
				{
					~scaredClicks.sdef.do({|item, idx|
						item.free; ~scaredClicks.sdef[idx] = nil;
					});
			});
			"Starting \scaredClicks".postln;
			~scaredClicks.sdef.do({|item, idx|
				~scaredClicks.sdef[idx] = Synth(\scaredClicks, [\input, ~global.mic[1] + idx ]);
			});
		});

		if(val==0, {
			if(~scaredClicks.sdef[0].notNil,
				{
					"KILL \scaredClicks".postln;
					~scaredClicks.sdef.do({|item, idx|
						item.free; ~scaredClicks.sdef[idx] = nil;
					});
			});

		});

	},
	ccNum: 24,
	chan: 1
);

// set the input gain
MIDIdef.cc(\scareClicks_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,10.0);

		("scareClicks - MicGain: ").post;
		val.round(0.01).postln;
		~scaredClicks.sdef.do({|item, idx|
			~scaredClicks.sdef[idx].set(\inMul, val);
		});
	},
	ccNum: 4,
	chan: 1
);

// set the output gain
MIDIdef.cc(\scareClicks_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,4.0);

		("scareClicks - Out Gain: ").post;
		val.round(0.01).postln;
		~scaredClicks.sdef.do({|item, idx|
			~scaredClicks.sdef[idx].set(\outMul, val);
		});
	},
	ccNum: 14,
	chan: 1
);


