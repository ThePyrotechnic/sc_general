(
SynthDef("tutorial-DecayPink", { arg outBus = 0, effectBus, direct = 0.5;
    var source;
    // Decaying pulses of PinkNoise. We'll add reverb later.
    source = Decay2.ar(Impulse.ar(1, 0.25), 0.01, 0.2, PinkNoise.ar);
    // this will be our main output
    Out.ar(outBus, source * direct);
    // this will be our effects output
    Out.ar(effectBus, source * (1 - direct));
}).add;

SynthDef("tutorial-DecaySin", { arg outBus = 0, effectBus, direct = 0.5;
    var source;
    // Decaying pulses of a modulating sine wave. We'll add reverb later.
    source = Decay2.ar(Impulse.ar(0.3, 0.25), 0.3, 1, SinOsc.ar(SinOsc.kr(0.2, 0, 110, 440)));
    // this will be our main output
    Out.ar(outBus, source * direct);
    // this will be our effects output
    Out.ar(effectBus, source * (1 - direct));
}).add;

SynthDef("tutorial-Reverb", { arg outBus = 0, inBus;
    var input;
    input = In.ar(inBus, 1);

    // a low-rent reverb
    // aNumber.do will evaluate its function argument a corresponding number of times
    // {}.dup(n) will evaluate the function n times, and return an Array of the results
    // The default for n is 2, so this makes a stereo reverb
    16.do({ input = AllpassC.ar(input, 0.04, { Rand(0.001,0.04) }.dup, 3)});

    Out.ar(outBus, input);
}).add;

b = Bus.audio(s, 1);
)

(
x = Synth.new("tutorial-Reverb", [\inBus, b]);
y = Synth.before(x, "tutorial-DecayPink", [\effectBus, b, \direct, 0.5]);
z = Synth.before(x, "tutorial-DecaySin", [\effectBus, b, \outBus, 1, \direct, 0.5]);
)

(
// make two control rate busses and set their values to 880 and 884.
b = Bus.control(s, 1); b.set(880);
c = Bus.control(s, 1); c.set(884);
// and make a synth with two frequency arguments
x = SynthDef("tutorial-map", { arg freq1 = 440, freq2 = 440;
    Out.ar(0, SinOsc.ar([freq1, freq2], 0, 0.1));
}).play(s);
)

x.map(\freq1, b, \freq2, c);

y = { Out.kr(b, SinOsc.kr(1, 0, 50, 880)) }.play(addAction: \addToHead);

y.free;

b.get({ arg val; val.postln; f = val; });

x.set(\freq2, f/2);

c.set(200);

x.free; b.free; c.free;
(
a = Bus.audio(s, 1);
b = Bus.audio(s, 1);
c = Bus.control(s, 1); c.set(1);

d = Bus.audio(s, 1); // Sink
m = Bus.audio(s, 1); // Master

SynthDef("osc", { arg mainBus, sideBus, mainSend = 0.5, sideSend = 0.5, inBus;
	var input;
	input = InFeedback.ar(inBus, 1);

	Out.ar(mainBus, input * mainSend);
	Out.ar(sideBus, input * sideSend);
}).add;

SynthDef("master", {
	var input;
	input = In.ar(m, 1);

	Out.ar(0, Pan2.ar(input));
}).add;
)

(
a.index.postln;
b.index.postln;
d.index.postln;
m.index.postln;
)

(
{Out.ar(a, SinOsc.ar(110, 0, 0.5))}.play;

y = Synth.new("osc", [\mainBus, m, \sideBus, a, \mainSend, 1, \sideSend, 0, \inBus, b]);
x = Synth.after(y, "osc", [\mainBus, b, \sideBus, d, \mainSend, 1, \sideSend, 1, \inBus, a]);

{Out.kr(c, SinOsc.kr(1, 0, 0.5, 0.5))}.play;
// x.map(\mainSend, c);
// y.map(\sideSend, c);

Synth.after(x, "master");
)

y.set(\sideSend, 0.9);

(
// a stereo version
SynthDef(\tutorial_DecaySin2, { arg outBus = 0, effectBus, direct = 0.5, freq = 440;
    var source;
    // 1.0.rand2 returns a random number from -1 to 1, used here for a random pan
    source = Pan2.ar(Decay2.ar(Impulse.ar(Rand(0.3, 1), 0, 0.125), 0.3, 1,
        SinOsc.ar(SinOsc.kr(0.2, 0, 110, freq))), Rand(-1.0, 1.0));
    Out.ar(outBus, source * direct);
    Out.ar(effectBus, source * (1 - direct));
}).add;

SynthDef(\tutorial_Reverb2, { arg outBus = 0, inBus;
    var input;
    input = In.ar(inBus, 2);
    16.do({ input = AllpassC.ar(input, 0.04, Rand(0.001,0.04), 3)});
    Out.ar(outBus, input);
}).add;
)

// now we create groups for effects and synths
(
~sources = Group.new;
~effects = Group.after(~sources);     // make sure it's after
~bus = Bus.audio(s, 2);         // this will be our stereo effects bus
)

// now synths in the groups. The default addAction is \addToHead
(
x = Synth(\tutorial_Reverb2, [\inBus, ~bus], ~effects);
y = Synth(\tutorial_DecaySin2, [\effectBus, ~bus, \outBus, 1], ~sources);
z = Synth(\tutorial_DecaySin2, [\effectBus, ~bus, \outBus, 0, \freq, 660], ~sources);
)

// we could add other source and effects synths here

~sources.free; ~effects.free; // this frees their contents (x, y, z) as well
~bus.free;

// remove references to ~sources and ~effects environment variables:
currentEnvironment.clear;

b = Buffer.alloc(s, s.sampleRate * 5, 1); // a 5 second 1 channel Buffer

// record for four seconds
(
x = SynthDef("tutorial-RecordBuf",{ arg bufnum=0;
    var noise;
    noise = PinkNoise.ar(0.3);    // record some PinkNoise
    RecordBuf.ar(noise, bufnum);     // by default this loops
}).play(s,[\bufnum, b]);
)

// free the record synth after a few seconds
x.free;

// play it back
(
SynthDef("tutorial-playback",{ arg out=0,bufnum=0;
    var playbuf;
    playbuf = PlayBuf.ar(1,bufnum);
    FreeSelfWhenDone.kr(playbuf); // frees the synth when the PlayBuf has played through once
    Out.ar(out, playbuf);
}).play(s,[\out, 0, \bufnum, b]);
)
b.free;

s.scope;
s.reboot;