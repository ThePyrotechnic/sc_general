(
s = Server.default;
s.options.memSize = 1024 * 1024; // 1 GB
s.reboot;
)

(
~encoder = FoaEncoderMatrix.newOmni;
// Available CIPIC subject numbers
// 3 8 9 10 11 12 15 17 18 19 20 21 27 28 33 40 44 48 50 51 58 59 60 61 65 119 124 126 127 131 133 134 135 137 147 148 152 153 154 155 156 158 162 163 165
~decoder = FoaDecoderKernel.newCIPIC(3);

~renderDecode = { arg in, decoder;
	FoaDecode.ar(in, decoder)
};
)

(
e = Bus.audio(s, 1); // Effects

SynthDef(\reverb, {|outBus = 0, inBus|
    var input;
    input = In.ar(inBus, 1);
    16.do({ input = AllpassC.ar(input, 0.04, { Rand(0.001,0.04) }.dup, 3)});

    Out.ar(outBus, input);
}).add;

SynthDef(\wave, {|out, effectBus, width = 0, start = 0, amp = 1, direct = 0.5|
	// var wave = Decay2.ar(Impulse.ar([0.06, 0.04]), 4, 20, WhiteNoise.ar(0.2));
    var wave = EnvGen.kr(Env(levels: [0, 0, 1, 0], times: [start, 1, 16], curve: [0, -7, -6]), doneAction: Done.freeSelf) * WhiteNoise.ar(0.2);
	Out.ar(out, [Pan2.ar(wave, width) * direct * amp, Pan2.ar(wave, (-1)*width) * direct * amp]);
	// Out.ar(effectBus, wave * (1 - direct) * amp);
}).add;

SynthDef(\cricket, {|out, effectBus, elev = -0.2, azim = -3, start = 0, amp = 1, direct = 0.5|
	var chirp = EnvGen.kr(Env(levels: [0, 0, 1, 0], times: [start, 0.01, 0.03], curve: [-6]), doneAction: Done.freeSelf) * SinOsc.ar(2000);
	chirp = FoaEncode.ar(chirp, ~encoder);
	chirp = FoaTransform.ar(chirp, 'push', pi/2, azim, elev);
	chirp = ~renderDecode.value(chirp, ~decoder);
	Out.ar(out, chirp * direct * amp);
	Out.ar(effectBus, chirp * (1 - direct) * amp);
}).add;

SynthDef(\crackle, {|out, effectBus, elev = -0.2, azim = 0, start = 0, amp = 1, direct = 0.5, pitchRatio = 1|
	var crack = EnvGen.kr(Env(levels: [1, 0], times: [0.04], curve: [-20]), doneAction: Done.freeSelf) *
	PitchShift.ar(
		BHiShelf.ar(BPeakEQ.ar(BPeakEQ.ar(BLowShelf.ar(
			BrownNoise.ar(),
			800, 0.8, -9),   // Low shelf
		2200, 1/2.37, 4.05), // Peak 1
		5500, 1/1.64, 4.05), // Peak 2
		12700, 0.7, -0.7),   // High shelf
		0.0, pitchRatio);     // Pitch shift

	crack = FoaTransform.ar(FoaEncode.ar(crack, ~encoder), 'push', pi/2, azim, elev);
	crack = ~renderDecode.value(crack, ~decoder);

	Out.ar(out, crack * direct * amp);
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

(
~sources = Group.new;
~effects = Group.after(~sources);
// Synth.new(\reverb, [\outBus, 0, \inBus, e], ~effects);

// Air
Pmono(
	\air,
	\effectBus,  e,
	\direct,     1,
	\amp,        Pwhite(0.01, 0.03),
	\slideTime,  Pgauss(2.0, 1.0, inf).abs,
	\dur,        Pwhite(3.0, 5.0, inf),
	\pan,        0,
	\group,      ~sources
).play;


~popAzim = 0.3;
~popElev = -1.14;
// Big pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(3.4, 6.847, inf).abs,
	\amp,        Pwhite(0.2, 0.3, inf),
	\azim,       ~popAzim,
	\elev,       ~popElev,
	\pitchRatio, Pwhite(0.1, 4, inf),
	\group,      ~sources
).play;

// Medium pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(2.5, 4.5, inf).abs,
	\amp,        Pwhite(0.1, 0.2, inf),
	\azim,       ~popAzim,
	\elev,       ~popElev,
	\pitchRatio, Pwhite(0.1, 4, inf),
	\group,      ~sources
).play;

// Little pops
Pbind(
	\instrument, \crackle,
	\effectBus,  e,
	\direct,     1,
	\delta,      Pgauss(1.5, 2.5, inf).abs,
	\amp,        Pwhite(0.05, 0.1, inf),
	\azim,       ~popAzim,
	\elev,       ~popElev,
	\pitchRatio, Pwhite(0.1, 4, inf),
	\group,      ~sources
).play;


// Waves
Pbind(
	\instrument, \wave,
	\effectBus,  e,
	\direct,     0.5,
	\delta,      Pwhite(10.0, 30.0, inf),
	\width,      Pwhite(0.1, 0.8, inf),
	\amp,        Pwhite(0.01, 0.05, inf),
	\group,      ~sources
).play;

// Pbind(
// 	\instrument, \cricket,
// 	\effectBus,  e,
// 	\direct,     0.96,
// 	\delta,      Pseq([Pn(0.03, 8), 0.3], inf),
// 	\azim,       3.1,
// 	\amp,        0.0016,
// 	\start,      0.1.rand,
// 	\group,      ~sources
// ).play;

Pbind(
	\instrument, \cricket,
	\effectBus,  e,
	\direct,     0.96,
	\delta,      Pseq([Pn(0.03, 8), 0.3], inf),
	\azim,       -3.1,
	\amp,        Pseq([Pseq([0.0016], 414), Pseq([0], 252)], inf),
	// \amp,        0.0016,
	\start,      0.1.rand,
	\group,      ~sources
).play;

// Crickets
// Change the <number>.collect lines to any number to add more crickets
/*Pspawner({ |sp|
	var streams, stream;
	streams = LinkedList();
	inf.do({
		streams.addAll(1.collect {
			sp.par(Pbind(
				\instrument, \cricket,
				\effectBus,  e,
				\direct,     0.96,
				\delta,      Pseq([Pn(0.03, 8), 0.3], inf),
/*				\azim,       0,
				\elev,       0,*/
				// \amp,        exprand(0.08, 0.1),
				\amp,        [0.002, 0.0016, 0.0016].choose,
				\start,      2.0.rand,
				\group,      ~sources
			))
		});
		sp.wait(rrand(15.0, 20.0));

		1.do({
			stream = streams.popFirst;
			sp.suspend(stream)
		})
	})
 }).play*/
)

a = Pseq([Pn(0.03, 8), 0.3], inf).asStream;
50.do({a.next.postln})

s.scope()
FreqScope.new()