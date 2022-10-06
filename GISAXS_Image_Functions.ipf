#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "HELIOS"
	Submenu "GISAXS"
		"Project GISAXS Images",ProjectImageSeries()
		"Follow Peaks",FollowPeaks()
		"Stitch Stacks",StitchStacks()
	End
End

Structure expFitStruct
	Wave coefw		// coefficient wave
	Variable x		// independent variable
	Variable x0	// x offset constant
EndStructure

// GISAXS_Image_Functions.ipf


// ProjectImageSeries()
// Import a series of GISAXS images
// 1) plots the series in a grid with scattering vector axes qx, qy (nm\S-1)
// 2) projects each image onto its horizontal axis and plots all projections
//		 as a 2D image with parallel scattering vector on the horizontal axis
//		 and image sequence (time, temperature, etc.) on the vertical axis
// The image file creation timestamp (presumably the time of the exposure) of each imported file is saved
// This allows the function FollowPeak to plot the peak position as a function of elapsed time
// or you may substitute another time-correlated parameter instead (vapor pressure, temperature, etc.)

// Change log:
// 20140617 KW
//		Changed projectionVsTime image to have aspect 0.5 instead of 1
//		Moved prompt to get stack name prior to numerical parameters to create folder using
//			stack name before creating numerical variables
//		Added global string to store stack name
//		Commented out stackedImages wave code to save memory
//		Changed frameTime wave from single to double precision
//	20140624 KW
//		Changed projection image colorscale to log instead of linear
// 20140626 KW
//		Changed vert/horz flipping
// 20140630 KW
//		Added text wave to save file names without full path
//		Aded annotation to imported images with number and filename
//		Fixed location of A,B cursors
//		Changed height of projection image to fit in FollowPeaks() layout
// 20160521 KW
//		Add axis labels to scattering patterns

