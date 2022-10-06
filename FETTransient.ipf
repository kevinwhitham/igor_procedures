#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma IndependentModule=FET 

// Fit_Transient_Current()
//	fit a single exponential function to current vs time data, save the time constant
// 20140822 KW
//		created
Function Fit_Transient_Current(timeWave, currentWave, timeUnitString, index)
	Wave timeWave, currentWave
	String timeUnitString
	Variable index
	
	DFREF initialDF = GetDataFolderDFR()
	NewDataFolder/O/S FitTransient
	Make/FREE/N=3 coefWave
	
	//SetScale/I x, timeWave[0], timeWave[numpnts(timeWave)-1], timeUnitString, currentWave
	
	CurveFit/Q/W=2 exp_Xoffset, kwCWave=coefWave, currentWave /AD=0 /X=timeWave
	
	WAVE/Z wTimeConstant = wTimeConstant
	
	if( !WaveExists(wTimeConstant) )
		Make/N=0 wTimeConstant
	endif
	
	InsertPoints numpnts(wTimeConstant), max(0,index-numpnts(wTimeConstant)+1), wTimeConstant
	
	wTimeConstant[index] = coefWave[2]
	
	SetDataFolder initialDF
End