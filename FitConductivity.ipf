#pragma rtGlobals=1		// Use modern global access method.
#pragma IndependentModule=FET

// 20140801 KW
//		plot conductance vs. voltage matrix to account for range limits instead of entire input voltage wave
// 20140811 KW
//	insert points into destination waves if the index number is larger than the size of the wave
// 20140815 KW
//	check for empty input waves
// 20140821 KW
//		Insert new points instead of using default 128 point wave size

Function FitConductivity(sSampleID,dTemperature, dContactPoints, wVoltageWaveRefs, wCurrent1, wCurrent2, wProbePosition, dWidth,dThickness,sDistanceUnit,dRangeMin,dRangeMax,dPlot, dDestIndex)
	
	// wave names listed in wVoltageWaveRefs are varying voltages (in Volts) from a >1 point measurement
	// wCurrent is the current (in Amperes) measured from points 1 and 4
	// wProbePosition lists the positions of the probes according to the order given in wVoltageWaveRefs in units specified by sDistanceUnit
	Wave/WAVE wVoltageWaveRefs
	Wave wCurrent1, wCurrent2, wProbePosition
	
	// dWidth is the device width (orthogonal to the current)
	// dThickness is the thickness of the sample (orthogonal to the current)
	// dMobility is the measured mobility (for calculating carrier concentration)
	// sDistanceUnit is a string specifying the unit for all distances
	// dPlot - true/false plot or not?
	Variable dWidth,dThickness,dTemperature, dContactPoints, dRangeMin, dRangeMax, dPlot, dDestIndex
	String sDistanceUnit,sSampleID
	
	// Check for empty input waves
	if( !numpnts(wCurrent1) | !numpnts(wCurrent2) | !numpnts(wVoltageWaveRefs) | !numpnts(wProbePosition) )
	 print "FitConductivity() empty input wave"
	 return 0
	endif
	
	String initialFolderName = GetDataFolder(0)
	String initialFolderPath = GetDataFolder(1)
	
	// Get reference to current data folder
	DFREF saveDFR = GetDataFolderDFR()
	
	// Create working directory for this analysis
	NewDataFolder/O/S FitConductivityData
	
	// Create data destination waves if they don't exist
	Wave/Z wConductivity1 = $"wConductivity1"
	if( !WaveExists(wConductivity1) )
		Make/N=0 wConductivity1
	endif
	
	Wave/Z wConductivity1SD = $"wConductivity1SD"
	if( !WaveExists(wConductivity1SD) )
		Make/N=0 wConductivity1SD
	endif
	
	Wave/Z wConductivity2 = $"wConductivity2"
	if( !WaveExists(wConductivity2) )
		Make/N=0 wConductivity2
	endif
	
	Wave/Z wConductivity2SD = $"wConductivity2SD"
	if( !WaveExists(wConductivity2SD) )
		Make/N=0 wConductivity2SD
	endif
	
	Wave/Z wContactResistance = $"wContactResistance"
	if( !WaveExists(wContactResistance) )
		Make/N=0 wContactResistance
	endif
	
	Wave/Z wContactResistanceSD = $"wContactResistanceSD"
	if( !WaveExists(wContactResistanceSD) )
		Make/N=0 wContactResistanceSD
	endif
	
	NewDataFolder/O/S $(NameOfWave(wCurrent1))
	
	// Check if the first voltage wave ref is null
	if( WaveExists(wVoltageWaveRefs[0]) == 0 )
		Make/O/N=(numpnts(wVoltageWaveRefs[dContactPoints-1])) wVS = 0
		wVoltageWaveRefs[0] = wVS
	endif
	
	// Assume the last contact point has the correct number of data points
	WAVE/D w = wVoltageWaveRefs[dContactPoints-1]

	//WaveStats/Q w
	SetScale/I x, w[0], w[numpnts(w)-1], "V", w
	
	if( dRangeMin == 0 && dRangeMax == 0)
		dRangeMin = w[0]
		dRangeMax = w[numpnts(w)-1]
	endif
	
	Variable firstPnt = x2pnt(w,dRangeMin), lastPnt = x2pnt(w,dRangeMax), dataPts = abs(firstPnt-lastPnt)+1, i = 0
	//printf "Fitting from point %g to %g\r", firstPnt, lastPnt
	
	// Plot measured voltages vs the last contact point voltage
	if( dPlot )
		String voltagePlotName = "V_vs_"+NameOfWave(wVoltageWaveRefs[dContactPoints-1])
		DoWindow/K $voltagePlotName	// kill any existing window with this window name
		Display/K=3 /N=$voltagePlotName  /HIDE=1 /I /W=(0,0,5,3) wVoltageWaveRefs[0] vs wVoltageWaveRefs[dContactPoints-1]
		for(i=1;i<dContactPoints;i=i+1)
			AppendToGraph/W=$voltagePlotName wVoltageWaveRefs[i] vs wVoltageWaveRefs[dContactPoints-1]
		endfor
		ModifyGraph/W=$voltagePlotName gfSize=12, gmSize=1, mode=3
		SetAxis/W=$voltagePlotName /A left
		Label/W=$voltagePlotName left, "Voltage (V)" 
		Label/W=$voltagePlotName bottom, "Voltage (V)"
	endif 
	
	// Calculate contact resistance at left and right contacts 
	//Rc = (voltage drop at contact) / current
	// Linear regression of second through second-to-last contact point
	Make/FREE /N=(dataPts) wVm_slope
	Make/O/N=(dataPts) wRcLeft,wRcRight
	Make/FREE/D /N=(dContactPoints-2) fitResults
	
	// Put all voltage data in a matrix
	Make/O/D /N=(dataPts,dContactPoints) wVoltageMatrix
	Make/FREE/O/D temp
	for(i=0;i<dContactPoints;i=i+1)
		Duplicate/O  wVoltageWaveRefs[i],temp
		wVoltageMatrix[,lastPnt][i] = temp[p+firstPnt]
	endfor
	
	// Impose desired range on wCurrent1 and wCurrent2
	Make/FREE/N=(dataPts) tempCurrent1, tempCurrent2
	tempCurrent1 = wCurrent1[p+firstPnt]
	tempCurrent2 = wCurrent2[p+firstPnt]
	
	// Assume the last voltage wave is the independent voltage and the first voltage wave is reference (zero volts)
	// Correct for zero-point offset in the other voltage waves	
	//SetScale/I x, w[0], w[dataPts-1], "V", w //doesn't work if dataPts is less than the length of w
	Variable zeroPointIndex = x2pnt(w, 0 )
	Variable offset = 0
	for( i = 1; i<(dContactPoints-1);i=i+1)
		offset = wVoltageMatrix[zeroPointIndex][i]
		//wVoltageMatrix[0,dataPts-1][i] = wVoltageMatrix[p][i]-offset
		//AppendToGraph/W=$voltagePlotName wVoltageMatrix[][i] vs wVoltageWaveRefs[dContactPoints-1]
		//ModifyGraph/W=$voltagePlotName mode[(wVoltageMatrix[][i])]=0
	endfor

	// Transpose the matrix of voltages
	MatrixOp/O wVoltageMatrixTranspose = wVoltageMatrix^t

	//Variable dFitSpread = 10
	for(i=0;i<dataPts;i=i+1)
		// linear fit the voltage vs. position for the inner electrodes (excluding first and last electrode)
		CurveFit/Q line  wVoltageMatrixTranspose[1,dContactPoints-2][i] /X=wProbePosition[1,dContactPoints-2]
		wVm_slope[i] = K1
		wRcLeft[i] = abs((wVoltageMatrix[i][0]-K0)/tempCurrent1[i])
		wRcRight[i] = abs((wVoltageMatrix[i][(dContactPoints-1)]-(K0+wProbePosition[(dContactPoints-1)]*K1))/tempCurrent1[i])
	endfor
	
	// Plot voltage vs. position
	Duplicate/O wProbePosition,wProbeSpots
	if( dPlot )
		String voltageProfilePlotName = "Vprofile_"+NameOfWave(wCurrent1)
		if(strlen(voltageProfilePlotName) > 20)
			voltageProfilePlotName = voltageProfilePlotName[0,20]
		endif
		DoWindow/K $voltageProfilePlotName	// kill any existing window with this window name
		Display/K=3 /N=$voltageProfilePlotName  /HIDE=1 /I /W=(0,0,5,3) wVoltageMatrix[floor(dataPts/2)][] vs wProbeSpots
		ModifyGraph/W=$voltageProfilePlotName gfSize=12, gmSize=8, mode=3
		Label/W=$voltageProfilePlotName left, "Voltage (V)"
		Label/W=$voltageProfilePlotName bottom, "Position ("+sDistanceUnit+")"
	endif
	
	String sRcLeft, sRcRight
	WaveStats/Q wRcLeft
	Variable dRcLeft = V_avg
	sprintf sRcLeft, "%1.3e ohm ± %1.3e", V_avg, V_sdev

	WaveStats/Q wRcRight
	Variable dRcRight = V_avg
	sprintf sRcRight, "%1.3e ohm ± %1.3e", V_avg, V_sdev
	
	// Save contact resistance and std. dev. to destination wave
	InsertPoints numpnts(wContactResistance), max(0,(dDestIndex-numpnts(wContactResistance)+1)), wContactResistance
	InsertPoints numpnts(wContactResistanceSD), max(0,(dDestIndex-numpnts(wContactResistanceSD)+1)), wContactResistanceSD
	
	wContactResistance[dDestIndex] = (wRcLeft+wRcRight)/2
	wContactResistanceSD[dDestIndex] = abs(wRcLeft-wRcRight)/2
	
	// Plot contact resistance vs applied voltage curve
	if( dPlot )
		String contactResistancePlotName = "Rc_"+NameOfWave(wCurrent1)
		DoWindow/K $contactResistancePlotName	// kill any existing window with this window name
		Display/K=3 /N=$contactResistancePlotName  /HIDE=1 /I /W=(0,0,5,3) wRcLeft vs wVoltageMatrix[][dContactPoints-1]
		AppendToGraph/W=$contactResistancePlotName wRcRight vs wVoltageMatrix[][dContactPoints-1]
		ModifyGraph/W=$contactResistancePlotName rgb(wRcLeft)=(0,0,0)
		ModifyGraph/W=$contactResistancePlotName rgb(wRcRight)=(0,0,0)
		ModifyGraph/W=$contactResistancePlotName marker(wRcLeft)=0
		ModifyGraph/W=$contactResistancePlotName marker(wRcRight)=1
		ModifyGraph/W=$contactResistancePlotName gfSize=12, gmSize=8, mode=3
		Label/W=$contactResistancePlotName left, "Contact Resistance (Ohm)"
		Label/W=$contactResistancePlotName bottom, "Voltage (V)"
	endif
	
	// Calculate resistance
	Make/O/N=(dataPts) wR = abs((wVm_slope*(abs(wProbePosition[dContactPoints-2]-wProbePosition[1])))/tempCurrent1)
	Make/O/N=(dataPts) wR = abs((wVm_slope*(abs(wProbePosition[dContactPoints-2]-wProbePosition[1])))/tempCurrent2)

	// Calculate average conductivity over the applied voltage range
	// conductivity = current density / electric field
	// wVm_slope (V/distance) is the electric field across the inner (excluding first and last) electrodes
	Make/FREE/O/N=(dataPts) wSigma1 = abs(tempCurrent1/(wVm_slope*dWidth*dThickness))
	Make/FREE/O/N=(dataPts) wSigma2 = abs(tempCurrent2/(wVm_slope*dWidth*dThickness))

	Make/FREE/O/N=(dataPts) wSigma1_smooth
	Loess /Z=1/DEST=wSigma1_smooth /R=1 srcWave=wSigma1
	WaveStats/Q wSigma1_smooth
	String sConductivity1, sConductivity1SD
	Variable sigma_avg = 0, sigma_sd = 0
	sigma_avg	= V_avg
	sigma_sd		= V_sdev
	sprintf sConductivity1, "%1.2e", (sigma_avg)
	sprintf sConductivity1SD, "%1.2e", (sigma_sd)
	
	// If the fitting error is large, just use the average instead of
	//	smoothing the data
	if( V_sdev > (0.5 * V_avg) )
		print "Large error in average conductivity "+sSampleID+" index # "+num2str(dDestIndex)+"\r"
		sigma_avg = StatsMedian(wSigma1)
		sprintf sConductivity1, "%1.2e", (sigma_avg)
		// keep the sdev from before
	endif
	
	// Save conductivity and std. dev. to destination wave
	InsertPoints numpnts(wConductivity1), max(0,(dDestIndex-numpnts(wConductivity1)+1)), wConductivity1
	InsertPoints numpnts(wConductivity1SD), max(0,(dDestIndex-numpnts(wConductivity1SD)+1)), wConductivity1SD
	
	wConductivity1[dDestIndex] = sigma_avg
	wConductivity1SD[dDestIndex] = sigma_sd
	
	Make/FREE/O/N=(dataPts) wSigma2_smooth
	Loess /DEST=wSigma2_smooth /R=1 srcWave=wSigma2	
	WaveStats/Q wSigma2_smooth
	String sConductivity2, sConductivity2SD
	sigma_avg	= V_avg
	sigma_sd		= V_sdev
	sprintf sConductivity2, "%1.2e", (sigma_avg)
	sprintf sConductivity2SD, "%1.2e", (sigma_sd)
	
	// If the fitting error is large, just use the average instead of
	//	smoothing the data
	if( V_sdev > (0.5 * V_avg) )
		WaveStats/Q wSigma2
		sigma_avg = StatsMedian(wSigma1)
		sprintf sConductivity2, "%1.2e", (sigma_avg)
		// keep the sdev from before
	endif
	
	// Save conductivity and std. dev. to destination wave
	InsertPoints numpnts(wConductivity2), max(0,(dDestIndex-numpnts(wConductivity2)+1)), wConductivity2
	InsertPoints numpnts(wConductivity2SD), max(0,(dDestIndex-numpnts(wConductivity2SD)+1)), wConductivity2SD
	
	wConductivity2[dDestIndex] = sigma_avg
	wConductivity2SD[dDestIndex] = sigma_sd	
		
	// Plot conductance vs applied voltage curve, should be constant
	if( dPlot )
		Make/O/N=(dataPts) wConductance = 1/wR
		String conductancePlotName = "G_"+NameOfWave(wCurrent1)
		DoWindow/K $conductancePlotName	// kill any existing window with this window name
		Display/K=3 /N=$conductancePlotName  /HIDE=1 /I /W=(0,0,5,3) wConductance vs wVoltageMatrix[][dContactPoints-1]
		ModifyGraph/W=$conductancePlotName gfSize=12, gmSize=8, mode=3
		Label/W=$conductancePlotName left, "Conductance (Ohm)\S-1\M"
		Label/W=$conductancePlotName bottom, "Voltage (V)"

		// Calculate average resistance over the applied voltage range
		WaveStats/Q wConductance
		Variable dRAvg = V_avg
		Variable dRSD = V_sdev
		String sConductance, sConductanceSD
		sprintf sConductance, "%1.2e", (V_avg)
		sprintf sConductanceSD, "%1.2e", (V_sdev)
	
	endif
	
	// Shorten plot names if neccessary
	if(strlen(voltagePlotName) > 31)
		voltagePlotName = voltagePlotName[0,31]
	endif
	
	if(strlen(contactResistancePlotName) > 31)
		contactResistancePlotName = contactResistancePlotName[0,31]
	endif
	
	if(strlen(conductancePlotName) > 31)
		conductancePlotName = conductancePlotName[0,31]
	endif
	
	// Save the analysis data in a notebook
	if( dPlot )
		String sCommandString = "FitConductivity(\""+sSampleID+"\","+num2str(dTemperature)+","+nameOfWave(wVoltageWaveRefs)+","+nameOfWave(wCurrent1)+","+nameOfWave(wProbePosition)+","+num2str(dWidth)+","+num2str(dThickness)+","+","+"\""+sDistanceUnit+"\")"
		String nb
		sprintf nb, "%.31s", "FitG_"+initialFolderName+"_"+NameOfWave(wCurrent1)
		DoWindow/K $nb
		NewNotebook/K=3 /N=$nb /F=1 /W=(5,44,646,639) as nb
		Notebook $nb defaultTab=36, statusWidth=529, magnification=175
		Notebook $nb showRuler=1, rulerUnits=1, updating={3, 60}
		Notebook $nb newRuler=Normal, justification=0, margins={0,0,468}, spacing={0,0,0}, tabs={}, rulerDefaults={"Arial",10,0,(0,0,0)}
		Notebook $nb ruler=Normal;
		Notebook $nb tabs={72}
		NotebookAction/W=$nb name=Evaluate, title="Evaluate", commands="SetDataFolder "+initialFolderPath+";"+sCommandString
		Notebook $nb text="\r"
		Notebook $nb text="Sample:\t"+sSampleID
		Notebook $nb text="\r"
		Notebook $nb text="Temperature:\t"+num2str(dTemperature)
		Notebook $nb text="\r"
		Notebook $nb text="Conductivity 1:\t"+sConductivity1+" (ohm "+sDistanceUnit+")", fSize=7, vOffset=-6, text="-1", fSize=10, vOffset=0, text="± "+sConductivity1SD+" std. dev."
		Notebook $nb text="\r"
		Notebook $nb text="Conductivity 2:\t"+sConductivity2+" (ohm "+sDistanceUnit+")", fSize=7, vOffset=-6, text="-1", fSize=10, vOffset=0, text="± "+sConductivity2SD+" std. dev."
		Notebook $nb text="\r"
		Notebook $nb text="Conductance:\t"+sConductance+" (ohm)", fSize=7, vOffset=-6, text="-1", fSize=10, vOffset=0, text="± "+sConductanceSD+" std. dev."
		//Notebook $nb text="\r"
		//Notebook $nb text="Carrier Conc.:\t"+sCarrierConcentration+" ("+sDistanceUnit+")", fSize=7, vOffset=-6, text="-3", fSize=10, vOffset=0
		Notebook $nb text="\r"
		Notebook $nb text="Contact R:\t"+sRcLeft+"\r\t"+sRcRight
		Notebook $nb text="\r"
		Notebook $nb picture={$voltagePlotName(0,0,360,216), -2, 1}
		Notebook $nb picture={$conductancePlotName(0,0,360,216), -2, 1}
		Notebook $nb picture={$contactResistancePlotName(0,0,360,216), -2, 1}	
		Notebook $nb picture={$voltageProfilePlotName(0,0,360,216), -2, 1}	
	endif
	
	// Restore current data folder		
	SetDataFolder saveDFR					
	
