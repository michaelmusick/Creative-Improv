/**************************************************************

Project: Sonic Space No. 8 -- One Deliberate Day
File: reflectiveMoments_rpi.scd

Author: Michael Musick
Email: michael@michaelmusick.com

Created: 2015-07-22 09:57:36
Modified: 2015-08-04 15:11:22


Notes:


**************************************************************/

"reflectiveMoments loading".postln;
// alloc buffers
(
~addr = NetAddr.localAddr;

~rmOut = 16;
~rm_BuffArray = (ptr: 0);
~rm_BuffArray.maxBuffs = 60;
~rm_BuffArray.audio = Array.newClear(~rm_BuffArray.maxBuffs);
~rm_BuffArray.mfccs = Array.newClear(~rm_BuffArray.maxBuffs);
~rm_BuffArray.meanmfcc = Array.newClear(~rm_BuffArray.maxBuffs);
~rm_BuffArray.startNum = 2;

~rm_info = ();
// the number of listener synths (probably 1 per mic)
~rm_info.numOfListeners = 1;
~rm_info.ptr = 0;
~rm_info.grainLen = 0.05;
~rm_info.tmpNum = 3;
~rm_info.listener = Array.fill(~rm_info.numOfListeners, {
	|i| (
		micSig: Bus.audio(s, 1).postln,
		mfccSig: Bus.control(s,13).postln,
		mfccPrev: Array.fill(12, {0}),
		sPtr: 0,
		recorder: Array.newClear(~rm_info.tmpNum),
		tempBuff: Array.fill(~rm_info.tmpNum, {|j| Buffer.alloc(s, 3*s.sampleRate )} ),
		tempMFCC: Array.fill(~rm_info.tmpNum, {|u| Buffer.alloc( s,
			(3/~rm_info.grainLen).round, 13 )}; ),
		temp: Array.fill(~rm_info.tmpNum, {(audiohead:0,mfcchead:0,meanMFCC:Array.newClear(13) )};),
		fluxBus: Bus.control(s,1)

	)
});

~rm_info.in = [~global.mic[1],~global.mic[2], 0, 1];
~rm_info.outGain = 1;

~grainWait = 0.1;
~nodeDistanceThresh = 0.2;
~rm_info.mfccDiffThresh = 0.6;
);




