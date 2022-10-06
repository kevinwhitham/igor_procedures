#pragma rtGlobals=1		// Use modern global access method.

Function MakeTraceColorsUnique()

	// Get number of traces in the top graph
	Variable numTraces = ItemsInList(TraceNameList("",";",1))

	if (numTraces <= 0)
		return -1
	endif

	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)
		index = mod(i, 10)				// Wrap after 10 traces.
		switch(index)
			case 0:
				red = 0; green = 0; blue = 0;
				break

			case 1:
				red = 65535; green = 16385; blue = 16385;
				break
				
			case 2:
				red = 2; green = 39321; blue = 1;
				break
				
			case 3:
				red = 0; green = 0; blue = 65535;
				break
				
			case 4:
				red = 39321; green = 1; blue = 31457;
				break
				
			case 5:
				red = 48059; green = 48059; blue = 48059;
				break
				
			case 6:
				red = 65535; green = 32768; blue = 32768;
				break
				
			case 7:
				red = 0; green = 65535; blue = 0;
				break
				
			case 8:
				red = 16385; green = 65535; blue = 65535;
				break
				
			case 9:
				red = 65535; green = 32768; blue = 58981;
				break
		endswitch
		ModifyGraph rgb[i]=(red, green, blue)
	endfor
End

Function MakeTraceColorsSequential(numTraces)
	Variable numTraces

	if (numTraces <= 0)
		return -1
	endif
	
	Make/O/N=(3,11) Blues_d
	
	//Blues_d[][0] = {0.20258362365703958, 0.25425605834699144, 0.2912879685794606}
 	Blues_d[][0] = {0.20516724731407915, 0.30851211669398293, 0.38257593715892124}
	Blues_d[][1] = {0.20787390066907296, 0.36535179686702157, 0.47821095186121326}
	Blues_d[][2] = {0.21045752432611253, 0.419607855214013, 0.56949892044067385}
	Blues_d[][3] = {0.2130411479831521, 0.47386391356100444, 0.66078688902013449}
	Blues_d[][4] = {0.21747534201036089, 0.53052930169635348, 0.75482251877878226}
	Blues_d[][5] = {0.29261567390042975, 0.57746509446038141, 0.77893631972518618}
	Blues_d[][6] = {0.3677560057904985, 0.62440088722440934, 0.80305012067159021}
	Blues_d[][7] = {0.44647444872295156, 0.67357171773910518, 0.82831219785353716}
	Blues_d[][8] = {0.52161478061302036, 0.72050751050313311, 0.85242599879994108}
	Blues_d[][9] = {0.59675511250308921, 0.76744330326716104, 0.87653979974634511}
	
	Blues_d *= 2^16
	MatrixOp/O Blues_d = Blues_d^t
	
	Make/O/N=(3,11) BuGn_d
	
	//BuGn_d[][0] = {0.20258362365703958, 0.27191080710467169, 0.23272587565814748}
	BuGn_d[][0] = {0.20516724731407915, 0.34382161420934343, 0.26545175131629495}
	BuGn_d[][1] = {0.20787390066907296, 0.41915674546185666, 0.29973600200578276}
	BuGn_d[][2] = {0.21045752432611253, 0.49106755256652829, 0.33246187766393026}
	BuGn_d[][3] = {0.2130411479831521, 0.56297835967119991, 0.36518775332207776}
	BuGn_d[][4] = {0.21745483707758334, 0.63752917705797685, 0.4003690948673323}
	BuGn_d[][5] = {0.29173396179099487, 0.67649880180171895, 0.47077278646768306}
	BuGn_d[][6] = {0.36601308650440639, 0.71546842654546106, 0.54117647806803382}
	BuGn_d[][7] = {0.44382931239464707, 0.75629374770557178, 0.61493272641125851}
	BuGn_d[][8] = {0.51810843710805854, 0.79526337244931389, 0.68533641801160927}
	BuGn_d[][9] = {0.59238756182147012, 0.83423299719305599, 0.75574010961196003}
	
	BuGn_d *= 2^16
	MatrixOp/O BuGn_d = BuGn_d^t
	 
 	Wave color_palette = BuGn_d

	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)
		index = mod(i, dimsize(color_palette,0))				// Wrap
		
		red	= color_palette[index][0]
		green	= color_palette[index][1]
		blue	= color_palette[index][2]
		
		ModifyGraph rgb[i]=(red, green, blue)
	endfor
