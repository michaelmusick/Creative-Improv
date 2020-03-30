/**************************************************************

Project: Sonic Space No. 8 -- One Deliberate Day
File: smallSounds.scd

Author: Michael Musick
Email: michael@michaelmusick.com

Created: 2015-07-19 14:23:55
Modified: 2015-08-01 17:58:46


Notes:


**************************************************************/


/*
~small_1 = Synth(\smallSounds, [\input, 10, \outMul, 0.7])
~small_2 = Synth(\smallSounds, [\input, 11, \outMul, 0.7])

~small_1.set(\outMul, 0)
~small_2.set(\outMul, 0)
*/

"\'Loading smallSounds\'".postln;

(
~smallSounds = ();
);

(
SynthDef(\smallSounds) {
	arg input = 0, output = 6, binMul = 60,
	fftSize = 4096, outMul = 1, inMul = 1;
	var sig, sigFFT, harmFFT, percFFT;

	sig = SoundIn.ar( input ) * inMul.lag(0.1);

	// sig = DelayC.ar(sig, 1, 1);

	sigFFT = FFT(
		LocalBuf(fftSize),
		sig,
		hop: 0.5,
		wintype: 0,
		winsize: fftSize*2
	);

	// separate out percussive and harmonic components
	// this patch will only use perc components
	#harmFFT,percFFT = MedianSeparation(
		sigFFT,
		FFTTrigger( LocalBuf(fftSize) ),
		FFTTrigger( LocalBuf(fftSize) ),
		fftSize,
		17,
		1,
		2,
		1
	);

	// only grab back ground noise in a range
	percFFT = PV_MagBelow(percFFT, 1.9);
	percFFT = PV_MagAbove(percFFT, 1.7);
	// amplify those bins
	percFFT = PV_MagMulAdd(percFFT, binMul);


	sig = IFFT.ar(percFFT, wintype: 0, winsize: fftSize*2);

	sig = HPF.ar( sig, 80 ) * 0.4;
	sig = HighShelf.ar( sig, 4000, dbgain: (-4.5) );

	// remove click at start
	sig = Line.ar(0, 1, 4) * sig * outMul.lag(1);

	// Limit signal so it does not blow up
	sig = Limiter.ar( sig, level: (-3).dbamp, dur: 0.01 );
	//  Insert high and low pass filters to protect speakers
	sig = LPF.ar( sig, freq: s.sampleRate*0.5 );
	sig = HPF.ar( sig, freq: 40 );
	sig = sig * Line.kr(0, 1, 8);
	sig = LeakDC.ar(sig);

	Out.ar(output, sig ! 2);

	// FreeSelf.kr( (0.0001 - inMul.lag(100)) );

}.add;
);



MIDIdef.cc(\smallSounds_init,
	{
		arg val, ccNum, chan, id;
		// "val:".post; val.round(0.01).postln;
		// "cc:".post; ccNum.postln;
		// "chan:".post; chan.postln;
		// "".postln;


		if(val > 0, {
			if(~smallSounds.sdef.notNil,
				{~smallSounds.sdef.free; ~smallSounds.sdef = nil;});
			"Starting \smallSounds".postln;
			~smallSounds.sdef = Synth(\smallSounds, [\input, ~global.mic[1]]);
		});

		if(val==0, {
			if(~smallSounds.sdef.notNil,
				{
					"KILL \smallSounds".postln;
					~smallSounds.sdef.set(\inMul, 0);
					~smallSounds.sdef.free; ~smallSounds.sdef = nil;
			});

		});

	},
	ccNum: 23,
	chan: 1
);

// set the input gain
MIDIdef.cc(\smallSounds_inMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,10.0);

		("smallSounds - MicGain: ").post;
		val.round(0.01).postln;
		~smallSounds.sdef.set(\inMul, val);
	},
	ccNum: 3,
	chan: 1
);

// set the output gain
MIDIdef.cc(\smallSounds_outMul,
	{
		arg val, ccNum, chan, id;
		val = val.linlin(0,127.0,0,1.0);

		("smallSounds - Out Gain: ").post;
		val.round(0.01).postln;
		~smallSounds.sdef.set(\outMul, val);
	},
	ccNum: 13,
	chan: 1
);

// set input chan
~smallSounds.micChan = 0;
MIDIdef.cc(\smallSounds_inChan,
	{
		arg val, ccNum, chan, id;

		~smallSounds.micChan = ~smallSounds.micChan + 1;
		~smallSounds.micChan = (~smallSounds.micChan).mod(2);

		("smallSounds - In Chan: ").post;
		(~smallSounds.micChan + ~global.mic[1]).postln;

		~smallSounds.sdef.set(\input, ~smallSounds.micChan + ~global.mic[1]);
	},
	ccNum: 33,
	chan: 1
);

