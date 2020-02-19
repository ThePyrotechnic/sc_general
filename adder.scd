(
s.options.memSize = 1024 * 1024;
s.reboot;
)

(
~waveRes = 8192;

~bufferTime = (~waveRes * 2) / s.sampleRate + 1;
~shapeBuf = Buffer.alloc(s, ~waveRes * 2);
~waveBuf = Buffer.alloc(s, ~waveRes * 2);
)

(
~waveSig = Signal.newClear(~waveRes);
~waveSig.waveFill({arg x, old, i;
	if((x < (-pi/3)) || (x > (pi/3)),
		-1 * sin(1.7 * x - 0.25),
		distort(tan(x + (pi/2)))/3)
}, -pi, pi);
~waveSig = ~waveSig.asWavetable;
~waveBuf.loadCollection(~waveSig);

~shape = Env([-1, 1], [1]).asSignal(~waveRes + 1);

~alterShape = {
	{Mix.ar(In.ar(0, 2))}.loadToFloatArray(~bufferTime, action:
		{
			arg arr;
			var newShape;

			~shape.waveFill({
				arg x, old, i;
		old + (arr[i] / rrand(2, 2.5))
			});
			~shapeBuf.loadCollection(~shape.asWavetableNoWrap);
		}
	);
	// {~shape.plot}.defer;
	0.0
};

SynthDef.new(\adder, {
	arg out=0, shapeBuf=0, waveBuf=1, center=0, freq=300, atk=0.005, sus=1, rel=0.3, gate=0, amp=1;
	var detune, bufPos, sig, env;

	detune = LFNoise1.kr(0.2!8).bipolar(0.2).midiratio;
	sig = Shaper.ar(shapeBuf, Osc.ar(waveBuf, freq * detune));
	env = Linen.kr(gate, atk, sus, rel, Done.none);
	sig = sig * env;
	sig = Splay.ar(sig, center: center);
	sig = LeakDC.ar(sig) * amp;
	Out.ar(out, sig);
}).add;

SynthDef.new(\bell, {
	arg out=0, freq=440, atk=0.005, sus=1, rel=0.3, center=0, gate=1, amp=1;

	var detune = LFNoise1.kr(0.2!3).bipolar(0.2).midiratio;
	var sig = SinOsc.ar(freq * detune);
	var env = EnvGen.ar(Env.asr(atk, sus, rel), gate, doneAction: Done.freeSelf);
	sig = Splay.ar(sig, center: center);
	sig = Klank.ar(`[[800, 1071, 1353, 1723], nil, [1, 1, 1, 1]], sig);
	sig = LeakDC.ar(sig);
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
)

(
~cur_a = 55;

Task {
	inf.do({
		Pbind(
			\instrument, \bell,
			\delta,      Pn(1, 1),
			\sus,        Pwhite(3, 8.0),
			\rel,        Pwhite(8, 12.0),
			\center,     Pwhite(-1, 1),
			\amp,        Pmeanrand(0.007, 0.009),
			\freq,       Phprand(110, 440.0)
		).play;

		~alterShape.value;
		if(~cur_a >= 55, {~cur_a = ~cur_a / rrand(1.8, 2.2)}, {});
		rrand(8, 10.0).wait;
	});
}.play;

Task {
	inf.do({
		~cur_a = ~cur_a * rrand(1.01, 1.028);
		~cur_a.postln;
		0.2.wait;
	});
}.play;


~shape = Env([-1, 1], [1]).asSignal(~waveRes + 1);
~shapeBuf.loadCollection(~shape.asWavetableNoWrap);

~snds = 8.collect({arg a;
	Synth(\adder, [
		shapeBuf: ~shapeBuf,
		waveBuf: ~waveBuf,
		amp: 0.2,
		atk: 3,
		rel: 5
	])}
);

8.do({ arg a;
	OSCdef.new(
		\note ++ a,
		{
			arg msg, time, addr, port;

			if(msg[1] == 1,
				{
					~snds[a].set(\freq, ~cur_a * (2**(a/12)));
					~snds[a].set(\center, 0.3.rand2);
				},{}
			);
			~snds[a].set(\gate, msg[1]);
		},
		'/main/multipush3/1/' ++ (a + 1)
	);
}
);

OSCdef.new(
	\octaveUp,
	{
		arg msg, time, addr, port;
		if(msg[1] == 1, {~cur_a = ~cur_a * 2; ~cur_a.postln},{});
	},
	'/main/multipush2/2/1'
);

OSCdef.new(
	\octaveDown,
	{
		arg msg, time, addr, port;
		if(msg[1] == 1, {~cur_a = ~cur_a / 2; ~cur_a.postln},{});
	},
	'/main/multipush2/1/1'
);
)

{Pan2.ar(Osc.ar(~shapeBuf, 110, mul: 0.2))}.scope
(
s.scope;
FreqScope.new()
)