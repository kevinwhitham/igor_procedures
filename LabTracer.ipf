#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// LabTracer.ipf
// Routines for importing data from the Keithley LabTracer data acquisition program
// 20140602 KW
//		First version. Routines for importing VD-ID data at 5 VG values
// 20140628 KW
//		Moved menu out of Macros
// 20140707 KW
//		Added Import_LabTracer_VGID() and generalized helper functions
// 20140801 KW
//		Added analysis to VDID data
// 20140801 KW
//		Added \u to vertical axis label
//	20140813 KW
//		Added carrier concentration analysis
//		Added ConvertEPSData()
// 20150114 KW
//		Before killing a graph window, get it's location to move the replacement to the same place
// 20150119 KW
//		When overwriting a measurement, kill all graphs and data folders with old data

// TODO:
//	put plots in layout instead of plot windows
//	change legend label to update parameter info dynamically

static constant defaultChanWidth = 0.3
static constant defaultChanLen = 100e-4
static constant defaultThickness = 25e-7
static constant defaultCox = 1e-8
static constant defaultBias = 5

Menu "HELIOS"
	Submenu "FET"
		"Import VDID", Import_LabTracer_VDID()
		"Import VGID", Import_LabTracer_VGID()
		"Import Time", Import_LabTracer_Time()
		"Analyze VDID", Run_Analysis("VDID")
		"Analyze VGID", Run_Analysis("VGID")
		"Analyze Threshold", Run_Analysis("VT")
		"Analyze Time", Run_Analysis("Time")
		"Analyze Conductance", Run_Analysis("Conductance")
		"Analyze Carriers", Run_Analysis("Carriers")
		"Analyze Hopping Mobility", Run_Analysis("HoppingMobility")
		"Analyze Hopping Conductivity", Run_Analysis("HoppingConductivity")
		"Plot VDID", Plot_Curves("VDID")
		"Plot VGID", Plot_Curves("VGID")
		"Plot VGIG", Plot_Curves("VGIG")
		"Plot Time", Plot_Curves("Time")
	End
End

// Run_Analysis()
//	Determines what data folders are available to analyze
//		calls the desired analysis function
// 20140819 KW
//		Fixed population of popup menu list
Function Run_Analysis(type)
	String type	// "VDID", "VGID", "Carriers", "Time"
	DFREF  initialDF = GetDataFolderDFR()
	Variable carriers = 0
	
	// Get a list of measurement folders
	DFREF typeFolder = $"root:"+type
	
	if( cmpstr(type,"Carriers") == 0 )
		typeFolder = root:VGID
		carriers = 1
	elseif( cmpstr(type,"HoppingMobility") == 0 )
		typeFolder = root:VGID
	elseif( cmpstr(type,"HoppingConductivity") == 0 )
		typeFolder = root:VDID
	elseif( cmpstr(type,"Conductance") == 0 )
		typeFolder = root:VGID
	elseif( cmpstr(type,"VT") == 0 )
		typeFolder = root:VGID
	endif
	
	if( DataFolderRefStatus(typeFolder) == 0 )
		print "No folder. Import data first."
		return 0
	endif
	
	SetDataFolder typeFolder
	
	// Create a list of measurement folders
	String measurementFolderList = GetIndexedObjNameDFR(typeFolder,4,0)
	Variable measurementIndex, measurementFolderCount = CountObjectsDFR(typeFolder,4)
	for(measurementIndex=1;measurementIndex < measurementFolderCount;measurementIndex+=1)
		measurementFolderList = AddListItem(GetIndexedObjNameDFR(typeFolder,4,measurementIndex),measurementFolderList,";",ItemsInList(measurementFolderList))
	endfor
	
	Variable measurementChoice
	Prompt measurementChoice, "Measurement?", popup, measurementFolderList
	DoPrompt "Measurement?", measurementChoice
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
		
	measurementChoice -= 1
	
	DFREF	measurementFolder = $(":"+GetIndexedObjNameDFR(typeFolder,4,measurementChoice))
	SetDataFolder measurementFolder
	SVAR	graphNameList = graphNameList
	
	// Get indices of first and last data sets to analyze
	Variable firstDataSet = 0
	Variable lastDataSet = CountObjectsDFR($(":Data"),1)-1
	
	if( lastDataSet > 0 )
		Prompt firstDataSet,"First data set index? 0.."+num2str(lastDataSet)
		Prompt lastDataSet, "Last data set index? 0.."+num2str(lastDataSet)
		DoPrompt "Indices", firstDataSet, lastDataSet
		
		if( V_flag == 1 )
			// Cancelled
			print "Cancel analyze data"
			return 0
		endif
	endif
		
	if( cmpstr(type,"Carriers") == 0 )
		Analyze_Carriers(measurementFolder, firstDataSet, lastDataSet)
	elseif( cmpstr(type,"VDID") == 0 )
		Analyze_VDID(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type,"VGID") == 0 )
		Analyze_VGID(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type,"Time") == 0 )
		Analyze_Time(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type, "HoppingMobility") == 0 )
		Analyze_HoppingMobility(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type, "HoppingConductivity") == 0 )
		Analyze_HoppingConductivity(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type, "Conductance") == 0 )
		Analyze_Conductance(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	elseif( cmpstr(type, "VT") == 0 )
		Analyze_VT(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	endif
	
	SetDataFolder initialDF
End

// Plot_Curves()
//	Determines what data folders are available to plot
//		calls the desired plot function
// 20140819 KW
//		created
Function Plot_Curves(type)
	String type	// "VDID", "VGID", "Time", "VGIG"
	DFREF  initialDF = GetDataFolderDFR()
	Variable carriers = 0, leakage_plot = 0
	
	if( cmpstr(type,"VGIG") == 0 )
		type="VGID"
		leakage_plot = 1
	endif
	
	if( cmpstr(type,"Carriers") == 0 )
		type = "VGID"
		carriers = 1
	endif
	
	// Get a list of measurement folders
	DFREF typeFolder = $"root:"+type
	
	if( DataFolderRefStatus(typeFolder) == 0 )
		print "No folder. Import data first."
		return 0
	endif
	
	SetDataFolder typeFolder
	
	// Create a list of measurement folders
	String measurementFolderList = GetIndexedObjNameDFR(typeFolder,4,0)
	Variable measurementIndex, measurementFolderCount = CountObjectsDFR(typeFolder,4)
	for(measurementIndex=1;measurementIndex < measurementFolderCount;measurementIndex+=1)
		measurementFolderList = AddListItem(GetIndexedObjNameDFR(typeFolder,4,measurementIndex),measurementFolderList,";",ItemsInList(measurementFolderList))
	endfor
	
	Variable measurementChoice
	Prompt measurementChoice, "Measurement?", popup, measurementFolderList
	DoPrompt "Measurement?", measurementChoice
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
		
	measurementChoice -= 1
	
	DFREF	measurementFolder = $(":"+GetIndexedObjNameDFR(typeFolder,4,measurementChoice))
	SetDataFolder measurementFolder

	// Get indices of first and last data sets to plot
	Variable firstDataSet = 0
	Variable lastDataSet = CountObjectsDFR($(":Data"),1)-1
	Prompt firstDataSet,"First data set index? 0.."+num2str(lastDataSet)
	Prompt lastDataSet, "Last data set index? 0.."+num2str(lastDataSet)
	DoPrompt "Indices", firstDataSet, lastDataSet
	
	if( V_flag == 1 )
		// Cancelled
		print "Cancel plot data"
		return 0
	endif
	
	if( carriers )
		//
	elseif( leakage_plot )
		PlotData(measurementFolder,"X:VG_;XLabel:V\\BG\\M (V);Y:IG_;YLabel:I\\BG\\M (A);P0:VD_;P0Label:V\\BD\\M",firstDataSet,lastDataSet)
	elseif( cmpstr(type,"VDID") == 0 )
		PlotData(measurementFolder,"X:VD_;XLabel:V\\BD\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",firstDataSet,lastDataSet)
	elseif( cmpstr(type,"VGID") == 0 )
		PlotData(measurementFolder,"X:VG_;XLabel:V\\BG\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VD_;P0Label:V\\BD\\M",firstDataSet,lastDataSet)
	elseif( cmpstr(type,"Time") == 0 )
		PlotData(measurementFolder,"X:Ch_;XLabel:Time (S);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",firstDataSet,lastDataSet)
	endif
	
	SetDataFolder initialDF
End

Function Import_LabTracer_VDID()
	DFREF  initialDF = GetDataFolderDFR()
	DFREF measurementFolder = GetData("VDID")
	String/G graphNameList
	
	if( DataFolderRefStatus(measurementFolder) != 0 )
		PauseForParams()
		graphNameList = PlotData(measurementFolder,"X:VD_;XLabel:V\\BD\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",-1,-1)
		
		// Get indices of first and last data sets to analyze
		DFREF dataFolder = measurementFolder:Data
		Variable firstDataSet = 0
		Variable lastDataSet = CountObjectsDFR(dataFolder,1)-1
		Analyze_VDID(measurementFolder,graphNameList, firstDataSet, lastDataSet)
		
	endif
	
	SetDataFolder initialDF
End

Function Analyze_VDID(measurementFolder, graphNameList, firstIndex, lastIndex)
	DFREF measurementFolder
	String graphNameList
	Variable firstIndex, lastIndex
	
	if( strlen(graphNameList) == 0 )
		print "no graph names"
		return 0
	endif
	
	// Calculate conductance
	Variable chanWidth = defaultChanWidth, chanLen = defaultChanLen, temperature = 300, thickness = defaultThickness, vgBias=0, rangeMin, rangeMax
	Prompt chanWidth,"Channel width (cm):"
	Prompt chanLen,"Channel length (cm):"
	Prompt thickness,"Thickness (cm):"
	Prompt rangeMin,"Range min (V):"
	Prompt rangeMax,"Range max (V):"
	Prompt vgBias, "Vg bias (V):"
	DoPrompt "FitConductivity params",chanWidth, chanLen, thickness, vgBias, rangeMin, rangeMax
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
	
	String analysisCall = "FET#FitConductivity(measurementName,"+num2str(temperature)+",2,{$\"\",X},Y,Y,{0,"+num2str(chanLen)+"},"+num2str(chanWidth)+","+num2str(thickness)+",\"cm\","+num2str(rangeMin)+","+num2str(rangeMax)+",0,index)"
	AnalyzeData(measurementFolder,firstIndex,lastIndex,analysisCall,"X:VD_;Y:ID_")
	
	// Plot analysis data
	WAVE conductivityData = $":Data:FitConductivityData:wConductivity1"
	String vgString
	DFREF dataFolder = $(":Data")
	String captionString = "\\F'Symbol's\\F'Arial'(VG="+num2str(round(vgBias))+") = "
	String yAxisLabel = "\F'Symbol's\F'Arial' (\F'Symbol'W\F'Arial' cm)\S-1\M \u"
	
	WAVE	mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,firstIndex))
	Variable vg_value, set, numTraces, trace, delta
	
	// Make a wave to store the trace in each set to plot on the analysis graph
	Make/FREE/N=(lastIndex-firstIndex+1) traceInSet
	
	for(set=firstIndex; set <= lastIndex; set+= 1)
		
		WaveClear mData
		WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,set))
		numTraces = dimsize(mData,1)/5	// Assume VG, IG, VD, ID, Time

		for(trace=0; trace < numTraces; trace+=1 )
			vg_value = mData[1][%$("VG_"+num2str(trace+1))]
			
			// Look for the trace with VD value closest to the given bias to analyze
			if( trace == 0 )
				delta = abs(vgBias-vg_value)
				traceInSet[set-firstIndex] = trace
			elseif( abs(vgBias-vg_value) < delta )
				delta = abs(vgBias-vg_value)
				traceInSet[set-firstIndex] = trace
			endif
		endfor
	endfor
	
	PlotAnalysisData(measurementFolder, conductivityData, traceInSet, graphNameList, captionString, yAxisLabel, firstIndex, lastIndex)
