(

s.waitForBoot(

	onComplete:{


		SystemClock.sched(1.0,{
		this.executeFile("/Users/simonkatan/Documents/SuperCollider/Code/Projects/danceTrackerSC/danceTrackerSCDefs.scd");

				nil
		});


		SystemClock.sched(2.0,{

			//wait a second just to be sure
			this.executeFile("/Users/simonkatan/Documents/SuperCollider/Code/Projects/danceTrackerSC/danceTrackerSCosc.scd");
			nil
		});


	}

)


)