(
SynthDef(\reflectiveMomentsAnalysis, {
	arg input = 0, output = 0, micBus = 0, krBus = 1, onsetThresh = 0.3,
	id = 0, analFFTSize = 512, fluxBus = 0, input_gain = 1;
	var sig, trig, delaySig, delayAmt, mfcc, env, envTrig, fft, flux;


	// Input signal from microphone
	// sig = SoundIn.ar(input);
	sig = SoundIn.ar( input ) * input_gain;
	// RunningSum.rms(sig).poll(label: \rm_mic_rms);

	// sig delay is a function of analysis size/length
	// that way signals are delayed the correct amount heading into the recorderSynth
	delayAmt = (analFFTSize / SampleRate.ir) * 2;

	// delayed version for recordingSynth
	delaySig = DelayC.ar(sig, delayAmt, delayAmt);
	Out.ar(micBus, delaySig);


	envTrig = LocalIn.kr(1);
	env = Env.new(
		[0, 2, 1, 0],
		[0.01, 0.8, 0.2]
	);
	env = EnvGen.kr(env, gate: envTrig, doneAction: 0);
	onsetThresh = onsetThresh + env;

	// ANALYSIS to determine when to record
	// TODO: what other analysis features should the species look at/consider?
	trig = Onsets.kr(
		FFT(LocalBuf(analFFTSize), sig, wintype: 1),
		threshold: onsetThresh,
		odftype: \wphase,
		relaxtime: 2,
		floor: 0.05,
		mingap: 10,
		medianspan: 11
	);
	LocalOut.kr( trig );
	// Send a trigger to sclang. This will analyze the data,
	// and start a recordingSynth if deemed appropriate
	// SendTrig.kr(trig, synthNum);

	// get mfcc's; 13 coef's
	fft = FFT( LocalBuf(1024), sig, wintype: 1 );
	mfcc = MFCC.kr(
		fft,
		13
	);
	Out.kr( krBus, mfcc.lag(0.01) );
	flux = FFTFlux.kr(fft).lag(0.01);
	Out.kr( fluxBus, flux );

	mfcc = Lag.kr(mfcc, lagTime: 0.1 );
	SendReply.kr(trig, '/analSynth',
		values: mfcc,
		replyID: id
	);

	// Out.ar( output, sig );
}).add;




SynthDef(\audioRecorder, {
	// bufnum is the buffer to write to
	// input is the audio input channel
	// delaycomp compensates for any delays introduced during pre-processing
	arg bufnum_audio = 0, bufnum_mfccs,
	input_audio = 0, input_slope = 1, input_mfcc = 2,
	grainLength = 0.05, fluxThresh = 1.0,
	bus_smooth = 0, fluxDelayComp = 0.5,
	t_reset = 0, gate = 1,
	id = 0, buffPtr = 0;
	var inSig, mfccSig, playhead_ar, playhead_grain;
	var recorder, countdown, env, envSig, mfccTrig, timestamp, averageMFCC;
	var avgCount, avgGate, envTrig;
	var onsetSig, flux;


	// an envelope
	envTrig = (gate * (1 - Trig1.kr( LocalIn.kr(1), 10 )));
	env = Env.new([0,0,1,1,0,0], [0.001, 0.05, 0, 0.05, 0.01], releaseNode: 3 );
	envSig = EnvGen.ar(env, envTrig );

	// input signals
	inSig = Delay2.ar(Delay2.ar( In.ar(input_audio) )) * envSig ;
	// inSig.poll(label: \sig);
	mfccSig = In.kr(input_mfcc, 13);



	// track playheads for each signal
	// keeping track of these values allow for variable length written signals
	playhead_ar = Phasor.ar(
		trig: t_reset,
		rate: 1,
		start: 0,
		end: BufFrames.kr(bufnum_audio),
		resetPos: 0
	);

	playhead_grain = (playhead_ar / (s.sampleRate * grainLength)).floor;

	// use the flux value as a gate for the mean MFCC value set calculation
	flux = FFTFlux.kr( FFT( LocalBuf(1024), inSig, wintype: 1) );
	flux = flux + Line.kr(3, 0, 0.5);
	// flux.poll(label: "flux");
	flux = ((flux - fluxThresh)*(-1));
	// flux.poll(label: "fluxThresh");

	// TRACK THE MFCC VALUES FOR THIS PHRASE
	// THIS IS USED FOR TIMBRE CLASSIFICATION.
	// only let MFCCs through when spectral flux is stable
	avgGate = Clip.kr(flux, 0, 1).ceil;
	// avgGate.poll(label: "gate");
	averageMFCC = if(avgGate, mfccSig, 0!13);
	// get the number of readings counted
	avgCount = 1 + RunningSum.kr(avgGate,
		(s.sampleRate/s.options.blockSize*60).ceil);
	// insure that division by 0 will not occur
	avgCount = Clip.kr(avgCount,
		lo: 1,
		hi: (s.sampleRate/s.options.blockSize*60).ceil);
	// avgCount.poll(label: "sumCount");
	// averageMFCC = AverageOutput.kr(averageMFCC);
	// find the average for MFCCs
	averageMFCC = RunningSum.kr(averageMFCC,
		(s.sampleRate/s.options.blockSize*60).ceil);
	// averageMFCC[3].poll(label: "testCoeff0");
	averageMFCC = averageMFCC / avgCount;
	// averageMFCC[3].poll(label: "testCoeff1");
	// IF AVG MFCC IS NEEDED INCORPORATE THE FOLLOWING
	// Out.kr(bus_smooth, averageMFCC);

	// apply smoothing to capture the nature of each grain
	mfccSig = MeanTriggered.kr(mfccSig[1..13-1], 1,
		grainLength/(s.options.blockSize/s.sampleRate));
	// capture the first time stamp for each grain and append to the list
	mfccTrig = Changed.ar(playhead_grain);
	timestamp = Latch.ar(playhead_ar, mfccTrig);
	// bundle into an array
	mfccSig = mfccSig++[timestamp];

	// copy it all in! HUZZAH
	BufWr.kr( mfccSig, bufnum_mfccs, playhead_grain, 0 );
	recorder = BufWr.ar( inSig, bufnum_audio, playhead_ar, 0 );

	// keep track of space remaining in each buffer
	countdown = (playhead_ar - BufFrames.kr(bufnum_audio)+100);
	LocalOut.kr(countdown+(SampleRate.ir*0.5));

	// if at the end, then let client know and relay the playhead positions
	SendReply.ar([K2A.ar(Done.kr(envSig)), countdown], '/endOfRec',
		values: ( [buffPtr, playhead_ar, playhead_grain] ++ averageMFCC ),
		replyID: id
	);

	FreeSelf.kr(Done.kr(recorder) + K2A.ar(Done.kr(envSig)));

	// mfccSig.poll;
	// (playhead_ar / s.sampleRate).poll;
	// [playhead_ar, playhead_kr, playhead_grain].poll;
	// countdown.poll(label:"countdown");

}).add;
);