End

Function Import_LabTracer_Time()
	DFREF  initialDF = GetDataFolderDFR()
	DFREF measurementFolder = GetData("Time")
	String/G graphNameList
	
	if( DataFolderRefStatus(measurementFolder) != 0 )
		PauseForParams()
		graphNameList = PlotData(measurementFolder,"X:Ch_;XLabel:Time (s);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",-1,-1)
		
		// Get indices of first and last data sets to analyze
		DFREF dataFolder = measurementFolder:Data
		Variable firstDataSet = 0
		Variable lastDataSet = CountObjectsDFR(dataFolder,1)-1
		Analyze_Time(measurementFolder,graphNameList, firstDataSet, lastDataSet)
		
	endif
	
	SetDataFolder initialDF
End

Function Analyze_Time(measurementFolder, graphNameList, firstIndex, lastIndex)
	DFREF measurementFolder
	String graphNameList
	Variable firstIndex, lastIndex
	
	if( strlen(graphNameList) == 0 )
		print "no graph names"
		return 0
	endif
	
	// Calculate conductance
	Variable chanWidth = defaultChanWidth, chanLen = defaultChanLen, temperature = 300, thickness = defaultThickness, rangeMin, rangeMax
	Prompt chanWidth,"Channel width (cm):"
	Prompt chanLen,"Channel length (cm):"
	Prompt thickness,"Thickness (cm):"
	DoPrompt "Transient current params",chanWidth, chanLen, thickness
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
	
	String analysisCall = "FET#Fit_Transient_Current(X,Y,\"s\",index)"
	AnalyzeData(measurementFolder, firstIndex, lastIndex, analysisCall,"X:Ch_;Y:ID_")
	
	// Plot analysis data
	WAVE timeConstantData = $":Data:FitTransient:wTimeConstant"
	String vgString, vdString
	DFREF dataFolder = $(":Data")
	WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,0))
	Variable numTraces = dimsize(mData,1)/5	// Assume VG, IG, VD, ID, Time
	Make/FREE/N=(lastIndex-firstIndex+1) traceInSet = 0	// set to 2 for the third trace of 5, or 0 for the only trace of 1
	sprintf vgString, "%g", round(mData[1][%$("VG_"+num2str(1))])
	sprintf vdString, "%g", round(mData[1][%$("VD_"+num2str(1))])
	String captionString = "\\F'Symbol't\\F'Arial'(VG="+vgString+",VD="+vdString+") = "
	String yAxisLabel = "\\F'Symbol't\\F'Arial' (s) \u"
	
	PlotAnalysisData(measurementFolder, timeConstantData, traceInSet, graphNameList, captionString, yAxisLabel, firstIndex, lastIndex)
End

Function Analyze_Carriers(measurementFolder, firstIndex, lastIndex)
	DFREF measurementFolder
	Variable firstIndex, lastIndex
	
	// Get conductivity and mobility values	
	String measurementName = GetDataFolder(0,measurementFolder)
	WAVE conductivityData	= $("root:VDID:"+measurementName+":wConductivity1_dataY")
	WAVE mobilityData 		= $("root:VGID:"+measurementName+":wMobilitySummary_dataY")
	WAVE dataX 				= $("root:VGID:"+measurementName+":wMobilitySummary_dataX")
	
	NewDataFolder/S root:Carriers
	NewDataFolder/S $measurementName
	
	// Calculate carrier concentration
	if( numpnts(conductivityData) == numpnts(mobilityData) )
		Make/N=(numpnts(mobilityData)) carrierConcentration = conductivityData/(1.6e-19*mobilityData)
	else
		print "Number of conductivity values and mobility values are different"
		return 0
	endif
	
	// Plot carrier concentration
	String graphName = measurementName+"_Carriers"
	GetWindow/Z $graphName wsize
	Variable move_error = V_flag
	DoWindow/K $graphName
	Display/N=$graphName carrierConcentration vs dataX
	if( move_error == 0 )
		MoveWindow/W=$graphName V_left,V_top,V_right,V_bottom	// from GetWindow
	endif
	ModifyGraph mode=3,marker=16,msize=0
	Label left "Carriers (cm\S-3\M) \u"
	PPP()
End

// 20140802 KW
//		Added textbox with calculated mobility to plots
//	20140811 KW
//		Plot against elapsed time if there are no param waves
// 20140819 KW
//		Fixed saving of graphNameList to global, not local	

Function Import_LabTracer_VGID()
	DFREF  initialDF = GetDataFolderDFR()
	DFREF measurementFolder = GetData("VGID")
	String/G graphNameList
	
	if( DataFolderRefStatus(measurementFolder) != 0 )
		PauseForParams()
		graphNameList = PlotData(measurementFolder,"X:VG_;XLabel:V\\BG\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VD_;P0Label:V\\BD\\M",-1,-1)
		
		// Get indices of first and last data sets to analyze
		DFREF dataFolder = measurementFolder:Data
		Variable firstDataSet = 0
		Variable lastDataSet = CountObjectsDFR(dataFolder,1)-1
		Analyze_VGID(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	endif
	
	SetDataFolder initialDF
End

Function Analyze_VGID(measurementFolder, graphNameList, firstIndex, lastIndex)
	DFREF measurementFolder
	String graphNameList
	Variable firstIndex, lastIndex
	
	if( strlen(graphNameList) == 0 )
		print "no graph names"
		return 0
	endif
	
	// Parameters to calculate mobility
	Variable chanWidth = defaultChanWidth, chanLen = defaultChanLen, cox = defaultCox, chanBias = defaultBias, xMin, xMax
	String carrierType
	Prompt chanWidth,"Channel width (cm):"
	Prompt chanLen,"Channel length (cm):"
	Prompt cox,"Cox (F/cm\S2):"
	Prompt chanBias,"Bias (V):"
	Prompt xMin,"Window min (V):"
	Prompt xMax,"Window max (V):"
	Prompt carrierType, "Carrier?", popup, "electrons;holes"
	DoPrompt "FitMobility params",chanWidth, chanLen, cox, chanBias, xMin, xMax, carrierType
	
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
	
	if( cmpstr(carrierType,"electrons") == 0 )
		carrierType = "e"
	else
		carrierType = "h"
	endif
	
	String analysisCall = "FET#FitMobility(X,Y,"+num2str(chanWidth)+","+num2str(chanLen)+","+num2str(cox)+","+num2str(chanBias)+","+num2Str(xMin)+","+num2str(xMax)+",index,0)"
	
	// Remove previous analysis data
	WAVE/Z mobilityData = $":Data:FitMobility:wMobilitySummary"
	if( WaveExists(mobilityData) )
		DeletePoints 0, numpnts(mobilityData), mobilityData
	endif
	
	AnalyzeData(measurementFolder, firstIndex, lastIndex, analysisCall,"X:VG_;Y:ID_")
	
	// Plot the results of the analysis
	WAVE mobilityData = $":Data:FitMobility:wMobilitySummary"
	String vgString
	DFREF dataFolder = $(":Data")
	WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,0))
	Variable numTraces, trace, delta, vd_value, set
	
	// Make a wave to store the trace in each set to plot on the analysis graph
	Make/FREE/N=(lastIndex-firstIndex+1) traceInSet
	
	for(set=firstIndex; set <= lastIndex; set+= 1)
		
		WaveClear mData
		WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,set))
		numTraces = dimsize(mData,1)/5	// Assume VG, IG, VD, ID, Time

		for(trace=0; trace < numTraces; trace+=1 )
			vd_value = mData[1][%$("VD_"+num2str(trace+1))]
			
			// Look for the trace with VD value closest to the given chanBias to analyze
			if( trace == 0 )
				delta = abs(chanBias-vd_value)
				traceInSet[set-firstIndex] = trace
			elseif( abs(chanBias-vd_value) < delta )
				delta = abs(chanBias-vd_value)
				traceInSet[set-firstIndex] = trace
			endif
		endfor
	endfor
	
	
	String captionString = "V\BD\M="+num2str(chanBias)+", \\F'Symbol'm\\F'Arial'"+carrierType+" = "
	String yAxisLabel = "\F'Symbol'm\\F'Arial' V\BD\M="+num2str(chanBias)+" (V) (cm\\S2\\M/Vs) \u"
	PlotAnalysisData(measurementFolder, mobilityData, traceInSet, graphNameList, captionString, yAxisLabel, firstIndex, lastIndex)
End

Function Analyze_VT(measurementFolder, graphNameList, firstIndex, lastIndex)
	DFREF measurementFolder
	String graphNameList
	Variable firstIndex, lastIndex
	
	if( strlen(graphNameList) == 0 )
		print "no graph names"
		return 0
	endif
	
	// Parameters to calculate mobility
	Variable chanWidth = defaultChanWidth, chanLen = defaultChanLen, cox = defaultCox, chanBias = defaultBias, xMin, xMax
	String carrierType
	Prompt chanWidth,"Channel width (cm):"
	Prompt chanLen,"Channel length (cm):"
	Prompt cox,"Cox (F/cm\S2):"
	Prompt chanBias,"Bias (V):"
	Prompt xMin,"Window min (V):"
	Prompt xMax,"Window max (V):"
	Prompt carrierType, "Carrier?", popup, "electrons;holes"
	DoPrompt "FitMobility params",chanWidth, chanLen, cox, chanBias, xMin, xMax, carrierType
	
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
	
	if( cmpstr(carrierType,"electrons") == 0 )
		carrierType = "e"
	else
		carrierType = "h"
	endif
	
	String analysisCall = "FET#FitMobility(X,Y,"+num2str(chanWidth)+","+num2str(chanLen)+","+num2str(cox)+","+num2str(chanBias)+","+num2Str(xMin)+","+num2str(xMax)+",index,0)"
	
	// Remove previous analysis data
	WAVE/Z mobilityData = $":Data:FitMobility:wMobilitySummary"
	if( WaveExists(mobilityData) )
		DeletePoints 0, numpnts(mobilityData), mobilityData
	endif
	
	AnalyzeData(measurementFolder, firstIndex, lastIndex, analysisCall,"X:VG_;Y:ID_")
	
	// Plot the results of the analysis
	WAVE vtData = $":Data:FitMobility:wThresholdVoltageSummary"
	String vgString
	DFREF dataFolder = $(":Data")
	WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,0))
	Variable numTraces, trace, delta, vd_value, set
	
	// Make a wave to store the trace in each set to plot on the analysis graph
	Make/FREE/N=(lastIndex-firstIndex+1) traceInSet
	
	for(set=firstIndex; set <= lastIndex; set+= 1)
		
		WaveClear mData
		WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,set))
		numTraces = dimsize(mData,1)/5	// Assume VG, IG, VD, ID, Time

		for(trace=0; trace < numTraces; trace+=1 )
			vd_value = mData[1][%$("VD_"+num2str(trace+1))]
			
			// Look for the trace with VD value closest to the given chanBias to analyze
			if( trace == 0 )
				delta = abs(chanBias-vd_value)
				traceInSet[set-firstIndex] = trace
			elseif( abs(chanBias-vd_value) < delta )
				delta = abs(chanBias-vd_value)
				traceInSet[set-firstIndex] = trace
			endif
		endfor
	endfor
	
	
	String captionString = "V\BD\M="+num2str(chanBias)+", \\F'Symbol'm\\F'Arial'"+carrierType+" = "
	String yAxisLabel = "V\BT\M V\BD\M="+num2str(chanBias)+" (V) \u"
	PlotAnalysisData(measurementFolder, vtData, traceInSet, graphNameList, captionString, yAxisLabel, firstIndex, lastIndex)