End


// group:	number of consecutive traces to group together
//				with the same color
Function MakeGroupColorsUnique(group)
	Variable group
	
	// Get number of traces in the top graph
	Variable numTraces = ItemsInList(TraceNameList("",";",1))

	if (numTraces <= 0)
		return -1
	endif

	Variable red, green, blue
	Variable i, index, j
	for(i=0; i<numTraces/group; i+=1)
		index = mod(i, 10)				// Wrap after 10 colors
		switch(index)
			case 0:
				red = 0; green = 0; blue = 0;
				break

			case 1:
				red = 65535; green = 16385; blue = 16385;
				break
				
			case 2:
				red = 2; green = 39321; blue = 1;
				break
				
			case 3:
				red = 0; green = 0; blue = 65535;
				break
				
			case 4:
				red = 39321; green = 1; blue = 31457;
				break
				
			case 5:
				red = 48059; green = 48059; blue = 48059;
				break
				
			case 6:
				red = 65535; green = 32768; blue = 32768;
				break
				
			case 7:
				red = 0; green = 65535; blue = 0;
				break
				
			case 8:
				red = 16385; green = 65535; blue = 65535;
				break
				
			case 9:
				red = 65535; green = 32768; blue = 58981;
				break
		endswitch
		
		for(j=0;j<group;j+=1)
			ModifyGraph rgb[i*group+j]=(red, green, blue)
		endfor
	endfor
End

Function ReverseTraceOrder()
	Variable traceIndex = 0, totalTraces = ItemsInList(TraceNameList("",";",5))
	
	for(traceIndex=0;traceIndex<(totalTraces-1);traceIndex+=1)
		ReorderTraces $(StringFromList(traceIndex,TraceNameList("",";",5))), {$(StringFromList(totalTraces-1,TraceNameList("",";",5)))}
	endfor
End

// Make the top graph a quarter-column sized plot
Function QCP()
	ModifyGraph width=53,height=73,fSize=9
	ModifyGraph margin(left)=43,margin(bottom)=36,margin(top)=0,margin(right)=36
	DoUpdate
	ModifyGraph width=0, height=0	// allow user resize
	ModifyGraph lsize=0.5
	ModifyGraph notation(left)=1	// scientific notation
	ModifyGraph axThick=0.5
	ModifyGraph tick=2,btLen=2,btThick=0.5,stLen=1,stThick=0.25,ftLen=1,ftThick=0.25
	ModifyGraph ttLen=1,ttThick=0.25
	ChangeAnnotationFontSize(9)
End

Function QCPAll()
	RunOnAllGraphs("QCP()")
End

// Make the top graph a single column sized plot
Function SCP()
	ModifyGraph width=144,height=144,fSize=9
	ModifyGraph margin(left)=43,margin(bottom)=36,margin(top)=0,margin(right)=36
	DoUpdate
	ModifyGraph width=0, height=0	// allow user resize
	ModifyGraph lsize=0.5
	ModifyGraph notation(left)=1	// scientific notation
	//ModifyGraph lowTrip(left)=1		// show just 1 decimal place
	ModifyGraph axThick=0.5
	ChangeAnnotationFontSize(9)
End

Function SCPAll()
	RunOnAllGraphs("SCP()")
End

// Resize and format the top graph for power point
Function PPP()
	ModifyGraph width=157,height=178,fSize=18
	ModifyGraph margin(left)=72,margin(bottom)=58,margin(top)=18,margin(right)=18
	DoUpdate
	ModifyGraph width=0, height=0	// allow user resize
	ModifyGraph lsize=3
	ModifyGraph notation(left)=1	// scientific notation
	ModifyGraph lowTrip(left)=1		// show just 1 decimal place
	ChangeAnnotationFontSize(12)
End

Function PPPAll()
	RunOnAllGraphs("PPP()")
End