OSCdef.newMatching(\analResponder,
	{
		|msg, time, addr, recvPort|
		var id, mfccArray, buffPtr;
		var mfccDiff;
		{
			// msg.postln;
			id = msg[2];
			mfccArray = msg[3..];

			// get the euclidean distance from the last 'marked' phrase
			mfccDiff =  ( mfccArray[1..12] - ~rm_info.listener[id].mfccPrev );
			mfccDiff = (mfccDiff**2).sum.sqrt;

			if( mfccDiff >= ~rm_info.mfccDiffThresh, {

				// stop the last recording (if it is still going)
				buffPtr = ~rm_info.listener[id].sPtr;
				if(~rm_info.listener[id].recorder[buffPtr].notNil, {
					~rm_info.listener[id].recorder[buffPtr].set(\gate, 0);
					~rm_info.listener[id].recorder[buffPtr] = nil;
				});

				// make sure we are caught up
				0.1.wait;

				// change the tempRecorder Synth Array Pointer
				buffPtr = ( (buffPtr+1) % ~rm_info.tmpNum );
				~rm_info.listener[id].sPtr = buffPtr;
				// copy over the MFCC set for future comparisons
				~rm_info.listener[id].mfccPrev = mfccArray[1..12];

				// Start a new recorder synth
				~rm_info.listener[id].recorder[buffPtr] = Synth(\audioRecorder,
					[
						\id, id,
						\buffPtr, buffPtr,
						\input_audio, ~rm_info.listener[id].micSig,
						\input_mfcc, ~rm_info.listener[id].mfccSig,
						\bufnum_audio, ~rm_info.listener[id].tempBuff[buffPtr],
						\bufnum_mfccs, ~rm_info.listener[id].tempMFCC[buffPtr],
					],
					addAction: \addToTail
				);
				// "new Recorder: ".post; id.post; ":".post;buffPtr.postln;

			};
			);


			// time.postln;
			// addr.postln;
			// recvPort.postln;

		}.fork;
	},
	'/analSynth'
);