End

Function Analyze_Conductance(measurementFolder, graphNameList, firstIndex, lastIndex)
	DFREF measurementFolder
	String graphNameList
	Variable firstIndex, lastIndex
	
	if( strlen(graphNameList) == 0 )
		print "no graph names"
		return 0
	endif
	
	// Parameters to calculate conductance
	Variable chanWidth = defaultChanWidth, chanLen = defaultChanLen, xMin, xMax, xStep
	String carrierType, sChanBias
	Prompt sChanBias,"Drain Bias (V):", popup, "1;5;10"
	Prompt xMin,"Gate Bias min (V):"
	Prompt xMax,"Gate Bias max (V):"
	Prompt xStep, "Gate Bias step (V):"
	Prompt carrierType, "Carrier?", popup, "electrons;holes"
	DoPrompt "Current params", sChanBias, xMin, xMax, xStep, carrierType
	
	if( V_flag == 1 )
		// Cancel
		print "Cancelled analysis"
		return 0
	endif
	
	if( cmpstr(carrierType,"electrons") == 0 )
		carrierType = "e"
	else
		carrierType = "h"
	endif
	
	
	
	String analysisCall = "FET#GetConductance(X,Y,"+sChanBias+","+num2Str(xMin)+","+num2str(xMax)+","+num2str(xStep)+",index,0)"
	
	// Remove previous analysis data
	WAVE/Z conductanceData = $":Data:GetConductanceData:wConductance"
	if( WaveExists(conductanceData) )
		DeletePoints/M=0 0, dimsize(conductanceData,0), conductanceData
	endif
	
	AnalyzeData(measurementFolder, firstIndex, lastIndex, analysisCall,"X:VG_;Y:ID_")
	
	
	// Plot the results of the analysis
	Variable i=0, maskPoint
	String sMaskPointsList = "", sampleName
	
	sampleName = GetDataFolder(0,measurementFolder)

	Prompt sMaskPointsList, "Mask points \"a,b,...\""
	DoPrompt "Select data points", sMaskPointsList
	
	WAVE conductanceData = $":Data:GetConductanceData:wConductance"
	
	// Make a wave to hold just one of the 3 sets of data for VD = 1, 5, or 10 V
	Make/O/N=(dimsize(conductanceData,0)/3,dimsize(conductanceData,1)) $(sampleName+"_G")
	WAVE wG = $(sampleName+"_G")
	Duplicate/O wG, $(sampleName+"_lnG")
	Wave wlnG = $(sampleName+"_lnG")
	
	Variable startIndex
	if( str2num(sChanBias) == 1 )
		startIndex = 0
	elseif( str2num(sChanBias) == 5 )
		startIndex = 1
	else
		startIndex = 2
	endif
	
	wG = conductanceData[startIndex+p*3][q]
	wlnG = ln(wG)
	
	Make/O/N=(dimsize(conductanceData,0)/3) $("wConductance_dataX")
	Wave temperature = $("wConductance_dataX")
	Wave tempFromMobility = $("wMobilitySummary_dataX")
	temperature = tempFromMobility[firstIndex+p]
	
	// mask off bad data
	for(i = 0;i < ItemsInList(sMaskPointsList,",");i+=1)
		maskPoint = str2num(StringFromList(i,sMaskPointsList,","))
		wG[maskPoint][] = nan
		wlnG[maskPoint][] = nan
		temperature[maskPoint] = nan
	endfor
	
	Duplicate/O temperature, mott3DInvT, mott2DInvT, esInvT, invT, invTwoThirdsT, lnInvT, lnT
	mott3DInvT = temperature^(-1/4)
	mott2DInvT = temperature^(-1/3)
	esInvT = temperature^(-1/2)
	invTwoThirdsT = temperature^(-2/3)
	invT = 1/temperature
	lnInvT = ln(invT)
	lnT = ln(temperature)
	
	Variable trace = 0
	String traceName
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wG[][trace]/TN=$traceName vs temperature
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "T (K)"
	Label left "G (\F'Symbol'W \F'Arial'cm\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wlnG[][trace]/TN=$(traceName) vs invT
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "T\S-1\M (K\S-1\M)"
	Label left "ln(G (\F'Symbol'W \F'Arial'cm)\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wlnG[][trace]/TN=$(traceName) vs mott2DInvT
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "T\S-1/3\M (K\S-1/3\M)"
	Label left "ln(G (\F'Symbol'W \F'Arial'cm)\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wlnG[][trace]/TN=$(traceName) vs lnInvT
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "ln(T\S-1\M (K\S-1\M))"
	Label left "ln(G (\F'Symbol'W \F'Arial'cm)\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wlnG[][trace]/TN=$(traceName) vs esInvT
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "T\S-1/2\M (K\S-1/2\M)"
	Label left "ln(G (\F'Symbol'W \F'Arial'cm)\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	Display
	for(trace = 0; trace < dimsize(wG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		AppendToGraph wlnG[][trace]/TN=$(traceName) vs invTwoThirdsT
		ModifyGraph mode($traceName)=3, marker($traceName)=1
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "T\S-2/3\M (K\S-2/3\M)"
	Label left "ln(G (\F'Symbol'W \F'Arial'cm)\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
	// Try to calculate the power ln(W) = -p ln(T) + const.
	// W = (1/T) d[ln(G)]/d[ln(1/T)]
	// Efros, Shklovskii. Electronic Prop. of Doped Semic. 1984, p. 241
	Make/FREE/O/N=(dimsize(wlnG,0)) wDimensionelss_Ea, wTemp_lnG
	Make/O/N=(dimsize(wlnG,0),dimsize(wlnG,1)) wlnW
	
	Display as sampleName+"_lnW"
	for(trace = 0; trace < dimsize(wlnG,1);trace+=1)
		traceName = num2str(xMin+trace*xStep)
		
		wTemp_lnG = wlnG[p][trace]
		Differentiate wTemp_lnG /X=invT /D=wDimensionelss_Ea
		wDimensionelss_Ea = invT * wDimensionelss_Ea
		wlnW[][trace] = ln(abs(wDimensionelss_Ea[p]))
		
		AppendToGraph wlnW[][trace]/TN=$(traceName) vs lnT
		ModifyGraph mode($traceName)=0
	endfor
	
	Legend/C/N=text0/F=2/B=0/A=RC/E=2/X=0/Y=0
	ModifyGraph axisEnab(bottom)={0,0.8}
	MakeGroupColorsUnique(1)
	Label bottom "ln(T (K))"
	Label left "ln(T\S-1\M dln(G)/dT\S-1\M)"
	PPP()
	ChangeAnnotationFontSize(9)
	
End

// PlotAnalysisData()
// Adds data from the analysis to graphs and creates graphs of the analysis data
// 	measurementFolder	DFREF of the folder that contains the "Data" folder
//		wAnalysisData 		WAVE reference to the results of the analysis
// 	traceInSet				WAVE of offsets to the desired analysis value within each set of data (from each file)
// 	graphNameList			a list of the names of the graphs to modify
// 	captionString			a string to prefix the analysis value on each graph
// 	yAxisLabel				a string to use for the vertical axis label of the analysis data
// 	firstIndex				index of the first data set to plot
// 	lastIndex				index of the lst data set to plot
// 20140811	KW
//		created
// 20150107 KW
//		added firstIndex, lastIndex
// 20150118 KW
//		changed indexing from number of objects in data folder to numpnts in wAnalysisData
Function PlotAnalysisData(measurementFolder, wAnalysisData, traceInSet, graphNameList, captionString, yAxisLabel, firstIndex, lastIndex)
	DFREF measurementFolder
	WAVE wAnalysisData
	WAVE traceInSet
	String graphNameList, captionString, yAxisLabel
	Variable firstIndex, lastIndex
	
	String xAxisLabel = " "

	DFREF dataFolder = $":Data"
	String dataName, xDataStr = "0"
	Variable set = 0, numTraces, dataSets, traceNum, setPtr = 0
	WAVE/WAVE paramWaveRefs = paramWaveRefs
	
	if( firstIndex < 0 )
		firstIndex = 0
	endif
	
	if( lastIndex < 0 )
		lastIndex = CountObjectsDFR(dataFolder,1)-1
	endif
			
	dataSets = lastIndex-firstIndex+1
	Make/O/N=(dataSets) $(NameOfWave(wAnalysisData)+"_dataY"), $(NameOfWave(wAnalysisData)+"_dataX")
	Wave dataX = $(NameOfWave(wAnalysisData)+"_dataX")
	Wave dataY = $(NameOfWave(wAnalysisData)+"_dataY")
	
	WAVE/T xData = paramWaveRefs[0]	// Assume one param (i.e. time, concentration, etc.)
	if( WaveExists(xData) )
		dataX = str2num(xData[p+firstIndex])
	else
		WAVE/Z elapsedTimeWave = $(GetDataFolder(0,measurementFolder)+"_elapsedTimeStamp")
		if( WaveExists(elapsedTimeWave) )
			dataX = elapsedTimeWave[p+firstIndex]
			xAxisLabel = "Time (s) \u"
		endif
	endif
	
	WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,firstIndex))
	
	String dataString, traceNames
	
	for(set=firstIndex;set<=lastIndex;set+=1)
		WaveClear mData
		WAVE mData = $(":Data:"+GetIndexedObjNameDFR(dataFolder,1,set))
		numTraces = dimsize(mData,1)/5	// Assume VG, IG, VD, ID, Time
		
		traceNum = setPtr+traceInSet[set-firstIndex]
		
		dataY[set-firstIndex] = wAnalysisData[traceNum]
		
		
		dataName = StringFromList(mod(set-firstIndex,ItemsInList(graphNameList)),graphNameList)
		traceNames = TraceNameList(dataName,";",1)
		
		// Only add textboxes if there are 1 or 2 traces on the data graph
		if( ItemsInList(traceNames) < 3 )
			sprintf dataString, "%.3e", dataY[set-firstIndex]
			TextBox/W=$dataName/C/N=$("text"+num2str(set-firstIndex))/F=0/A=MC/Y=(-10*(set-firstIndex)) captionString+dataString
		endif
		
		setPtr += numTraces
				
	endfor
	
	// get the name of the parent folder of the testFolder
	// this will be "VGID", "VDID", etc.
	String fullPath = GetDataFolder(1,measurementFolder)
	String dataType = StringFromList(ItemsInList(fullPath,":")-2,fullPath,":")
	String graphName = dataType+"_"+GetDataFolder(0,measurementFolder)+"_"+NameOfWave(wAnalysisData)
	
	if( strlen(graphName) > 30 )
		sprintf graphName, "%.30s", graphName
	endif 
	
	// Save window location
	GetWindow/Z $graphName wsize
	Variable move_error = V_flag
	DoWindow/K $graphName
	Display/N=$graphName dataY vs dataX
	if( move_error == 0 )
		MoveWindow/W=$graphName V_left,V_top,V_right,V_bottom	// from GetWindow
	endif
	ModifyGraph mode=3,marker=16,msize=0
	Label left yAxisLabel
	Label bottom xAxisLabel
	TextBox/W=$graphName /N=p0 /C/F=0/A=MC captionString
	PPP()
		
