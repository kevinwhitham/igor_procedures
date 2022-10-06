#pragma rtGlobals=1		// Use modern global access method.
#pragma IndependentModule=FET

// 20140731 KW
//		return mobility value
// 	save abs() mobility values
// 20140819 KW
//		Insert new points instead of using default 128 point wave size
//		do not save abs() mobility values
// 20140822 KW
//		Only insert points if new points are needed
// 20150112 KW
//		Instead of getting transconductance by differentiating current vs. gate voltage, just fit a line in the voltage window
//		This fixes problems when the gate voltage wave is not monotonic e.g. -40 to 40 and back to -40 (the slope diverges at the turn around point)
//		Now it works for double sweeps with forward and reverse in one wave

Function FitMobility(wGateBias, wChannelCurrent,dChannelWidth,dChannelLength,dCox,dChannelBias,dAvgWindowMin,dAvgWindowMax,dIndex,dPlot)
	Wave wGateBias, wChannelCurrent
	Variable dChannelWidth,dChannelLength,dCox,dChannelBias,dAvgWindowMin,dAvgWindowMax,dIndex,dPlot
	
	// Check for empty input waves
	if( !numpnts(wGateBias) | !numpnts(wChannelCurrent) )
	 print "FitFETMobility() empty input wave"
	 return 0
	endif
	
	// Get reference to current data folder
	DFREF saveDFR = GetDataFolderDFR()
	
	// Create working directory for this analysis
	NewDataFolder/O/S FitMobility
	
	// Create data destination waves if they don't exist
	Wave/Z wMobilitySummary = $"wMobilitySummary"
	if( !WaveExists(wMobilitySummary) )
		Make/N=0 wMobilitySummary
	endif
	
	Wave/Z wMobilityStdVarSummary = $"wMobilityStdVarSummary"
	if( !WaveExists(wMobilityStdVarSummary) )
		Make/N=0 wMobilityStdVarSummary
	endif
	
	Wave/Z wThresholdVoltageSummary = $"wThresholdVoltageSummary"
	if( !WaveExists(wThresholdVoltageSummary) )
		Make/N=0 wThresholdVoltageSummary
	endif
	
	Wave/Z wThresholdVoltageSDSummary = $"wThresholdVoltageSDSummary"
	if( !WaveExists(wThresholdVoltageSDSummary) )
		Make/N=0 wThresholdVoltageSDSummary
	endif
	
	NewDataFolder/O/S $(NameOfWave(wChannelCurrent))
	
	//Wave/Z wMobility = $"wMobility"
	//if( !WaveExists(wMobility) )
	//	Make/N=0 wMobility
	//endif
	
	if( dPlot )
		// Plot Vg Id curve
		Display/N=Id_vs_Vg wChannelCurrent vs wGateBias
	endif
	
	// Check range
	if( (dAvgWindowMin == 0) && (dAvgWindowMax == 0) )
		WaveStats/Q wGateBias
		dAvgWindowMin = V_min
		dAvgWindowMax = V_max
	endif
	
	// Calculate FET mobility
	// Get dId/dVg
	//Differentiate wChannelCurrent/X=wGateBias/D=wTransconductance
	
	// Get data points between dAvgWindowMin and dAvgWindowMax
	Variable turnPnt
	WaveStats/Q wGateBias
	
	if( (wGateBias[1]-wGateBias[0]) > 0 )
		turnPnt = V_maxloc
	else
		turnPnt = V_minloc
	endif
	
	if( turnPnt < (numpnts(wGateBias)-1) )
		Make/O/FREE/N=(turnPnt+1) wGateBias_1
		wGateBias_1 = wGateBias[p]
		SetScale/I x wGateBias[0],wGateBias[turnPnt], "V", wGateBias_1
		
		Make/O/FREE/N=(numpnts(wGateBias)-turnPnt+1) wGateBias_2
		wGateBias_2 = wGateBias[p+turnPnt]
		SetScale/I x wGateBias[turnPnt],wGateBias[numpnts(wGateBias)-1], "V", wGateBias_2
		
		Variable minPnt_1 = x2pnt(wGateBias_1,dAvgWindowMin)
		Variable maxPnt_1 = x2pnt(wGateBias_1,dAvgWindowMax)
		Variable minPnt_2 = x2pnt(wGateBias_2,dAvgWindowMin)
		Variable maxPnt_2 = x2pnt(wGateBias_2,dAvgWindowMax)
		
		Make/O/FREE/N=(abs(maxPnt_1-minPnt_1)+1+abs(maxPnt_2-minPnt_2)+1) wWindowCurrent
		wWindowCurrent[0,abs(maxPnt_1-minPnt_1)] = wChannelCurrent[p+min(minPnt_1,maxPnt_1)]
		wWindowCurrent[abs(maxPnt_1-minPnt_1)+1,numpnts(wWindowCurrent)-1] = wChannelCurrent[(p-(abs(maxPnt_1-minPnt_1)+1))+min(minPnt_2,maxPnt_2)+turnPnt]
		
		Make/O/FREE/N=(abs(maxPnt_1-minPnt_1)+1+abs(maxPnt_2-minPnt_2)+1) wWindowGateBias
		wWindowGateBias[0,abs(maxPnt_1-minPnt_1)] = wGateBias[p+min(minPnt_1,maxPnt_1)]
		wWindowGateBias[abs(maxPnt_1-minPnt_1)+1,numpnts(wWindowGateBias)-1] = wGateBias[(p-(abs(maxPnt_1-minPnt_1)+1))+min(minPnt_2,maxPnt_2)+turnPnt]
	else
	
		Duplicate/O wChannelCurrent, wWindowCurrent
		Duplicate/O wGateBias, wWindowGateBias
		
	endif
	
	CurveFit/Q/M=2/W=2/N line, wWindowCurrent /X=wWindowGateBias
	WAVE W_coef
	WAVE W_sigma
	Variable transconductance = W_coef[1]
	Variable transconductanceSD = W_sigma[1]
	Variable thresholdVoltage = abs(W_coef[0]/W_coef[1])
	Variable thresholdVoltageSD = W_sigma[0]*W_sigma[1]		// probably not right
	
	//Get transconductance value
	//Duplicate/O wTransconductance,wTransconductance_Smooth
	
	//Loess /R=1/E=1 /DEST=wTransconductance_Smooth srcWave=wTransconductance
	//if( dPlot )
	//	Display/N=Transconductance_vs_Vg wTransconductance,wTransconductance_Smooth vs wGateBias
	//	ModifyGraph mode(wTransconductance)=3
	//	Label/W=Transconductance_vs_Vg left "Transconductance x \\u#1"
	//endif
	
	//Calculate FET mobility
	//Duplicate/O wTransconductance_Smooth, wMobility
	//wMobility = -wTransconductance_Smooth*dChannelLength/(dChannelWidth*dCox*dChannelBias)
	//WaveStats/Q wGateBias
	//Variable iTotalPoints = V_npnts
	//SetScale/I x wGateBias[0],wGateBias[iTotalPoints-1],"V", wMobility
	//SetScale d 0,0,"cm\S2\M/Vs", wMobility
	
	//WaveStats/Q/R=(dAvgWindowMin,dAvgWindowMax) wMobility
	InsertPoints numpnts(wMobilitySummary), max(0,(dIndex-numpnts(wMobilitySummary)+1)), wMobilitySummary
	InsertPoints numpnts(wMobilityStdVarSummary), max(0,(dIndex-numpnts(wMobilityStdVarSummary)+1)), wMobilityStdVarSummary
	
	
	wMobilitySummary[dIndex] = -transconductance*dChannelLength/(dChannelWidth*dCox*dChannelBias)
	wMobilityStdVarSummary[dIndex] = transconductanceSD
	
	// Save threshold voltage
	InsertPoints numpnts(wThresholdVoltageSummary), max(0,(dIndex-numpnts(wThresholdVoltageSummary)+1)), wThresholdVoltageSummary
	InsertPoints numpnts(wThresholdVoltageSDSummary), max(0,(dIndex-numpnts(wThresholdVoltageSDSummary)+1)), wThresholdVoltageSDSummary
	wThresholdVoltageSummary[dIndex] = thresholdVoltage
	wThresholdVoltageSDSummary[dIndex] = thresholdVoltageSD
	
	//if(dPlot)
		//Plot mobility vs gate bias
	//	Display/N=Mobility_vs_Vg wMobility vs wGateBias
	//	Label/W=Mobility_vs_Vg left "Mobility x \\u#1"
	//endif
	
	if( !dPlot )
		KillWaves wGateBias_1, wGateBias_2
		KillWaves wWindowCurrent, wWindowGateBias
	endif
	
	// Restore current data folder		
	SetDataFolder saveDFR	
	
	return wMobilitySummary[dIndex]				
	
