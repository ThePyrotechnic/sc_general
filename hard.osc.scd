(
~compBus = Bus.audio(s, 2);
~sideBus = Bus.audio(s,2);
~masterBus = Bus.audio(s, 2);
)
~masterBus.scope
(
SynthDef(\master, {
	arg in, out=0, amp=1, lpFreq = 22000;
	var snd = In.ar(in, 2);
	snd = LPF.ar(snd, lpFreq);
	snd = snd * amp;
	Out.ar(out, snd);
}).add;

SynthDef.new(\compressor, {
	arg in, control, out=0, thresh=0.5, ratio=4, decay=0.2, amp=1;
	var snd = Compander.ar(In.ar(in, 2), In.ar(control, 2), thresh, 1, 1 / (ratio), 0.01, decay);
	snd = snd * amp;
	Out.ar(out, snd);
}).add;

SynthDef.new(\vosc, {
	arg out=0, buf=0, numBufs=2, center=0, freq=300, atk=0.005, sus=1, rel=0.3, gate=0, amp=1;
	var detune, bufPos, sig, env;

	detune = LFNoise1.kr(0.2!8).bipolar(0.2).midiratio;
	bufPos = buf + LFNoise1.kr(0.5).range(0, numBufs - 1);
	sig = VOsc.ar(bufPos, freq * detune);
	env = Linen.kr(gate, atk, sus, rel, Done.none);
	buf.postln;
	sig = sig * env;
	sig = Splay.ar(sig, center: center);
	Out.ar(out, LeakDC.ar(sig) * amp);
}).add;

SynthDef.new(\wave, {
	arg out=0, buf=0, freq=300, center=0, atk=0.005, sus=1, rel=0.3, gate=0, amp=1, maxCurve=0;
	var env, tri, sig, curve;

	curve = LFNoise1.kr(0.5!8).bipolar(maxCurve);
	tri = LFTri.ar({freq * Rand(-0.1, 0.1).midiratio}!8);
	tri = tri.lincurve(-1, 1, -1, 1, curve);
	env = Linen.kr(gate, atk, sus, rel, Done.none);
	sig = Splay.ar(tri, center: center) * env * amp;
	sig = LeakDC.ar(sig);
	Out.ar(out, sig);
}).add;

SynthDef(\retro, {
	arg out=0, buf=0, lpOsc=0, detune=0.02, freq=55, lpOscFreq=1, amp=1, gate=0;
	var env = EnvGen.ar(Env.asr(0.001, 1, 0.1), gate, doneAction: Done.none);
	var snd = Osc.ar(buf,
		freq * LFNoise1.kr(0.2!8).bipolar(detune.neg, detune).midiratio);
	// snd = LPF.ar(snd, lpFreq);
	snd = Splay.ar(snd);
	lpOsc = Osc.kr(lpOsc, lpOscFreq, 0, 800, 200);
	snd = LPF.ar(snd, lpOsc);
	snd = snd * env * amp;
	Out.ar(0, snd);
}).add;

SynthDef(\pulse, {
	arg out=0, send=0, freq=80, pan=0, amp=1, direct=0.5, detune=0.02;
	var snd;
	snd = EnvGen.kr(Env.perc(0.001, 0.2, 1, -4), doneAction: Done.freeSelf) *
	SinOsc.ar(freq * LFNoise1.kr(0.2!8).bipolar(detune.neg, detune).midiratio);
	snd = Pan2.ar(snd, pan);
	Out.ar(out, snd * direct * amp);
	Out.ar(send, snd * (1 - direct) * amp)
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

SynthDef(\air, {|out, pan = 0, start = 0, amp = 1, direct = 0.5, slideTime = 1|
	var air = BLowPass.ar(BPeakEQ.ar(BLowShelf.ar(
		WhiteNoise.ar(),
		79.8, 0.4, 12.1),   // Low shelf
	469, 1/5.12, 4.05), // Peak
	499, 1/0.89); // Low Pass

	amp = Lag.kr(amp, slideTime);

	Out.ar(out, Pan2.ar(air, pan) * direct * amp);
}).add;
)
{Osc.kr(~lpWaveBuf, 5, 0, 4800, 200)}.plot(2)
(
~wt.do({arg w, a;
	w.plot;
});
)
{SinOsc.kr(10,0,5000,5200)}.plot(1)
(
~waveRes = 8192;

~wt = Array.fill(4, {
	var segments = rrand(4, 20);
	Env(
		[0]++
		(({rrand(0.0, 1.0)}!(segments - 1)) * [1, -1]).scramble
		++[0],
		{exprand(1, 20)}!segments,
		{rrand(-20, 20)}!segments,
	).asSignal(~waveRes).asWavetable;
});
~wt[0].plot
~buf = Buffer.allocConsecutive(4, s, ~waveRes * 2);

~buf.do({
	arg buf, a;
	buf.loadCollection(~wt[a]);
});

)

(
~lpWave = Env(
	levels: [0, 1, 0],
	times: [0.02, 0.5],
	curve: [-2, -4]
).asSignal(~waveRes).asWavetable;
~lpWaveBuf = Buffer.alloc(s, ~waveRes * 2);
~lpWaveBuf.loadCollection(~lpWave);
~lpWave.plot;
)

(
~linWave = Signal.newClear(~waveRes + 1).waveFill ({
	arg x, old, i;
	sin(x)
}, -pi/2, pi/2);
~linWave = ~linWave.waveFill({
	arg x, old, i;
	old * ((cos(x*0.08)/4) + 0.3);
}, 0, 50pi).normalize;
~linWave.plot;
~waveBuf = Buffer.loadCollection(s, ~linWave.asWavetableNoWrap);
)

(
~retroBuf = Buffer.alloc(s, 8192 * 2);
~retroSig = Signal.newClear(8192);
~retroSig.waveFill({arg x, old, i;
	if((x < (-pi/3)) || (x > (pi/3)),
		-1 * sin(1.7 * x - 0.25),
		distort(tan(x + (pi/2)))/3)
}, -pi, pi);
~retroSig = ~retroSig.asWavetable;
~retroBuf.loadCollection(~retroSig);
)

(
~sourceGrp = Group.new;
~effectGrp = Group.after(~sourceGrp);

Synth(\compressor,
	[
		in: ~compBus,
		control: ~sideBus,
		amp: 1,
		out: ~masterBus,
		thresh: 0.1,
		ratio: 4,
		decay: 0.45
], ~effectGrp);

Synth.after(~effectGrp, \master,
	[
		in: ~masterBus,
		amp: 1,
		out: 0,
]);

/*Pbind(*[
	instrument: \pulse,
	amp: 0.8,
	freq: 60,
	dur: 1,
	out: ~masterBus,
	send: ~sideBus,
	direct: 0.5,
	pan: 0,
	group: ~sourceGrp
]).play(TempoClock(128 / 60), quant: 1);*/

~snds = 8.collect({arg a;
	Synth(\retro, [
		buf: ~retroBuf,
		lpOsc: ~lpWaveBuf,
		lpOscFreq: 32,
		amp: 0.1,
		out: ~compBus
	], ~sourceGrp)}
);

~cur_a = 55;

8.do({ arg a;
	OSCdef.new(
		\note ++ a,
		{
			arg msg, time, addr, port;

			if(msg[1] == 1,
				{
					~snds[a].set(\freq, ~cur_a * (2**(a/12)));

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
		freq: 440 * (1 + a/6),

	], ~sourceGrp)}
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

s.scope()
FreqScope.new()