#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// MarkBraggPeaks.ipf
// Place markers on a plot of diffraction data at the theoretical locations of bragg peaks
// for some materials

Menu "HELIOS"
	Submenu "Diffraction"
		"Load Peak Data", LoadDiffractionData()
		"Mark Bragg Peaks", BraggPeaks()
	End
End

// MarkBraggPeaks()
// Present a prompt to select the material
Function BraggPeaks()
	Variable materialNum
	String materialList = "PbSe;PbS;alpha Fe2O3;CdSe (ZB);CdSe (RS)"
	Prompt materialNum,"Material?", popup, materialList
	
	DoPrompt "Select material",materialNum
	
	switch(materialNum)
		case 1: //PbSe
			MarkPbSe()
			break
		case 2:
			MarkPbS()
			break
		case 3:
			MarkalphaFe2O3()
			break
		case 4:
			MarkCdSeZB()
			break
		case 5:
			MarkCdSeRS()
			break
	endswitch
End

Function LoadDiffractionData()
 	
 	// Load the reference data
 	String sMaterialName
 	Prompt sMaterialName, "Material Name?"
	DoPrompt "Material Name?", sMaterialName
	
	if( V_flag != 0 )
		print "User cancelled load data"
		return 0
	endif
	
	Variable refNum
	String message = "Select the powder diffraction table file"
	String path
	String fileFilters = "Data Files (*.txt):.txt;"
	fileFilters += "All Files:.*;"
 
	Open /D /R /F=fileFilters /M=message refNum
	path = S_fileName
	
	if( strlen(path) == 0 )
		print "No files loaded"
		return 0
	endif
	
	Wave/Z refData = $(sMaterialName+"_ref")
	if( WaveExists(refData) )
		KillWaves refData
	endif
	
	LoadWave/O/D/J/M/Q/U={0,0,1,0}/N=$sMaterialName path
	Rename $(sMaterialName+"0"), $(sMaterialName+"_ref")
	Wave refData = $(sMaterialName+"_ref")
 	
 	
 	// Now load the electron diffraction data
 	String sSampleName
 	Prompt sSampleName, "Sample Name?"
	DoPrompt "Sample Name?", sSampleName
	
	if( V_flag != 0 )
		print "User cancelled load data"
		return 0
	endif
	
	message = "Select electron diffraction data"
	fileFilters = "Data Files (*.txt,*.chi):.txt,.chi;"
	fileFilters += "All Files:.*;"
 
	Open /D /R /F=fileFilters /M=message refNum
	path = S_fileName
	
	if( strlen(path) == 0 )
		print "No files loaded"
		return 0
	endif
	
	Wave/Z sampleData = $(sSampleName)
	if( WaveExists(sampleData) )
		KillWaves sampleData
	endif
	
	LoadWave/O/D/G/M/Q/N=$sSampleName path
	Rename $(sSampleName+"0"), $(sSampleName)
	Wave sampleData = $(sSampleName)
 	
 	// Separate the required data into waves
 	Make/O/N=(dimsize(sampleData,0)) $(sSampleName+"_q"), $(sSampleName+"_intensity")
 	Wave sampleQ = $(sSampleName+"_q")
 	Wave sampleIntensity = $(sSampleName+"_intensity")
 	
 	sampleQ = sampleData[p][0]
 	sampleIntensity = sampleData[p][1]
 	
 	Make/O/N=(dimsize(refData,0)) $(sMaterialName+"_q"), $(sMaterialName+"_intensity")
 	Wave peakQ = $(sMaterialName+"_q")
 	Wave peakIntensity = $(sMaterialName+"_intensity")
 	
 	// assume d-values are in angstrom units
 	// save q values in nm^(-1) units
 	peakQ = 10*2*pi/refData[p][%'D-VALUE']
 	peakIntensity = refData[p][%INTENSITY]
 	
 	// Normalize intensity values
 	WaveStats/Q peakIntensity
	peakIntensity /= V_max
 	
 	// combine HKL into a text wave
 	Make/O/T/N=(dimsize(refData,0)) $(sMaterialName+"_labels")
 	Wave/T labels = $(sMaterialName+"_labels")
 	
 	labels = (num2str(refData[p][%H]) + num2str(refData[p][%K]) + num2str(refData[p][%L]))
 	
 	// Plot the electron diffraction data and put the A cursor on it
 	Display sampleIntensity vs sampleQ
 	Cursor/P A $(sSampleName+"_intensity") 0
 	
 	MarkBraggPeaks(peakQ, labels, peakIntensity, sMaterialName)
 	
 	ppp()
 	ChangeAnnotationFontSize(18)
 	