// "End Of Recording Messages"
OSCdef.newMatching(\endOfRec,
	{
		arg msg, time, addr, recvPort;
		var id, buffPtr, buffArrayPtr;
		// msg.postln;

		// get the ~tempRecSynths[] instance id
		id = msg[2];
		buffPtr = msg[3];

		// copy over the data!
		~rm_info.listener[id].temp[buffPtr].audiohead = msg[4];
		~rm_info.listener[id].temp[buffPtr].mfcchead = msg[5];

		// must be longer than 2"
		if( ( ~rm_info.listener[id].temp[buffPtr].audiohead >= (s.sampleRate*1) ), {
			// "recording is long enough. copy it and get classifications".postln;
			// {~rm_info.listener[id].tempBuff[buffPtr].plot}.defer;

			// increment the pointer so that the other voices cannot try and grab it.
			buffArrayPtr = ~rm_BuffArray.ptr;
			~rm_BuffArray.ptr = (buffArrayPtr + 1) % ~rm_BuffArray.maxBuffs;



			~rm_info.listener[id].tempMFCC[buffPtr].loadToFloatArray(
				action: {
					arg array;

					~rm_BuffArray.mfccs[buffArrayPtr] = array.reshape(
						(~rm_info.listener[id].temp[buffPtr].mfcchead+1).asInt,
						13);
					~rm_BuffArray.mfccs[buffArrayPtr].do({
						|arr, idx|
						~rm_BuffArray.mfccs[buffArrayPtr][idx] = arr[0..11] ++ [(ts:arr[12], idx:buffArrayPtr, ogid:id)];
					});

					// IF ITS TIME, GET A NEW KDTREE
					if( ((buffArrayPtr+1)%~rm_BuffArray.startNum) == 0, {
						~addr.sendMsg('/startThePlayer', id, buffArrayPtr);
					});

			});

			~rm_BuffArray.meanmfcc[buffArrayPtr] = msg[6..18];

			~rm_BuffArray.audio[buffArrayPtr] = Buffer.alloc( s,
				~rm_info.listener[id].temp[buffPtr].audiohead, 1,
				// send a message which calls a copy function once its allocated
				completionMessage: { ~addr.sendMsg('/audioBuffReady', id, buffPtr, buffArrayPtr); }
			);

		}, {
			// POSTER
			// "phrase was too short to classify".postln;
		} );

		// release the pointer so another process doesn't try to free a dead Synth
		~rm_info.listener[id].recorder[buffPtr] = nil;

	}, 	// end of the OSCFunc function definition
	// the message to match
	'/endOfRec'
);



// COPY THE AUDIO INTO THE audioArray
OSCdef.newMatching(\audioReady,
	{
		arg msg, time, addr, recvPort;
		var id, buffPtr, buffArrayPtr, num;
		// msg.postln;

		// get the ~tempRecSynths[] instance id
		id = msg[1];
		buffPtr = msg[2];
		buffArrayPtr = msg[3];

		~rm_info.listener[id].tempBuff[buffPtr].copyData(
			~rm_BuffArray.audio[buffArrayPtr]
		);
		~rm_BuffArray.audio[buffArrayPtr].normalize;

		// plot & play the saved signal
		// num = ~rm_BuffArray.ptr;
		// ~rm_BuffArray.audio[num].play;
		// {
		// 	{if((~audioWindow1 != nil), {~audioWindow1.parent.close;});}.defer;
		// 	0.01.wait;
		// 	{~audioWindow1 = ~rm_BuffArray.audio[num].plot;}.defer;
		// 	{~audioWindow1.parent.onClose = { ~audioWindow1 = nil };}.defer;
		// }.fork;

	},
	'/audioBuffReady'
);







/**************************************************************************

Create a tree and after completing X number of recordings.
This can then be searched using .nearest(mfccArray[]).
**************************************************************************/
OSCdef.newMatching(\startThePlayer,
	{
		arg msg, time, addr, recvPort;
		var id, buffArrayPtr;
		var tempArr, size, continue=true;
		// msg.postln;

		id = msg[1];
		buffArrayPtr = msg[2];

		tempArr = ~rm_BuffArray.mfccs[0..buffArrayPtr].deepCopy;
		// tempArr.postln;
		d = tempArr;
		size = tempArr.flatSize;
		// ("The size of the array is: " + size).postln;
		size = (size/15);
		// ("The numbers of entires is: " + size).postln;
		if( size%1==0, {},{"boooo".postln; continue=false;});


		if(continue, {
			tempArr = tempArr.reshape(size.asInt, 13);
			~rm_tree = KDTree( tempArr, lastIsLabel: true );

			if(~rm_players.isNil, {
				~rm_players = ~grainSearch.(0).start;
				"\'Started the Grain Players!!!!\'".postln;
			});
		});

	},
	'/startThePlayer'
);

