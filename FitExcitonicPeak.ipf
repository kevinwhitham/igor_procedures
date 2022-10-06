#pragma rtGlobals=1		// Use modern global access method.

// History
// 20140131 - KW
// 	Added CalculatePbSConcentration()
// 	Changed CalculatePbSeConcentration() input from diameter to peak wavelength
// 20140216 KW
//		Moved concentration calculation to FitExcitonicPeak(), removed CalculateXXXConcentration() functions
//		reformatted Tag to Textbox
//		Moved citations to function parameter
//		Fixed factor of 8 error (radius vs. diameter) in PbSe concentration calculation (concentrations were 8 times too high)
// 20140520 KW
//		Removed material specific functions, replaced with popup menu selection in dialog
//		Replaced command line data entry with dialog
//		Added CdSe material parameters
// 20140523 KW
//		Added code to remove offset artifact at 800 nm
// 20140524 KW
//		Changed calculation of concentration to subtract offset at highest wavelength (no absorption "zero point")
//		Fixed calculation of HWHM, previous calculation had wrong WL to energy conversion
//		Added density calculation based on bulk material density, assumes spherical particle, does not include ligand mass
// 20140628 KW
//		Moved menu out of Macros
//	20140710 KW
//		Check for x-scaling instead of assuming data is Y wave vs X wave
//		Remove SCP() call, replace with custom graph size
// 20150207 KW
//		Added MolarityFromDensity
//		Changed submenu name from Optical to Nanocrystal

Menu "HELIOS"
	Submenu "Nanocrystal"
		"Fit Excitonic Peak"
		"Molarity from Density", MolarityFromDensity()
	End
End

Function FitExcitonicPeak()

	// Check if the data window is set up correctly
	// Cursor A should be on the gaussian peak from Multi-Peak fit
	Wave fitCurve = CsrWaveRef(A)
	
	// Cursor B should be on the absorbance curve
	Wave absorbance = CsrWaveRef(B)
	Wave wavelength = CsrXWaveRef(B)
	
	
	if( WaveExists(fitCurve) == 0 || WaveExists(absorbance) == 0 || (fitCurve == absorbance) )
		printf "Use Multi-peak Fit first to fit the first excitonic peak.\rPut cursor A on the fit curve.\rPut cursor B on the actual data curve."
		return 0
	endif
	
	String		legendLabel, materialList = "PbS;PbSe;CdSe"
	Variable		dilutionFactor, materialNum
	Prompt		legendLabel, "Sample name: "
	Prompt		dilutionFactor, "Dilution factor: "
	Prompt		materialNum, "Material: ", popup, materialList
	DoPrompt		"Enter sample data", legendLabel, dilutionFactor, materialNum
	
	if(V_flag)
		print "User cancelled FitExcitonicPeak()"
		return 0
	endif
	
	// Create working directory for this analysis
	DFREF saveDF = GetDataFolderDFR()
	NewDataFolder/O/S root:$legendLabel
	
	// Material specific parameters
	// FIT is an expression which gives the diameter in nm calculated using the first excitonic peak position "peakWL"
	// ABS is an expression which gives the wavelength in nm at which the molar extinction coefficient is valid
	//	EXT is an expression which gives the molar extinction coefficient in units of 1/(µM*cm) at the wavelength defined by ABS given by "absWL"
	// DEN is the density of the bulk material in g/cm^3
	String		PbS_param_list = 	"CITE:Moreels, I., ACS Nano 2009;FIT:(-0.283+sqrt(0.283^2-4*0.0252*(0-1/(1240/peakWL-0.41))))/(2*0.0252);ABS:400;EXT:0.0233*(diameter)^3;DEN:8.27"
	String		PbSe_param_list =	"CITE:Moreels, I., Chem Mat., 2007;FIT:(-0.209+sqrt(0.209^2-4*0.016*(0.45-1/(1240/peakWL-0.278))))/(2*0.016);ABS:400;EXT:0.0277*(diameter)^3;DEN:7.60"
	String		CdSe_param_list = 	"CITE:Jasieniak, J., J. Phys. Chem. C, 2009\r(valid 2 to 8 nm);FIT:59.60816-0.54736*peakWL+1.8873e-3*peakWL^2-2.85743e-6*peakWL^3+1.62974e-9*peakWL^4;ABS:peakWL;EXT:1e-6*(155507+6.67054e13*exp((-1240/absWL)/0.10551))/(hwhm_ev/0.06);DEN:5.82"
	String		materialParams
	
	// Get variables according to material
	switch(materialNum)
		case 1:
			materialParams = PbS_param_list
			break
		case 2:
			materialParams = PbSe_param_list
			break
		case 3:
			materialParams = CdSe_param_list
			break
	endswitch
	
	
	String strCitation, diameterFunction, extinctionFunction, absWavelengthFunction	
	strCitation = StringByKey("CITE", materialParams)
	diameterFunction = StringByKey("FIT", materialParams)
	extinctionFunction = StringByKey("EXT", materialParams)
	absWavelengthFunction = StringByKey("ABS", materialParams)
	
	Variable	/G	peakWL, FWHM, diameter, dispersity, absWL, hwhm_ev
	String 		diameterLabel = "Diameter: "
		
	// Check if the absorbance wave is plotted vs calculated
	if( WaveExists(wavelength) == 0 )
		if( deltax(absorbance) == 0 )
			print "No X scaling available"
			return 0
		endif
	else
		// Set scale of absorbance wave in order to fix artifact at 800 nm
		SetScale/I x, wavelength[0], wavelength[numpnts(wavelength)-1], "nm", absorbance
	endif
	
	// Fix artifacts due to detector, grating changes, etc.
	// Assumes there are artifacts at 800 nm
	Variable offset = absorbance[x2pnt(absorbance,800)]-absorbance[x2pnt(absorbance,799)]
	absorbance[x2pnt(absorbance,799),] = absorbance[p]+offset
	
	// Find peak wavelength and FWHM by fitting a gaussian function between cursors A and B
	Make/O/N=(4) fitParams
	Duplicate/O fitCurve, fittedWave
	
	CurveFit/Q/M=2/W=0 gauss, kwCWave=fitParams, fitCurve/D
	RemoveFromGraph $("fit_"+CsrWave(A))
