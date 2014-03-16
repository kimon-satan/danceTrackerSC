
(

SynthDef(\SceneMix, {arg att = 0.01, dec = 0.01, inBus = 0, trig = 1;

	var sig = In.ar(inBus, 2);
	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 13);
	Out.ar(0,sig);

}).send(s);

SynthDef(\SimplePlayer, {
	arg pan = 0, buf = 0, amp = 0.5, att =0.01, dec = 0.01, loop= 1, trig = 1, rate = 1, outBus = 0;

	var sig;

	sig = PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, 1, 0, loop: loop, doneAction: 2);
	sig = sig * EnvGen.kr(Env.asr(att,1,dec,'sine'), trig, doneAction: 2);
	sig = Pan2.ar(MulAdd(sig, amp, 0),pan);
	Out.ar(outBus, sig);

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


)




(



//handshake code

//this will go in the startup file not as an OSC node

~ini.remove;
~ini=nil;
~ini = OSCresponderNode(nil, '/init', {|i, r, msg|

	msg.postln;
	b = NetAddr.new("127.0.0.1", 71717);    // create the NetAddr

	//initialisation of env variables

	~zoneDict = Dictionary.new;
	~fileBuffers = Dictionary.new;
	~liveSynths = Dictionary.new;
	~sceneBuses = Array.fill(10, {Bus.audio(s,2)});
	~sceneGroups = Array.fill(10, {Group.new});
	~sceneBusIndex = 0;
	~sceneMaster = Synth.new(\SceneMix, [\inBus, ~sceneBuses[~sceneBusIndex]],
		~sceneGroups[~sceneBusIndex]
	);

	t = Task({

		200.do{arg count;

			b.sendMsg("/sc_hello");
			" sending sc_hello ".post; count.post; " ...".postln;
			0.5.wait
		};

		"handshake failed ... quiting server".postln;
		s.quit;


	}).play;



}).add;


//this goes int he start up file but stays as osc...

~handshake.remove;
~handshake=nil;
~handshake = OSCresponderNode(nil, '/of_hello', {|i, r, msg|

	msg.postln;
	t.stop;

}).add;


~addZone.remove;
~addZone = nil;
~addZone = OSCresponderNode(nil, '/addZone', {|i,r,msg|

	var zone;
	msg.postln;

	zone = ();
	~zoneDict.put(msg[1], zone);

}).add;

~removeZone.remove;
~removeZone = nil;
~removeZone = OSCresponderNode(nil, '/removeZone', {|i,r,msg|

	msg.postln;
	~zoneDict.removeAt(msg[1]);
	//also will need to clear file buffers

}).add;


~updateSynth.remove;
~updateSynth = nil;
~updateSynth = OSCresponderNode(nil, '/updateSynth', {|i ,r, msg|

	~zoneDict.at(msg[1]).keysValuesDo{|key, value|

		if(key != \playToEnd ||  key != \synthType , {
			//key.post; ",".post;value.postln;
			~liveSynths.at(msg[1]).set(key, value);
		});

	}

}).add;

~updateZoneSettings.remove;
~updateZoneSettings = nil;
~updateZoneSettings = OSCresponderNode(nil, '/updateZoneSettings', {|i,r,msg|

	//msg.postln;
	if(~zoneDict.at(msg[1]).at(msg[2]) == nil ,
		{
		~zoneDict.at(msg[1]).value.add(msg[2].asSymbol->msg[3])
		},
		{
			~zoneDict.at(msg[1])[msg[2].asSymbol] = msg[3];
		}
	);

}).add;

~loadZoneSound.remove;
~loadZoneSound = nil;
~loadZoneSound = OSCresponderNode(nil, '/loadZoneSound', {|i,r,msg|

	msg.postln;

	if(~fileBuffers.at(msg[1]).value != nil,

	{
		~fileBuffers.at(msg[1]).value.free;
		~fileBuffers.removeAt(msg[1]);

	}

	);


	~fileBuffers.put(msg[1] , Buffer.read(s, msg[2]));


}).add;


~playZone.remove;
~playZone = nil;
~playZone = OSCresponderNode(nil, '/playZone', {|i, r, msg|

	msg.postln;

	if(~liveSynths.at(msg[1]) != nil){
		~liveSynths.at(msg[1]).set(\trig, 0);
		~liveSynths.removeAt(msg[1]);
	};

	if(~zoneDict.at(msg[1]).at(\synthType) == 0,{

			~liveSynths.put(msg[1],

				Synth.new(\SimplePlayer,
					[\buf, ~fileBuffers.at(msg[1]).value,
					\outBus, ~sceneBuses[~sceneBusIndex],
					\loop, ~zoneDict.at(msg[1]).at(\loop),
					\pan, ~zoneDict.at(msg[1]).at(\pan),
					\amp, ~zoneDict.at(msg[1]).at(\amp),
					\att, ~zoneDict.at(msg[1]).at(\fadeIn),
					\dec, ~zoneDict.at(msg[1]).at(\fadeOut)
					],~sceneGroups[~sceneBusIndex]
				);

			)

	});

	if(~zoneDict.at(msg[1]).at(\synthType) == 1,{

			~liveSynths.put(msg[1],

				Synth.new(\Gran1,
					[\buf, ~fileBuffers.at(msg[1]).value,
					\outBus, ~sceneBuses[~sceneBusIndex],
					\pan, ~zoneDict.at(msg[1]).at(\pan),
					\amp, ~zoneDict.at(msg[1]).at(\amp),
					\trate, ~zoneDict.at(msg[1]).at(\trate),
					\rate, ~zoneDict.at(msg[1]).at(\rate),
					\dur, ~zoneDict.at(msg[1]).at(\dur),
					\pos, ~zoneDict.at(msg[1]).at(\pos),
					\att, ~zoneDict.at(msg[1]).at(\fadeIn),
					\dec, ~zoneDict.at(msg[1]).at(\fadeOut)
					], ~sceneGroups[~sceneBusIndex]
				);

			)

	});

	if(~zoneDict.at(msg[1]).at(\synthType) == 2,{

			~liveSynths.put(msg[1],

				Synth.new(\Gran2,
					[\buf, ~fileBuffers.at(msg[1]).value,
					\outBus, ~sceneBuses[~sceneBusIndex],
					\width, ~zoneDict.at(msg[1]).at(\width),
					\amp, ~zoneDict.at(msg[1]).at(\amp),
					\trate, ~zoneDict.at(msg[1]).at(\trate),
					\rate, ~zoneDict.at(msg[1]).at(\rate),
					\dur, ~zoneDict.at(msg[1]).at(\dur),
					\prange, ~zoneDict.at(msg[1]).at(\prange),
					\att, ~zoneDict.at(msg[1]).at(\fadeIn),
					\dec, ~zoneDict.at(msg[1]).at(\fadeOut)
					], ~sceneGroups[~sceneBusIndex]
				);

			)

	});


}).add;


~stopZone.remove;
~stopZone = nil;
~stopZone = OSCresponderNode(nil, '/stopZone', {|i, r, msg|

	msg.postln;

	if(~zoneDict.at(msg[1]).at(\playToEnd) == 0 ,{
		~liveSynths.at(msg[1]).set(\trig, 0);
	},{
		~liveSynths.at(msg[1]).set(\loop, 0);
	});

	//~liveSynths.removeAt(msg[1]);


}).add;

~newScene.remove;
~newScene = nil;
~newScene = OSCresponderNode(nil, '/newScene', {|i, r, msg|

	msg.postln;
	s.queryAllNodes;
	~sceneMaster.set(\trig, 0);
	~sceneMaster = nil;
	~sceneGroups[~sceneBusIndex].set(\loop, 0);
	~sceneBusIndex = (~sceneBusIndex + 1)%10;
	~sceneMaster = Synth.new(\SceneMix, [\inBus, ~sceneBuses[~sceneBusIndex], \att, msg[1], \dec, msg[2]], ~sceneGroups[~sceneBusIndex],'addToTail');

}).add;

~exitNode.remove;
~exitNode = nil;
~exitNode = OSCresponderNode(nil, '/exit', {|i, r, msg|

	msg.postln;
	~sceneMaster.free;
	~sceneBuses.size.do{|count|

		~sceneBuses[count].free;
		~sceneGroups[count].free;

	};
	//0.exit;


}).add;

)