End

// GetData()
// Handles loading of data from files
// Returns a reference to the folder created with the name of the measurement (e.g. sample name)
// 20140707 KW
//		Added return after prompt cancel
// 	Added dataFolderName to generalize
// 20140811 KW
//	Added time stamp and elapsed time as parameter option
// 	Added append data option
// 20140814 KW
//		Modified setting of elapsed times to be relative to minimum time, not to the first file imported
// 20140819 KW
//		When using file creation time, sort the file names, paths, and time stamp waves by the file creation times
//		before importing data. Imported data waves are then sorted by file creation time.
// 20140820 KW
//		When appending data using file creation time, reimport all files after sorting file time stamps so that
//		the order of data waves matches the order of file time stamps

Function/DF GetData(dataFolderName)
	String	dataFolderName
	String packagePath = "root:"+dataFolderName
	DFREF packageFolder = $packagePath
	
	// Create a list of measurement folders
	String measurementFolderList = ""
	if( DataFolderRefStatus(packageFolder) > 0 )
		Variable measurementIndex, measurementFolderCount = CountObjectsDFR(packageFolder,4)
		
		if( measurementFolderCount > 0 )
			for(measurementIndex=0;measurementIndex < measurementFolderCount;measurementIndex+=1)
				measurementFolderList = AddListItem(GetIndexedObjNameDFR(packageFolder,4,measurementIndex),measurementFolderList,";",ItemsInList(measurementFolderList))
			endfor
		endif
	endif
	
	String	paramNames
	String	measurementName = ""
	Variable measurementChoice = -1
	Prompt	measurementChoice, "Measurement?", popup, measurementFolderList
	Prompt	measurementName, "New measurement:"
	Prompt	paramNames,"List parameter names:"
	DoPrompt "Enter Measurement Info",measurementChoice,measurementName,paramNames

	if( V_flag != 0 )
		print "User cancelled"
		return DFREF
	endif
	
	if( cmpstr(measurementName,"") == 0 )
		if( measurementChoice > -1 )
			measurementName = StringFromList(measurementChoice-1,measurementFolderList)
		endif
	endif
	
	Variable folder,measurementFolders = CountObjectsDFR(packageFolder,4)
	for(folder=0;folder<measurementFolders;folder+=1)
		if( cmpstr(measurementName,GetIndexedObjNameDFR(packageFolder,4,folder)) == 0 )
			String optionsList = "Append;Overwrite;Cancel;"
			Variable appendData = 0
			Prompt appendData, "Append?", popup, optionsList
			DoPrompt "Data already exists", appendData
			if( appendData == 1 )
				// append
				appendData = 1
			elseif( appendData == 2 )
				// overwrite
				appendData = 0
			else
				print "User cancelled"
				return DFREF
			endif
		endif
	endfor
	
	String fileList = DoLoadMultipleFiles()
	
	// Save current directory for return
	DFREF workingDF = GetDataFolderDFR()
	
	if (strlen(fileList) == 0)
		Print "Cancelled"
		return DFREF
	endif
	
	// Make a folder to hold the data
	if( appendData )
		SetDataFolder $packagePath
		SetDataFolder $measurementName
	else
		NewDataFolder/O/S $packagePath
		NewDataFolder/O/S $measurementName
	endif
	
	// How many files to import?
	Variable numFilesSelected = ItemsInList(fileList, "\r")
	
	// Store parameters and filenames
	Variable startIndex = 0
	if( appendData )
		WAVE/T fileNamesWave = $(measurementName+"_files")
		WAVE/T filePathsWave = $(measurementName+"_paths")
		startIndex = numpnts(fileNamesWave)
		InsertPoints numpnts(fileNamesWave), numFilesSelected, fileNamesWave, filePathsWave
	else
		Make/T/O/N=(numFilesSelected) $(measurementName+"_files"), $(measurementName+"_paths")
		WAVE/T fileNamesWave = $(measurementName+"_files")
		WAVE/T filePathsWave = $(measurementName+"_paths")
	endif
	
	
	// Ask if the user wants to import the file creation date
	optionsList = "Yes;No;"
	Variable useFileCreationTime = 0
	Prompt useFileCreationTime, "Import file creation time?", popup, optionsList
	DoPrompt "Extra Parameters",useFileCreationTime
	useFileCreationTime = mod(useFileCreationTime,2)		// change from 1,2 to 1,0
	
	// Create a wave of wave references to each wave holding the parameter values
	Variable paramNum = 0
	String paramWaveName = ""
	if( appendData )
		WAVE/WAVE paramWaveRefs
		
		// Add points to existing param waves
		for(paramNum=0;paramNum<numpnts(paramWaveRefs);paramNum+=1)
			WAVE/T paramWave = paramWaveRefs[paramNum]
			InsertPoints numpnts(paramWave), numFilesSelected, paramWave
		endfor
		
		// Create any new param waves
		for(paramNum=0;paramNum < ItemsInList(paramNames,",");paramNum+=1)
			// Create a wave to hold this new parameter data
			// with length of the old plus the new files
			Make/T/O/N=(numpnts(fileNamesWave)) $(measurementName+"_"+StringFromList(paramNum,paramNames,","))
			WAVE paramWaveRef = $(measurementName+"_"+StringFromList(paramNum,paramNames,","))
			InsertPoints numpnts(paramWaveRefs), 1, paramWaveRefs
			paramWaveRefs[paramNum] = paramWaveRef
		endfor
				
		if( useFileCreationTime )			
			WAVE/Z wFileTimeStamp = $(measurementName+"_fileTimeStamp")
			WAVE/Z wElapsedTimeStamp = $(measurementName+"_elapsedTimeStamp")

			if( WaveExists(wFileTimeStamp) && WaveExists(wElapsedTimeStamp) )
				InsertPoints numpnts(wFileTimeStamp), numFilesSelected, wFileTimeStamp
				InsertPoints numpnts(wElapsedTimeStamp), numFilesSelected, wElapsedTimeStamp
			else
				print "No file time stamps for existing data, not importing file time stamps for new data"
			endif
		endif
		
		SetDataFolder Data
	else
		Make/O/WAVE/N=(ItemsInList(paramNames,",")) paramWaveRefs
		for(paramNum = 0;paramNum < ItemsInList(paramNames,",");paramNum+=1)
			Make/T/O/N=(numFilesSelected) $(measurementName+"_"+StringFromList(paramNum,paramNames,","))
			WAVE paramWaveRef = $(measurementName+"_"+StringFromList(paramNum,paramNames,","))
			paramWaveRefs[paramNum] = paramWaveRef
		endfor
		
		if( useFileCreationTime )
			Make/D/O/N=(numFilesSelected) $(measurementName+"_fileTimeStamp")
			Make/D/O/N=(numFilesSelected) $(measurementName+"_elapsedTimeStamp")
			WAVE wFileTimeStamp = $(measurementName+"_fileTimeStamp")
			WAVE wElapsedTimeStamp = $(measurementName+"_elapsedTimeStamp")
		endif
		
		//kill any graphs showing data from this data folder
		String windowNameList = WinList(dataFolderName+"_"+measurementName+"*",";","")
		Variable win = 0
		for(win=0;win<ItemsInList(windowNameList);win+=1)
			DoWindow/K $(StringFromList(win,windowNameList,";"))
		endfor
		
		DFREF dataRef = Data
		if( DataFolderRefStatus(dataRef) != 0 )
			KillDataFolder Data		// will give error if data is being used
		endif
		NewDataFolder/O/S Data
	endif
	
	
	Variable i = 0
	String path, fileName
	
	// Populate the file time stamp wave with the creation time of each file
	// Populate the fileNamesWave
	if( useFileCreationTime )
		for(i=startIndex; i<numpnts(fileNamesWave); i+=1)
			path = StringFromList(i-startIndex, fileList, "\r")
			fileName = StringFromList(ItemsInList(path,":")-1, path, ":")
			filePathsWave[i] = path
			fileNamesWave[i] = fileName
			
			GetFileFolderInfo/Q path
			wFileTimeStamp[i] = V_creationDate
		endfor
		
		// Sort the file time stamp wave and file names wave by the file creation time
		Sort wFileTimeStamp, wFileTimeStamp, fileNamesWave, filePathsWave
		
		// Reimport all files to match the sorted file time stamps
		startIndex = 0
	endif
	
	
	for(i=startIndex; i<numpnts(fileNamesWave); i+=1)
	
		if( useFileCreationTime )
			path = filePathsWave[i]
			fileName = fileNamesWave[i]
		else
			path = StringFromList(i-startIndex, fileList, "\r")
			fileName = StringFromList(ItemsInList(path,":")-1, path, ":")
			fileNamesWave[i] = fileName
		endif
		
		// Load data from general text file
		// as a matrix, using column labels
		String currentMatrixName = (measurementName+"_"+num2str(i))
		
		// Load a delimeted file as a matrix with column labels and skip blanks at the bottom
		LoadWave/O/D/J/M/Q/L={1,2,0,0,0}/U={0,0,1,0}/B=("C=1,N="+currentMatrixName+";")/V={"\t","",0,1} path

		WAVE mData = $(currentMatrixName)
		
		Variable col = 0
		String s1, s2, dummyString, colName
		for(col=0;col < dimsize(mData,1);col+=1)
			colName = GetDimLabel(mData,1,col)
			SplitString/E="(.._)(. \()(.)" colName, s1, dummyString, s2
			colName = s1+s2
			SetDimLabel 1,col,$(colName),mData
		endfor
	endfor
	
	// Set elapsed time relative to the minimum time value
	if( useFileCreationTime )
		WaveStats/Q wFileTimeStamp
		wElapsedTimeStamp = wFileTimeStamp[p] - V_min + 1 // add 1 second for log(time) axes
	endif
	
	SetDataFolder $(packagePath+":"+measurementName)
	
	// Display parameters for entry
	String paramWaveNameList = WaveList(measurementName+"_*",",","TEXT:1")
	SplitString/E="(.*)(,)" paramWaveNameList, paramWaveNameList
	DoWindow/K FileParams
	Execute "Edit/N=FileParams "+paramWaveNameList
	
	DFREF dataFolder = $(packagePath+":"+measurementName)
	return dataFolder
	
End

// PlotData()
// Plots data in the testFolder according to the X and Y data names given in the
//	list string dataNames
// testFolder	-	DFREF pointing to the folder that contains the folder called "Data"
// dataNames	-	list string "X:name;Y:name;P0:name;"
//						X and Y are the ordinate and abcissa data
//						XLabel and YLabel are the labels to go on the plot axes
//						P0 is the name of parameter data used to label or identify each trace e.g. the gate voltage
// 20140710 KW
//		Moved legend up and to the left
// 20140801 KW
//		Moved legend to center top
//		Changed legend font size form 18 to 10
// 20140805 KW
//		Added overlay option
// 20140819 KW
//		Added option to plot a subset of the data waves in the testFolder
// 20140823 KW
//		Only ask about overlay if there is more than one dataset

