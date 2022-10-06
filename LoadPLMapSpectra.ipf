#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This function automatically loads all files in a folder that the user selects. In this instance, the function
//assumes that each file is a Dionex Chromeleon generated ASCII file, and that the chromatogram's data
//points were collected at 0.2 sec. intervals. You MUST must make the changes appropriate to your data
//files on the lines below marked with exclamation points!!!
//Original version available from http://www.igorexchange.com/node/1720
//Edited by Ben Treml to load and scale Spectra from the Raman Spectrometer in CCMR generated from 
//a map such that all spectra have the same scaling
//Also saves the Maximum value and Location of Maximum value for later analysis
Menu "Helios"
	Submenu "Optical"
		"Load PL Map Spectra"
	End
End

function LoadPLMapSpectra()
	//initialize loop variable
	variable i=0
	string wname,fname            //wave names and file name, respectively
 
	//Ask the user to identify a folder on the computer
	getfilefolderinfo/D
 
	//Store the folder that the user has selected as a new symbolic path in IGOR called cgms
        //!!!!!!!!! if you prefer a different name, change ALL instances of cgms in the function !!!!!!!!
	newpath/O cgms S_path
 
	//Create a list of all files that are .txt files in the folder. -1 parameter addresses all files.
       // !!!!!!!!! if your files have a different extension, change .TXT below to your extension!!!!!!!!!!!!
	string filelist= indexedfile(cgms,-1,".TXT")
	filelist = SortList(filelist,";", 16) //Sort by combination of alphabetic and numeric sorting
	
	
	//Make waves to store Peak Intensity, Total Intensity, Peak Location, FWHM, and the Normalized Spectra in later
	//Make/N=(itemsinlist(filelist))/D/O PeakIntensity
	Make/N=(itemsinlist(filelist))/D/O PeakLocation
	//Make/N=(itemsinlist(filelist))/D/O HWHM
	//Make/N=(itemsinlist(filelist))/D/O TotalIntensity
	//Make/N=(1021,itemsinlist(filelist))/D/O NormalizedSpectra 
	//SetScale/I x 666.51,490.32,"nm", NormalizedSpectra
	//Make/N=(1021,itemsinlist(filelist))/D/O UnNormalizedSpectra 
	//SetScale/I x 666.51,490.32,"nm", UnNormalizedSpectra
	//Size of spectra is hard coded in here, in future can ask the user for length of waves in addition to scaling
	
 
	//Begin processing the list
	do
		//store the ith name in the list into wname.
		fname = stringfromlist(i,filelist)
 
		//strip away ".txt" to get the name of the chromatogram, which is the file name
                //!!!!!!!!!! change the next line if you want a different name for the waves that are created !!!!!!!!!!!!!!!
                //BT Delete several useless characters from file name
		wname = fname[0,strlen(fname)-4]
 
		//reference a wave with the name of the spectra. Also reference wave0
		wave w = $wname
		//wave wave0
 
		//if the referenced wave does not exist, create it.
		if (!waveexists(w) )
 
			//The /L parameter tells IGOR to load no headers, and to load the 3rd column of data (indexed as 2) only
                        //!!!!!!!! You must change this next line to tell IGOR how to load the data in each file !!!!!!!!!!!!!!!
                        //Changed by BT to load the second column only. This contains PL intensities, scale set below
			LoadWave/G/D/A=wave/P=cgms/O/L={0,0,0,1,0} stringfromlist(i,filelist);
			
			wave wave0
			//wave Levels
			
 
			//wave created is wave0. It is renamed to the filename.
			Duplicate/O wave0, w; KillWaves wave0
			
			
			//And scaled accordingly.
                        //!!!!!!!!! you MUST change or delete the following line according to your data's scaling or lack thereof. !!!!!!!!!!!!
                        //BT This currently has values for my current scans hard coded in, will eventually ask user for data range
			SetScale/I x 686.507,510.255,"Wavelength (nm)", w
 
			
			//Print confirmation of what was just loaded.
			//print 	"Loaded "+fname
			
			//new section added by BT.  Gets PL maximum and location of maximum and adds it to the ith entry in the 1D waves created above			
			WaveStats/Q w
			//PeakIntensity[i]=V_max
			PeakLocation[i]=V_maxloc
			//TotalIntensity[i]=V_sum
			//NormalizedSpectra [] [i]=w[p]/V_max
			//UnNormalizedSpectra [] [i]=w[p]
			//This section of code is for finding the FWHM of the PL peak comment out when not using
			//FindLevels/M=30/N=2/D=Levels/B=3 w ((V_max-V_min)/2 +V_min)
			//if (V_LevelsFound>1)
				//HWHM[i]=abs(Levels(0)-Levels(1))/2
			//else 
			//	HWHM[i]=abs(Levels(0)-V_maxloc)
			//endif
			
 
		else 
			//Othewise, tell the user that this chromatogram was previously loaded.
			print 	fname+" was previously loaded. Its corresponding wave exists."
		endif
		i += 1  		//move to next file
	while(i<itemsinlist(filelist)) 			//end when all files are processed.
end