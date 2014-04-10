
(

SynthDef(\SceneMix, {arg att = 0.01, dec = 0.01, inBus = 0, trig = 1;

	var sig = In.ar(inBus, 2);
	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 13);
	Out.ar(0,sig);

}).send(s);

SynthDef(\Reverb, {arg att = 0.01, dec = 0.01, inBus = 0, outBus = 0, trig = 1;

	var sig = In.ar(inBus, 2);
	sig = GVerb.ar(sig + PinkNoise.ar(0.0001));
	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 2);
	Out.ar(outBus,sig);

}).send(s);

SynthDef(\SimplePlayer, {
	arg pan = 0, buf = 0, amp = 0.5, att =0.01, dec = 0.01, loop= 1, trig = 1, rate = 1, outBus = 0, revBus = 0, startPos = 0, rev = 0.5;

	var sig;

	sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, 1,
		startPos: BufFrames.kr(buf) * startPos, loop: loop, doneAction: 2);

	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 2);
	sig = Pan2.ar(MulAdd(sig, amp, 0),pan);

	Out.ar(revBus, sig * rev);
	Out.ar(outBus, sig * (1- rev));

}).send(s);


SynthDef(\Gran1, {

	arg pan = 0, buf = 0, amp = 0.5,  att = 0.01, dec = 0.01,trig = 1, trate = 10, dur = 0.25, rate = 1.0, pos = 0, outBus = 0;

	var sig;

	dur = BufDur.kr(buf) * dur;

	sig = TGrains.ar(2,
		Impulse.kr(trate),
		buf,
		rate, //playback rate
		(BufDur.kr(buf) - dur) * pos,
		dur,
		pan, //pan
		amp); //amp

	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 2);
	Out.ar(outBus, sig);

}).send(s);


SynthDef(\Gran2, {

	arg buf = 0, amp = 0.5,  att = 0.01, dec = 0.01, trig = 1, trate = 10, dur = 0.25, rate = 1.0, prange = 0, width = 0.75, outBus = 0;

	var sig, gtrig;

	dur = BufDur.kr(buf) * dur;
	gtrig = Impulse.kr(trate);

	sig = TGrains.ar(2,
		gtrig,
		buf,
		rate,
		TRand.kr(0,(BufDur.kr(buf) - dur) * prange, gtrig),
		dur,
		TRand.kr(width * -1 ,width, gtrig), //randomised pan
		amp);

	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 2);
	Out.ar(outBus, sig);

}).send(s);

"loaded Synth Definitions".postln


)