Function/S PlotData(testFolder,dataNames,firstDataSet,lastDataSet)
	DFREF testFolder
	String dataNames
	Variable firstDataSet, lastDataSet
		
	DFREF workingDirectory = GetDataFolderDFR()
	SetDataFolder GetDataFolder(1,testFolder)+"Data:"
	DFREF dataFolder = GetDataFolderDFR()
	Variable set, pair, dataSets = CountObjectsDFR(dataFolder,1) // Count number of waves in data folder
	String xColName, yColName, graphName, legendLabels, p0ColName
	WAVE/WAVE paramWaveRefs = testFolder:paramWaveRefs
	Variable param = 0, p0_value, numTraces, traceNum
	String paramString, graphBaseName, actualGraphName = "nothing", graphNameList = "none"
	
	if( dataSets == 0 )
		print "No data to plot"
		return graphNameList
	endif
	
	if( ItemsInList(dataNames) < 5 )
		print "Not enough information in dataNames"
		return graphNameList
	endif
	
	String xDataName = "", yDataName = "", p0DataName = "", xLabel = "", yLabel = "", p0Label = ""
	xDataName = StringByKey("X", dataNames)
	yDataName = StringByKey("Y", dataNames)
	p0DataName = StringByKey("P0", dataNames)
	xLabel = StringByKey("XLabel", dataNames)
	yLabel = StringByKey("YLabel", dataNames)
	p0Label = StringByKey("P0Label", dataNames)
	
	if( strlen(xDataName) == 0 )
		print "No X data name"
		return ""
	endif
	
	if( strlen(yDataName) == 0 )
		print "No Y data name"
		return ""
	endif
	
	if( strlen(p0DataName) == 0 )
		print "No P0 data name"
		return ""
	endif
	
	if( strlen(xLabel) == 0 )
		print "no XLabel"
		return ""
	endif
	
	if( strlen(yLabel) == 0 )
		print "no YLabel"
		return ""
	endif
	
	if( strlen(p0Label) == 0 )
		print "no P0Label"
		return ""
	endif
	
	if( firstDataSet < 0 | firstDataSet >= dataSets )
		firstDataSet = 0
	endif
	
	if( lastDataSet < 0 | lastDataSet >= dataSets )
		lastDataSet = dataSets-1
	endif
	
	if( firstDataSet > lastDataSet )
		set = lastDataSet
		lastDataSet = firstDataSet
		firstDataSet = set
	endif
			
	if( (lastDataSet - firstDataSet) > 0 )
		Variable overlay
		String overlayList = "Yes;No;"
		Prompt overlay,"Overlay?", popup, overlayList
		DoPrompt "Plot Settings", overlay
		overlay = mod(overlay,2)
	endif
	
	for(set=firstDataSet;set<=lastDataSet;set+=1)
		WAVE mData = $(GetIndexedObjNameDFR(dataFolder,1,set))
		paramString = " "
		String p0_string = ""
		String paramText
		// only use the first param wave data
		//for(param=0;param<numpnts(paramWaveRefs);param+=1)
		if( WaveExists(paramWaveRefs) )
			if( numpnts(paramWaveRefs) > 0 )
				WAVE/T paramWave = paramWaveRefs[0]
				paramText = paramWave[set]
				paramString += paramText+" "
				WAVEClear paramWave
			endif
		endif
		//endfor
		
		// get the name of the parent folder of the testFolder
		// this will be "VGID", "VDID", etc.
		String fullPath = GetDataFolder(1,testFolder)
		String dataType = StringFromList(ItemsInList(fullPath,":")-2,fullPath,":")
		
		if( overlay )
			graphBaseName = dataType+"_"+GetDataFolder(0,testFolder)
		else
			graphBaseName = dataType+"_"+NameOfWave(mData)
		endif
		graphName = graphBaseName+"_"+yDataName+"vs_"+xDataName
		
		if( cmpstr(graphName,actualGraphName) != 0 )
			GetWindow/Z $graphName wsize
			Variable move_error = V_flag
			DoWindow/K $graphName
			Display/N=$graphName as graphName
			if( move_error == 0 )
				MoveWindow/W=$graphName V_left,V_top,V_right,V_bottom	// from GetWindow
			endif
			actualGraphName = S_name
			
			if( cmpstr(graphNameList,"none") == 0 )
				graphNameList = actualGraphName+";"
			else
				graphNameList = AddListItem(actualGraphName,graphNameList,";",ItemsInList(graphNameList))
			endif
			
			legendLabels = "\\Z10"
		endif
		
		if( !overlay )
			legendLabels += paramString
		endif
		
		numTraces = dimsize(mData,1)/5	// Assumes 5 variables (VG,IG,VD,ID,Time)
		for(pair=0;pair<numTraces;pair+=1)
			traceNum = pair+set*numTraces
			xColName = xDataName+num2str(pair+1)
			yColName = yDataName+num2str(pair+1)
			p0ColName = p0DataName+num2str(pair+1)
			AppendToGraph/W=$actualGraphName mData[][%$yColName]/TN=$("trace_"+num2str(traceNum)) vs mData[][%$xColName]
			
			sscanf num2str(mData[1][%$p0ColName]), "%g", p0_value
			
			// truncate p0_valute to one decimal place
			sprintf p0_string, "%.1f", p0_value

			legendLabels += "\r\\s(trace_"+num2str(traceNum)+")"+p0Label+"="+p0_string+", "+num2str(set)
			if( overlay )
				legendLabels += paramString
			endif
		endfor
		Legend/C/N=livingLegend/J/F=0/A=MT/B=1 legendLabels
		Legend/C/N=livingLegend/J/X=0.00/Y=-11.00
		Label bottom xLabel
		Label left yLabel+" \u"
		MakeTraceColorsUnique()
		PPP()
		DoUpdate/W=$actualGraphName
	endfor
	
	SetDataFolder workingDirectory
	return graphNameList
End

// AnalyzeData()
// Analyze data in the testFolder according to the X and Y data names given in the
//	list string dataNames
// testFolder	-	DFREF pointing to the data folder
//	firstIndex	-	index of first data set to analyze	
//	lastIndex	-	index of last data set to analyze
// analysisCall	-	string "FunctionName(...,X,...,Y,...)"
//							X and Y will be replaced with wave names
// dataNames	-	list string "X:name;Y:name;"
//						X and Y are the ordinate and abcissa data
Function AnalyzeData(testFolder,firstIndex,lastIndex,analysisCall,dataNames)
	DFREF testFolder
	Variable firstIndex, lastIndex
	String analysisCall, dataNames
	
	DFREF workingDirectory = GetDataFolderDFR()
	SetDataFolder GetDataFolder(1,testFolder)+"Data:"
	DFREF dataFolder = GetDataFolderDFR()
	Variable set, pair, dataSets = CountObjectsDFR(dataFolder,1) // Count number of waves in data folder
	String xColName, yColName
	WAVE/WAVE paramWaveRefs = testFolder:paramWaveRefs
	Variable param = 0, p0_value, numTraces
	String paramString, measurementName, modifiedCall
	
	if( ItemsInList(dataNames) < 2 )
		print "Not enough information in dataNames"
		return 0
	endif
	
	String xDataName = "", yDataName = ""
	xDataName = StringByKey("X", dataNames)
	yDataName = StringByKey("Y", dataNames)
	
	if( strlen(xDataName) == 0 )
		print "No X data name"
		return 0
	endif
	
	if( strlen(yDataName) == 0 )
		print "No Y data name"
		return 0
	endif
	
	analysisCall = ReplaceString("X", analysisCall, "analysisXData", 1, 1)
	analysisCall = ReplaceString("Y", analysisCall, "analysisYData", 1)
	
	if( (firstIndex == -1) & (lastIndex == -1) )
		firstIndex = 0
		lastIndex = dataSets-1
	endif
	
	if( firstIndex < 0 | firstIndex >= dataSets )
		print "First index out of range for analysis"
		return 0
	endif
	
	if( lastIndex < 0 | lastIndex >= dataSets )
		print "Last index out of range for analysis"
		return 0
	endif
	
	if( firstIndex > lastIndex )
		set = lastIndex
		lastIndex = firstIndex
		firstIndex = set
		set = 0
	endif
	
	Variable setPtr = 0
		
	for(set=firstIndex;set<=lastIndex;set+=1)
		
		WAVE mData = $(GetIndexedObjNameDFR(dataFolder,1,set))
		Make/O/N=(dimsize(mData,0)) analysisXData, analysisYData
		
		numTraces = dimsize(mData,1)/5	// Assumes 5 variables (VG,IG,VD,ID,Time)
		
		for(pair=0;pair<numTraces;pair+=1)
			xColName = xDataName+num2str(pair+1)
			yColName = yDataName+num2str(pair+1)
			
			analysisXData = mData[p][%$xColName]
			analysisYData = mData[p][%$yColName]
			
			// Get a name for this measurement
			measurementName = NameOfWave(mData)
			modifiedCall = ReplaceString("index",analysisCall,num2str(setPtr+pair),1,1)
			modifiedCall = ReplaceString("measurementName",modifiedCall,"\""+measurementName+"\"",1,1)
			
			// save the result of each calculation if the analysis call has an "index" variable
			Execute modifiedCall
		endfor
		
		setPtr += numTraces
		
	endfor
	
	KillWaves analysisXData, analysisYData
	SetDataFolder GetDataFolder(1,testFolder)
End

