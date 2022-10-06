#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ConvertToBornAgainFormat()

	// Hard code these wavenames from FitGISAXS for now
	Wave imagePhi = root:twothetaf
	Wave imageTheta = root:alphaf
	
	if( WaveExists(CsrWaveRef(A)) == 0 || WaveExists(CsrWaveRef(B)) == 0 )
		print "Place cursors A and B on the GISAXS image at the crop points"
		return 0
	endif
	
	Wave imageWave = CsrWaveRef(A)
	
	Variable minH, maxH, minV, maxV
	minH = min(pcsr(A),pcsr(B))
	maxH = max(pcsr(A),pcsr(B))
	minV = min(qcsr(A),qcsr(B))
	maxV = max(qcsr(A),qcsr(B))
	
	Make/FREE/N=(1,maxH-minH+1) phiVector		// horizontal
	Make/FREE/N=(1,maxV-minV+1) thetaVector	// vertical

	phiVector = imagePhi[minH+q]*pi/180			// convert to radians
	thetaVector = imageTheta[minV+q]*pi/180	// convert to radians
	
	Make/FREE/N=((maxH-minH+1),(maxV-minV+1)) croppedImage
	croppedImage = imageWave[minH+p][minV+q]
	
	if( numpnts(croppedImage) != (numpnts(phiVector)*numpnts(thetaVector)) )
		print "index vectors don't match image size, trying to truncate scaling vectors"
	endif
	
	Variable fileRef
	Open fileRef as "refdata.txt"	
	String fileName = S_fileName
	
	fprintf  fileRef, "# 2D scattering data\n# shape %d %d\r# 0-axis [phi]\n",dimsize(croppedImage,0),dimsize(croppedImage,1)
	
	Close fileRef
	
	Save/A=2/J/M="\n" phiVector as (fileName)

	Open/A fileRef as fileName
	
	fprintf fileRef, "# 1-axis [theta]\n"

	Close fileRef
	
	Save/A=2/J/M="\n" thetaVector as (fileName)
	
	Open/A fileRef as fileName
	
	fprintf fileRef, "# data\n"
	
	Close fileRef
	
	Save/A=2/J/M="\n" croppedImage as (fileName)
	
End

// Set the scale of top graph showing an image from BornAgain (32 bit Tiff)
// all angles in degrees
// phi_max = largest in-plane scattering angle
// alpha_max = largest out of plance scattering factor
// alpha_i = incident angle
// wavelength_nm = duh
Function ShowBornAgainImage(phi_min, phi_max,alpha_min, alpha_max, alpha_i, wavelength_nm)
	Variable phi_min, phi_max, alpha_min, alpha_max, alpha_i, wavelength_nm
	
	Variable qx_min, qx_max, qy_min, qy_max
	
	// Get the images selected in the data browser
	String itemName
	Variable i
	itemName=GetBrowserSelection(i)
	if (strlen(itemName)>0)

		do
			itemName=GetBrowserSelection(i)
			if(strlen(itemName)<=0)
				break
			endif
			
			Wave image = $itemName
			
			qx_min = 2*pi/wavelength_nm * sin(phi_min*pi/180)
			qx_max = 2*pi/wavelength_nm*sin(phi_max*pi/180)
			
			qy_min = 2*pi/wavelength_nm*(sin(alpha_min*pi/180) + sin(alpha_i*pi/180))
			qy_max = 2*pi/wavelength_nm*( sin(alpha_max*pi/180) + sin(alpha_i*pi/180))
			
			SetScale/I x qx_min,qx_max,"nm\S-1\M",  image
			
			// images are flipped vertically by default
			SetScale/I y qy_max,qy_min ,"nm\S-1\M", image
			
			// /F puts horizonatal axis on bottom
			NewImage/F image
			
			SetAxis left qy_min,qy_max	
			Label left "\\Z09\\F'Helvetica'q\\B\\F'Symbol'^\\M\\Z09\\F'Helvetica' (\\u)"
			
			SetAxis bottom qx_min, qx_max
			Label bottom "\\F'Helvetica'\\Z09q\\B||\\M\\F'Helvetica'\\Z09 (\\u)"
			
			// set the color scale
			ModifyImage $nameOfWave(image) ctab= {126,*,Geo,0}
			ModifyImage $nameOfWave(image) log=1
			
			// Change graph size, style
			ModifyGraph gFont="Helvetica"
			ModifyGraph margin=26
			ModifyGraph width=85,height={Aspect,1},gfSize=9
			ModifyGraph btLen =1.667,btThick=0.5,stLen=1,stThick=0.5
			ModifyGraph ftLen =1,ftThick=0.5,ttLen=1,ttThick=0.5

			i+=1
		
		while(1)
	
	else  //this is if there are no selected items in the browser
		Print "Select wave(s) in the data browser"
	endif
	
	
	
End