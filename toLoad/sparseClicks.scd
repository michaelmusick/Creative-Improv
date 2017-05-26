/**************************************************************

 Project: Sonic Space No. 8 -- One Deliberate Day
    File: sparseClicks.scd

  Author: Michael Musick
   Email: michael@michaelmusick.com

 Created: 2015-07-19 17:22:50
Modified: 2015-11-05 19:40:44


   Notes: A very nice little noise burst feedback synth.
   		The delay can be quite short (ie. 0.01") but because of how the sound
   		is pulled apart, the synth does not blow up.





**************************************************************/

/*
~sc3 = Synth(\sparseClicks, [\input, 10])
*/

"\'Loading sparseClicks\'".postln;

(
~sparseClicks = ();
);

(
SynthDef(\sparseClicks, {
	arg input = 0, output = 2, bufferSize = 512, panPos = 0,
		magBelowThresh = 70, inMul = 1, outMul = 1;
	var sig, analysis, runningMin, runningMax, sigFFT, delay, onsetanalysis;
	var burstEnv, amplitude;


	sig = SoundIn.ar(input) * inMul.lag(1);

	sigFFT = FFT(
		LocalBuf(bufferSize),
		sig,
		hop: 0.5,
		winsize: bufferSize * 2
	);

	// Spectral Power of the incoming signal
	analysis = (FFTPower.kr(sigFFT)+0);
	// create a time variable running min/max from spectral power
	runningMin = analysis.lag(30, 0);
	runningMax = analysis.lag(0, 30);

	// get information about the rate of onsets detected
	onsetanalysis = OnsetStatistics.kr(
		Onsets.kr(sigFFT,0.3),
		// window size of statistics
		2.0
	);

	sigFFT = PV_Compander(sigFFT, thresh: 1, slopeBelow: 4, slopeAbove: 10);
	sigFFT = PV_MagBelow(sigFFT, magBelowThresh);
	sigFFT = PV_LocalMax(sigFFT, 30);
	sig = IFFT(sigFFT, winsize: bufferSize * 2);

	// map the analysis sig to Comb Filter Delay Length
	// add constant ints to inMin/inMax in order to prevent 'nan'
	delay = LinLin.kr(analysis, runningMin+0, runningMax+1, 0.01, 4000).clip(0.00001, 2000).lag(0.5, 2);
	amplitude = LinLin.kr(analysis, runningMin+0, runningMax+1, 1, (-120).dbamp );

	// releaseTime
	burstEnv = LinLin.kr(onsetanalysis[0], 0, 20, 0.2, 0.01).clip(0.01,1);
	burstEnv = Env.perc(0.001, burstEnv);
	burstEnv = EnvGen.kr(burstEnv, Dust.kr((onsetanalysis[0]).lag(0.01, 0.1)));


	sig = Normalizer.ar(sig, 0.7, 0.1) * inMul.lag(1);
	sig = sig * burstEnv;

	sig = CombC.ar(sig, 10, delay, delay*1) * amplitude;
	sig = HPF.ar(sig, 30) * 0.5;

	// fucking around and adding a pos value
	panPos = analysis.linlin(0, runningMax, 1e-6, 10);
	panPos = SinOsc.ar(panPos);


	sig = Pan2.ar( sig, panPos );

	sig = sig * outMul;

	// Limit signal so it does not blow up
	sig = Limiter.ar( sig, level: (-3).dbamp, dur: 0.01 );
	//  Insert high and low pass filters to protect speakers
	sig = LPF.ar( sig, freq: s.sampleRate*0.5 );
	sig = HPF.ar( sig, freq: 40 );
	sig = sig * Line.kr(0, 1, 8);
	sig = LeakDC.ar(sig);

	Out.ar( output, sig );




}).add;
);




MIDIdef.cc(\sparseClicks_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~sparseClicks.sdef.notNil,
				{~sparseClicks.sdef.free; ~sparseClicks.sdef = nil;});
			"Starting \sparseClicks".postln;
			~sparseClicks.sdef = Synth(\sparseClicks);
		});

		if(val==0, {
			if(~sparseClicks.sdef.notNil,
				{
					"KILL \sparseClicks".postln;
					~sparseClicks.sdef.set(\inMul, 0);
					~sparseClicks.sdef.free; ~sparseClicks.sdef = nil;
			});

		});

	},
	ccNum: 25,
	chan: 1
);

// set the input gain
MIDIdef.cc(\sparseClicks_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,10.0);

		("sparseClicks - MicGain: ").post;
		val.round(0.01).postln;
		~sparseClicks.sdef.set(\inMul, val);
	},
	ccNum: 5,
	chan: 1
);

// set the output gain
MIDIdef.cc(\sparseClicks_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("sparseClicks - Out Gain: ").post;
		val.round(0.01).postln;
		~sparseClicks.sdef.set(\outMul, val);
	},
	ccNum: 15,
	chan: 1
);

// set input chan
~sparseClicks.micChan = 0;
MIDIdef.cc(\sparseClicks_inChan,
	{
		arg val, ccNum, chan, id;

		~sparseClicks.micChan = ~sparseClicks.micChan + 1;
		~sparseClicks.micChan = (~sparseClicks.micChan).mod(4);

		("sparseClicks - In Chan: ").post;
		~sparseClicks.micChan.postln;

		~sparseClicks.sdef.set(\input, ~sparseClicks.micChan);
	},
	ccNum: 35,
	chan: 1
);
