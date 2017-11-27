

(

//Explore
(    //<-- Double Click the Parenthesis and press "enter"
~pre = "/Users/mmusick/mm_GD/Art_Music/Sonic Environment Exploration 1/mmusickGorilla/natureSounds/";
~b1 = Buffer.read(s, ~pre++"bL1.wav");
~b2 = Buffer.read(s, ~pre++"bL2.wav");
~b3 = Buffer.read(s, ~pre++"bL3.wav");
~b4 = Buffer.read(s, ~pre++"bL4.wav");
~b5 = Buffer.read(s, ~pre++"bL5.wav");
~b6 = Buffer.read(s, ~pre++"bL6.wav");
~b7 = Buffer.read(s, ~pre++"bL7.wav");
~b8 = Buffer.read(s, ~pre++"bL8.wav");
~b9 = Buffer.read(s, ~pre++"bL9.wav");
~b10 = Buffer.read(s, ~pre++"bL10.wav");
);
~buff1 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;
~buff2 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;
~buff3 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;
~buff4 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;

//Buffer Playback Engine
(
SynthDef("playBuff", {
	arg out = 4, bufnum = 0, trigRate = 0, startPos = 0, rate = 1, pan = 0, loop = 0, mul = 1;
	var bufPlay, trig;

	trig = Impulse.kr(trigRate.lag(0.1));

	bufPlay = Pan2.ar(
		PlayBuf.ar(1,
			bufnum,
			BufRateScale.kr(bufnum)*rate.lag(0.1),
			trig,
			startPos.lag(0.1),
			loop),
		pos: pan.lag(0.1),
		level: mul,
);

	Out.ar(out, bufPlay);

}).add
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 12, {
		"PlayBuf1 - Start".postln;
		~playBuff1 = Synth("playBuff",
			[\bufnum, ~buff1.bufnum,
				\trigRate, 0,
				\mul, 0,
				\pan, -1,
				]);

	} );
},
30, // any CC number
chan: 1
);

//Stop the PlayBuf
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 13, {
		"PlayBuf1 - Free".postln;
		~playBuff1.free; ~playBuff1=nil;

	} );
},
30, // any CC number
chan: 1
);

//Choose a new sample
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 11, {
		"PlayBuf1 - New Sound".postln;
		~buff1 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;
		"".postln;
	} );
},
30, // any CC number
chan: 1
);

//Loop
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 23, {
		"PayBuf1 - Loop: 1".postln;
		~playBuff1.set(\loop, 1);

	} );
},
30, // any CC number
chan: 1
);

//Do Not Loop
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 22, {
		"PayBuf1 - Loop: 0".postln;
		~playBuff1.set(\loop, 0);

	} );
},
30, // any CC number
chan: 1
);

//Play Buf Mul
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf1 - Mul: ".post;
	~playBuff1.set(\mul, ((value/127)*4).postln);

},
41, // any CC number
chan: 1
);

//Playback Rate
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf1 - Rate: ".post;
	~playBuff1.set(\rate, (((value/127)*8)-4).postln);

},
52, // any CC number
chan: 1
);

//Trigger Rate
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf1 - TrigRate: ".post;
	~playBuff1.set(\trigRate, ((value+1).linexp(1,129,1,80)-1).postln);

},
42, // any CC number
chan: 1
);

//Start position
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf1 - StartPos: ".post;
	~playBuff1.set(\startPos, ((value/127)*(~buff1.numFrames)).postln);

},
51, // any CC number
chan: 1
);

//Buff 2
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 32, {
		"PlayBuf2 - Start".postln;
		~playBuff2 = Synth("playBuff",
			[\bufnum, ~buff2.bufnum,
				\trigRate, 0,
				\mul, 0,
				\pan, -0.3,
				]);

	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 33, {
		"PlayBuf2 - Free".postln;
		~playBuff2.free;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 31, {
		"PlayBuf2 - New Sound".postln;
		~buff2 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 43, {
		"PayBuf2 - Loop: 1".postln;
		~playBuff2.set(\loop, 1);

	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 42, {
		"PayBuf2 - Loop: 0".postln;
		~playBuff2.set(\loop, 0);

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf2 - Mul: ".post;
	~playBuff2.set(\mul, ((value/127)*4).postln);

},
43, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf2 - Rate: ".post;
	~playBuff2.set(\rate, (((value/127)*8)-4).postln);

},
54, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf2 - TrigRate: ".post;
	~playBuff2.set(\trigRate, ((value+1).linexp(1,129,1,80)-1).postln);

},
44, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf2 - StartPos: ".post;
	~playBuff2.set(\startPos, ((value/127)*(~buff2.numFrames)).postln);

},
53, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 52, {
		"PlayBuf3 - Start".postln;
		~playBuff3 = Synth("playBuff",
			[\bufnum, ~buff3.bufnum,
				\trigRate, 0,
				\mul, 0,
				\pan, 0.3,
				]);

	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 53, {
		"PlayBuf3 - Free".postln;
		~playBuff3.free;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 51, {
		"PlayBuf3 - New Sound".postln;
		~buff3 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 63, {
		"PayBuf3 - Loop: 1".postln;
		~playBuff3.set(\loop, 1);

	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 62, {
		"PayBuf3 - Loop: 0".postln;
		~playBuff3.set(\loop, 0);

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf3 - Mul: ".post;
	~playBuff3.set(\mul, ((value/127)*4).postln);

},
45, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf3 - Rate: ".post;
	~playBuff3.set(\rate, (((value/127)*8)-4).postln);

},
56, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf3 - TrigRate: ".post;
	~playBuff3.set(\trigRate, ((value+1).linexp(1,129,1,80)-1).postln);

},
46, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;

	"PayBuf3 - StartPos: ".post;
	~playBuff3.set(\startPos, ((value/127)*(~buff3.numFrames)).postln);

},
55, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 72, {
		"PlayBuf4 - Start".postln;
		~playBuff4 = Synth("playBuff",
			[\bufnum, ~buff4.bufnum,
				\trigRate, 0,
				\mul, 0,
				\pan, 1,
				]);

	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 73, {
		"PlayBuf4 - Free".postln;
		~playBuff4.free;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 71, {
		"PlayBuf4 - New Sound".postln;
		~buff4 = [~b1, ~b2, ~b3, ~b4, ~b5, ~b6, ~b6, ~b8, ~b9, ~b10].choose.postln;

	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 83, {
		"PayBuf4 - Loop: 1".postln;
		~playBuff4.set(\loop, 1);
	} );
},
30, // any CC number
chan: 1
);
MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	if( value == 82, {
		"PayBuf4 - Loop: 0".postln;
		~playBuff4.set(\loop, 0);
	} );
},
30, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	"PayBuf4 - Mul: ".post;
	~playBuff4.set(\mul, ((value/127)*4).postln);
},
47, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	"PayBuf4 - Rate: ".post;
	~playBuff4.set(\rate, (((value/127)*8)-4).postln);
},
58, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	"PayBuf4 - TrigRate: ".post;
	~playBuff4.set(\trigRate, ((value+1).linexp(1,129,1,80)-1).postln);
},
48, // any CC number
chan: 1
);

MIDIFunc.cc({ | value, ccNum, chan, id |
	// [src,chan,num,value].postln;
	"PayBuf4 - StartPos: ".post;
	~playBuff4.set(\startPos, ((value/127)*(~buff4.numFrames)).postln);
},
57, // any CC number
chan: 1
);


)