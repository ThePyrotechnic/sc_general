(
e = Bus.audio(s, 1); // Effects

SynthDef(\reverb, {|outBus = 0, inBus|
    var input;
    input = In.ar(inBus, 1);
    16.do({ input = AllpassC.ar(input, 0.04, { Rand(0.001,0.04) }.dup, 3)});

    Out.ar(outBus, input);
}).add;

SynthDef(\wave, {|out, effectBus, pan = 0, start = 0, amp = 1, direct = 0.5|
	// var wave = Decay2.ar(Impulse.ar([0.06, 0.04]), 4, 20, WhiteNoise.ar(0.2));
    var wave = EnvGen.kr(Env(levels: [0, 0, 1, 0], times: [start, 1, 16], curve: [0, -7, -6]), doneAction: Done.freeSelf) * WhiteNoise.ar(0.2);
	Out.ar(out, Pan2.ar(wave, pan) * direct * amp);
	// Out.ar(effectBus, wave * (1 - direct) * amp);
}).add;

SynthDef(\cricket, {|out, effectBus, pan = 0, start = 0, amp = 1, direct = 0.5|
	var chirp = EnvGen.kr(Env(levels: [0, 0, 1, 0], times: [start, 0.01, 0.03], curve: [-6]), doneAction: Done.freeSelf) * SinOsc.ar(2000);
	Out.ar(out, Pan2.ar(chirp, pan) * direct * amp);
	Out.ar(effectBus, chirp * (1 - direct) * amp)
}).add;

SynthDef(\crackle, {|out, effectBus, pan = 0, start = 0, amp = 1, direct = 0.5, pitchRatio = 1|
	var crack = EnvGen.kr(Env(levels: [1, 0], times: [0.04], curve: [-20]), doneAction: Done.freeSelf) *
	PitchShift.ar(
		BHiShelf.ar(BPeakEQ.ar(BPeakEQ.ar(BLowShelf.ar(
			BrownNoise.ar(),
			800, 0.8, -9),   // Low shelf
		2200, 1/2.37, 4.05), // Peak 1
		5500, 1/1.64, 4.05), // Peak 2
		12700, 0.7, -0.7),   // High shelf
		0.0, pitchRatio);     // Pitch shift

	Out.ar(out, Pan2.ar(crack, pan) * direct * amp);
	Out.ar(effectBus, crack * (1 - direct) * amp)
}).add;

SynthDef(\air, {|out, effectBus, pan = 0, start = 0, amp = 1, direct = 0.5, slideTime = 1|
	var air = BLowPass.ar(BPeakEQ.ar(BLowShelf.ar(
		WhiteNoise.ar(),
		79.8, 0.4, 12.1),   // Low shelf
	469, 1/5.12, 4.05), // Peak
	499, 1/0.89); // Low Pass

	amp = Lag.kr(amp, slideTime);

	Out.ar(out, Pan2.ar(air, pan) * direct * amp);
	Out.ar(effectBus, air * (1 - direct) * amp)
}).add;
)

// Campfire, Wind effect
(
~sources = Group.new;
~effects = Group.after(~sources);
Synth.new(\reverb, [\outBus, 0, \inBus, e], ~effects);

// Air
Pmono(
	\air,
	\effectBus,  e,
	\direct,     1,
	\amp,        Pwhite(0.01, 0.03),
	\slideTime,  Pgauss(2.0, 1.0, inf).abs,
	\dur,        Pwhite(3.0, 5.0, inf),
	\pan,        0.15,
	\group,      ~sources
).play;

// Big pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(3.4, 6.847, inf).abs,
	\amp,        Pwhite(0.5, 0.8, inf),
	\pitchRatio, Pwhite(0.1, 4, inf),
	\pan,        0,
	\group,      ~sources
).play;

// Medium pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(2.5, 4.5, inf).abs,
	\amp,        Pwhite(0.2, 0.4, inf),
	\pitchRatio, Pwhite(0.1, 4, inf),
	\pan,        -0.05,
	\group,      ~sources
).play;

// Little pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(1.5, 2.5, inf).abs,
	\amp,        Pwhite(0.05, 0.1, inf),
	\pitchRatio, Pwhite(0.1, 4, inf),
	\pan,        0.05,
	\group,      ~sources
).play;

// Waves
Pbind(
	\instrument, \wave,
	\effectBus,  e,
	\direct,     0.5,
	\delta,      Pwhite(10.0, 30.0, inf),
	\pan,        Pwhite(-0.85, -0.45, inf),
	\amp,        Pwhite(0.15, 0.35, inf),
	\group,      ~sources
).play;

// Crickets
Pspawner({ |sp|
	var streams, stream;
	streams = 2.collect {
		stream = sp.par(Pbind(
			\instrument, \cricket,
			\effectBus,  e,
			\direct,     0.96,
			\delta,      Pseq([Pn(0.03, 8), 0.3], inf),
			\pan,        0.5.rand + 0.5,
			// \amp,        exprand(0.08, 0.1),
			\amp,        0.002,
			\start,      2.0.rand,
			\group,      ~sources
		));
		stream;
	};
	streams = LinkedList.newFrom(streams);
	inf.do({
		streams.addAll(2.collect {
			stream = sp.par(Pbind(
				\instrument, \cricket,
				\effectBus,  e,
				\direct,     0.96,
				\delta,      Pseq([Pn(0.03, 8), 0.3], inf),
				\pan,        0.5.rand + 0.5,
				// \amp,        exprand(0.08, 0.1),
				\amp,        0.002,
				\start,      2.0.rand,
				\group,      ~sources
			));
			stream;
		});
		sp.wait(10);

		2.do({
			stream = streams.popFirst;
			sp.suspend(stream)
		})
	})
 }).play
)

p = Pgauss(2.0, 1.0, inf).abs.asStream;
p.next(Event.new)

s.scope()
FreqScope.new()