Class pkg.isc.codetidy.extension.Utils
{

/// Corrects internal names for routines with slashes instead of dots, as a workaround for PL 145107
ClassMethod CorrectInternalNames(pInternalNames As %String = "") As %String
{
	set tInternalNames = $listfromstring(pInternalNames,",")
	set tModifiedList = ""
	set tPtr = 0
	while $listnext(tInternalNames,tPtr,tInternalName) {
		if ($extract(tInternalName) = "/") {
			// See if this is a valid CSP resource
			set tAppName = $system.CSP.GetAppName(tInternalName)
			if (tAppName = "") {
				// Replace slashes with dots
				set tInternalName = $replace($extract(tInternalName,2,*),"/",".")
				
				// Convert extension to upper case
				set $piece(tInternalName,".",*) = $zconvert($piece(tInternalName,".",*),"U")
			}
		} else {
			// Convert extension to upper case
			set $piece(tInternalName,".",*) = $zconvert($piece(tInternalName,".",*),"U")
		}
		set tModifiedList = tModifiedList_$listbuild(tInternalName)
	}
	quit $listtostring(tModifiedList,",")
}

}