//	ModifyGraph lstyle($("fit_"+CsrWave(A)))=8,lsize($("fit_"+CsrWave(A)))=3;DelayUpdate
//	ModifyGraph rgb($("fit_"+CsrWave(A)))=(0,0,0)
	peakWL = fitParams[2]
	
	// fitParams[3] equals sqrt(2)*sigma, where sigma is the std. dev.
	FWHM = 2*sqrt(2*ln(2))*(fitParams[3]/Sqrt(2))
	dispersity = (fitParams[3]/Sqrt(2))/peakWL*100
	hwhm_ev = (1240/peakWL)*(dispersity/100)*sqrt(2*ln(2))
	
	// Find particle size from 1st excitonic peak energy using an empirical fit
	String setDiameterCmd = ("diameter = "+diameterFunction)
	Execute setDiameterCmd
	
	// Annotate graph
	ModifyGraph margin(left)=54,margin(bottom)=54,width=216,height=216
	String strPeakWL, strFWHM, strHWHM, strDiameter, strDispersity, strTagName
	sprintf strPeakWL "%.0f", peakWL
	sprintf strFWHM "%.0f (nm)", FWHM
	sprintf strHWHM "%.1f (meV)", hwhm_ev*1000
	sprintf strDiameter "%.1f", diameter
	sprintf strDispersity "%.1f", dispersity
	sprintf strTagName "tag_%.0f", peakWL
	
	Textbox/C/N=sample_info_box /A=RC /E=0 /Z=0 /T={108} /F=0  "\\Z09"+legendLabel+"\rMaterial:\t"+StringFromList(materialNum-1,materialList)+"\rPeak\t"+strPeakWL+" (nm)\rFWHM\t"+strFWHM+"\rHWHM\t"+strHWHM+"\rStd.Dev.\t"+strDispersity+"%\r"+diameterLabel+"\t"+strDiameter+" (nm)"
	
	Label bottom "Wavelength (nm)"
	Label left "Absorbance"
	ModifyGraph lblPos(left)=70
	
	Variable/G concentration, extinctionCoeff
	
	Variable smallestWavelength = inf
	
	if( WaveExists(absorbance) == 0 )
		printf "Put cursor A ion the fit curve to calculate size and dispersity.\rPut cursor B on the data curve and make sure the spectrum includes absorbance at 400 nm to calculate concentration."
	else
		if( WaveExists(wavelength) )
			smallestWavelength = min(wavelength[0],wavelength[numpnts(wavelength)-1])
		else
			smallestWavelength = min(leftx(absorbance),rightx(absorbance))
		endif
		
		String setAbsWLCmd = ("absWL = " + absWavelengthFunction)
		Execute setAbsWLCmd
		
		// Calculate concentration if absorbance includes the required wavelength at which the molar extinction coefficient is calculated
		if(  smallestWavelength <= absWL )
			String setExtCoeffCmd = ("extinctionCoeff = " + extinctionFunction)
			Execute setExtCoeffCmd

			// concentration in uM, assume standard path length 1 cm
			// subtract zero offset at absorbance[0], highest wavelength
			// assume there is no scattering background
			concentration = (absorbance(absWL)-absorbance[0])/extinctionCoeff
			
			// Estimate the concentration in mg/mL
			Variable density
			density = concentration*dilutionFactor*1e-6 * 6.022e23 * 1e-3 * (4/3)*pi*(diameter/2*1e-7)^3 * NumberByKey("DEN",materialParams) * 1000
				
			// Annotate graph
			String concStr, initialStr, densityStr
			sprintf concStr "%.3f (µM)", concentration
			sprintf initialStr "%.1f (µM)", concentration*dilutionFactor
			sprintf densityStr "%.1f (mg/mL)", density
				
			AppendText/N=sample_info_box "\\Z09Concentration\t"+concStr+"\rInitial Concentration "+initialStr+"\rEstimated Density\t"+densityStr
		else
			printf "Make sure cursor B is on the data curve and the spectrum includes absorbance at "+num2str(absWL)+" nm\r"
		endif
	endif
		
	AppendText/N=sample_info_box "\\Zr075"+strCitation
	
	SetDataFolder saveDF
	
