// more gui controls for GrainBuf args

(
var bufs, dur, rec, playBtns, micBtns, mic, sliders, volSliders, plays, size, qty, ctrlViews, xmap, ymap;

dur = 3;
qty = 10;
bufs = Array.fill(qty, {Buffer.alloc(s, s.sampleRate * dur)});
plays = Array.newClear(qty);
mic = Array.fill(qty, {0});


SynthDef(\rec, { arg out = 0, bufnum = 0, mic = 0;
    var in;
	in = SoundIn.ar(mic);
    RecordBuf.ar(in, bufnum, doneAction: 2, loop: 0);
}).add;

/*SynthDef(\buf_grain, {
	arg gate = 1, amp = 1, sndbuf, envbuf;
	var env, out, grainDur;
	grainDur = 0.2;
	env = EnvGen.kr(
		Env([0, 1, 0], [1, 2], [-1, -5], 1),
        gate,
        amp,
        doneAction: 2);
	out = GrainBuf.ar(
		2,
		Impulse.kr(MouseX.kr(5, 100, 1)),
		grainDur,
		sndbuf,
		1,
		MouseY.kr(0.04, 0.96 - (grainDur / dur)),
		4,
		envbufnum: envbuf) * env;
	Out.ar(0, out);
}).add;*/

SynthDef(\buf_grain, {
	arg gate = 1, amp = 0.9, grainDur = 0.2, sndbuf, envbuf, freq = 50, pos = 0.1;
	var env, out;
	env = EnvGen.kr(
		Env([0, 1, 0], [1, 2], [-1, -5], 1),
        gate,
        amp,
        doneAction: 2);
	out = GrainBuf.ar(
		2,
		Impulse.kr(freq),
		grainDur,
		sndbuf,
		1,
		pos,
		4,
		envbufnum: envbuf) * amp * env;
	Out.ar(0, out);
}).add;


w = Window.new("grainy-grain", [100, 500, 500, 500], scroll: true).front;
w.background_(Color.grey(0.2));
q = w.addFlowLayout( 20@20, 30@30 );
size = 50;
ctrlViews = Array.fill(qty, {CompositeView(w, 200@200)} );
ctrlViews.do{ |item, ind|
	item.background_(Color.grey(0.3))
};

rec = Array.fill(qty, { |i|
	Button(ctrlViews[i], 75@size)
});
rec.do{ |item, ind|
	item.states_([
		["REC", Color.red, Color.white],
		["REC", Color.black, Color.red]
		]);
	item.action_({
		if (item.value == 1) {
			// ("rec" ++ mic[ind]).postln;
			Synth(\rec, [\bufnum, bufs[ind], \mic, mic[ind]]);
			Routine{
				dur.wait;
				{rec[ind].valueAction_(0)}.defer;
			}.play;
		};
	});
};

playBtns = Array.fill(qty, { |i|
	Button(ctrlViews[i], [75, 0, 75, size])
});
playBtns.do{ |item, ind|
	item.states_([
		["PLAY " ++ (ind), Color.green(0.8), Color.white],
		["STOP " ++ ind, Color.black, Color.green(0.9)]
	]);
	item.action_({
		if (item.value == 1) {
			plays[ind] = Synth(\buf_grain,
				[\sndbuf, bufs[ind], \envbuf, -1, \freq, 50, \pos, 0.01]);
		} {
			plays[ind].release
		}
	});
};

micBtns = Array.fill(qty, {|i|
	Button(ctrlViews[i], [150, 0, 50, size])
});
micBtns.do{ |item, ind|
	item.states_([
		["mic 1", Color.white, Color.black],
		["mic 2", Color.white, Color.black]
	]);
	item.action_({
		mic[ind] = item.value;
		mic[ind].postln;
	});
};

sliders = Array.fill(qty, { |i|
	Slider2D(ctrlViews[i], [0, size, 175, 200-size]);
});
xmap = ControlSpec(0.01, 0.9);
ymap = ControlSpec(5, 100, \exponential);
sliders.do{ |sl, ind|
	sl.background_(Color.rand);
	sl.x = 0;
	sl.y = 0.5;
	sl.action = {
		plays[ind].set(\pos, xmap.map(sl.x));
		plays[ind].set(\freq, ymap.map(sl.y));
		// plays[ind].set(\grainDur, ymap.map(sl.y));
	};
};

volSliders = Array.fill(qty, { |i|
	Slider(ctrlViews[i], [175, size, 25, 200-size])
});
volSliders.do{ |sl, ind|
	sl.value = 0.9;
	sl.action = {
		plays[ind].set(\amp, sl.value)
	}
}

)








y.release;



GrainBuf.ar(2, Impulse.kr(10), 0.1, sndbuf, LFNoise1.kr.range(0.5, 2),
	LFNoise2.kr(0.1).range(0, 1), 2, pan, envbuf) * env)