End

Function MarkPbSe()

	Make/FREE/N=19		PbSeQ 		= {17.75,	20.5,		28.99,	sqrt(11/4)*20.5, 35.5,		41,		44.6916, 	45.84,	50.21,	   53.26,		53.26,		57.98,	60.628,	sqrt(36/3)*17.75,	sqrt(36/3)*17.75,	sqrt(40/3)*17.75,	sqrt(43/3)*17.75,	sqrt(44/3)*17.75,	sqrt(48/3)*17.75	,	sqrt(48/3)*17.75,	sqrt(52/3)*17.75}
	Make/FREE/N=19/T		PbSeLabels	= {"111",	"200",	"220",	"311",				 "222",	"400",	   	"331", 	"420",		"422",	"511"	,		"333",	"440",	"531",	"442",					"600",									"620",					"533",					"622",					"444"	,					"642",					"640"}
	Make/FREE/N=19 		PbSeIntensity	= {358.9, 1000, 715.3, 162, 239.5, 105, 57.7, 270.8, 188.4, 28.6, 9.5, 1, 1, 1, 1, 1,1,1,1,1,1}
	
	MarkBraggPeaks(PbSeQ,PbSeLabels,PbSeIntensity, "PbSe")
End

Function MarkPbS()

	Make/FREE/N=18 	PbSQ 			= {	18.325,	21.16,	sqrt(8/4)*21.16,		sqrt(12/4)*21.16,		sqrt(16/4)*21.16,	sqrt(20/4)*21.16,		sqrt(24/4)*21.16,			sqrt(27/4)*21.16,		sqrt(32/4)*21.16,		sqrt(35/4)*21.16,	sqrt(36/4)*21.16,	sqrt(36/4)*21.16,	sqrt(40/4)*21.16,	sqrt(43/4)*21.16,	sqrt(44/4)*21.16,	sqrt(48/4)*21.16,	sqrt(48/4)*21.16,	sqrt(52/4)*21.16}
	Make/FREE/N=18/T PbSLabels	= {	"111",	"200",					"220",					"222",						"400",					"420",						"422",							"333"	,						"440",						"531",					"442",					"600",					"620",					"533",					"622",					"444"	,					"642",					"640"}
	Make/FREE/N=18 	PbSIntensity 		= 1
	
	MarkBraggPeaks(PbSQ, PbSLabels, PbSIntensity, "PbS")
End

Function MarkalphaFe2O3()

	Make/FREE/N=10 	alphaFe2O3Q 			= {	17.05, 23.25, 24.94, 27.37, 28.45, 28.45, 30.21, 34.1, 37, 37 }
	Make/FREE/N=10/T alphaFe2O3Labels	= {	"012", "104", "110", "006", "113", "11-3", "202", "024", "116", "11-6"}
	Make/FREE/N=10 alphaFe2O3Intensity	= {	0.278, 1, 0.744, 0.02, 0.09, 0.09, 0.02, 0.4, 0.25, 0.25}
	
	MarkBraggPeaks(alphaFe2O3Q,alphaFe2O3Labels,alphaFe2O3Intensity,"Fe\B2\MO\B3")
End

Function MarkCdSeZB()

	Make/FREE/N=10 		q_value 		= {	 17.908,20.6786,29.2445,34.2912,35.8159,41.3558,45.0666,46.2373,50.6504,53.7254,53.7254}
	Make/FREE/N=10/T 	labels		= { "111","200","220","311","222","400","331","420","422","511","333"}
	Make/FREE/N=10		intensity	= {	1,0.032,0.6907,0.4138,0.0072,0.0998,0.1466,0.0074,0.1801,0.0742,0.0247}
	
	MarkBraggPeaks(q_value,labels,intensity,"CdSe(ZB)")
End

