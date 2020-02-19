(
SynthDef.new(\vosc, {
	arg out=0, buf=0, numBufs=2, center=0, freq=300, atk=0.005, sus=1, rel=0.3, gate=0, amp=1;

	var detune = LFNoise1.kr(0.2!8).bipolar(0.2).midiratio;
	var bufPos = buf + LFNoise1.kr(0.5).range(0, numBufs - 1);
	var sig = VOsc.ar(bufPos, freq * detune);
	var env = Linen.kr(gate, atk, sus, rel, Done.none);
	buf.postln;
	sig = sig * env;
	sig = Splay.ar(sig, center: center);
	Out.ar(out, LeakDC.ar(sig) * amp);
}).add;

SynthDef.new(\bell, {
	arg out=0, freq=440, atk=0.005, sus=1, rel=0.3, pan=0, gate=0, amp=1;

	var detune = LFNoise1.kr(0.2).bipolar(0.2).midiratio;
	var sig = SinOsc.ar(freq * detune);
	var env = Linen.kr(gate, atk, sus, rel, Done.none);
	sig = Pan2.ar(sig, pan);
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
)

(
~wt.do({arg w, a;
	w.plot;
});
)

(
~waveRes = 8192;

~wt = Array.fill(4, {
	var segments = rrand(4, 20);
	Env(
		[0]++
		(({rrand(0.0, 1.0)}!(segments - 1)) * [1, -1]).scramble
		++[0],
		{exprand(1, 20)}!segments,
		{rrand(-20, 20)}!segments
	).asSignal(~waveRes).asWavetable;
});

~buf = Buffer.allocConsecutive(4, s, ~waveRes * 2);

~buf.do({
	arg buf, a;
	buf.loadCollection(~wt[a]);
});
)

(
~snds = 8.collect({arg a;
	Synth(\vosc, [
		buf: ~buf,
		numBufs: 4,
		amp: 0.2,
		atk: 1,
		rel: 5
	])}
);

~cur_a = 440;

8.do({ arg a;
	OSCdef.new(
		\note ++ a,
		{
			arg msg, time, addr, port;

			if(msg[1] == 1,
				{
					~snds[a].set(\freq, ~cur_a * (1 + a/8));
					~snds[a].set(\center, 1.rand2);
				},{}
			);
			~snds[a].set(\gate, msg[1]);
		},
		'/main/multipush3/1/' ++ (a + 1)
	);
}
);

~bells = 6.collect({arg a;
	Synth(\bell, [
		amp: 0.2,
		atk: 0.05,
		rel: 5,
		freq: 440 * (1 + a/6)
	])}
);

6.do({ arg a;
	OSCdef.new(
		\bell ++ a,
		{
			arg msg, time, addr, port;

			if(msg[1] == 1, {~bells[a].set(\center, 1.rand2);}, {});
			~bells[a].set(\gate, msg[1]);
		},
		'/main/multipush4/' ++ (a + 1) ++ '/1'
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