Function ProjectImageSeries()
	String filePath, imageName, imageFileList, fileFilters = "Image Files (*.tif,*.tiff):.tif,.tiff;"
	Variable refNum, i = 0, totalFrames
	
	DFREF wd = GetDataFolderDFR()
	NewDataFolder/O/S root:ImageStacks
	
	String stackName = "stack"
	SVAR/Z gStackName
	
	if( SVAR_Exists(gStackName) == 0 )
		String/G gStackName = stackName
	else
		stackName = gStackName
	endif
	
	Prompt stackName, "Stack Name?"
	DoPrompt "Stack Name?"stackName
	
	if( V_flag != 0 )
		print "User cancelled"
		return 0
	endif
	
	gStackName = stackName
	
	
	// Keep this info in the ImageStacks folder, access for all stacks
	NVAR/Z gBeamX
	NVAR/Z gBeamY
	NVAR/Z gWavelength_ang
	NVAR/Z gDistance_mm
	NVAR/Z gPixelSize_um
	NVAR/Z gAlpha_i
	NVAR/Z gFlipHorz
	NVAR/Z gFlipVert
	NVAR/Z gColMin,gColMax,gRowMin,gRowMax
	Variable beamX = gBeamX, beamY = gBeamY, wavelength_ang = gWavelength_ang, distance_mm = gDistance_mm,flipHorz = gFlipHorz, flipVert = gFlipVert, pixelSize_um = gPixelSize_um,alpha_i = gAlpha_i
	
	if( numtype(gBeamX) == 2)
		Variable/G gBeamX,gBeamY, gWavelength_ang, gDistance_mm, gPixelSize_um,gAlpha_i,gFlipHorz,gFlipVert
	endif
	
	if( numtype(gColMin) == 2 )
		Variable/G gColMin,gColMax,gRowMin,gRowMax
		gColMin = -1
		gColMax = -1
		gRowMin = -1
		gRowMax = -1
	endif
	
	Prompt beamX,"Beam X (before flip)?"
	Prompt beamY,"Beam Y (before flip)?"
	Prompt wavelength_ang,"Wavelength (ang)?"
	Prompt distance_mm,"Distance (mm)?"
	Prompt flipHorz,"Flip horizontal (1/0)?"
	Prompt flipVert,"Flip vertical (1/0)?"
	Prompt pixelSize_um,"Pixel size (um)?"
	Prompt alpha_i, "Incident angle (deg)?"
	DoPrompt "Setup",beamX,beamY,wavelength_ang,distance_mm,flipHorz,flipVert,pixelSize_um,alpha_i
	gBeamX = beamX
	gBeamY = beamY
	gWavelength_ang = wavelength_ang
	gDistance_mm = distance_mm
	gPixelSize_um = pixelSize_um
	gAlpha_i = alpha_i
	gFlipHorz = flipHorz
	gFlipVert = flipVert
	
	if(V_Flag)
		print "User cancelled"
		return 0
	endif
	
	// Change working directory to this image stack
	NewDataFolder/O/S $(stackName)	
	String/G importedFileList
	
	SVAR/Z gFolderPath
	if( SVAR_Exists(gFolderPath) == 0 )
		String/G gFolderPath = ""
		Open/D/R/MULT=1 /F=fileFilters /M="Choose files, sorting matters!" refNum
	else
		NewPath/Q/O dataFolder, gFolderPath
		Open/D/R/MULT=1 /P=dataFolder /F=fileFilters refNum
	endif

	imageFileList = S_fileName
	importedFileList = S_fileName
	
	if(strlen(imageFileList) == 0 )
		print "No files to import"
		return 0
	endif
	
	String folderPath
	folderPath = StringFromList(0,imageFileList,"\r")
	folderPath = folderPath[0,strsearch(folderPath, ":", Inf, 1)-1]
	gFolderPath = folderPath
	
	totalFrames = itemsInList(imageFileList,"\r")
	Make/D/O/N=(totalFrames) frameTime
	
	// Save filenames for use in FollowPeaks()
	Make/O/T/N=(totalFrames) imageFileNames
	
	// Find layout parameters
	Variable layoutAspect = 11/8.5
	Variable layoutGraphsHorz = ceil(sqrt(totalFrames)/layoutAspect)
	Variable layoutGraphsVert = ceil(totalFrames/layoutGraphsHorz)
	Variable layoutLeft, layoutTop

	for(i=0;i < totalFrames;i+=1)
	
		filePath = StringFromList(i,imageFileList, "\r")
		imageName = "stack_"+num2str(i)
		
		// Store just the filename, extracted from the full path
		imageFileNames[i] = StringFromList(ItemsInList(filePath,":")-1,filePath, ":")
		
		GetFileFolderInfo/Q filePath
		frameTime[i] = V_creationDate
		
		ImageLoad/Q/O/N=$(imageName) filePath
		WAVE imageWave = $(imageName)
		
		// Remove hot pixels
		//RemoveHotPixels(medOpticsHotPixelList,imageWave)
		
		// Flip
		if( flipHorz )
			ImageTransform flipRows imageWave
			beamX = dimsize(imageWave,0)-beamX
		endif
		
		if( flipVert )
			ImageTransform flipCols imageWave
			beamY = dimsize(imageWave,1)-beamY
		endif
		
		if( i == 0 )
			// Get projection limits from user interactively
			if( gColMin == -1 )
				gColMin = 0
				gRowMin = 0
				gRowMax = dimsize(imageWave,0)-1
				gColMax = dimsize(imageWave,1)-1
			endif
			
			NewImage/K=3 /N=projectionLimits imageWave
			ModifyImage/W=projectionLimits $(imageName) ctab= {25,*,Geo,0}, log=1
			ShowInfo
			Cursor/I/H=1/C=(65535,65535,65535)/P A $(imageName) gRowMin,gColMin
			Cursor/I/H=1/C=(65535,65535,65535)/P B $(imageName) gRowMax,gColMax
			PauseForLimitsInput()
			gRowMin = min(pcsr(A),pcsr(B))
			gRowMax = max(pcsr(A),pcsr(B))
			gColMin = min(qcsr(A),qcsr(B))
			gColMax = max(qcsr(A),qcsr(B))
			DoWindow/K projectionLimits
			
			Make/O/N=(gRowMax-gRowMin+1,totalFrames) projectionVsTime
			
			// Display projection slices vs time now so we can watch during the import
			DoWindow/K $(stackName+"_projection")
			NewImage/K=0/N=$(stackName+"_projection")  projectionVsTime
			
			// Autoscale the color according to the visible data
			ModifyImage/W=$(stackName+"_projection") projectionVsTime ctabAutoscale=1,lookup= $""
			
			ModifyImage/W=$(stackName+"_projection") projectionVsTime ctab= {*,*,Rainbow,0}, log=1
			ModifyGraph/W=$(stackName+"_projection") width=520, height=190	// sized to fit in the FollowPeaks() layout
			ModifyGraph/W=$(stackName+"_projection") nticks(left)=(dimsize(projectionVsTime,1))
			MoveWindow 0,0,0,0
			
			// Scale the rows (in the horizontal scattering plane)
			Make/FREE/O/N=(DimSize(imageWave,0)+1)/D twothetaf, qx
			twothetaf = atan((p-beamX)*gPixelSize_um*1e-3/gDistance_mm)*180/pi
			qx = 2*pi/(0.1*gWavelength_ang)*sin(twothetaf*pi/180)
			SetScale/I x, qx[gRowMin], qx[gRowMax], "nm\S-1\M", projectionVsTime//, stackedImages
			
			// Set vertical scattering scale for the collection of images
			Make/O/N=(DimSize(imageWave,1)+1)/D alphaf, qy
			alphaf=atan((p-beamY)*gPixelSize_um*1e-3/gDistance_mm)*180/pi-gAlpha_i
			qy=2*pi/(0.1*gWavelength_ang)*(sin(alphaf*pi/180)+sin(gAlpha_i*pi/180))
			
			// Display images tiled in a layout
			DoWindow/K $(stackName)
			Variable layoutWidth = 570, layoutHeight
			layoutHeight = layoutWidth*layoutAspect
			NewLayout/W=(500,0,500+800,layoutHeight) /N=$(stackName)
			ModifyLayout mag=1
		endif

		// Set the scale of the image in x
		SetScale/I x, qx[0], qx[numpnts(qx)-1], " nm\S-1\M", imageWave

		// Set the scale of the image in y
		// this is reversed by default
		SetScale/I y, qy[numpnts(qy)-1], qy[0], " nm\S-1\M", imageWave
		
		
		String imageWindowName = (stackName+"_image_"+num2str(i))
		DoWindow/K $(imageWindowName)
		
		// /F means don't flip vertically
		NewImage/F/K=3/HIDE=1 /N=$(imageWindowName) imageWave
		ModifyImage/W=$(imageWindowName) $(imageName) ctab= {25,*,Geo,0}, log=1
		ModifyGraph gfSize=9;ModifyGraph gFont="Helvetica"
		TextBox/C/N=text0/F=0/E=2 "\Z10"+num2str(i)+" ("+imageFileNames[i]+")"
		Label left "q\\B\\F'Symbol'^\\F'Helvetica'\\M (nm\\S-1\\M)"
		DelayUpdate;Label bottom "q\\B||\\M (nm\\S-1\\M)"
		ModifyGraph margin(left)=36,margin(bottom)=34
		ModifyGraph fSize=9,font="Helvetica"
		
		Variable margin = 20, grout = 5
		layoutLeft = margin+grout*(mod(i,layoutGraphsHorz))+mod(i,layoutGraphsHorz)/layoutGraphsHorz*(layoutWidth-2*margin)
		layoutTop = margin+grout*(floor(i/layoutGraphsHorz))+floor(i/layoutGraphsHorz)/layoutGraphsVert*(layoutHeight-2*margin)
		
		AppendLayoutObject/R=(layoutLeft,layoutTop,layoutLeft+(layoutWidth-2*margin)/layoutGraphsHorz,layoutTop+(layoutHeight-2*margin)/layoutGraphsVert) graph $(imageWindowName)
		
		Make/FREE/N=(gRowMax-gRowMin+1,gColMax-gColMin+1) roiImage
		roiImage = imageWave[p+gRowMin][q+gColMin]
		SetScale/I x, qx[gRowMin], qx[gRowMax], "nm\S-1\M", roiImage
		ImageTransform sumAllRows roiImage
		WAVE W_sumRows
		projectionVsTime[][i] = W_sumRows[p]
	endfor
	
	printf "Imported %s...%s\r", StringFromList(0,imageFileList, "\r"), StringFromList(totalFrames-1,imageFileList, "\r")
	
	SetDataFolder wd
End

strconstant medOpticsHotPixelList = "R0=436;C0=362;R1=831;C1=737"

static Function RemoveHotPixels(hotPixelList,imageWave)
	String hotPixelList
	WAVE imageWave
	Variable rowNumber,colNumber, point
	
	// Format: "R0=xx;C0=XX;..."
	for(point=0;point<(ItemsInList(hotPixelList,";")/2);point+=1)
		rowNumber = NumberByKey("R"+num2str(point),hotPixelList,"=",";")
		colNumber = NumberByKey("C"+num2str(point),hotPixelList,"=",";")
		imageWave[rowNumber][colNumber] = 0
	endfor
End

