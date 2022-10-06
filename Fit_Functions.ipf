#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function FET_SquareLaw(w,VD) : FitFunc
	Wave w
	Variable VD

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(VD) = (C0*Z*mu/L)*((VG-VT)*VD-VD^2/2)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ VD
	//CurveFitDialog/ Coefficients 6
	//CurveFitDialog/ w[0] = C0
	//CurveFitDialog/ w[1] = Z
	//CurveFitDialog/ w[2] = mu
	//CurveFitDialog/ w[3] = L
	//CurveFitDialog/ w[4] = VT
	//CurveFitDialog/ w[5] = VG

	return (w[0]*w[1]*w[2]/w[3])*((w[5]-w[4])*VD-VD^2/2)
End