(
~grainSearch = {
	arg id = 0;
	Task({
		arg lookAhead = 0.1, fluxThresh = 0.3, waitTime = 0.25;
		var timestamp, label, lastLabel, distance, buffId;
		var dur = 0;
		// "Grain Search Function Started".postln;
		inf.do{
			~rm_info.listener[0].fluxBus.get({
				arg fluxVal;
				// fluxVal.postln;
				if( (fluxVal < fluxThresh), {
					~rm_info.listener[id].mfccSig.get({
						arg mfccSet;
						var node, updown, out, pitchShift, level;
						// mfccSet.postln;
						node = ~rm_tree.nearest( mfccSet[1..12] );
						distance = node[1];
						label = (node[0].label);
						out = 0;
						updown = (2.rand).asInteger;
						if(updown==0,
							{ pitchShift = distance.expexp(0.05, 0.4, 1, 1.5).clip(1, 2);
								level = distance.explin(0.1, 0.4, 0.8, 0.6 ).clip(0.3, 1) },
							{ pitchShift = distance.expexp(0.05, 0.4, 1, 0.5).clip(0.5, 1);
								level = distance.explin(0.1, 0.4, 0.6, 0.2 ).clip(0.3, 1) }
						);

						if( (distance < ~nodeDistanceThresh).and(label != lastLabel), {
							timestamp = label.ts;
							buffId = label.idx;
							// make sure cpu is low enough
							if( s.peakCPU<60, {
								dur = distance.expexp(0.05, ~nodeDistanceThresh, 1, 0.1);
								// ("ID: "++id++" DistanceThresh: "++~nodeDistanceThresh++" Distance: "++distance.round(0.01)++"- Dur: "++dur.round(0.01)++"- Level: "++level.round(0.01)++"- pitchShift: "++pitchShift.round(0.01)++
								// "- Timestamp: "++timestamp++"- Last Timestamp: "++lastTimestamp++"- Flux: "++fluxVal.round(0.01)).postln;
								{Synth(\grainPB,
									args: [\startFrame, timestamp, \dur, dur,
										\level, level * ~rm_info.outGain,
										\out, ~rmOut, \pitchShift, pitchShift,
										\bufnum, ~rm_BuffArray.audio[buffId],
									],
									// target: ~sysOut,
									// addAction: \addBefore
								);
								}.value;
								lastLabel = label;
								// ~nodeDistanceThresh = 0;
							}/*, {"cpu too high".postln;}*/);
						}, { dur = 0; } );

					});
				});
				// ~nodeDistanceThresh = ~nodeDistanceThresh + 0.02;
			});
			// choose an appropriate wait time
			if( (dur*0.25) > 0, {(dur*0.15).wait;}, {~grainWait.wait});
		};
	});
};
);

SynthDef(\grainPB, {
	arg startFrame = 0, dur = 0.6, level = 1, bufnum = 0,
	pitchShift = 1, out = 0;
	var sig, env;



	// env = Env.sine( dur, level );
	env = Env.new(
		[ 0, 0.5, 1, 0.5, 0, 0 ],
		[0.25, 0.25, 0.25, 0.25, 0.25],
		[1, -1, 1, -1, 0]*5
	);
	env = EnvGen.kr( env, levelScale: level, timeScale: dur, doneAction: 2 );

	sig = PlayBuf.ar(
		numChannels: 1,
		bufnum: bufnum,
		rate: 1,
		trigger: 1,
		startPos: startFrame,
		loop: 1,
		doneAction: 2
	) * 0.707;

	// pitch shift
	sig = PitchShift.ar( sig,
		windowSize: 0.023,
		pitchRatio: pitchShift,
		pitchDispersion: 0,
		timeDispersion: 0.001
	);



	sig = Limiter.ar( sig, 0.95, 0.1 );

	sig = sig * env;

	sig = HPF.ar( sig, freq: 80 );

	sig = Pan2.ar(sig, LFNoise1.kr(1));


	Out.ar( out, sig );
	// OffsetOut.ar( out, sig );

}).add;



