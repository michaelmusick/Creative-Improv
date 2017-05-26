// record synth - in from delay filter, record short snippet

// non-fading throwSamp...
// modulate dur of samp during echoes...
// samp doesn't fade until new samp starts?

(
var start = 0, bus, buf, recRout, sample, playSamp, throwSamp, trigTime, dur, loopSamp, loop_samp_rout, buf_track, ampTrig, randoSamp, hiRate;

trigTime = 0;
dur = 0.1;

SynthDef("ampFollow", {
	arg bus;
	var in, amp, out;
	in = Mix(SoundIn.ar([0, 1]));
	amp = Amplitude.kr(in);
	Out.kr(bus, amp);
}).add;

SynthDef(\Rec, { arg out = 0, bufnum = 0;
    var in;
	in = SoundIn.ar(0);
    RecordBuf.ar(in, bufnum, doneAction: 2, loop: 0);
}).add;

SynthDef(\playback, { arg out = 0, bufnum = 0, rate = 1, loop = 0, level = 1, pan = 0;
	var playbuf, env;
	playbuf = Pan2.ar(PlayBuf.ar(1, bufnum, rate, loop: loop, doneAction: 2), pan, level);
	env = EnvGen.kr(Env([0, 1, 1, 0], [0.01, dur/rate - 0.016, 0.006])); // for snippets
	// env = EnvGen.kr(Env([0, 1, 0], [dur/2, dur/2])); // for grains
	playbuf = playbuf * env;
	//playbuf = Pan2.ar(PlayBuf.ar(1,bufnum), LFNoise1.kr(0.6));
	//playbuf = Pan2.ar(PlayBuf.ar(1, bufnum, rate, doneAction: 2), Rand(-1.0, 1.0));
	FreeSelfWhenDone.kr(playbuf); // frees the synth when the PlayBuf is finished
	Out.ar(out, playbuf);
}).add;

buf_track = 0;
bus = Bus.control;
buf = Array.fill(10, {Buffer.alloc(s, 44100*dur, 1)} );
buf.postln;
Synth(\ampFollow, [\bus, bus]);

recRout = {
	Routine{
		// buf = buf.add(Buffer.alloc(s, 44100*dur, 1));
		// num_bufs = (buf.size).postln;
		0.001.wait;
		0.02.wait;
		Synth(\Rec, [\bufnum, buf[buf_track]]);

		throwSamp.play;
		// hiRate.play;

		0.2.wait;
		buf_track = (buf_track + 1)%10;
		buf_track.postln;
	}.play;
};

playSamp = Routine{
	2.wait;
	Synth(\playback, [\bufnum, buf, \rate, 1]);
};

throwSamp = {
	var r, p, l, b;
	b = buf_track;
	Routine{
		0.001.wait;
		0.1.wait;
		20.do{ arg count;
			exprand(0.06, 0.9).wait;
			r = rrand(0.96, 1.05);
			// r = rrand(2, 2.5);
			p = rrand(-1.0, 1.0);
			l = rrand(0.2, 1);
			l = l - (l * count / 20);
			Synth(\playback, [\bufnum, buf[b], \rate, r, \pan, p, \level, l]);
		};
	}.play;
};

hiRate = {
	var r, p, l, b;
	b = buf_track;
	Routine{
		0.1.wait;
		20.do{ arg count;
			exprand(0.06, 0.4).wait;
			r = rrand(3, 3.7);
			p = rrand(-1.0, 1.0);
			l = rrand(0.2, 1);
			// l = l - (l * count / 20);
			Synth(\playback, [\bufnum, buf[b], \rate, r, \pan, p, \level, l]);
		};
	}.play;
};

loopSamp = Routine{
	loop{
		Synth(\playback, [\bufnum, buf]);
		(dur/2).wait;
	};
};

loop_samp_rout = Routine{
	loopSamp.reset;
	2.wait;
	loopSamp.play;
	3.wait;
	loopSamp.stop;
};

ampTrig = Routine({
	var prev_val = 0;
	loop{
		bus.get( {arg val;
			if( (val > 0.008).and(prev_val <= 0.003).and(thisThread.clock.seconds - trigTime > 1), {
				start.postln;
				start = start + 1;

				recRout.play;
				// throwSamp.play;

				/*playSamp.reset;
				playSamp.play;*/
				/*loop_samp_rout.reset;
				loop_samp_rout.play;*/

				trigTime = thisThread.clock.seconds;
				trigTime.postln;
			});

			// if((val > 0.008), {"yaaaaarp".postln;});
			// if((val <= 0.003), {"narp".postln});
			prev_val = val;
		});
		//thisThread.clock.seconds.postln;
		0.04.wait;
	}
});

randoSamp = Routine({
	var rand;
	loop{
		bus.get( {arg val;
			rand = rrand(0, 20);
			if( (val > 0.005).and(rand == 2).and(thisThread.clock.seconds - trigTime > 0.8), {
				recRout.play;
				// throwSamp.play;

				trigTime = thisThread.clock.seconds;
			});

			if((val > 0.005), {"yaaaaarp".postln;}, {"narp".postln});

		});
		0.04.wait;
	}
});

// ampTrig.play;
randoSamp.play;

)






