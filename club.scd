(
~master = Bus.audio(s, 2);
~pulse_verb = Bus.audio(s, 1);
~pulse_main = Bus.audio(s, 1);
~wave = Bus.audio(s, 2);
)

(
~retro_buf = Buffer.alloc(s, 8192 * 2);

SynthDef(\compressor, {|in, control|
	var snd = Compander.ar(In.ar(in, 2), In.ar(control), \thresh.kr(0.5), 1, 1 / (\ratio.kr(4)), 0.01, \decay.kr(0.2));
	snd = snd * \amp.kr(1);
	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\reverb, {|in|
    var input;
	input = In.ar(in);
	16.do({ input = AllpassC.ar(input, 0.04, { Rand(0.001,0.04) }.dup, \decay.kr(1))});

	Out.ar(\out.kr(0), input);
}).add;

SynthDef(\pulse, {
	var freq, snd;
	snd = EnvGen.kr(Env.perc(0.001, 0.2, 1, -4), doneAction: Done.freeSelf) *
	SinOsc.ar(\freq.kr(80) + Crackle.ar(1, 0.5));
	snd = Pan2.ar(snd, \pan.kr(0));
	Out.ar(\out.kr(0), snd * \direct.kr(0.5) * \amp.kr(1));
	Out.ar(\send.kr(0), Mix(snd) * (1 - \direct.kr(0.5)) * \amp.kr(1))
}).add;

~retro_sig = Signal.newClear(8192);
~retro_sig.waveFill({arg x, old, i;
	if((x < (-pi/3)) || (x > (pi/3)),
		-1 * sin(1.7 * x - 0.25),
		distort(tan(x + (pi/2)))/3)
}, -pi, pi);
~retro_sig = ~retro_sig.asWavetable;
~retro_buf.loadCollection(~retro_sig);

SynthDef(\retro, {
	arg detune = 0.02;
	var env = EnvGen.ar(Env.asr(0.001, 1, 0.1), \gate.kr(0), doneAction: Done.none);
	var snd = Osc.ar(~retro_buf,
		\freq.kr(55) * LFNoise1.kr(0.2!8).bipolar(detune.neg, detune).midiratio);
	snd = LPF.ar(snd, \lp_freq.kr(100));
	snd = Splay.ar(snd);
	snd = snd * env * \amp.kr(1);

	Out.ar(\out.kr(0), snd);
}).add;

SynthDef(\smack, {
	var freq, snd;
	snd = EnvGen.kr(Env.perc(0.001, 0.2, 1, -4), doneAction: Done.freeSelf) *
	PitchShift.ar(
		BHiShelf.ar(BPeakEQ.ar(BPeakEQ.ar(BLowShelf.ar(
			WhiteNoise.ar(),
			800, 0.8, -9),   // Low shelf
		2200, 1/2.37, -4), // Peak 1
		12000, 1/1.64, 0), // Peak 2
		12700, 0.7, -9),   // High shelf
		0.0, \pitchRatio.kr(1));    // Pitch shift
	snd = Pan2.ar(snd, \pan.kr(0));
	Out.ar(\out.kr(0), snd * \direct.kr(0.5) * \amp.kr(1));
	Out.ar(\send.kr(0), Mix(snd) * (1 - \direct.kr(0.5)) * \amp.kr(1))
}).add;

SynthDef(\masterOut, {
	var snd = In.ar(\in.kr(0), 2);
	// snd = LPF.ar(snd, \lp_freq.kr(22000));
	Out.ar(\out.kr(0), snd * \amp.kr(1));
}).add;

)

(
OSCdef.new(
	\toggle,
	{
		arg msg, time, addr, port;
		~retro_ref.set(\gate, msg[1]);
	},
	'/main/toggle1'
);

OSCdef.new(
	\fader1,
	{
		arg msg, time, addr, port;
		~retro_ref.set(\detune, msg[1].linexp(0, 1, 0.02, 12));
	},
	'/main/fader1'
);

OSCdef.new(
	\fader2,
	{
		arg msg, time, addr, port;
		~retro_ref.set(\lp_freq, msg[1].linexp(0, 1, 20, 10000));
	},
	'/main/fader2'
);

~sources = Group.new();
~effects_grp = Group.after(~sources);
~master_grp = Group.after(~effects_grp);

Pmono(*[
	\compressor,
	in: ~wave,
	control: ~pulse_main,
	amp: 3.3,
	out: ~master,
	thresh: 0.1,
	ratio: 4,
	decay: 0.45,
	group: ~effects_grp
]).play;

Pmono(*[
	\reverb,
	in: ~pulse_verb,
	decay: 0.4,
	amp: 1,
	out: ~master,
	group: ~effects_grp
]).play;

Ppar([
	Pbind(*[
		instrument: \pulse,
		amp: 2.43,
		freq: 60,
		dur: 1,
		out: ~master,
		send: ~pulse_main,
		pan: 0,
		group: ~sources
	]),
	Pbind(*[
		instrument: \pulse,
		amp: 0.1,
		freq: 60,
		dur: 1,
		out: ~master,
		direct: 0,
		send: ~pulse_verb,
		pan: 0,
		group: ~sources
	]),
	Pbind(*[
		instrument: \smack,
		amp: 0.2,
		dur: 2,
		out: ~master,
		direct: 1,
		send: ~pulse_verb,
		pan: 0,
		group: ~sources
	]),
/*	Pbind(*[
		instrument: \retro,
		amp: 0.35,
		dur: Pseq([Pn(1/2, 6), 1], inf),
		freq: 55,
		lp_freq: Pseq([Pseq([800, 1600], 3), 800], inf),
		out: ~wave,
		group: ~sources
	]),*/
/*	Pbind(*[
		instrument: \retro,
		amp: 0.2,
		dur: Pseq([Pn(3/2, 32), Pn(1/4, 192)], inf),
		scale: #[0, 2, 3, 5, 7, 8, 10],
		octave: Pseq([Pn(2, 16)], inf),
		lp_freq: 10000,
		root: 2,
		degree: Ppatlace([Pseq(#[3, 2, 1, 0, -0.9, 0, 1, 2, -3, -1.9, -0.9, 0, -0.9, 0, 1, 2], inf),
			Pn(4, inf)], inf),
		// freq: 20,
		// freq: Pseq([40], inf),
		out: ~wave,
		group: ~sources
	])*/

]).play(TempoClock(128 / 60), quant: 1);

~retro_ref = Synth.new(\retro, [
	amp: 0.2,
	out: ~wave,
	group: ~sources
]);
)
(
~master_ref = Synth.new(\masterOut, [
	instrument: \masterOut,
	in: ~master,
	amp: 1,
	out: 0,
	group: ~master_grp
]);

)

FreqScope.new()
s.scope()