End

// PbSe: e0 = 0.278, a = 0.016, b = 0.209, c = 0.45
Function CalculateWavelengthFromDiameter(diameter,e0,a,b,c)
	Variable diameter,e0,a,b,c
	Variable peakWL = 1240/(-1/(((diameter*(2*a)+b)^2-b^2)/(-4*a)-c)+e0)
	printf "Peak wavelength: %g (nm)\r",peakWL
	return  peakWL
End


// MolarityFromDensity
// Estimates the molar concentration based on particle and ligand density
// 20150227 KW
//		created
Function MolarityFromDensity()
	Variable diameter, bulk_density, solution_density, ligand_molar_weight, ligand_area
	
	Prompt diameter, 				"Diameter (nm):"
	Prompt bulk_density,			"Bulk Density (g/mL):"
	Prompt solution_density,		"Solution Density (mg/mL):"
	Prompt ligand_molar_weight,	"Ligand molar weight (g/mol):"
	Prompt ligand_area,				"Surface area per ligand (nm^2):"
	DoPrompt "Enter parameters:", diameter, bulk_density, solution_density, ligand_molar_weight, ligand_area
	
	Variable particle_volume	= (4/3)*pi*(1e-7*diameter/2)^3					// diameter in nm
	Variable particle_weight	= particle_volume * bulk_density				// bulk_density in g/mL (g/cm^3)
	Variable ligand_count		= (4*pi*(diameter/2)^2) / ligand_area				// ligand area in nm^2
	Variable ligand_weight		= (ligand_molar_weight / 6.02e23) * ligand_count	// ligand_molar_weight in g/mol
	Variable total_weight		= ligand_weight + particle_weight				// total_weight in grams 
	Variable concentration		= 1e-3 * solution_density / total_weight			// particle_density in mg/mL
	Variable molarity			= 1e3 * concentration / 6.02e23				// concentration in 1/mL
	
	printf "Diameter: %g (nm)\r", diameter
	printf "Bulk Density: %g (g/mL)\r", bulk_density
	printf "Solution Density %g (mg/mL)\r", solution_density
	printf "Ligand Molar Weight: %g (g/mol)\r", ligand_molar_weight
	printf "Effective area per ligand: %g (nm^2)\r", ligand_area
	printf "Ligands per particle: %g\r", ligand_count
	printf "Molarity: %g (M)\r", molarity
	
End