Function UserGetInputPanel_ContButton(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/K tmp_GetInputPanel
End

Function DoMyInputPanel()
	NewPanel /W=(500,50,500+200,239)
	DoWindow/C tmp_GetInputPanel			// Set to an unlikely name
	DrawText 33,23,"Enter parameters"
	Button button0,pos={52,120},size={92,20}
	Button button0,proc=UserGetInputPanel_ContButton,title="Continue"

	PauseForUser tmp_GetInputPanel, FileParams
	DoWindow/K FileParams
End

Function PauseForParams()
	DoMyInputPanel()
End

//	ConvertEPSData()
//	Transforms data from the EPS procedures to the format created from LabTracer files
//	Assumes there are certain test folders specified in testTypeList
// 20140812 KW
//		created
// 20141013 KW
//		only create time, temperature waves for VGID or VDID if those tests are chosen
Function ConvertEPSData()
	Variable i=0, testTypeIndex, measurementIndex = 0
	String itemName, sampleName, dataPath, matrixName, vgWaveName, vdWaveName, idWaveName, isWaveName, igWaveName
	Variable dataSets, temperature, dataCopied = 0
	DFREF sampleDF,dataDF
	WAVE/Z wConductivity1 = root:FitConductivityData:wConductivity1
	String testTypeList = "VDID_m40;VDID_m20;VDID_0;VDID_20;VDID_40;VGID_1V;VGID_5V;VGID_10V"
	String testVoltageList = "-40;-20;0;20;40;1;5;10;"
	
	
	// O option does not overwrite, it just omits the error message
	NewDataFolder/O root:VGID
	NewDataFolder/O root:VDID
	
	itemName=GetBrowserSelection(0)
	if (strlen(itemName)>0)

		do
			itemName=GetBrowserSelection(measurementIndex)
			if(strlen(itemName)<=0)
				break
			endif

			sampleDF = $itemName
			sampleName = ParseFilePath(3,itemName,":",0,0)
			
			NewDataFolder/O $"root:VGID:"+sampleName
			NewDataFolder/O $"root:VGID:"+sampleName+":Data"
			NewDataFolder/O $"root:VDID:"+sampleName
			NewDataFolder/O $"root:VDID:"+sampleName+":Data"
						
			// Copy temperature and time as parameter waves
			WAVE/Z wTestTemperature = $(itemName+":"+StringFromList(0,testTypeList)+":wTestTemperature")
			WAVE/Z wTime = $(itemName+":"+StringFromList(0,testTypeList)+":wTime")
			
			
			SetDataFolder sampleDF
			SetDataFolder ":"+StringFromList(0,testTypeList)
			dataSets = ItemsInList(WaveList("wID*",";",""))
			String testName = ""
			
			for(i=0;i<dataSets;i+=1)
				matrixName = sampleName+"_"+num2str(i)
				
				// VGID
				if( stringmatch(testTypeList,"*VGID*") )
					
					if( i == 0 )
						Make/T/N=(numpnts(wTestTemperature)) $("root:VGID:"+sampleName+":"+sampleName+"_temperature") = num2str(wTestTemperature[p])+" K"
						Duplicate wTime, $("root:VGID:"+sampleName+":"+sampleName+"_timeStamp")
						Make/D/N=(numpnts(wTime)) $("root:VGID:"+sampleName+":"+sampleName+"_elapsedTimeStamp") = wTime[p]-wTime[0]
						WAVE/T wVGIDTemp = $("root:VGID:"+sampleName+":"+sampleName+"_temperature")
						WAVE wVGIDTime = $("root:VGID:"+sampleName+":"+sampleName+"_timeStamp")
						WAVE wVGIDElapsed = $("root:VGID:"+sampleName+":"+sampleName+"_elapsedTimeStamp")
						Make/WAVE/N=3 $("root:VGID:"+sampleName+":paramWaveRefs") = {wVGIDTemp,wVGIDTime,wVGIDElapsed}
					endif
					
					// Get a list of "VGID" tests
					String vgidTestList = ListMatch(testTypeList,"*VGID*")
					
					SetDataFolder sampleDF
					SetDataFolder ":"+StringFromList(0,vgidTestList)
					idWaveName = StringFromList(i,WaveList("wID*",";",""))
					WAVE idWave = $idWaveName
					
					// Create a matrix to hold the data from all VDID tests with index i
					// assume there are 5 waves of data from each test (IG,ID,IS,VG,VD)
					Make/N=(numpnts(idWave),5*ItemsInList(vgidTestList)) $("root:VGID:"+sampleName+":Data:"+matrixName)
					WAVE matrix = $("root:VGID:"+sampleName+":Data:"+matrixName)
					dataCopied = 0

					for(testTypeIndex=0;testTypeIndex<ItemsInList(vgidTestList);testTypeIndex+=1)
						SetDataFolder sampleDF
						SetDataFolder ":"+StringFromList(testTypeIndex,vgidTestList)
						
						igWaveName = StringFromList(i,WaveList("wIG*",";",""))
						idWaveName = StringFromList(i,WaveList("wID*",";",""))
						isWaveName = StringFromList(i,WaveList("wIS*",";",""))
						vgWaveName = StringFromList(i,WaveList("wVG*",";",""))
						WAVE igWave = $igWaveName
						WAVE idWave = $idWaveName
						WAVE isWave = $isWaveName
						WAVE vgWave = $vgWaveName
						
						SetDimLabel 1,0+5*testTypeIndex,$"VG_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,1+5*testTypeIndex,$"IG_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,2+5*testTypeIndex,$"VD_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,3+5*testTypeIndex,$"ID_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,4+5*testTypeIndex,$"IS_"+num2str(testTypeIndex+1),matrix
						
						// Check if there is data in all the waves
						if(	numpnts(igWave) & numpnts(idWave) & numpnts(isWave) & numpnts(vgWave) )
						
							dataCopied = 1
							
							matrix[][%$("VG_"+num2str(testTypeIndex+1))] = vgWave[p]
							matrix[][%$("IG_"+num2str(testTypeIndex+1))] = igWave[p]
							matrix[][%$("VD_"+num2str(testTypeIndex+1))] = str2num(StringFromList(WhichListItem(StringFromList(testTypeIndex,vgidTestList),testTypeList),testVoltageList))
							matrix[][%$("ID_"+num2str(testTypeIndex+1))] = idWave[p]
							matrix[][%$("IS_"+num2str(testTypeIndex+1))] = isWave[p]
						else
							matrix[][%$("VG_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("IG_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("VD_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("ID_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("IS_"+num2str(testTypeIndex+1))] = 0
						endif
					endfor
					
					// Check if any data was copied to the matrix
					if( !dataCopied )
						print "No VDID data at index #"+num2str(i)
						KillWaves matrix
					endif
					
				endif
				
				// VDID
				if( stringmatch(testTypeList,"*VDID*") )
				
					if( i == 0 )
						Make/T/N=(numpnts(wTestTemperature)) $("root:VDID:"+sampleName+":"+sampleName+"_temperature") = num2str(wTestTemperature[p])+" K"
						Duplicate wTime, $("root:VDID:"+sampleName+":"+sampleName+"_timeStamp")
						Make/D/N=(numpnts(wTime)) $("root:VDID:"+sampleName+":"+sampleName+"_elapsedTimeStamp") = wTime[p]-wTime[0]					
						WAVE/T wVDIDTemp = $("root:VDID:"+sampleName+":"+sampleName+"_temperature")
						WAVE wVDIDTime = $("root:VDID:"+sampleName+":"+sampleName+"_timeStamp")
						WAVE wVDIDElapsed = $("root:VDID:"+sampleName+":"+sampleName+"_elapsedTimeStamp")
						Make/WAVE/N=3 $("root:VDID:"+sampleName+":paramWaveRefs") = {wVDIDTemp,wVDIDTime,wVDIDElapsed}
					endif
					
					// Get a list of "VDID" tests
					String vdidTestList = ListMatch(testTypeList,"*VDID*")
					
					// Get the number of points in the VDID data waves
					// assume all VDID tests have the same number of points
					SetDataFolder sampleDF
					SetDataFolder ":"+StringFromList(0,vdidTestList)
				
					vdWaveName = StringFromList(i,WaveList("wVD*",";",""))
					WAVE vdWave = $vdWaveName
					
					// Create a matrix to hold the data from all VDID tests with index i
					// assume there are 5 waves of data from each test (VD,ID,IG,IS,VG)
					Make/N=(numpnts(vdWave),5*ItemsInList(vdidTestList)) $("root:VDID:"+sampleName+":Data:"+matrixName)
					WAVE matrix = $("root:VDID:"+sampleName+":Data:"+matrixName)
					dataCopied = 0
					for(testTypeIndex=0;testTypeIndex<ItemsInList(vdidTestList);testTypeIndex+=1)
						SetDataFolder sampleDF
							SetDataFolder ":"+StringFromList(testTypeIndex,vdidTestList)
						
						// VDID
						vdWaveName = StringFromList(i,WaveList("wVD*",";",""))
						idWaveName = StringFromList(i,WaveList("wID*",";",""))
						isWaveName = StringFromList(i,WaveList("wIS*",";",""))
						igWaveName = StringFromList(i,WaveList("wIG*",";",""))
						if( strlen(igWaveName) == 0 )
							igWaveName = StringFromList(i,WaveList("wI1*",";",""))
						endif
						WAVE	vdWave = $vdWaveName
						WAVE idWave = $idWaveName
						WAVE isWave = $isWaveName
						WAVE igWave = $igWaveName
						
						SetDimLabel 1,0+5*testTypeIndex,$"VG_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,1+5*testTypeIndex,$"IG_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,2+5*testTypeIndex,$"VD_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,3+5*testTypeIndex,$"ID_"+num2str(testTypeIndex+1),matrix
						SetDimLabel 1,4+5*testTypeIndex,$"IS_"+num2str(testTypeIndex+1),matrix
						
						// Check if there is data in all the waves before copying to the matrix
						if(	numpnts(vdWave) & numpnts(idWave) & numpnts(isWave) & numpnts(igWave) )
							
							dataCopied = 1
							
								matrix[][%$("VG_"+num2str(testTypeIndex+1))] = str2num(StringFromList(WhichListItem(StringFromList(testTypeIndex,vdidTestList),testTypeList),testVoltageList))
							matrix[][%$("IG_"+num2str(testTypeIndex+1))] = igWave[p]
							matrix[][%$("VD_"+num2str(testTypeIndex+1))] = vdWave[p]
							matrix[][%$("ID_"+num2str(testTypeIndex+1))] = idWave[p]
							matrix[][%$("IS_"+num2str(testTypeIndex+1))] = isWave[p]
						else
							matrix[][%$("VG_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("IG_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("VD_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("ID_"+num2str(testTypeIndex+1))] = 0
							matrix[][%$("IS_"+num2str(testTypeIndex+1))] = 0
								print "No data for test "+StringFromList(testTypeIndex,vdidTestList)+" at index #"+num2str(i)
						endif
					endfor
				
					// Check if any data was copied to the matrix
					if( !dataCopied )
						print "No VDID data at index #"+num2str(i)
						KillWaves matrix
					endif
				endif
			endfor
			
			// make plots because the analyze functions
			// expect a graphName variable
			DFREF measurementFolder = $"root:VDID:"+sampleName
			SetDataFolder measurementFolder
			String/G graphNameList
			graphNameList = PlotData(measurementFolder,"X:VD_;XLabel:V\\BD\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",-1,-1)
			
			measurementFolder = $"root:VGID:"+sampleName
			SetDataFolder measurementFolder
			String/G graphNameList
			graphNameList = PlotData(measurementFolder,"X:VG_;XLabel:V\\BG\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VD_;P0Label:V\\BD\\M",-1,-1)
			
			measurementIndex += 1	
		while(1)

		else
		print "Select the sample folder in the data browser"
	endif
End

Function Analyze_HoppingConductivity(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	DFREF measurementFolder
	String graphNameList
	Variable firstDataSet, lastDataSet
	Variable startIndex, interval, i=0, maskPoint
	String sMaskPointsList = "", sampleName


	Prompt startIndex, "First data set"
	Prompt interval, "Interval"
	Prompt sMaskPointsList, "Mask points \"a,b,...\""
	DoPrompt "Select data points", startIndex, interval, sMaskPointsList
			
	sampleName = GetDataFolder(0,measurementFolder)
	SetDataFolder measurementFolder
	
	DFREF sampleDF,dataDF
	WAVE conductivity = $":Data:FitConductivityData:wConductivity1"
	Make/O/N=((lastDataSet-firstDataSet+1)-floor(startIndex/interval)) $(sampleName+"_lnG")
	WAVE lnG = $(sampleName+"_lnG")
	lnG = ln(conductivity[interval*p+startIndex+interval*firstDataSet])
	
	WAVE temperature = $("wConductivity1_dataX")
	Duplicate/O/R=[firstDataSet,lastDataSet] temperature, mott3DInvT, mott2DInvT, esInvT, invT, invTwoThirdsT, selectedTemperatures
	mott3DInvT = temperature^(-1/4)
	mott2DInvT = temperature^(-1/3)
	esInvT = temperature^(-1/2)
	invTwoThirdsT = temperature^(-2/3)
	invT = 1/temperature
	
	for(i = 0;i < ItemsInList(sMaskPointsList,",");i+=1)
		maskPoint = str2num(StringFromList(i,sMaskPointsList,","))
		lnG[maskPoint] = nan
		selectedTemperatures[maskPoint] = nan
	endfor
	
	
	Duplicate/O lnG, fit_mott3D
	Display lnG vs mott3DInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/4\\M (K\\S-1/4\\M)"
	Label left "ln(\F'Symbol's (W \F'Arial'cm)\S-1\M)"
	CurveFit/M=2/W=0 line, lnG /X=mott3DInvT /D=fit_mott3D
	WAVE W_coef = W_coef
	Variable T0 = (abs(W_coef[1])^4)
	AppendToGraph /C=(0,0,0) fit_mott3D vs mott3DInvT
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)+"\r"
	PPP()

	// Calculate localization radius
	// Efros, A., Shklovskii, B., Electronic Properties of Doped Semiconductors, Springer, 1984
	Variable mobilityStartIndex, mobilityInterval
	Prompt mobilityStartIndex, "Mobility start index?"
	Prompt mobilityInterval, "Mobility index interval?"
	DoPrompt "Mobility indexing", mobilityStartIndex, mobilityInterval
	
	WAVE mobility = $"root:VGID:"+sampleName+":Data:FitMobility:wMobilitySummary"
	Make/O/N=((lastDataSet-firstDataSet+1)-floor(startIndex/interval)) $(sampleName+"_DOS"), $(sampleName+"_localization3D"), $(sampleName+"_localization2D")
	WAVE wDOS = $(sampleName+"_DOS")
	wDOS = conductivity[interval*p+startIndex+interval*firstDataSet]/(1.6e-19*abs(mobility[mobilityInterval*p+mobilityStartIndex+mobilityInterval*firstDataSet]))
	 
	WAVE wLocalizationRadius3D = $(sampleName+"_localization3D")
	wLocalizationRadius3D = (T0*8.617e-5*wDOS[p]/21.2)^(-1/3)
	Display wLocalizationRadius3D vs selectedTemperatures
	PPP()
	
	Duplicate/O lnG, fit_mott2D
	Display lnG vs mott2DInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/3\\M (K\\S-1/3\\M)"
	Label left "ln(\F'Symbol's (W \F'Arial'cm)\S-1\M)"
	CurveFit/M=2/W=0 line, lnG /X=mott2DInvT /D=fit_mott2D
	WaveClear W_coef
	WAVE W_coef = W_coef
	T0 = abs(W_coef[1])^3
	AppendToGraph /C=(0,0,0) fit_mott2D vs mott2DInvT
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	WAVE wLocalizationRadius2D = $(sampleName+"_localization2D")
	wLocalizationRadius2D = (13.8/(T0*8.617e-5*wDOS[p]))^(1/2)
	Display wLocalizationRadius2D vs selectedTemperatures
	PPP()
	
	Duplicate/O lnG, fit_es
	Display lnG vs esInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/2\\M (K\\S-1/2\\M)"
	Label left "ln(\F'Symbol's (W \F'Arial'cm)\S-1\M)"
	CurveFit/M=2/W=0 line, lnG /X=esInvT /D=fit_es
	AppendToGraph /C=(0,0,0) fit_es vs esInvT
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnG, fit_nn
	Display lnG vs invT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1\\M (K\\S-1\\M)"
	Label left "ln(\F'Symbol's (W \F'Arial'cm)\S-1\M)"
	CurveFit/M=2/W=0 line, lnG /X=invT /D=fit_nn
	AppendToGraph /C=(0,0,0) fit_nn vs invT
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnG, fit_twoThirds
	Display lnG vs invTwoThirdsT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-2/3\\M (K\\S-2/3\\M)"
	Label left "ln(\F'Symbol's (W \F'Arial'cm)\S-1\M)"
	CurveFit/M=2/W=0 line, lnG /X=invTwoThirdsT /D=fit_twoThirds
	AppendToGraph /C=(0,0,0) fit_twoThirds vs invTwoThirdsT
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
		
End 

Function Analyze_HoppingMobility(measurementFolder, graphNameList, firstDataSet, lastDataSet)
	DFREF measurementFolder
	String graphNameList
	Variable firstDataSet, lastDataSet
	Variable startIndex, interval, i=0, maskPoint
	String sMaskPointsList = "", sampleName


	Prompt startIndex, "First data set"
	Prompt interval, "Interval"
	Prompt sMaskPointsList, "Mask points \"a,b,...\""
	DoPrompt "Select data points", startIndex, interval, sMaskPointsList
			
	sampleName = GetDataFolder(0,measurementFolder)
	SetDataFolder measurementFolder
	
	WAVE mobility = $":Data:FitMobility:wMobilitySummary"
	Make/O/N=((lastDataSet-firstDataSet+1)-floor(startIndex/interval)) $(sampleName+"_lnMu")
	WAVE lnMu = $(sampleName+"_lnMu")
	lnMu = ln(abs(mobility[interval*p+startIndex+interval*firstDataSet]))
	
	for(i = 0;i < ItemsInList(sMaskPointsList,",");i+=1)
		maskPoint = str2num(StringFromList(i,sMaskPointsList,","))
		lnMu[maskPoint] = nan
	endfor
	
	WAVE temperature = $("wMobilitySummary_dataX")
	Duplicate/O/R=[firstDataSet,lastDataSet] temperature, mott3DInvT, mott2DInvT, esInvT, invT, invTwoThirdsT
	mott3DInvT = temperature^(-1/4)
	mott2DInvT = temperature^(-1/3)
	esInvT = temperature^(-1/2)
	invTwoThirdsT = temperature^(-2/3)
	invT = 1/temperature
	
	
	Duplicate/O lnMu, fit_mott3D
	Display lnMu vs mott3DInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/4\\M (K\\S-1/4\\M)"
	Label left "ln(\F'Symbol'm (\F'Arial'cm\S2\M/Vs)\M)"
	CurveFit/M=2/W=0 line, lnMu[firstDataSet,lastDataSet] /X=mott3DInvT[firstDataSet,lastDataSet] /D=fit_mott3D
	AppendToGraph /C=(0,0,0) fit_mott3D vs mott3DInvT[firstDataSet,lastDataSet]
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnMu, fit_mott2D
	Display lnMu vs mott2DInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/3\\M (K\\S-1/3\\M)"
	Label left "ln(\F'Symbol'm (\F'Arial'cm\S2\M/Vs)\M)"
	CurveFit/M=2/W=0 line, lnMu[firstDataSet,lastDataSet] /X=mott2DInvT[firstDataSet,lastDataSet] /D=fit_mott2D
	AppendToGraph /C=(0,0,0) fit_mott2D vs mott2DInvT[firstDataSet,lastDataSet]
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnMu, fit_es
	Display lnMu vs esInvT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1/2\\M (K\\S-1/2\\M)"
	Label left "ln(\F'Symbol'm (\F'Arial'cm\S2\M/Vs)\M)"
	CurveFit/M=2/W=0 line, lnMu[firstDataSet,lastDataSet] /X=esInvT[firstDataSet,lastDataSet] /D=fit_es
	AppendToGraph /C=(0,0,0) fit_es vs esInvT[firstDataSet,lastDataSet]
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnMu, fit_nn
	Display lnMu vs invT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-1\\M (K\\S-1\\M)"
	Label left "ln(\F'Symbol'm (\F'Arial'cm\S2\M/Vs)\M)"
	CurveFit/M=2/W=0 line, lnMu[firstDataSet,lastDataSet] /X=invT[firstDataSet,lastDataSet] /D=fit_nn
	AppendToGraph /C=(0,0,0) fit_nn vs invT[firstDataSet,lastDataSet]
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
	
	Duplicate/O lnMu, fit_twoThirds
	Display lnMu vs invTwoThirdsT
	ModifyGraph mode=3, marker=1
	Label bottom "T\\S-2/3\\M (K\\S-2/3\\M)"
	Label left "ln(\F'Symbol'm (\F'Arial'cm\S2\M/Vs)\M)"
	CurveFit/M=2/W=0 line, lnMu[firstDataSet,lastDataSet] /X=invTwoThirdsT[firstDataSet,lastDataSet] /D=fit_twoThirds
	AppendToGraph /C=(0,0,0) fit_twoThirds vs invTwoThirdsT[firstDataSet,lastDataSet]
	TextBox/C/N=text0/F=0/A=MC "\F'Symbol'c\F'Arial'\S2\M = "+num2str(V_chisq)
	PPP()
			
End 

Function CombineMeasurements(newName)
	String newName
	Variable dataSets
	String testTypeList = "VGID;VDID;"
	Variable testTypeIndex = 0
	
	for(testTypeIndex=0; testTypeIndex < ItemsInList(testTypeList);testTypeIndex+=1)
		
		DFREF testTypeFolder = root:$(StringFromList(testTypeIndex,testTypeList))	// VGID, VDID
		
		if( DataFolderRefStatus(testTypeFolder) == 0 )
			print "No "+StringFromList(testTypeIndex,testTypeList)+" folder"
			break
		endif
	
		SetDataFolder testTypeFolder
		
		String measurementName, srcWaveName
		Variable waveIndex, initialLength, paramWaveIndex
		
		// Create a list of measurement folders
		String measurementFolderList = GetIndexedObjNameDFR(testTypeFolder,4,0)+";"
		Variable measurementIndex, measurementFolderCount = CountObjectsDFR(testTypeFolder,4)
		Variable sourceDatasets = 0, destDatasets = 0
		for(measurementIndex=1;measurementIndex < measurementFolderCount;measurementIndex+=1)
			measurementFolderList = AddListItem(GetIndexedObjNameDFR(testTypeFolder,4,measurementIndex),measurementFolderList,";",ItemsInList(measurementFolderList))
		endfor
		
		// Create a folder to hold the combined data
		NewDataFolder/O $newName
		NewDataFolder/O $(":"+newName+":Data")
		
		DFREF destFolder = $newName
		DFREF measurementFolder
		
		WAVE/WAVE sourceParamWaveRefs
		String destWaveName
		
		// For each measurement folder, copy the data to the new folder
		for( measurementIndex=0; measurementIndex < ItemsInList(measurementFolderList);measurementIndex+=1)
			measurementName = StringFromList(measurementIndex, measurementFolderList)
			measurementFolder = $measurementName
			
			// use the paramWaveRefs to find the param waves to copy
			WaveClear sourceParamWaveRefs
			WAVE/WAVE sourceParamWaveRefs = measurementFolder:paramWaveRefs
			
			// Create a new paramWaveRefs wave in the new folder
			// for each test type
			if( measurementIndex == 0 )
				// Assume all measurements have the same number of param waves
				Make/WAVE/N=(numpnts(sourceParamWaveRefs)) destFolder:paramWaveRefs
				WAVE/WAVE destParamWaveRefs = destFolder:paramWaveRefs
			endif
			
			WAVE sourceParamWave
			
			for(paramWaveIndex = 0;paramWaveIndex < numpnts(sourceParamWaveRefs);paramWaveIndex+=1)
				WaveClear sourceParamWave
				WAVE/Z sourceParamWave = sourceParamWaveRefs[paramWaveIndex]
				
				destWaveName = ReplaceString(measurementName,NameOfWave(sourceParamWave),newName)
				
				if( 2 == WaveType(sourceParamWave,1) )
					// This is a text wave
					WAVE/T wTextSource = sourceParamWave
					WAVE/T/Z wTextDest = destFolder:$(destWaveName)
					
					if( WaveExists(wTextDest) == 0 )
						Duplicate wTextSource, destFolder:$(destWaveName)
						WaveClear wTextDest
						WAVE/T wTextDest = destFolder:$(destWaveName)
						destParamWaveRefs[paramWaveIndex] = wTextDest
					else
						initialLength = numpnts(wTextDest)
						InsertPoints numpnts(wTextDest), numpnts(wTextSource), wTextDest
						wTextDest[initialLength,*] = wTextSource[p-initialLength]
					endif	
				
				else
					WAVE wSource = sourceParamWave
					WAVE/Z wDest = destFolder:$(destWaveName)
					
					if( WaveExists(wDest) == 0 )
						Duplicate wSource, destFolder:$(destWaveName)
						WaveClear wDest
						WAVE wDest = destFolder:$(destWaveName)
						destParamWaveRefs[paramWaveIndex] = wDest
					else
						initialLength = numpnts(wDest)
						InsertPoints numpnts(wDest), numpnts(wSource), wDest
						wDest[initialLength,*] = wSource[p-initialLength]
					endif	
					
				endif
										
			endfor
			
			// Copy data waves, renumbering and renaming
			Variable missingDataSetCount = 0
			DFREF sourceDataFolder = measurementFolder:Data
			DFREF destDataFolder = destFolder:Data
			sourceDatasets = CountObjectsDFR(sourceDataFolder,1)
			destDatasets = CountObjectsDFR(destDataFolder,1)
			
			for(waveIndex = 0;waveIndex < sourceDatasets;waveIndex+=1)
				srcWaveName = GetIndexedObjNameDFR(sourceDataFolder,1,waveIndex)
				destWaveName = newName+"_"+num2str(destDatasets+waveIndex-missingDataSetCount)
				
				WAVE wDataSource = sourceDataFolder:$srcWaveName
				
				// Don't copy empty datasets, assuming there isn't an entry in the param waves for empty datasets
				if( numpnts(wDataSource) )
					Duplicate wDataSource, destDataFolder:$destWaveName
				else
					missingDataSetCount += 1
				endif
			endfor
			
		endfor
		
	endfor
	
	// Make plots because the analyze functions expect a graphName variable
	DFREF measurementFolder = $"root:VDID:"+newName
	SetDataFolder measurementFolder
	String/G graphNameList
	graphNameList = PlotData(measurementFolder,"X:VD_;XLabel:V\\BD\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VG_;P0Label:V\\BG\\M",-1,-1)
	
	measurementFolder = $"root:VGID:"+newName
	SetDataFolder measurementFolder
	String/G graphNameList
	graphNameList = PlotData(measurementFolder,"X:VG_;XLabel:V\\BG\\M (V);Y:ID_;YLabel:I\\BD\\M (A);P0:VD_;P0Label:V\\BD\\M",-1,-1)

	
End

Function SortData(testFolderName)
	String testFolderName
	DFREF testFolder = $testFolderName
	
	if( DataFolderRefStatus(testFolder) == 0 )
		print "No folder: "+testFolderName
		return 0
	endif
	
	// numpnts in param wave should match number of datasets in Data folder
	SetDataFolder testFolder
	DFREF dataFolder = testFolder:Data
	
	if( DataFolderRefStatus(dataFolder) == 0 )
		print "No data folder"
		return 0
	endif
	
	Variable dataSetCount = CountObjectsDFR(dataFolder,1)
	WAVE/WAVE paramWaveRefs = paramWaveRefs
	WAVE/Z paramWave = paramWaveRefs[0]
	WAVE/T textParamWave
	Make/FREE/N=(numpnts(paramWave)) paramNumeric
	
	if( 2 == WaveType(paramWave,1) )
		// This is a text wave
		
		// Check length
		if( numpnts(paramWave) != dataSetCount )
			print "Number of datasets and setpoints don't match"
			return 0
		endif
		
		// Recast wave variable as a text wave
		WaveClear textParamWave
		Wave/T textParamWave = paramWaveRefs[0]
		
		paramNumeric = str2num(textParamWave[p])
	
	else
		// This is a numeric wave
		
		// Check length
		if( numpnts(paramWave) != dataSetCount )
			print "Number of datasets and setpoints don't match"
			return 0
		endif
		
		// Copy
		paramNumeric = paramWave[p]
		
	endif
	
	Make/FREE/N=(numpnts(paramNumeric)) order
	order = p
	
	// Sort using the first parameter wave
	Sort paramNumeric, order
	
	// Sort each parameter wave by the first parameter wave
	Variable paramWaveIndex = 0
	for(paramWaveIndex = 0; paramWaveIndex < numpnts(paramWaveRefs);paramWaveIndex+=1)
		WaveClear paramWave
		WAVE/Z paramWave = paramWaveRefs[paramWaveIndex]
		
		if( 2 == WaveType(paramWave,1) )
			// This is a text wave
			// Recast wave variable as text
			WaveClear textParamWave
			WAVE/T textParamWave = paramWaveRefs[paramWaveIndex]
			
			Sort paramNumeric, textParamWave
		else
			Sort paramNumeric, paramWave
		endif
		
		
	endfor
	
	// Rename datasets according to order
	NewDataFolder SortedData
	DFREF sortedDataFolder = SortedData
	Variable dataSetIndex = 0
	String dataSetName
	for(dataSetIndex = 0;dataSetIndex<dataSetCount;dataSetIndex+=1)
		Duplicate dataFolder:$(GetIndexedObjNameDFR(dataFolder,1,order[dataSetIndex])), sortedDataFolder:$(testFolderName+"_"+num2str(dataSetIndex))
	endfor
	
	RenameDataFolder dataFolder, UnsortedData
	RenameDataFolder sortedDataFolder, Data
		
End


Function AddTemperatureTopAxis()
	WAVE dataWave = CsrWaveRef(A)
	WAVE xWave = CsrXWaveRef(A)
	
	if( !WaveExists(dataWave) | !WaveExists(xWave) )
		print "Put A cursor on trace"
		return 0
	endif
	
	String sDataWaveBaseName, sXWaveBaseName
	
	sDataWaveBaseName = ReplaceString("_avg",NameOfWave(dataWave),"")
	sXWaveBaseName = ReplaceString("_avg",NameOfWave(xWave),"")
	
	//ppp()
	
	// Get 1/T values from xWave, make a text wave of T values
	Make/T/N=(numpnts(xWave)) selectedTemperatures_TEXT = num2str(round(1/exp(xWave)))
		
	AppendToGraph/T dataWave/TN=topData vs xWave
	ReorderTraces $NameOfWave(dataWave),{topData}
	ModifyGraph userticks(top)={xWave,selectedTemperatures_TEXT}
	ModifyGraph mode(topData)=2,rgb(topData)=(65535,65535,65535)
	Label top "Temperature (K)"
	//ModifyGraph fSize(top)=18
	//ModifyGraph margin(top)=55
	
	// Add error bars to the visible data
	//ErrorBars $NameOfWave(dataWave) XY,wave=($(sXWaveBaseName+"_max"),$(sXWaveBaseName+"_min")),wave=($(sDataWaveBaseName+"_max"),$(sDataWaveBaseName+"_min"))
	//ModifyGraph marker($NameOfWave(dataWave))=0

End

// Calculate transition temperature from intersection of two linear fits
// wConductance is the wave with the values of ln(conductance)
// wLnInvT is the wave with ln(1/T)
// startTrace is the index of the first trace on the top graph to be fit
// endTrace is the index of the last trace on the top graph to be fit
// a,b,c,d are the data point indices defining the points to use for 
//		the linear fits at high and low T
//		e.g. 0, 6, 20, 32 to fit the first 7 and last 13 points in 33 point data sets
Function getTc(wConductance, wLnInvT, startTrace, endTrace, a, b, c, d)
	Wave wConductance, wLnInvT
	Variable startTrace, endTrace, a, b, c, d
	
	Wave/Z W_coef, W_sigma
	
	// Make a wave to put the transition temperatures and activation energies
	Make/O/N=(dimsize(wConductance,1)) $(NameOfWave(wConductance)+"_Tc")
	Make/O/N=(dimsize(wConductance,1)) $(NameOfWave(wConductance)+"_E3")
	Wave wTc = $(NameOfWave(wConductance)+"_Tc")
	Wave wEa = $(NameOfWave(wConductance)+"_E3")
	
	// Make waves for the fitting errors
	// one for the error in Tc to be calculated from the error in the slopes
	// one for the error in the activation energy
	Make/O/N=(dimsize(wConductance,1))		$(NameOfWave(wConductance)+"_TcErr")
	Make/O/N=(dimsize(wConductance,1))		$(NameOfWave(wConductance)+"_EaErr")
	Wave wTcErr = $(NameOfWave(wConductance)+"_TcErr")
	Wave wEaErr = $(NameOfWave(wConductance)+"_EaErr")
		
	Variable trace
	for( trace = startTrace; trace <= endTrace; trace += 1 )
	
		// Do a linear fit between points a-b
		CurveFit/M=2/W=0/Q line, wConductance[a,b][trace]/X=wLnInvT[a,b];
		Variable y1 = W_coef[0]
		Variable slope1 = W_coef[1]
		Variable y1Err = W_sigma[0]
		Variable slope1Err = W_sigma[1]
	
		// Do a linear fit between points c-d
		CurveFit/M=2/W=0/Q line, wConductance[c,d][trace]/X=wLnInvT[c,d];
		Variable y2 = W_coef[0]
		Variable slope2 = W_coef[1]	
		Variable y2Err = W_sigma[0]
		Variable slope2Err = W_sigma[1]
		
		// calculate the rightmost Tc
		Variable tcMax = ((y1-abs(y1Err))-(y2+abs(y2Err)))/((slope2-abs(slope2Err)) - (slope1+abs(slope1Err)))
		
		// calculate the leftmost Tc
		Variable tcMin = ((y1+abs(y1Err))-(y2-abs(y2Err)))/((slope2+abs(slope2Err)) - (slope1-abs(slope1Err)))
		
		Variable tc = (y1-y2)/(slope2 - slope1)
		wTc[trace] = 1/exp(tc)
		
		// Add the percent error in the two fitting parameters (slope and intercept)
		// to calculate the error in Tc
		wTcErr[trace] = (1/exp(tc))*abs(1-((1+slope1Err/slope1+slope2Err/slope2) * (1+y1Err/y1+y2Err/y2)))
		
		// Get the NN hopping energy
		// Assumes fitting region 2 from points c,d is the NN hopping region
		wEa[trace] = 8.617e-5*abs((y2+slope2*wLnInvT[c])-(y2+slope2*wLnInvT[d]))/(exp(wLnInvT[c])-exp(wLnInvT[d]))
		wEaErr[trace] = abs(wEa[trace] * slope2Err/slope2)
		
		printf "Tc: %g  ± %g, Min/Max: %g , %g,    Ea: %g, ± %g\r", wTc[trace], wTcErr[trace], 1/exp(tcMin), 1/exp(tcMax), wEa[trace], wEaErr[trace]
		
		// Make waves to plot the lines on the top graph
		Make/O/N=2 $(NameOfWave(wConductance)+num2str(trace)+"_fit1"), $(NameOfWave(wConductance)+num2str(trace)+"_fit2")
		Wave line1 = $(NameOfWave(wConductance)+num2str(trace)+"_fit1")
		Wave line2 = $(NameOfWave(wConductance)+num2str(trace)+"_fit2")
		
		line1[0] = y1+slope1*wLnInvT[a]
		line1[1] = y1+slope1*tc
		SetScale/I x, wLnInvT[a], tc, line1
		
		line2[0] = y2+slope2*tc
		line2[1] = y2+slope2*wLnInvT[d]
		SetScale/I x, tc, wLnInvT[d], line2
		
		RemoveFromGraph/Z $(NameOfWave(wConductance)+num2str(trace)+"_fit1"),$(NameOfWave(wConductance)+num2str(trace)+"_fit2")
		AppendToGraph line1, line2
		
	endfor
		
End