/***********************************************/


// ~grainWait // -> 0.01 25
// ~nodeDesitanceThresh // -> 0.01 0.3
/*
~rm_info.synth1 = Synth(\reflectiveMomentsAnalysis, [
// id.postln;
\micBus, ~rm_info.listener[0].micSig,
\ampBus, ~rm_info.listener[0].ampSig,
\krBus, ~rm_info.listener[0].mfccSig,
\fluxBus, ~rm_info.listener[0].fluxBus,
\onsetThresh, 0.2,
\input, 24,
\id, 0
]);


~rm_info.synth1.free;
if(~rm_players.notNil, {~rm_players.stop;});

*/


(
~rm_OSC.notNil(thisProcess.removeOSCRecvFunc(~rm_OSC));
~rm_OSC = { |msg, time, addr|
	var val, oscAddr, inst, idx, mainParam, secondParam;
	oscAddr = msg[0].asString.split;

	// msg.postln;

	(oscAddr[1].asSymbol == \rm).if({
		inst = oscAddr[1].asSymbol;

		mainParam = oscAddr[2].asSymbol;
		secondParam = oscAddr[3].asSymbol;
		val = msg[1];

		// oscAddr.postln;
		// secondParam.postln;
		// val.postln;

		/* Turn the Synths on and off */
		(mainParam == \OnOff).if({
			// ("Turn "++idx++" OnOff").postln;
			if(val==1, {
				~rm_info.synth1 = Synth(\reflectiveMomentsAnalysis, [
					// id.postln;
					\micBus, ~rm_info.listener[0].micSig,
					\ampBus, ~rm_info.listener[0].ampSig,
					\krBus, ~rm_info.listener[0].mfccSig,
					\fluxBus, ~rm_info.listener[0].fluxBus,
					\onsetThresh, 0.2,
					\input, ~rm_info.in[0],
					\id, 0
				]);
				("START Reflective Moments Analysis...").postln;
			});

			if(val==0, {
				~rm_info.synth1.free;
				if(~rm_players.notNil, {~rm_players.stop;});

			});
		});

		/* Set Input Chan */
		(secondParam == \input).if({
			("Set input to "++~rm_info.in[val]).postln;
			~rm_info.synth1.set(\input, ~rm_info.in[val]);
		});

		/* Set Mic Gain */
		(secondParam == \micGain).if({
			("Set mic gain to "++val).postln;
			~rm_info.synth1.set(\input_gain, val);
		});

		/* Set Out Gain */
		(secondParam == \outGain).if({
			("Set out gain to "++val).postln;
			~rm_info.outGain = val;
		});


		/* Set Decay Time */
		(secondParam == \onsetThresh).if({
			("Set onset threshold to "++val).postln;
			~rm_info.synth1.set(\onsetThresh, val);
		});

		/* Set Delay Lag */
		(secondParam == \mfccDiffThresh).if({
			("Set mfcc diff thresh to "++val).postln;
			~rm_info.mfccDiffThresh = val;
		});


		/* Set Delay Time */
		(secondParam == \nodeDistThresh).if({
			("Set node distance thresh to "++val).postln;
			~nodeDistanceThresh = val;
		});

		/* Set PitchEffect OnOff */
		(secondParam == \grainWait).if({
			("Set grainWait to "++val).postln;
			~grainWait = val;
		});





	}

	)
};
thisProcess.addOSCRecvFunc(~rm_OSC);
);




"reflectiveMoments done".postln;