Function RunOnAllGraphs(callString)
	String callString
	
	// Get a list of all graph windows
	String list = WinList("*", ";", "WIN:1")
	Variable graphNum = 0, hidden = 0
	
	for(graphNum=0;graphNum<ItemsInList(list);graphNum+=1)
		// Bring window to front
		DoWindow/HIDE=? $(StringFromList(graphNum,list))
		hidden = V_flag	// 1 is visible, 2 is hidden, 0 is does not exist
		DoWindow/F $(StringFromList(graphNum,list))
		Execute callString
		DoWindow/B $(StringFromList(graphNum,list))
		DoWindow/HIDE=(hidden-1) $(StringFromList(graphNum,list))
	endfor
	DoUpdate
End
	
Function/S DoLoadMultipleFiles()
	Variable refNum
	String message = "Select one or more files"
	String outputPaths
	String fileFilters = "Data Files (*.txt,*.dat,*.csv):.txt,.dat,.csv;"
	fileFilters += "All Files:.*;"
 
	Open /D /R /MULT=1 /F=fileFilters /M=message refNum
	outputPaths = S_fileName
 
	return outputPaths		// Will be empty if user canceled
End

Function ChangeAnnotationFontSize(newFontSize)
	Variable newFontSize
	
	// Change annotation font size
	String annotations = AnnotationList("")
	String info = "", contents = "", newFontSizeStr = "", oldFontSizeStr = ""
	Variable textItem = 0, oldFontSize
	
	sprintf newFontSizeStr,"%02d",newFontSize
	
	for(textItem=0;textItem<ItemsInList(annotations);textItem+=1)
		oldFontSize = 0
		info = AnnotationInfo("",StringFromList(textItem,annotations),1)
		contents = StringByKey("TEXT",info)
		sscanf (contents), "\\Z%d", oldFontSize
		sprintf oldFontSizeStr, "%02d", oldFontSize
		
		if( oldFontSize == 0 )
			// Add a font size
			contents = "\\Z"+newFontSizeStr+contents
		else
			
			// change the value to the new font size
			contents = ReplaceString("\\Z"+oldFontSizeStr,contents,"\\Z"+newFontSizeStr+"\\[1")
			
			// Add a font size directive after any \M directives not already followed by a \Z
			if( GrepString(contents,"\\\\M([^\\\\Z]|$)") )
				contents = ReplaceString("\\M",contents,"\\M\\Z"+newFontSizeStr)
			endif
			
		endif
		
		ReplaceText/N=$StringFromList(textItem,annotations) contents
	endfor
	
End

Function ChangeAnnotationFont(newFontName)
	String newFontName
	
	// Change annotation font size
	String annotations = AnnotationList("")
	String info = "", contents = "", oldFontName = ""
	Variable textItem = 0
	
	for(textItem=0;textItem<ItemsInList(annotations);textItem+=1)
		info = AnnotationInfo("",StringFromList(textItem,annotations),1)
		contents = StringByKey("TEXT",info)
		sscanf (contents), "\\F'%[^']'", oldFontName
		
		if( strlen(oldFontName) == 0 )
			// Add a font name
			contents = "\\F'"+newFontName+"'"+contents
		else
			// change the value to the new font name
			contents = ReplaceString("\\F'"+oldFontName+"'",contents,"\\F'"+newFontName+"'")	
		endif
		
		ReplaceText/N=$StringFromList(textItem,annotations) contents
	endfor
	
End



Function NormalizeWaves(normalizeAt)
	Variable normalizeAt
	Variable inMin, inMax, i=0
	String itemName
	WAVE inWave
	
	print "This only works if the wave has X dimension set\r"
	
	itemName=GetBrowserSelection(i)
	if (strlen(itemName)>0)

		do
			itemName=GetBrowserSelection(i)
			if(strlen(itemName)<=0)
				break
			endif
			
			String sOutWaveName
			sOutWaveName = itemName[0,25]+"_Norm"
			Printf "%s\r", sOutWaveName
			
			Duplicate/O $itemName, $sOutWaveName
			
			Wave inWave = $itemName
			Wave outWave = $sOutWaveName
			
			inMin = WaveMin(inWave)
			MatrixOp/O  outWave = inWave - inMin
			
			if(normalizeAt==0)
				inMax = WaveMax(outWave)
			else
				inMax = outWave(normalizeAt)
			endif
			
			MatrixOp/O outWave = outWave / inMax

			i+=1
		
		while(1)
	
	else  //this is if there are no selected items in the browser
		Print "Select wave(s) to normalize in the data browser"
	endif