Function MarkCdSeRS()

	Make/FREE/N=10 		q_value 		= {	 19.6442,22.683,32.0783,37.6149,39.2871,45.366,49.435,50.7199,55.5641,58.9306,58.9306,64.16,67.0994,68.0514,68.0514,71.7259}
	Make/FREE/N=10/T 	labels		= { "111","200","220","311","222","400","331","420","422","511","333","440","531","442","600","620"}
	Make/FREE/N=10		intensity	= {	0.0631,1,0.7357,0.0274,0.2544,0.1148,0.0093,0.3006,0.2079,0.0045,0.0015,0.0555,0.0052,0.0842,0.021,0.0651}
	
	MarkBraggPeaks(q_value,labels,intensity,"CdSe(RS)")
End



// MarkBraggPeaks()
// Mark given crystal plane reference peaks on a graph
// peakQ - 1D wave of peak locations in nm^-1
// peakLabel - 1D wave of strings with a peak label for each location
// peakIntensity - normalized intensity of each peak
Function MarkBraggPeaks(peakQ, peakLabel, peakIntensity,material)
	WAVE 		peakQ
	WAVE/T	peakLabel
	WAVE		peakIntensity
	String	material
	
	// Use the top graph
	Wave intensity = CsrWaveRef(A)
	Wave q_wave = CsrXWaveRef(A)
	
	if( (WaveExists(intensity) == 0) || (WaveExists(q_wave) == 0) )
		printf "Put cursor A on the diffraction curve"
		return 0
	endif
	
	SetScale/I x q_wave[0],q_wave[numpnts(q_wave)-1],"nm\S-1", intensity
	
	// Clean up the graph
	Label bottom "nm\\S-1"
	ModifyGraph noLabel(left)=2,axOffset(left)=-5
	ModifyGraph nticks(bottom)=10
	SetAxis/A/N=1 left	// round limits on vertical axis to nice values
	
	if( numpnts(peakQ) != numpnts(peakLabel) )
		print "Number of peak locations and labels do not match"
		return 0
	endif
	
	Variable maxQ, minQ
	WaveStats/Q q_wave
	maxQ = V_max
	minQ = V_min
	
	// make waves to plot the theoretical peak intensities
	WaveStats/Q peakIntensity
	Variable max_intensity = V_max
	Variable max_intensity_loc = V_maxRowLoc
	
	Make/O/N=(numpnts(peakQ)) peak_locations, peak_intensities
	peak_locations = peakQ
	peak_intensities = peakIntensity/max_intensity * 0.9 * intensity(peakQ[max_intensity_loc])
	
	AppendToGraph/C=(0,0,0) peak_intensities/TN=$(NameOfWave(intensity)+"ref") vs peak_locations
	ModifyGraph mode($(NameOfWave(intensity)+"ref"))=1
	
	
	Variable i = 0, vertShift = 0, line = 1
	
	for(i = 0; i < numpnts(peakQ); i += 1 )
	
		// Don't draw labels beyond the range of the data
		if( peakQ[i] >= minQ )
			if( peakQ[i] <= maxQ )
		
				// If this label is at the same X location as the previous
				// then shift it up so it doesn't cover the previous one and
				// don't draw a line through the previous one
				// this assumes the peak list is sorted by Q
				if( i > 0 )
					if( peakQ[i] == peakQ[i-1] 	)
						vertShift += 8
						line = 0
					else
						vertShift = 0
						line = 1
					endif
				endif
				
				Tag/C/N=$(NameOfWave(intensity)+num2str(i))/O=0/F=0/Z=0/L=(line)/X=0/Y=(10+vertShift)/A=LB $(NameOfWave(intensity)), peakQ[i], "\Z16{"+peakLabel[i]+"}\B"+material		
			endif
		endif
	endfor
	

	
End


// Estimate crystal size using Scherr's equation to analyze electron diffraction
// peakResults is probably called: "MPF2_ResultsListWave"
Function CalculatePbSeCrystalSize(peakresults)
	Wave/T		peakresults
	Variable i = 0, q_radius, FWHM_q
	
	for(i = 0; i < dimsize(peakresults,0);i+=1)
		q_radius = str2num(peakresults[i][2])
		FWHM_q = str2num(peakresults[i][8])
//		d = 6.12/sqrt(s_values[i])	// angstroms
		
//		theta_bragg = asin(wavelength_ang/(2*d))
//		theta_breadth = (atan(q_radius/cameralength_mm/q_radius)
	
		printf "Q=%g (nm\S-1),\tFWHM=%0.3g,\tD=%g (nm)\r",q_radius,FWHM_q,2*pi*0.9/FWHM_q
	endfor
	
End