End Function



Function GetConductance( wVG, wID, dVD, dVG_min, dVG_max, dVG_step, index, plot)
	
	Wave wVG, wID
	Variable dVD, dVG_min, dVG_max, dVG_step, index, plot
	
	// Check for empty input waves
	if( !numpnts(wVG) | !numpnts(wID) )
	 print "GetCurrent() empty input wave"
	 return 0
	endif
	
	String initialFolderName = GetDataFolder(0)
	String initialFolderPath = GetDataFolder(1)
	
	// Get reference to current data folder
	DFREF saveDFR = GetDataFolderDFR()
	
	// Create working directory for this analysis
	NewDataFolder/O/S GetConductanceData
	
	// Create data destination waves if they don't exist
	Wave/Z wConductance = $"wConductance"
	if( !WaveExists(wConductance) )
		Make/N=(1,abs(dVG_max-dVG_min)/abs(dVG_step)+1) wConductance
	else
		if( index >= dimsize(wConductance,0) )
			if( index == 0 )
				InsertPoints/M=0 dimsize(wConductance,0), 1, wConductance
				InsertPoints/M=1 dimsize(wConductance,1), abs(dVG_max-dVG_min)/abs(dVG_step), wConductance
			else
				InsertPoints/M=0 dimsize(wConductance,0), 1, wConductance
			endif
		endif
	endif
	
	// Get the current from wID for measurements with channel bias dVD
	// at gate voltages dVG_min to dVG_max by dVG_step
	// Output wave wConductance looks like:
	// 	GA1 GA2 GA3...
	// 	GB1 GB2 GB3...
	// 	...
	// where each row contains the conductance values for VG values from min to max at VD for one index
	// each column contains the conductance at a certain gate bias at VD for all indices
	Variable i = 0, gateBias = dVG_min, current = 0
	for( i = 0; i < ((dVG_max - dVG_min)/dVG_step+1); i += 1 )
		// Find the point where wVG == gateBias
		current = Interp(gateBias,wVG,wID)
		wConductance[index][i] = current/dVD
		gateBias += dVG_step
	endfor
	
	SetDataFolder saveDFR
End
		