End Function

Function SeparateMobilities(dataWave)
	Wave dataWave
	
	DFREF mobilityFolder = GetWavesDataFolderDFR(dataWave):FitMobility
	print GetDataFolder(1,mobilityFolder)
	
	Wave/Z wMobilitySummary = mobilityFolder:wMobilitySummary
	Wave/Z wHoleMobility = mobilityFolder:wHoleMobility
	Wave/Z wElectronMobility = mobilityFolder:wElectronMobility
		
	if( WaveExists(wMobilitySummary) == 0 )
		print "SeparateMobilities() Error: No mobility wave"
		return 0
	endif
	
	if( WaveExists(wHoleMobility) == 0 )
		Make/N=(numpnts(wMobilitySummary)/2) mobilityFolder:wHoleMobility
		Wave wHoleMobility = mobilityFolder:wHoleMobility
	endif
	
	if( WaveExists(wElectronMobility) == 0 )
		Make/N=(numpnts(wMobilitySummary)/2) mobilityFolder:wElectronMobility
		Wave wElectronMobility = mobilityFolder:wElectronMobility
	endif	
	
	InsertPoints numpnts(wElectronMobility),(numpnts(wMobilitySummary)/2-numpnts(wElectronMobility)),wElectronMobility
	InsertPoints numpnts(wHoleMobility), (numpnts(wMobilitySummary)/2-numpnts(wHoleMobility)), wHoleMobility
	wHoleMobility = wMobilitySummary[2*p+1]
	wElectronMobility = abs(wMobilitySummary[2*p])
	
End