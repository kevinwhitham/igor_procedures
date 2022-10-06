#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Proc nature_style() : GraphStyle
	PauseUpdate; Silent 1		// modifying window...
	// Width should be 230 - (margin(left) + margin(right))
	ModifyGraph/Z margin(left)=43,margin(bottom)=36,margin(right)=7,width=180,height=120
	ModifyGraph/Z font="Helvetica"
	ModifyGraph/Z fSize=9
	ModifyGraph/Z lowTrip(left)=1
	ModifyGraph/Z axThick=0.5
	ModifyGraph/Z notation(left)=1
	ModifyGraph/Z axRGB=(13107,13107,13107)
	ModifyGraph/Z lblPosMode(bottom)=3
	ModifyGraph/Z lblPos=30
	ModifyGraph/Z useTSep(bottom)=1
	ModifyGraph/Z btLen=1.67
	ModifyGraph/Z btThick=0.25
	ModifyGraph/Z stLen=1
	ModifyGraph/Z stThick=0.25
	ModifyGraph/Z ttLen=1
	ModifyGraph/Z ttThick=0.25
	ModifyGraph/Z ftLen=1
	ModifyGraph/Z ftThick=0.25
	ModifyGraph/Z tlOffset=2
	ModifyGraph tick=0,btLen=1.67,btThick=0.25
	ModifyGraph tlOffset=2
	ModifyGraph/Z mirror(bottom)=2
	ModifyGraph/Z mirror(left)=2
	ChangeAnnotationFontSize(9)
	ChangeAnnotationFont("Helvetica")
	ModifyGraph lsize=1
EndMacro