Function LimitsPanel_Continue(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/K tmp_GetInputPanel
End

// Call with these variables already created and initialized:
Function ShowLimitsInputPanel()
	NewPanel /W=(822,131,1070,200)
	DoWindow/K tmp_GetInputPanel
	DoWindow/C tmp_GetInputPanel			// Set to an unlikely name
	DrawText 33,23,"Move cursors to set projection area"
	Button button0,pos={85,34},size={92,20}
	Button button0,proc=UserGetInputPanel_ContButton,title="Continue"

	PauseForUser tmp_GetInputPanel, projectionLimits
End

Function PauseForLimitsInput()
	ShowLimitsInputPanel()
End


// InterpolateStackProjection
// interpolates a stack of projections such that the columns (slices or frames or exposures)
// are spaced at regular intervals which allows the matrix to be scaled according to the 
// time value
Function InterpolateStackProjection(projectionImage, timeWave)
	Wave projectionImage, timeWave
	Variable row
	MAKE/FREE/O/N=(numpnts(timeWave)) slice, interpolatedSlice
	Duplicate/O projectionImage, interpolatedProjection
	
	if(numpnts(timeWave) != dimsize(projectionImage,1) )
		print "Time points and projection $(imageName) columns do not match."
		return 0
	endif
	
	// Perform an interpolation over time on each row of the projection $(imageName)
	for( row = 0; row < dimsize(projectionImage,0);row+=1)
		slice = projectionImage[row][p]
		Interpolate2 /A=(numpnts(timeWave)) /T=1 /J=2 /Y=interpolatedSlice timeWave,slice
		interpolatedProjection[row][] = interpolatedSlice[q]
	endfor
	
	SetScale/I y, 0, (timeWave[numpnts(timeWave)-1]-timeWave[0]), "s", interpolatedProjection
	
End

// FollowPeaks
//	Fits a single gaussian peak in a selected range of x values for a series
//	of 1-D waves and plots the peak position as a function of the xWave 
// The xWave should be e.g. exposure elapsed time, vapor pressure, temperature, etc.
// Use the A and B cursors on the series of projections to find minRow and maxRow
// to define a region of interest in which to search for a single peak
// 20140617 KW
//		Added to macro menu
//		Added prompt to get stack name to get waves
//		Get min/max rows for fitting from cursor positions
// 20140619 KW
//		Get min/max columns from cursors to fit a subset of frames
//		Changed peak fitting from gauss to Lor_exp. Lorentz peaks
//			are more appropriate for scattering peaks. Background needs
//			to be fit for more accurate peak location of small peaks
//		Added plot of integrated intensity vs scattering vector
//	20140622 KW
//		Added MakeTraceColorsUnique() call to 1D plot
// 20140624 KW
//		Added multi-peak tracking
// 20140630 KW
//		Added constraints for the exp background terms

Function FollowPeaks()
	Variable i
	
	SVAR gStackName = root:ImageStacks:gStackName
	String stackName = gStackName
	//Variable useGauss = 0
	Variable maxPeaks = 2
	Variable minPeakPercent = 5
	Prompt stackName, "Stack Name?"
	//Prompt useGauss, "Gauss (1) or Lorentz (0)?"
	Prompt maxPeaks, "Maximum No. of Peaks?"
	Prompt minPeakPercent, "Minimum peak %?"
	DoPrompt "Stack Name?"stackName,maxPeaks,minPeakPercent//,useGauss
	
	if( V_flag != 0 )
		print "Cancelled"
		return 0
	endif
	
	SetDataFolder root:ImageStacks
	SetDataFolder $(stackName)
	
	Wave projectionImage = projectionVsTime
	if( WaveExists(projectionImage) == 0)
		WAVE stitchedProjectionVsTime = stitchedProjectionVsTime
		WaveClear projectionImage
		WAVE projectionImage = stitchedProjectionVsTime
	endif
	
	WAVE xWave = frameTime
	if( WaveExists(xWave) == 0)
		WAVE stitchedElapsedTime = stitchedElapsedTime
		WaveClear xWave
		WAVE xWave = stitchedElapsedTime
	endif
	
	Variable minRow,maxRow, minCol, maxCol
	
	// Find the right plot window to get the cursor locations
	DoWindow/F $(stackName+"_projection")
	
	if( WaveExists(CsrWaveRef(A))==0 || WaveExists(CsrWaveRef(B))==0)
		print "Place cursors on graph to bound peak position"
		return 0
	endif
	
	minRow = min(pcsr(A),pcsr(B))
	maxRow = max(pcsr(A),pcsr(B))
	minCol = min(qcsr(A),qcsr(B))
	maxCol = max(qcsr(A),qcsr(B))
	
	if(dimsize(projectionImage,1) != numpnts(xWave))
		print "Image projections and x points don't match."
		return 0
	endif
	
	Make/O/N=(maxCol-minCol+1) elapsedTime
	
	Variable xMin, xMax, A, tau,y0
	xMin = pnt2x(projectionImage,minRow)
	xMax = pnt2x(projectionImage,maxRow)
	
	Make/O/N=3 bkgTerms
	Struct expFitStruct bkgStruct
		
	String fitSpec, fitFunctions, peakName, traceName
	fitFunctions = "{exp_y0_x0,bkgTerms,STRC=bkgStruct}" 
	
	Make/T/FREE/N=(maxCol-minCol+1) legendTextWave
	DoWindow/K $("fit_"+stackName)
	Display/HIDE=1/N=$("fit_"+stackName)
	MoveWindow/I/W=$("fit_"+stackName) 4,0,7,3
	TextBox/N=legendText/F=0/A=RT ""	// Legend text
	
	Make/O/N=(maxRow-minRow+1) fitData
	Make/O/N=(maxRow-minRow+1,maxCol-minCol+1) fitSlices, normalizedData
	SetScale/I x, xMin, xMax, "nm\S-1\M", fitSlices, fitData, normalizedData
	
	Variable/C estimates
	Variable noiselevel, smoothingFactor, peaksFound, peakNum, amplitude = 0
	WAVE/Z W_AutoPeakInfo
	WAVE/Z fitTerms

	Make/O/N=(maxCol-minCol+1,maxPeaks) peakPosition = nan, peakPositionErr, peakFWHM = nan, peakFWHMErr
	Make/O/N=(maxCol-minCol+1,maxPeaks-1) relativePeakPosition
	
	Variable satisfied = 0, userNoiseLevel, userSmoothingFactor, userAmplitude, skipAdjustments = 0
	Prompt userNoiseLevel,"Noise level"
	Prompt userSmoothingFactor,"Smoothing"
	Prompt userAmplitude,"Amplitude"
	
	Variable dataMin, dataMax
	
	for(i=0;i<=(maxCol-minCol);i+=1)
		
		fitData = projectionImage[p+minRow][i+minCol]
		
		WaveStats/Q/R=(xMin,xMax) fitData
		dataMin = V_min
		dataMax = V_max
		
		Variable currentX0 = xMin	//V_maxLoc
		bkgStruct.x0 = currentX0
		y0 = V_min
		A = fitData(currentX0)-y0
		tau = 0.5							// maybe linear approximation based on end points would work here
		
		bkgTerms = {y0,A,tau}
		
		amplitude = A
		userAmplitude = A
	
		estimates = EstNoiseAndSmfact(fitData,0, numpnts(fitData))
		noiselevel=real(estimates)
		smoothingFactor=imag(estimates)
		userNoiseLevel = noiseLevel
		userSmoothingFactor = smoothingFactor
		
		do
			peakPosition[i][] = nan
			peakPositionErr[i][] = nan
			relativePeakPosition[i][] = nan
			peakFWHM[i][] = nan
			peakFWHMErr[i][] = nan
			peaksFound = FindPeaks(fitData, 0, numpnts(fitData), noiseLevel, smoothingFactor, maxPeaks)
			Wave/Z W_sigma
			if( WaveExists(W_sigma) )
				W_sigma = nan
			endif
			
			if( peaksFound > 0 )
				WAVE/Z W_AutoPeakInfo = W_AutoPeakInfo
				if( WaveExists(W_AutoPeakInfo) )
					peaksFound= TrimAmpPeakInfo(W_AutoPeakInfo,minPeakPercent/100)
					WAVE/Z xW	// dummy wave ref, use calculated
					AdjustPeakInfoForX(W_AutoPeakInfo,fitData,xW)
				else
					print "No peak info"
					return 0
				endif
			else
				printf "No peak found for row %g",i+minCol
				break
			endif
			
			fitFunctions = "{exp_y0_x0,bkgTerms,STRC=bkgStruct}"
	
			// Make constraints for the fit	
			Variable peakConstraintTerms = 4	//	
			Make/T/O/N=(peaksFound*peakConstraintTerms+3) constraintSpec	// 4 terms per peak + 3 terms for background
			constraintSpec[0] = "K0 > 0"	// exp bkg y0
			constraintSpec[2] = "K2 > 0"	// exp bkg tau
			
			// if the user changed the amplitude value from the original guess
			// then set that as a constraint on the exponential background fit
			if( floor(userAmplitude) != floor(A) )
				constraintSpec[1] = "K1 = "+num2str(userAmplitude)
			else
				constraintSpec[1] = "K1 > 0"	// exp bkg A
			endif
			
			Make/O/FREE/WAVE/N=(peaksFound) fitTermWaves
			String x0_constraintIndex, B_constraintIndex, A_constraintIndex
			
			// Store the initial fitting guesses and constraints
			// for each peak we want to fit
			for(peakNum=0;peakNum<peaksFound;peakNum+=1)
				peakName = "fit"+num2str(peakNum)
				Make/D/O/N=3 $peakName
				WaveClear fitTerms
				WAVE fitTerms = $peakName
				// w[0] = x0
				// w[1] = B
				// w[2] = A
				fitTerms = {W_AutoPeakInfo[peakNum][0],W_AutoPeakInfo[peakNum][1],W_AutoPeakInfo[peakNum][2]}
				fitTermWaves[peakNum] = fitTerms
				fitSpec = "{Lorentz,"+peakName+"}"
				x0_constraintIndex = num2str(numpnts(bkgTerms)+peakNum*numpnts(fitTerms))
				B_constraintIndex = num2str(numpnts(bkgTerms)+peakNum*numpnts(fitTerms)+1)
				A_constraintIndex = num2str(numpnts(bkgTerms)+peakNum*numpnts(fitTerms)+2)
				constraintSpec[peakConstraintTerms*peakNum+3] = "K"+x0_constraintIndex+" > "+num2str(xMin)		// peak position > xMin
				constraintSpec[peakConstraintTerms*peakNum+1+3] = "K"+x0_constraintIndex+" < "+num2str(xMax)	// peak Position < xMax
				constraintSpec[peakConstraintTerms*peakNum+2+3] = "K"+B_constraintIndex+" > 0"						// no negative peak width
				constraintSpec[peakConstraintTerms*peakNum+3+3] = "K"+A_constraintIndex+" > 0"						// no negative peak amplitude
				fitFunctions += fitSpec
				
				printf "Lorentz %g: x0=%g, B=%g, A=%g\r",peakNum,fitTerms[0],fitTerms[1],fitTerms[2]
				
			endfor			
			
			print constraintSpec
			
			Variable V_FitError = 0
			FuncFit {string = fitFunctions} fitData /C=constraintSpec
			
			String errorString
			if( V_FitError != 0 )
				sprintf errorString, "Fit of projection %g had issues, error %g",i+minCol,V_FitError
				
				if( V_FitError == 1 )
					errorString += " Singular Matrix, try including more points"
				endif
				
				print errorString
			endif
			
			Wave/Z W_sigma
			Variable sumPeakTerms = 0, sigmaIndex, fwhmSigmaIndex					
			if( WaveExists(W_sigma) )
				// bkgTerms should contain values from the FuncFit
				fitSlices[][i] = bkgTerms[0]+bkgTerms[1]*exp(-(pnt2x(fitSlices,p)-bkgStruct.x0)/bkgTerms[2])
				for(peakNum=0;peakNum<peaksFound;peakNum+=1)
					WAVE fitTerms = fitTermWaves[peakNum]
					sumPeakTerms += numpnts(fitTerms)
					
					// Store the peak positions
					peakPosition[i][peakNum] = fitTerms[0]
					
					// Store the peak widths
					// the fit term is the B parameter of the Lorentz function
					// which is the HWHM
					peakFWHM[i][peakNum] = 2*fitTerms[1]
					
					// Don't calculate the peak ratio for the first peak
					if( peakNum > 0 )
						relativePeakPosition[i][peakNum-1] = peakPosition[i][peakNum]/peakPosition[i][0]
					endif
					
					// fix this!
					sigmaIndex = numpnts(bkgTerms)+sumPeakTerms-numpnts(fitTerms)
					if( sigmaIndex < numpnts(W_sigma) )
						peakPositionErr[i][peakNum] = W_sigma[sigmaIndex]
					else
						print "Fix this W_sigmaError"
					endif
					
					// Save the error in the peak width value
					fwhmSigmaIndex = sigmaIndex + 1
					if( fwhmSigmaIndex < numpnts(W_sigma) )
						peakFWHMErr[i][peakNum] = W_sigma[fwhmSigmaIndex]
					else
						print "Bad index for peakFWHMErr value"
					endif
					
					
					// Remove points with large error
					// setting to nan instead of zero prevents plotting the point
					if( peakPositionErr[i][peakNum] > (xMax-xMin) )
						peakPosition[i][peakNum] = nan
					endif
					
					fitSlices[][i] += Lorentz(fitTerms,pnt2x(fitSlices,p))
				endfor
				
				
				// Sort the peaks so that the smallest is first
				Make/FREE/O/N=(dimsize(peakPosition,1)) positions, positionErr
				positions = peakPosition[i][p]
				positionErr = peakPositionErr[i][p]
				Sort positions, positions, positionErr
				peakPosition[i][] = positions[q]
				peakPositionErr[i][] = positionErr[q]
			else
				print "No W_sigma"
			endif
			
			traceName = "trace"+num2str(i)
			elapsedTime[i] = xWave[i+minCol] - xWave[0]
			
			// Normalize and offset traces for clarity
			normalizedData[][i] = (fitData[p]-dataMin)/(dataMax - dataMin) + i
			fitSlices[][i] = (fitSlices[p][i]-dataMin)/(dataMax - dataMin) + i
			
			// Display a preview plot of the current trace
			Display/N=fitPreview normalizedData[][i] /TN=data, fitSlices[][i] /TN=fit
			ModifyGraph/W=fitPreview rgb(data)=(0,0,0)
			ModifyGraph/W=fitPreview lstyle(fit)=8, rgb(fit)=(65530,0,0)
			
			// Add the individual peaks and background to a bottom axis
			ModifyGraph/W=fitPreview axisEnab(left)={0.3,1}
			TextBox/C/N=fitPeakInfoText/F=0/A=RT ""
			Make/O/N=(dimsize(fitData,0),peaksFound+1) previewData
			SetScale/I x, xMin, xMax, "nm\S-1\M", previewData
			
			// Add background curve
			Variable pnt = 0
			Struct expFitStruct s
			WAVE s.coefw = fitTermWaves[0]
			s.x0 = currentX0
			for(pnt=0;pnt<dimsize(previewData,0);pnt+=1)
				s.x = pnt2x(previewData,pnt)
				previewData[pnt][0] = exp_y0_x0(s)
			endfor
			AppendToGraph/W=fitPreview/L=fit previewData[][0] /TN=bkg
			ModifyGraph/W=fitPreview rgb(bkg)=(0,0,0)
			
			for(peakNum=0;peakNum<peaksFound;peakNum+=1)
				WAVE fitTerms = fitTermWaves[peakNum]
				previewData[][peakNum+1] = Lorentz(fitTerms,pnt2x(previewData,p))
				AppendToGraph/W=fitPreview/L=fit previewData[][peakNum+1] /TN=$("fit_"+num2str(peakNum))
				AppendText/W=fitPreview/N=fitPeakInfoText num2str(fitTerms[0])
			endfor
			ModifyGraph/W=fitPreview axisEnab(fit)={0,0.3}
			ModifyGraph/W=fitPreview log(fit)=0, log(left)=1
			
			DoUpdate/W=fitPreview
			
			if( skipAdjustments == 0 ) 
				DoPrompt "Continue to next, Cancel to skip the rest",userNoiseLevel,userSmoothingFactor,userAmplitude
			endif
			
			// If user cancelled, skip the rest of the prompts
			if( V_flag != 0 )
				skipAdjustments = 1
			endif
			
			DoWindow/K fitPreview
			
			// use floor to convert float to int
			// otherwise they are not equal because of imprecision
			if( (floor(noiseLevel) != floor(userNoiseLevel)) || (smoothingFactor != userSmoothingFactor) || (floor(amplitude) != floor(userAmplitude)) )
				satisfied = 0
				noiseLevel = userNoiseLevel
				smoothingFactor = userSmoothingFactor
				amplitude = userAmplitude
			else
				satisfied = 1
			endif
			
		while(satisfied == 0)
		
		AppendToGraph/W=$("fit_"+stackName) normalizedData[][i] /TN=$(traceName)
		
		// Add legend entries in reverse order to match the stacking of traces on the graph
		legendTextWave[(maxCol-minCol)-i] = "\s("+traceName+")"+num2str(i)+": "+num2str(elapsedTime[i])+" (s)" 
	endfor
	
	// Form the legend and append it
	String legendEntries = legendTextWave[0]
	for(i=1;i<numpnts(legendTextWave);i+=1)
		legendEntries += "\r" + legendTextWave[i]
	endfor
	AppendText/W=$("fit_"+stackName)/N=legendText legendEntries
	
	// Remove the left axis from the stacked plot because it is arbitrary
	ModifyGraph/W=$("fit_"+stackName) tick(left)=3,noLabel(left)=2,axOffset(left)=-4
	ModifyGraph/W=$("fit_"+stackName) axRGB(left)=(65535,65535,65535)
	MakeTraceColorsUnique()
	ModifyGraph/W=$("fit_"+stackName) width=234,height=179.28,fSize=18
	ModifyGraph/W=$("fit_"+stackName) margin(left)=10,margin(bottom)=55,margin(top)=18,margin(right)=18
	Execute("nature_style()")
	
	String plotName = "peakPosition_"+stackName
	DoWindow/K $plotName
	Display/HIDE=1/N=$plotName
	for(peakNum=0;peakNum<dimsize(peakPosition,1);peakNum+=1)
		AppendToGraph/W=$plotName peakPosition[][peakNum] /TN=$("peak"+num2str(peakNum)) vs elapsedTime
		ErrorBars $("peak"+num2str(peakNum)) Y,wave=(peakPositionErr[][peakNum],peakPositionErr[][peakNum])
	endfor
	MakeTraceColorsUnique()

	for(i=0;i<=(maxCol-minCol);i+=1)
		AppendToGraph/W=$("fit_"+stackName) fitSlices[][i] /TN=$("fit"+num2str(i))
		ModifyGraph/W=$("fit_"+stackName) lstyle($("fit"+num2str(i)))=8, rgb($("fit"+num2str(i)))=(65535,0,0)
	endfor
	
	ModifyGraph mode=3, marker=16
	ModifyGraph lowTrip(left)=0.01
	Label left "In-Plane Peak Position"
	Label bottom "Elapsed Time (s)"
	Execute("nature_style()")
	
	// Set the column labels on the peak position waves for clarity
	for(peakNum=0;peakNum<dimsize(peakPosition,1);peakNum+=1)
		SetDimLabel 1,peakNum,$("q_"+num2str(peakNum)) peakPosition
	endfor
	
	for(peakNum=0;peakNum<dimsize(relativePeakPosition,1);peakNum+=1)
		SetDimLabel 1,peakNum,$("q_"+num2str(peakNum+1)+"/q0") relativePeakPosition
	endfor
		
	// Show peak positions and ratios
	WAVE/T imageFileNames
	Make/O/T/N=(dimsize(peakPosition,0)) imageFileNumber
	imageFileNumber = num2str(p+minCol)+" ("+StringFromList((ItemsInList(imageFileNames[p+minCol],"_")-1),imageFileNames[p+minCol],"_")+")"
	
	DoWindow/K $("peaks_"+stackName)
	Edit/HIDE=1/N=$("peaks_"+stackName) imageFileNumber,peakPosition,relativePeakPosition
	ModifyTable/W=$("peaks_"+stackName) showParts=4, horizontalIndex=2, sigDigits=5, size=10
	
	// Put the projection image, peak position, and fit trace plots in a layout
	DoWindow/K $(stackName+"_analysis")
	Variable layoutWidth, layoutHeight, margin = 25, grout = 5, plotWidth = 232, plotHeight = 172
	layoutWidth = 2*plotWidth+2*margin+grout+100+77
	layoutHeight = layoutWidth*11/8.5
	NewLayout/W=(500,0,500+layoutWidth,layoutHeight) /N=$(stackName+"_analysis")
	ModifyLayout mag=1
	AppendLayoutObject/R=(margin,margin,400,210) graph $(stackName+"_projection")
	AppendLayoutObject/R=(margin,336,plotWidth+margin,336+plotHeight) graph $("fit_"+stackName)
	AppendLayoutObject/R=(margin+grout+plotWidth+77,336,margin+grout+2*plotWidth,336+plotHeight) graph $("peakPosition_"+stackName)
	AppendLayoutObject/R=(margin,520,margin+550,520+235) table $("peaks_"+stackName)
End

Function Lorentz(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = y0+A1*exp(-(x-x0)/tau)+A2/((x-x0)^2+B)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = x0
	//CurveFitDialog/ w[1] = B
	//CurveFitDialog/ w[2] = A

	Variable returnVal = w[2]*w[1]/((x-w[0])^2+w[1]^2)
	return returnVal
End

Function exp_y0_x0(s) : FitFunc
	Struct expFitStruct &s
	Variable returnVal = s.coefw[0]+s.coefw[1]*exp(-(s.x-s.x0)/s.coefw[2])
	return returnVal
End

static constant numPeakInfoColumns = 5
Function FindPeaks(w,pBegin,pEnd,noiseEst,smFact,maxPeaks)
	Wave w
	Variable pBegin,pEnd
	Variable noiseEst,smFact
	Variable maxPeaks
	
	if( pBegin > pEnd )
		Variable tmp= pBegin
		pBegin= pEnd
		pEnd= tmp
	endif
	
	Make/O/N=(0,numPeakInfoColumns) W_AutoPeakInfo
	
	NewDataFolder/S/O afpTemp2
	Duplicate/O/R=[pBegin,pEnd] w,wtmp1
	SetScale/P x,0,1,wtmp1					// we work in point numbers here

	Smooth/B=3 smFact, wtmp1				// for peak amp determination
	
//Duplicate/O wtmp1, root:smooth1

	Duplicate/O wtmp1,wtmp2
//Duplicate/O wtmp1, root:debugDif

	Differentiate wtmp2
	Smooth/E=2/B=3 2*smFact, wtmp2
//Duplicate/O wtmp2, root:difsmooth2
	Differentiate wtmp2
	Smooth/E=2/B=3 2*smFact, wtmp2
//Duplicate/O wtmp2, root:dif2smooth3
	Duplicate/O wtmp2,wtmp3				// we mung one copy and need an unmunged version also
	
	findPeaksIn2ndDer(wtmp2)
//PutLinesOnGraph(results, "Graph7", DimSize(results, 0))
	Wave Results
//print GetWavesDataFolder(results, 2)
	maxPeaks = min(maxPeaks, DimSize(results, 0))
	Variable nRows = DimSize(results, 0)
	
	Variable avgWidth=0					// for width not too far from average width criteria
	
	Variable i=0,peakNum=0,numBadPeaks=0
	for (i = 0; i < nRows; i += 1)
		Variable x0= Results[i][0]
		Variable xr= Results[i][4]
		Variable xl= Results[i][2]

		Variable widthEst
		Variable rightWidthEst, leftWidthEst, leftWidthFraction	// JW 071031
		do
			if( (x0-xl) < 1 )
				widthEst= xr-x0				// if up against the left edge, use right width
				break
			endif
			if( (xr-x0) < 1 )
				widthEst= x0-xl				// similar for right edge
				break
			endif
			Variable ratio= (xr-x0)/ (x0-xl)	// right width/left width
			if( (ratio < 0.5) || (ratio>2) )
				widthEst=2* min(xr-x0, x0-xl)	// take smaller of widths if one is much larger
				break
			endif
			widthEst= xr-xl
		while(0)

		rightWidthEst = xr-x0						// JW 071031
		leftWidthEst = x0-xl						// JW 071031
		leftWidthFraction = leftWidthEst/widthEst	// JW 071031
		
		if( !(widthEst>3) )						// this probably will neverhappen but if it did, we are probably out of real peaks
			break
		endif

		Variable impulseWidth= 2*(2*smFact+1)
		if( widthEst > 1.3*impulseWidth )
			widthEst= sqrt(widthEst^2 - impulseWidth^2)
		else
			widthEst= widthEst/2
		endif
		widthEst /= sqrt(6)
		leftWidthEst = widthEst*leftWidthFraction
		rightWidthEst = widthEst - leftWidthEst
		
		Variable yl= wtmp1[xl], y0= wtmp1[x0], yr= wtmp1[xr]
		Variable bl0 = min(yr, yl)
		
		Variable heightEst= 1.3*(y0-bl0)
		if (heightEst < 0)
			continue
		endif
		
		Variable avgNoiseEst= noiseEst/(1.35*sqrt(2*smFact+1))
		Variable minH= avgNoiseEst*8
		Variable saveMinH = minH
		
		// throw in an additional penalty if width is far away from the average
		if( avgWidth>0 )
			minH *= sqrt( (widthEst/avgWidth)^2 + (avgWidth/widthEst)^2 )
		endif
//print "i=",i,"; point=", x0, "; original minH=",saveMinH,"; minH=",minH,"; heightEst=",heightEst, "; widthEst=", widthEst
		if( heightEst >  minH )
			Redimension/N=(peakNum+1,numPeakInfoColumns) W_AutoPeakInfo
			avgWidth= (avgWidth*peakNum+widthEst)/(peakNum+1)
			W_AutoPeakInfo[peakNum]={{x0+pBegin},{widthEst},{heightEst},{leftWidthEst},{rightWidthEst}}
			peakNum+=1
		else
			if( peakNum == 0 )
				break					// if very first peak is bad, then give up
			endif
			numBadPeaks += 1
			if( numBadPeaks > 3 )
				break
			endif
		endif
		if(peakNum>=maxPeaks)
			break;
		endif
	endfor
	KillDataFolder :

	return 	peakNum
end

Function findPeaksIn2ndDer(win)
	Wave win
	
	Make/N=(100,7)/O results
	Variable startP = 0
	Variable numPeak=0
	Variable lowBad = 0
	Variable highBad = 0

	findpeak/B=1/N/P/R=[startP,]/Q win
	results[numPeak][0]=V_PeakLoc
	results[numPeak][1]=V_PeakVal
	if (V_flag)
		// couldn't find even one low point???
		Redimension/N=0 results
		return -1
	endif
	findpeak/B=1/P/R=[V_PeakLoc,0]/Q win
	results[numPeak][2]=V_PeakLoc
	results[numPeak][3]=V_PeakVal
	if (V_flag)
		lowBad = 1
	endif
	findpeak/B=1/P/R=[results[numPeak][0],]/Q win
	results[numPeak][4]=V_PeakLoc
	results[numPeak][5]=V_PeakVal
	if (V_flag)
		// Couldn't find the other side of the first peak
		Redimension/N=0 results
		return -1
	endif
	if (lowBad)
		startP = V_PeakLoc
	endif
	
	Variable leftPeakLoc, leftPeakVal
	Variable midPeakLoc, midPeakVal
	Variable rightPeakLoc, rightPeakVal
	do
		findpeak/B=1/N/P/R=[startP,]/Q win
		midPeakLoc=V_PeakLoc
		midPeakVal=V_PeakVal
		if (V_flag)
			break;
		endif
		findpeak/B=1/P/R=[V_PeakLoc,0]/Q win
		leftPeakLoc=V_PeakLoc
		leftPeakVal=V_PeakVal
		if (V_flag)
			break;
		endif
		findpeak/B=1/P/R=[midPeakLoc,]/Q win
		rightPeakLoc=V_PeakLoc
		rightPeakVal=V_PeakVal
		if (V_flag)
			break;
		endif
		
		results[numPeak][0]=midPeakLoc
		results[numPeak][1]=midPeakVal
		results[numPeak][2]=leftPeakLoc
		results[numPeak][3]=leftPeakVal
		results[numPeak][4]=rightPeakLoc
		results[numPeak][5]=rightPeakVal
		results[numPeak][6]=min(abs(midPeakVal - leftPeakVal), abs(midPeakVal - rightPeakVal))
	
		startP=V_PeakLoc
		numPeak += 1
		if (numPeak >= DimSize(results, 0))
			Redimension/N=(numPeak+100, -1) results
		endif
	while(1)
	
	Redimension/N=(numPeak, -1) results
	Make/O/N=(numPeak) sortwave
	sortwave = results[p][6]
	MakeIndex/R sortwave, sortwave
	Duplicate/O results, resultscopy
//Duplicate/O results, root:resultscopy
//Wave resultscopy = root:resultscopy
	results = resultscopy[sortwave[p]][q]
//Duplicate/O results, root:resultsSorted
end

Function TrimAmpPeakInfo(wpi,gMinPeakFraction)
	Wave wpi
	Variable gMinPeakFraction
	
	Variable i= DimSize(wpi,0)-1					// index of last row
	Variable ymin= wpi[0][2]*gMinPeakFraction	// user want peaks to be bigger than this
	
	do
		if( wpi[i][2] < ymin )
			DeletePoints i,i,wpi
		endif
		i -= 1
	while(i>0)

	return DimSize(wpi,0)
end

Function AdjustPeakInfoForX(wpi,yData,xData)
	Wave wpi,yData
	WAVE/Z xData
	
	Variable imax= DimSize(wpi,0),i=0
	do
		if( WaveExists(xData) )
			Variable p0= wpi[i][0]
			Variable pw= wpi[i][1]/2
			wpi[i][0]=xData[p0]
			wpi[i][1]= abs(xData[p0+pw] - xData[p0-pw])
			Variable pLw = wpi[i][3]
			wpi[i][3]= abs(xData[p0] - xData[p0-pLw])
			Variable pRw = wpi[i][4]
			wpi[i][4]= abs(xData[p0-pRw] - xData[p0])
		else
			wpi[i][0]=pnt2x(yData,wpi[i][0])
			wpi[i][1]=  abs(wpi[i][1]*deltax(yData))
			wpi[i][3]=  abs(wpi[i][3]*deltax(yData))
			wpi[i][4]=  abs(wpi[i][4]*deltax(yData))
		endif
		i+=1
	while(i<imax)
end

Function/C EstNoiseAndSmfact(w,pBegin,pEnd)
	Wave w
	Variable pBegin,pEnd
	
	if (abs(pBegin-pEnd) < 10)			// 10 is pretty arbitrary; this is intended to avoid trying to apply this test to unreasonably small waves. Even a 10-point wave is probably a mistake: a fit coefficient wave was selected by mistake or something.
		return cmplx(0,0)
	endif
		
	if( pBegin > pEnd )
		Variable tmp= pBegin
		pBegin= pEnd
		pEnd= tmp
	endif
	
	NewDataFolder/S/O afpTemp
	Duplicate/O/R=[pBegin,pEnd] w,wtmp
	Differentiate wtmp
	Duplicate/O wtmp, wtmpOrigDif

	Make/O/N=1000 hist
	Histogram/B=1 wtmp,hist
	Integrate hist

	FindLevel/Q hist,0.4*hist[999]
	Variable x0= V_LevelX
	FindLevel/Q hist,0.6*hist[999]
	Variable x1= V_LevelX
	Variable noiselevel= abs(2*(x1-x0)*deltax(w))
	Variable snr=(pnt2x(hist, 999)-pnt2x(hist, 0))/(x1-x0)
	
	if( pEnd>=numpnts(w) )
		pEnd= numpnts(w)-1
	endif
	if( pBegin<0 )
		pBegin= 0
	endif
	Variable maxSfact= (pEnd-pBegin+1)/20

	Variable nMaxSF=2* ceil(sqrt(maxSfact))
	Make/O/N=(nMaxSF) wsmdata=0,wsmFact= round((P/2)^2)


	Variable nLin=10
	Variable nSpaced=20
	//print maxSfact
	if( maxSfact<20 )
		nSpaced= 0
		nLin= maxSfact
	endif
	nMaxSF= nLin+nSpaced
	Variable a= (maxSfact-nLin)/nSpaced^2
	Make/O/N=(nMaxSF) wsmdata=0,wsmFact= p+1
	if( nSpaced>0 )
		wsmFact[nLin,*]= ceil(nLin+a*(p-nLin+1)^2)
	endif

	Variable i=1,imax= min(nMaxSF, numpnts(wsmFact))

	wsmdata[0]= snr
	do
		Duplicate/O wtmpOrigDif,wtmp
		Smooth/E=2/B=3 2*wsmFact[i]+1, wtmp
		Histogram/B=1 wtmp,hist
		Integrate hist
		FindLevel/Q hist,0.4*hist[999]
		x0= V_LevelX
		FindLevel/Q hist,0.6*hist[999]
		x1= V_LevelX
		snr= (pnt2x(hist, 999)-pnt2x(hist, 0))/(x1-x0)
		wsmdata[i]= snr
		i+=1
	while(i<imax)
//Duplicate/O wsmdata, root:snrData
//Duplicate/O wsmFact, root:smoothFactors
	WaveStats/Q/R=[2,] wsmdata
	Variable smFact= wsmFact[V_maxloc]

	// added heuristics
//	Variable smFactwpd=0
	do
		if( wsmdata[V_maxloc] < 100 )
			Variable didIt=0
			i=0
			do
				Variable findPeaksReturn = FindPeaks(w,pBegin,pEnd,noiselevel*10,wsmFact[i],1)
//				Variable findPeaksReturnOriginal = AutoFindPeaksOriginal(w,pBegin,pEnd,noiselevel*10,wsmFact[i],1)
//				Variable findPeaksReturnNew = AutoFindPeaksNew(w,pBegin,pEnd,noiselevel*10,wsmFact[i],1)
//print "Smooth Factor:", wsmFact[i], "Original:", findPeaksReturnOriginal, "New:", findPeaksReturnNew
//				if( findPeaksReturnOriginal > 0 )
//				if( findPeaksReturnNew > 0 )
				if( findPeaksReturn > 0 )
					Wave wpd= W_AutoPeakInfo
//					smFactwpd= floor(wpd[0][1]/3)
					smFact= round(wpd[0][1]/3)
					didIt= 1
//	print "TRIAL FIND",wpd[0][1],smFact,i,wsmFact[i],wsmdata[V_maxloc],wsmdata[i]
					break;
				endif
				i+=1
			while(i<imax)
			if( didIt )
				break
			endif
		endif

		// If really low snr and couldn't find a principal peak, force high smooth factors
		if( wsmdata[V_maxloc] < 20 )
			smFact= maxSfact
			break
		endif
		if( wsmdata[V_maxloc] < 30 )
			smFact= round(maxSfact/4)
			break
		endif
		if( wsmdata[V_maxloc] < 50 )
			smFact= round(maxSfact/6)
			break
		endif
	while(0)

	if( smFact < 2 )
		smFact= 2
	endif
	
//	smFact = max(smFact, smFactwpd)

	KillDataFolder :
//SetDataFolder ::
	return cmplx(noiselevel,smFact)
end

// StitchStacks()
// Combines data from all available stacks
// 20140618 KW
//		First version
//		Added markerType wave to change the marker shape of the stitchedPeakPosition plot
//			to differentiate data from different stacks
		
Function StitchStacks()
	// make a stiched folder
	DFREF stackDF = root:ImageStacks
	SetDataFolder stackDF
	NewDataFolder/S/O StitchedStacks
	
	// for each folder in the ImageStacks folder
	Variable stackFolders = CountObjectsDFR(stackDF,4)
	
	// make waves to hold stitched data
	Make/O/N=0 stitchedElapsedTime, stitchedPeakPosition, stitchedpeakPositionErr, stitchedProjectionVsTime, markerType
	WAVE stitchedElapsedTime = stitchedElapsedTime
	WAVE stitchedProjectionVsTime = stitchedPeakPosition
	WAVE stitchedProjectionVsTime = stitchedProjectionVsTime
	WAVE stitchedpeakPositionErr = stitchedpeakPositionErr
	
	SetDataFolder stackDF
	String stackFolderName = ""
	Variable i = 0, initialTime = 0
	for(i=0;i<stackFolders;i+=1)
		stackFolderName = GetIndexedObjNameDFR(stackDF, 4, i)
		
		// append points from the peakPosition, elapsedTime, and projectionVsTime waves
		WAVE frameTime = $(":"+stackFolderName+":frameTime")
		WAVE peakPosition = $(":"+stackFolderName+":peakPosition")
		WAVE projectionVsTime = $(":"+stackFolderName+":projectionVsTime")
		WAVE peakPositionErr = $(":"+stackFolderName+":peakPositionErr")
		
		if( WaveExists( frameTime ) )
			if( numpnts(stitchedElapsedTime) == 0 )
				initialTime = frameTime[0]
			endif
			InsertPoints numpnts(stitchedElapsedTime), numpnts(frameTime), stitchedElapsedTime
			stitchedElapsedTime[numpnts(stitchedElapsedTime)-numpnts(frameTime),] = frameTime[p-(numpnts(stitchedElapsedTime)-numpnts(frameTime))]-initialTime
		endif
		
		if( WaveExists(peakPosition) )
			InsertPoints numpnts(stitchedPeakPosition), numpnts(peakPosition), stitchedPeakPosition, markerType, stitchedpeakPositionErr
			stitchedPeakPosition[numpnts(stitchedPeakPosition)-numpnts(peakPosition),] = peakPosition[p-(numpnts(stitchedPeakPosition)-numpnts(peakPosition))]
			stitchedpeakPositionErr[numpnts(stitchedpeakPositionErr)-numpnts(peakPositionErr),] = peakPositionErr[p-(numpnts(stitchedpeakPositionErr)-numpnts(peakPositionErr))]
			markerType[numpnts(markerType)-numpnts(peakPosition),] = i
		endif
		
		if( WaveExists( projectionVsTime ) )
			if( numpnts(stitchedProjectionVsTime) == 0 )
				Duplicate/O projectionVsTime, stitchedProjectionVsTime
			else
				InsertPoints/M=1 dimsize(stitchedProjectionVsTime,1), dimsize(projectionVsTime,1), stitchedProjectionVsTime
				stitchedProjectionVsTime[][dimsize(stitchedProjectionVsTime,1)-dimsize(projectionVsTime,1),] = projectionVsTime[p][q-(dimsize(stitchedProjectionVsTime,1)-dimsize(projectionVsTime,1))]
			endif
		endif
		
	endfor
	
	DoWindow/K stitchedProjectionVsTime
	NewImage/K=0/N=stitchedProjectionVsTime  stitchedProjectionVsTime
	ModifyImage stitchedProjectionVsTime ctab= {*,*,Rainbow,0}
	ModifyGraph width=360, height={Aspect,0.5}
	MoveWindow 0,0,0,0
	
	DoWindow/K stitchedPeakPosition
	Display/N=stitchedPeakPosition stitchedPeakPosition vs stitchedElapsedTime
	ModifyGraph mode=3
	ModifyGraph zmrkNum(stitchedPeakPosition)={markerType}
	ModifyGraph lowTrip(left)=0.01
	Label left "In-Plane Peak Position"
	Label bottom "Elapsed Time (s)"
	SCP()
	ErrorBars stitchedPeakPosition Y,wave=(stitchedpeakPositionErr,stitchedpeakPositionErr)
		
End

Function GetFrameTimes()
	String fileFilters = "Image Files (*.tif,*.tiff):.tif,.tiff;"
	Variable refNum
	
	NewPath/Q/O dataFolder
	Open/D/R/MULT=1 /P=dataFolder /F=fileFilters refNum

	String imageFileList = S_fileName
	String importedFileList = S_fileName
	
	if(strlen(imageFileList) == 0 )
		print "No files to import"
		return 0
	endif
	
	Variable totalFrames = itemsInList(imageFileList,"\r")
	Make/D/O/N=(totalFrames) frameTime
	
	Variable i = 0
	String filePath
	for(i=0;i<totalFrames;i+=1)
		filePath = StringFromList(i,imageFileList, "\r")
		GetFileFolderInfo/Q filePath
		frameTime[i] = V_creationDate
	endfor
	
End