(


//handshake code


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
	0.quit;


}).play;




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
	zone.add(\sampleIndex->0);
	zone.add(\isSampleAscend->true);
	~zoneDict.put(msg[1], zone);

}).add;

~removeZone.remove;
~removeZone = nil;
~removeZone = OSCresponderNode(nil, '/removeZone', {|i,r,msg|

	//msg.postln;
	~zoneDict.removeAt(msg[1]);
	//also will need to clear file buffers

}).add;


~updateSynth.remove;
~updateSynth = nil;
~updateSynth = OSCresponderNode(nil, '/updateSynth', {|i ,r, msg|

	//msg.postln;

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

	var t_path, isMulti;

	msg.postln;
	t_path = PathName.new(msg[2].asString);
	isMulti = t_path.isFolder;


	if(~fileBuffers.at(msg[1]).value != nil,

		{
			if(~fileBuffers.at(msg[1]).value.isArray == false, {
				//for single files
				~fileBuffers.at(msg[1]).value.free;
				},{
					~fileBuffers.at(msg[1]).size().do{arg count;
						~fileBuffers.at(msg[1]).at(count).value.free;

					}
				}
			);

			~fileBuffers.removeAt(msg[1]);
		}


	);


	if(isMulti,
		{
			//for multiple files
			var fileNames = Array.newClear(), t_sounds = Array.newClear();

			//fill an
			t_path.filesDo{|aFile|fileNames = fileNames.add(aFile.fullPath.asString)};

			fileNames.asSortedList.do({|item|
				t_sounds = t_sounds.add(Buffer.read(s, item));
			});

			~fileBuffers.put(msg[1], t_sounds);

		},
		{
			//for single files
			~fileBuffers.put(msg[1] , Buffer.read(s, msg[2]));
		},
	);



}).add;


~playZone.remove;
~playZone = nil;
~playZone = OSCresponderNode(nil, '/playZone', {|i, r, msg|

	var sel_sample;

	msg.postln;

	if(~liveSynths.at(msg[1]) != nil){
		~liveSynths.at(msg[1]).set(\trig, 0);
		~liveSynths.removeAt(msg[1]);
	};

	//choose the correct sample
	if(~fileBuffers.at(msg[1]).value.isArray,{

		var st = ~zoneDict.at(msg[1]).at(\selectorType).asString,
		si = ~zoneDict.at(msg[1]).at(\sampleIndex),
		numFiles = ~fileBuffers.at(msg[1]).value.size();

		//only random is modified before
		if( st == "random",{si = rrand(0, numFiles -1)});

		sel_sample = ~fileBuffers.at(msg[1]).value[si];

		if( st == "wrap",{si = (si + 1)%numFiles; });
		if( st == "serial",{si = min(si + 1, numFiles - 1);});
		if( st == "pingPong",{

			if(~zoneDict.at(msg[1]).at(\isSampleAscend) == true,
				{
				//ascending
					si = si + 1;
					if(si == (numFiles - 1), {~zoneDict.at(msg[1])[\isSampleAscend] = false});
				},{
				//descending
					si = si - 1;
					if(si == 0, {~zoneDict.at(msg[1])[\isSampleAscend] = true});
				}
			);


		});

		~zoneDict.at(msg[1])[\sampleIndex] = si;

	},{
		sel_sample = ~fileBuffers.at(msg[1]).value;
	});

	//NB. a multisample selector could be created later for multiple sample gran synths



	if(~zoneDict.at(msg[1]).at(\synthType).asString == "simple",{

			~liveSynths.put(msg[1],

				Synth.new(\SimplePlayer,
					[\buf, sel_sample,
					\outBus, ~sceneBuses[~sceneBusIndex],
					\loop, ~zoneDict.at(msg[1]).at(\loop),
					\pan, ~zoneDict.at(msg[1]).at(\pan),
					\amp, ~zoneDict.at(msg[1]).at(\amp),
					\att, ~zoneDict.at(msg[1]).at(\fadeIn),
					\dec, ~zoneDict.at(msg[1]).at(\fadeOut),
					\startPos, ~zoneDict.at(msg[1]).at(\startPos),
					],~sceneGroups[~sceneBusIndex]
				);

			)

	});

	if(~zoneDict.at(msg[1]).at(\synthType).asString == "gran1",{

			~liveSynths.put(msg[1],

				Synth.new(\Gran1,
					[\buf, sel_sample,
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

	if(~zoneDict.at(msg[1]).at(\synthType).asString == "gran2",{

			~liveSynths.put(msg[1],

				Synth.new(\Gran2,
					[\buf, sel_sample,
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
		"stop".postln;
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


~resetZone.remove;
~resetZone = nil;
~resetZone = OSCresponderNode(nil, '/resetZone', {|i, r, msg|

	//msg.postln;
	//reset persistent data here
	~zoneDict.at(msg[1])[\sampleIndex] = 0;
	~zoneDict.at(msg[1])[\isSampleAscend] = true;

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

	~fileBuffers.do({|item|
		if(item.isArray,
			{
				item.do({|buf|
					buf.free;
				});

			},{
				item.free;
			}
		)
	});

	~fileBuffers = nil;

	0.exit;


}).add;



)


