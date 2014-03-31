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

	var t_path, isMulti;

	msg.postln;
	t_path = PathName.new(msg[2].asString);
	isMulti = t_path.isFolder;

	if(~fileBuffers.at(msg[1]).value != nil,

		{
			if(~zoneDict.at(msg[1]).at(\isMultiFile) == false, {
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
			var fileArray = Array.newClear();
			//for multi files
			"multi".postln;
			~zoneDict.at(msg[1])[\isMultiFile] = true;


			t_path.filesDo{|aFile|

				//fill an array of all the files in the directory
				aFile.realPath.postln;

			};

			~fileBuffers.put(msg[1], fileArray);



		},
		{
			//for single files
			~zoneDict.at(msg[1])[\isMultiFile] = false;
			~fileBuffers.put(msg[1] , Buffer.read(s, msg[2]));
		},
	);



}).add;


~playZone.remove;
~playZone = nil;
~playZone = OSCresponderNode(nil, '/playZone', {|i, r, msg|

	msg.postln;

	if(~liveSynths.at(msg[1]) != nil){
		~liveSynths.at(msg[1]).set(\trig, 0);
		~liveSynths.removeAt(msg[1]);
	};

	//isMultiFile needs to be considered here

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