End Function

Function ScaleWaves()
	Variable i=0
	String itemName
	WAVE inWave
	
	itemName=GetBrowserSelection(i)
	if (strlen(itemName)>0)

		do
			itemName=GetBrowserSelection(i)
			if(strlen(itemName)<=0)
				break
			endif
			
			String sOutWaveName
			sOutWaveName = itemName[0,25]+"_Norm"
			
			Duplicate/O $itemName, $sOutWaveName
			
			Wave inWave = $itemName
			Wave outWave = $sOutWaveName
			
			MatrixOp/O  outWave = scale(inWave,0,1)

			i+=1
		
		while(1)
	
	else  //this is if there are no selected items in the browser
		Print "Select wave(s) to scale in the data browser"
	endif

End Function

// Acts on data from EPS
// Runs FitConductivity on VD/ID/IS waves from selected sample name folders in the data browser
// device width/length/thickness set to 1 to give conductivity=conductance
// if there are multiple tests in a folder, it uses the last in the list
Function PlotVDID()
	Variable i=0, sampleNum, channelLen, j=0
	String itemName, sampleName, dataPath, vdWaveName, idWaveName, isWaveName, graphName
	Variable dataSets, temperature
	DFREF sampleDF,dataDF
	WAVE/Z wConductivity1 = root:FitConductivityData:wConductivity1
	
	itemName=GetBrowserSelection(i)
	if (strlen(itemName)>0)

		do
			itemName=GetBrowserSelection(i)
			if(strlen(itemName)<=0)
				break
			endif

			sampleDF = $itemName
			sampleName = ParseFilePath(3,itemName,":",0,0)
			dataPath = itemName+":VDID:"
			SetDataFolder dataPath
			WAVE/Z wTestTemperature = $(dataPath+"wTestTemperature")
			dataSets = ItemsInList(WaveList("wVD*",";",""))
			
			graphName="VDID_"+sampleName
			
			for(i=0;i<dataSets;i+=1)
				vdWaveName = StringFromList(i,WaveList("wVD*",";",""))
				idWaveName = StringFromList(i,WaveList("wID*",";",""))
				isWaveName = StringFromList(i,WaveList("wIS*",";",""))
				temperature = wTestTemperature[i]
				
				WAVE idWave = $(dataPath+idWaveName)
				WAVE vdWave = $(dataPath+vdWaveName)
				if( numpnts(vdWave) )
					WaveStats/Q $(vdWaveName)
					Make/O/N=(V_npnts) wVS = 0
					FET#FitConductivity(sampleName,temperature, 2, {wVS,$(dataPath+vdWaveName)}, $(dataPath+idWaveName), $(dataPath+isWaveName), {0,1}, 1,1,"cm",0,0,0, i)
					if(i == 0 )
						Display/N=$(graphName) idWave/TN=$(num2str(temperature)) vs vdWave 
					else
						AppendToGraph idWave/TN=$(num2str(temperature)) vs vdWave 
					endif
				endif
			endfor		
		while(1)
	
	else  //this is if there are no selected items in the browser
		Print "Select wave(s) in the data browser"
	endif

End Function

// Removes all traces from the top graph except
// the trace number "first" and every "period"
// e.g. first = 1, period = 2 then every odd
// number trace is kept, every even is removed
Function KeepTraces(first,period)
	Variable first, period
	
	String traceNames = TraceNameList("",";",1)
	Variable totalTraces = ItemsInList(traceNames)
	Variable trace = 0
	
	for(trace=0; trace < totalTraces; trace+=1)
		if( mod(trace-first,period) != 0 | trace < first)
			RemoveFromGraph $StringFromList(trace,traceNames)
		endif
	endfor
