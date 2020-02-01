(
b = Buffer.alloc(s, 2048);
)
(
var env, sig, wt, segs;

segs = rrand(4, 20);
env = Env(
	{rrand(-1.0, 1.0)}!(segs + 1),
	{exprand(1, 20)}!segs,
	{rrand(-20, 20)}!segs);

sig = env.asSignal(1024);
wt = sig.asWavetable;
sig = LeakDC.ar(sig);
b.loadCollection(wt);
)

(
~pulse = Bus.audio(s, 1); // Pulse
~saw = Bus.audio(s, 1); // Saw
~effects = Bus.audio(s, 1); // Effects
)

(
SynthDef(\retro, {
	var snd = Pulse.ar(\freq.kr(110));
	snd = EnvGen.ar(Env.perc(), doneAction: Done.freeSelf) * snd;
	snd = Pan2.ar(snd, \pan.kr(0));

	Out.ar(\out.kr(0), snd * \amp.kr(1));
}).add;
)

Synth(\retro).play;

(
m = SimpleMIDIFile.read("C:/Users/micha/Downloads/Overworld 1.mid");
m.p(\retro).play;
)

{EnvGen.kr(Env.adsr, doneAction: Done.freeSelf)}.plot(3)

{Pulse.ar(44, width: 0.5, mul: 0.1!2)}.play

(
Pbind(*[
	\instrument: \retro,
	\amp: 0.5,
	\midinote: Pseq(~notes, 1),
	\dur: Pseq(~durations, 1),
]).play;
)
(
SynthDef(\compressor, {
	var snd = Compander.ar(In.ar(~saw), In.ar(~pulse), \thresh.kr(0.5), 1, 1 / (\ratio.kr(4)), 0.01, \decay.kr(0.2));
	snd = Pan2.ar(snd, \pan.kr(0));
	Out.ar(\out.kr(0), snd * \amp.kr(1));
}).add;

SynthDef(\saw, {
	var snd = Mix.ar([
		Osc.ar(b, \freq.kr(50) * (4.collect({|n| n + 1})), mul: 1),
		Osc.ar(b, \freq.kr(50) * (4.collect({|n| (n + 1.01)})), mul: 1)
	]);
	Out.ar(\out.kr(0), snd * \amp.kr(1));
}).add;

SynthDef(\pulse, {
	var freq, snd;
	snd = EnvGen.kr(Env.perc(0.001, 0.2, 1, -4), doneAction: Done.freeSelf) *
	SinOsc.ar(\freq.kr(80) + Crackle.ar(1, 0.5));
	snd = Pan2.ar(snd, \pan.kr(0));
	Out.ar(\out.kr(0), snd * \amp.kr(1));
	Out.ar(\send.kr(0), Mix(snd) * \amp.kr(1))
}).add;

SynthDef(\pwm, {
	var snd = EnvGen.kr(Env.adsr, doneAction: Done.freeSelf)
	* Pulse.ar(\freq.kr(44), width: 0.5, mul: 2.6);
	Out.ar(\out.kr(0), Pan2.ar(snd * \amp.kr(1)));
}).add;
)

(
~sources = Group.new();
~effects_grp = Group.after(~sources);

Pmono(*[
	\compressor,
	amp: 1,
	in: ~saw,
	control: ~pulse,
	out: 0,
	thresh: 0.1,
	ratio: 4,
	decay: 0.45,
	group: ~effects_grp
]).play;

Ppar([
	Pbind(*[
		instrument: \pulse,
		amp: 1,
		freq: 60,
		dur: Pseq(#[1], inf),
		out: 0,
		send: ~pulse,
		pan: 0,
		group: ~sources
	]),
	Pbind(*[
		instrument: \pwm,
		amp: 1,
		freq: Pseq([44, 44.02], inf),
		out: ~saw,
		dur: 0.5,
		group: ~sources
	]),
]).play(TempoClock(120 / 60));
)

{In.ar(k)}.plot(2)

s.scope()
FreqScope.new()