End

Function MakeAllTracesRGB(windowName,r,g,b)
	String windowName
	Variable r,g,b
	
	String traceNames = TraceNameList(windowName,";",1)
	Variable totalTraces = ItemsInList(traceNames)
	Variable trace = 0
	
	for(trace=0; trace < totalTraces; trace+=1)
		ModifyGraph/W=$windowName rgb($StringFromList(trace,traceNames))=(r,g,b)
	endfor
End

// Takes a pair of waves for Y and X datapoints
// Computes the highest, lowest, and average Y value for all points
// within +/- xRange of each X point
// For example if the dataset is a number of measurement at different temperatures
// approximately every 5 degrees, set xRange to be +/- 2 degrees to average values
// within 2 degrees 
//
//	Assumes the data waves are in the current directory
//
// sDataWaveName - string name of wave containing Y values
// sXWaveName - string name of wave containing X values
// xRange - number specifying window in which to group datapoints

Function ComputeStats(sDataWaveName, sXWaveName, xRange)
	String sDataWaveName, sXWaveName
	Variable xRange
	WAVE dataWave = $sDataWaveName
	WAVE xWave = $sXWaveName
	Variable index = 0, dataTotal = 0, samples = 0, minXValue = xWave[0], maxXValue = xWave[0], minData = dataWave[0], maxData = dataWave[0], xTotal = 0
	Make/O/N=0 $(sDataWaveName+"_avg"), $(sDataWaveName+"_min"), $(sDataWaveName+"_max"), $(sXWaveName+"_avg"), $(sXWaveName+"_min"), $(sXWaveName+"_max")
	Wave wAverage = $(sDataWaveName+"_avg")
	Wave wMin = $(sDataWaveName+"_min")
	Wave wMax = $(sDataWaveName+"_max")
	Wave wXAvg = $(sXWaveName+"_avg")
	Wave wXMin = $(sXWaveName+"_min")
	Wave wXMax = $(sXWaveName+"_max")
	
	for(index=0; index < numpnts(dataWave); index+=1)
	
		if( numtype(xWave[index]) == 0 & numtype(dataWave[index]) == 0 )
	
			if( (xWave[index] <= (minXValue + xRange)) & (xWave[index] >= (maxXValue - xRange)) )
					dataTotal += dataWave[index]
					xTotal += xWave[index]
					samples += 1
					
					if( dataWave[index] < minData )
						minData = dataWave[index]
					endif
					
					if( dataWave[index] > maxData )
						maxData = dataWave[index]
					endif
					
					if( xWave[index] > maxXValue )
						maxXValue = xWave[index]
					endif
					
					if( xWave[index] < minXValue )
						minXValue = xWave[index]
					endif
					
			else
				InsertPoints numpnts(wAverage), 1, wAverage, wMin, wMax, wXAvg, wXMin, wXMax
				wAverage[numpnts(wAverage)-1] = dataTotal/samples
				wMin[numpnts(wMin)-1] = dataTotal/samples - minData
				wMax[numpnts(wMax)-1] = maxData - dataTotal/samples
				wXAvg[numpnts(wXAvg)-1] = xTotal/samples
				wXMin[numpnts(wXMin)-1] = xTotal/samples - minXValue
				wXMax[numpnts(wXMax)-1] = maxXValue - xTotal/samples
				
				dataTotal = dataWave[index]
				xTotal = xWave[index]
				samples = 1
				minData = dataWave[index]
				maxData = dataWave[index]
				minXValue = xWave[index]
				maxXValue = xWave[index]
				
			endif
		endif
	endfor
End

Function BlackBackground()
	ModifyGraph alblRGB=(65535,65535,65535), axRGB=(65535,65535,65535), gbRGB=(0,0,0), tickRGB=(65535,65535,65535), tlblRGB=(65535,65535,65535), wbRGB=(65535,65535,65535)
End

Function WhiteBackground()
	ModifyGraph alblRGB=(0,0,0), axRGB=(0,0,0), gbRGB=(65535,65535,65535), tickRGB=(0,0,0), tlblRGB=(0,0,0), wbRGB=(65535,65535,65535)
End