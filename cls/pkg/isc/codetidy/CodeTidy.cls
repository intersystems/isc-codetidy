Include (%occErrors, pkg.isc.codetidy.CodeTidy)

/// Code Cleanup Methods
/// Process class methods and MAC routines
/// Expand / contract / upper  / lower / title case commands, special variables, intrinsic functions and embedded SQL keywords
Class pkg.isc.codetidy.CodeTidy Extends %RegisteredObject
{

/// Process a document - main entry point
ClassMethod Document(InternalName) As %Status
{
	set status = $$$OK
	
    set type = ##class(pkg.isc.codetidy.Assistant).FileType(InternalName)
	set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	
	if type = "class" {
		quit ..Class(Name,1)
	}
	
	if type = "routine" {
		quit ..Routine(Name,1)
	}
	
	if type = "csp" {
		quit ..CSP(InternalName,1)
	}
	
	
	quit status
}

/// Process all methods in a class
ClassMethod Class(pClassName As %String, pSaveChanges = 0) As %Status
{
	set oClass=##class(%Dictionary.ClassDefinition).%OpenId(pClassName,,.tSc)
	if $$$ISERR(tSc) quit tSc
	
	for j=1:1:oClass.Methods.Count() {
		set oMth=oClass.Methods.GetAt(j)
		
		if oMth.CodeMode="expression" continue
		if oMth.ClientMethod {
			do ..ProcessStream(oMth.Implementation,oMth.Language,"Method:"_pClassName_":"_oMth.Name)
		} else {
			do ..ProcessStream(oMth.Implementation,,"Method:"_pClassName_":"_oMth.Name)
		}
	}
	for j=1:1:oClass.Queries.Count() {
		set oQuery=oClass.Queries.GetAt(j)
		//copy to a stream
		set querystream=##class(%Stream.TmpCharacter).%New()
		do querystream.Rewind()
		for jj=1:1:$length(oQuery.SqlQuery,$char(13,10)) {
			do querystream.WriteLine($piece(oQuery.SqlQuery,$char(13,10),jj))
		}
		//process the stream
		do ..ProcessStream(querystream,"SQL","Query:"_pClassName_":"_oQuery.Name)
		//and copy from stream back to string
		do querystream.Rewind()
		set querystring=""
		while 'querystream.AtEnd {
			set line=querystream.ReadLine()
			set querystring=querystring_$select(querystring'="":$char(13,10),1:"")_line
		}
		set oQuery.SqlQuery=querystring
	}
	if pSaveChanges {
		set tSc=oClass.%Save()
		quit tSc
	}
	quit $$$OK
}

/// Process a routine
ClassMethod Routine(pRoutineName As %String, pSaveChanges = 0) As %Status
{
	set oRtn=##class(%Library.Routine).%OpenId(pRoutineName, .tSc)
	do ..ProcessStream(oRtn,,"Routine:"_pRoutineName)
	
	if pSaveChanges {
		set tSc=oRtn.%Save()
		quit tSc
	}
	quit $$$OK
}

/// Process a csp file
ClassMethod CSP(pCspName As %String, pSaveChanges = 0) As %Status
{
	set cspfilename = $system.CSP.GetFileName(pCspName)
	if '##class(%File).Exists(cspfilename) quit $$$FileNotFound
	
	set file = ##class(%File).%New(cspfilename)
	set status = file.Open("RS")
	if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	
	do file.Close()
	//copy from file to stream
	set streamout=##class(%Stream.FileCharacter).%New()
	set streamout.Filename=cspfilename
	
	//replace the stream was HTML
	do ..ProcessStream(streamout,"CSP","CSP:"_pCspName)
	
	if pSaveChanges {
		//write stream back to file
		do streamout.Rewind()
		set status=streamout.%Save()
		if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	}
	
	quit $$$OK
}

/// Process a stream
ClassMethod ProcessStream(ByRef instream, lang = "COS", pInfo)
{
	set outstream=##class(%Stream.TmpCharacter).%New()
	do outstream.Rewind()
	
	set debug=0
	set colorer=##class(%SyntaxColor).%New()
	set flags="PFCE"
	set ret=colorer.Color(instream,.outstream,lang,flags,,,.langs,.coloringerrors)
	if 'ret {write "Fatal error: ",pInfo," ",colorer.DLLResultCode,! quit}
	if coloringerrors {
		write "Syntax error(s):",pInfo,!
		quit
	}
	
	set map("COS",$$$COSFunction,"$a")="$ascii"
	set map("COS",$$$COSFunction,"$ascii")="$ascii"
	set map("COS",$$$COSFunction,"$bit")="$bit"
	set map("COS",$$$COSFunction,"$case")="$case"
	set map("COS",$$$COSFunction,"$c")="$char"
	set map("COS",$$$COSFunction,"$char")="$char"
	set map("COS",$$$COSFunction,"$d")="$data"
	set map("COS",$$$COSFunction,"$data")="$data"
	set map("COS",$$$COSFunction,"$decimal")="$decimal"
	set map("COS",$$$COSFunction,"$double")="$double"
	set map("COS",$$$COSFunction,"$e")="$extract"
	set map("COS",$$$COSFunction,"$extract")="$extract"
	set map("COS",$$$COSFunction,"$f")="$find"
	set map("COS",$$$COSFunction,"$find")="$find"
	set map("COS",$$$COSFunction,"$g")="$get"
	set map("COS",$$$COSFunction,"$get")="$get"
	set map("COS",$$$COSFunction,"$i")="$increment"
	set map("COS",$$$COSFunction,"$increment")="$increment"
	set map("COS",$$$COSFunction,"$j")="$justify"
	set map("COS",$$$COSFunction,"$justify")="$justify"
	set map("COS",$$$COSFunction,"$l")="$length"
	set map("COS",$$$COSFunction,"$length")="$length"
	set map("COS",$$$COSFunction,"$li")="$list"
	set map("COS",$$$COSFunction,"$list")="$list"
	set map("COS",$$$COSFunction,"$locate")="$locate"
	set map("COS",$$$COSFunction,"$match")="$match"
	set map("COS",$$$COSFunction,"$method")="$method"
	set map("COS",$$$COSFunction,"$na")="$name"
	set map("COS",$$$COSFunction,"$name")="$name"
	set map("COS",$$$COSFunction,"$normalize")="$normalize"
	set map("COS",$$$COSFunction,"$now")="$now"
	set map("COS",$$$COSFunction,"$number")="$num"
	set map("COS",$$$COSFunction,"$number")="$number"
	set map("COS",$$$COSFunction,"$o")="$order"
	set map("COS",$$$COSFunction,"$order")="$order"
	set map("COS",$$$COSFunction,"$parameter")="$parameter"
	set map("COS",$$$COSFunction,"$p")="$piece"
	set map("COS",$$$COSFunction,"$piece")="$piece"
	set map("COS",$$$COSFunction,"$property")="$property"
	set map("COS",$$$COSFunction,"$q")="$query"
	set map("COS",$$$COSFunction,"$query")="$query"
	set map("COS",$$$COSFunction,"$r")="$random"
	set map("COS",$$$COSFunction,"$random")="$random"
	set map("COS",$$$COSFunction,"$re")="$reverse"
	set map("COS",$$$COSFunction,"$replace")="$replace"
	set map("COS",$$$COSFunction,"$reverse")="$reverse"
	set map("COS",$$$COSFunction,"$s")="$select"
	set map("COS",$$$COSFunction,"$select")="$select"
	set map("COS",$$$COSFunction,"$stack")="$stack"
	set map("COS",$$$COSFunction,"$t")="$text"
	set map("COS",$$$COSFunction,"$text")="$text"
	set map("COS",$$$COSFunction,"$tr")="$translate"
	set map("COS",$$$COSFunction,"$translate")="$translate"
	set map("COS",$$$COSFunction,"$xecute")="$xecute"
	
	set map("COS",$$$COSCommand,"as")="as"
	set map("COS",$$$COSCommand,"b")="break"
	set map("COS",$$$COSCommand,"break")="break"
	set map("COS",$$$COSCommand,"catch")="catch"
	set map("COS",$$$COSCommand,"c")="close"
	set map("COS",$$$COSCommand,"close")="close"
	set map("COS",$$$COSCommand,"continue")="continue"
	set map("COS",$$$COSCommand,"d")="do"
	set map("COS",$$$COSCommand,"do")="do"
	set map("COS",$$$COSCommand,"e")="else"
	set map("COS",$$$COSCommand,"else")="else"
	set map("COS",$$$COSCommand,"f")="for"
	set map("COS",$$$COSCommand,"for")="for"
	set map("COS",$$$COSCommand,"g")="goto"
	set map("COS",$$$COSCommand,"goto")="goto"
	//leave H as is (due to HANG x   versus HALT)
	set map("COS",$$$COSCommand,"h")="h"
	set map("COS",$$$COSCommand,"hang")="hang"
	set map("COS",$$$COSCommand,"i")="if"
	set map("COS",$$$COSCommand,"if")="if"
	set map("COS",$$$COSCommand,"j")="job"
	set map("COS",$$$COSCommand,"job")="job"
	set map("COS",$$$COSCommand,"k")="kill"
	set map("COS",$$$COSCommand,"kill")="kill"
	set map("COS",$$$COSCommand,"l")="lock"
	set map("COS",$$$COSCommand,"lock")="lock"
	set map("COS",$$$COSCommand,"m")="merge"
	set map("COS",$$$COSCommand,"merge")="merge"
	set map("COS",$$$COSCommand,"n")="new"
	set map("COS",$$$COSCommand,"new")="new"
	set map("COS",$$$COSCommand,"o")="open"
	set map("COS",$$$COSCommand,"open")="open"
	set map("COS",$$$COSCommand,"p")="print"
	set map("COS",$$$COSCommand,"print")="print"
	set map("COS",$$$COSCommand,"q")="quit"
	set map("COS",$$$COSCommand,"quit")="quit"
	set map("COS",$$$COSCommand,"r")="read"
	set map("COS",$$$COSCommand,"read")="read"
	set map("COS",$$$COSCommand,"ret")="ret"
	set map("COS",$$$COSCommand,"return")="return"
	set map("COS",$$$COSCommand,"s")="set"
	set map("COS",$$$COSCommand,"set")="set"
	set map("COS",$$$COSCommand,"throw")="throw"
	set map("COS",$$$COSCommand,"try")="try"
	set map("COS",$$$COSCommand,"ts")="tstart"
	set map("COS",$$$COSCommand,"tstart")="tstart"
	set map("COS",$$$COSCommand,"u")="use"
	set map("COS",$$$COSCommand,"use")="use"
	set map("COS",$$$COSCommand,"v")="view"
	set map("COS",$$$COSCommand,"view")="view"
	set map("COS",$$$COSCommand,"while")="while"
	set map("COS",$$$COSCommand,"w")="write"
	set map("COS",$$$COSCommand,"write")="write"
	set map("COS",$$$COSCommand,"x")="xecute"
	set map("COS",$$$COSCommand,"xecute")="xecute"
	
	
	set map("COS",$$$COSSystemvariable,"$j")="$job"
	set map("COS",$$$COSSystemvariable,"$job")="$job"
	
	//leave as $h...
	set map("COS",$$$COSSystemvariable,"$h")="$h"
	set map("COS",$$$COSSystemvariable,"$horolog")="$h"
	
	set map("COS",$$$COSSystemvariable,"$j")="$job"
	set map("COS",$$$COSSystemvariable,"$job")="$job"
	set map("COS",$$$COSSystemvariable,"$k")="$key"
	set map("COS",$$$COSSystemvariable,"$key")="$key"
	set map("COS",$$$COSSystemvariable,"$ns")="$namespace"
	set map("COS",$$$COSSystemvariable,"$namespace")="$namespace"
	set map("COS",$$$COSSystemvariable,"$principal")="$principal"
	set map("COS",$$$COSSystemvariable,"$roles")="$roles"
	set map("COS",$$$COSSystemvariable,"$s")="$storage"
	set map("COS",$$$COSSystemvariable,"$storage")="$storage"
	set map("COS",$$$COSSystemvariable,"$stack")="$stack"
	set map("COS",$$$COSSystemvariable,"$system")="$system"
	set map("COS",$$$COSSystemvariable,"$t")="$test"
	set map("COS",$$$COSSystemvariable,"$test")="$test"
	set map("COS",$$$COSSystemvariable,"$this")="$this"
	set map("COS",$$$COSSystemvariable,"$username")="$username"
	set map("COS",$$$COSSystemvariable,"$x")="$x"
	set map("COS",$$$COSSystemvariable,"$q")="$quit"
	set map("COS",$$$COSSystemvariable,"$quit")="$quit"

	if ##class(pkg.isc.codetidy.Utils).GetUseCapitals() {
		// Iterate over the current values in map and capitalize them
		for sub = $$$COSFunction, $$$COSCommand, $$$COSSystemvariable {
			set key = $order(map("COS", sub, ""))
			while key '= "" {
				set currentValue = map("COS", sub, key)
				
				if sub = $$$COSCommand {
					set map("COS", sub, key) = $zconvert(currentValue, "w")
				} else {
					set word = $extract(currentValue, 2, *)
					set newValue = "$"_$zconvert(word, "w")
					set map("COS", sub, key) = newValue
				}
				
				set key = $order(map("COS", sub, key))
			}
		}
		// Things that differ in capatilization beyond just the first letter
		set map("COS",$$$COSFunction,"$bitcount")="$BitCount"
		set map("COS",$$$COSFunction,"$bitfind")="$BitFind"
		set map("COS",$$$COSFunction,"$bitlogic")="$BitLogic"
		set map("COS",$$$COSFunction,"$classmethod")="$ClassMethod"
		set map("COS",$$$COSFunction,"$classname")="$ClassName"
		set map("COS",$$$COSFunction,"$fn")="$FNumber"
		set map("COS",$$$COSFunction,"$fnumber")="$FNumber"
		set map("COS",$$$COSFunction,"$isobject")="$IsObject"
		set map("COS",$$$COSFunction,"$isvalidnum")="$IsValidNum"
		set map("COS",$$$COSFunction,"$lb")="$ListBuild"
		set map("COS",$$$COSFunction,"$ld")="$ListData"
		set map("COS",$$$COSFunction,"$lf")="$ListFind"
		set map("COS",$$$COSFunction,"$lfs")="$ListFromString"
		set map("COS",$$$COSFunction,"$lg")="$ListGet"
		set map("COS",$$$COSFunction,"$listbuild")="$ListBuild"
		set map("COS",$$$COSFunction,"$listdata")="$ListData"
		set map("COS",$$$COSFunction,"$listfind")="$ListFind"
		set map("COS",$$$COSFunction,"$listfromstring")="$ListFromString"
		set map("COS",$$$COSFunction,"$listget")="$ListGet"
		set map("COS",$$$COSFunction,"$ll")="$ListLength"
		set map("COS",$$$COSFunction,"$listlength")="$ListLength"
		set map("COS",$$$COSFunction,"$listnext")="$ListNext"
		set map("COS",$$$COSFunction,"$listsame")="$ListSame"
		set map("COS",$$$COSFunction,"$listtostring")="$ListToString"
		set map("COS",$$$COSFunction,"$listvalid")="$ListValid"
		set map("COS",$$$COSFunction,"$lts")="$ListToString"
		set map("COS",$$$COSFunction,"$lv")="$ListValid"
		set map("COS",$$$COSFunction,"$nconvert")="$NConvert"
		set map("COS",$$$COSFunction,"$ql")="$QLength"
		set map("COS",$$$COSFunction,"$qlength")="$QLength"
		set map("COS",$$$COSFunction,"$qs")="$QSubscript"
		set map("COS",$$$COSFunction,"$qsubscript")="$QSubscript"
		set map("COS",$$$COSFunction,"$sconvert")="$SConvert"
		set map("COS",$$$COSFunction,"$sortbegin")="$SortBegin"
		set map("COS",$$$COSFunction,"$sortend")="$SortEnd"
		set map("COS",$$$COSFunction,"$zabs")="$ZAbs"
		set map("COS",$$$COSFunction,"$zb")="$ZBoolean"
		set map("COS",$$$COSFunction,"$zbitget")="$ZBitGet"
		set map("COS",$$$COSFunction,"$zbitlen")="$ZBitLen"
		set map("COS",$$$COSFunction,"$zbitor")="$ZBitOr"
		set map("COS",$$$COSFunction,"$zbitset")="$ZBitSet"
		set map("COS",$$$COSFunction,"$zbitstr")="$ZBitStr"
		set map("COS",$$$COSFunction,"$zboolean")="$ZBoolean"
		set map("COS",$$$COSFunction,"$zconvert")="$ZConvert"
		set map("COS",$$$COSFunction,"$zcrc")="$ZCRC"
		set map("COS",$$$COSFunction,"$zcvt")="$ZConvert"
		set map("COS",$$$COSFunction,"$zconvert")="$ZConvert"
		set map("COS",$$$COSFunction,"$zd")="$ZDate"
		set map("COS",$$$COSFunction,"$zdate")="$ZDate"
		set map("COS",$$$COSFunction,"$zdateh")="$ZDateH"
		set map("COS",$$$COSFunction,"$zdatetime")="$ZDateTime"
		set map("COS",$$$COSFunction,"$zdatetimeh")="$ZDateTimeH"
		set map("COS",$$$COSFunction,"$zdh")="$ZDateH"
		set map("COS",$$$COSFunction,"$zdt")="$ZDateTime"
		set map("COS",$$$COSFunction,"$zdth")="$ZDateTimeH"
		set map("COS",$$$COSFunction,"$zf")="$ZF"
		set map("COS",$$$COSFunction,"$zh")="$ZHex"
		set map("COS",$$$COSFunction,"$zhex")="$ZHex"
		set map("COS",$$$COSFunction,"$ziswide")="$ZIsWide"
		set map("COS",$$$COSFunction,"$zlascii")="$ZLAscii"
		set map("COS",$$$COSFunction,"$zlc")="$ZLC"
		set map("COS",$$$COSFunction,"$zlchar")="$ZLChar"
		set map("COS",$$$COSFunction,"$zlog")="$ZLog"
		set map("COS",$$$COSFunction,"$zname")="$ZName"
		set map("COS",$$$COSFunction,"$zo")="$ZOrder"
		set map("COS",$$$COSFunction,"$zobjclass")="$ZObjClass"
		set map("COS",$$$COSFunction,"$zobjclassmethod")="$ZObjClassMethod"
		set map("COS",$$$COSFunction,"$zobjexport")="$ZObjExport"
		set map("COS",$$$COSFunction,"$zobjmethod")="$ZObjMethod"
		set map("COS",$$$COSFunction,"$zobjproperty")="$ZObjProperty"
		set map("COS",$$$COSFunction,"$zobjval")="$ZObjVal"
		set map("COS",$$$COSFunction,"$zpower")="$ZPower"
		set map("COS",$$$COSFunction,"$zse")="$ZSearch"
		set map("COS",$$$COSFunction,"$zsearch")="$ZSearch"
		set map("COS",$$$COSFunction,"$zstrip")="$ZStrip"
		set map("COS",$$$COSFunction,"$zt")="$ZTime"
		set map("COS",$$$COSFunction,"$zth")="$ZTimeH"
		set map("COS",$$$COSFunction,"$ztime")="$ZTime"
		set map("COS",$$$COSFunction,"$ztimeh")="$ZTimeH"
		set map("COS",$$$COSFunction,"$zu")="$ZUtil"
		set map("COS",$$$COSFunction,"$zutil")="$ZUtil"
		set map("COS",$$$COSFunction,"$zv")="$ZVersion"
		set map("COS",$$$COSFunction,"$zversion")="$ZVersion"
		set map("COS",$$$COSFunction,"$zwascii")="$ZWAscii"
		set map("COS",$$$COSFunction,"$zwc")="$ZWChar"
		set map("COS",$$$COSFunction,"$zwchar")="$ZWChar"
		set map("COS",$$$COSCommand,"elseif")="ElseIf"
		set map("COS",$$$COSCommand,"tc")="TCommit"
		set map("COS",$$$COSCommand,"tcommit")="TCommit"
		set map("COS",$$$COSCommand,"trollback")="TRollback"
		set map("COS",$$$COSCommand,"za")="ZAllocate"
		set map("COS",$$$COSCommand,"zbreak")="ZBreak"
		set map("COS",$$$COSCommand,"zd")="ZDeallocate"
		set map("COS",$$$COSCommand,"zkill")="ZKill"
		set map("COS",$$$COSCommand,"zn")="ZNspace"
		set map("COS",$$$COSCommand,"znspace")="ZNspace"
		set map("COS",$$$COSCommand,"zt")="ZTrap"
		set map("COS",$$$COSCommand,"ztrap")="ZTrap"
		set map("COS",$$$COSCommand,"zw")="ZWrite"
		set map("COS",$$$COSCommand,"zwrite")="ZWrite"
		set map("COS",$$$COSSystemvariable,"$ec")="$EC"
		set map("COS",$$$COSSystemvariable,"$ecode")="$ECode"
		set map("COS",$$$COSSystemvariable,"$i")="$IO"
		set map("COS",$$$COSSystemvariable,"$io")="$IO"
		set map("COS",$$$COSSystemvariable,"$tl")="$TLevel"
		set map("COS",$$$COSSystemvariable,"$tlevel")="$TLevel"
		set map("COS",$$$COSSystemvariable,"$zb")="$ZB"
		set map("COS",$$$COSSystemvariable,"$zc")="$ZC"
		set map("COS",$$$COSSystemvariable,"$zchild")="$ZChild"
		set map("COS",$$$COSSystemvariable,"$ze")="$ZError"
		set map("COS",$$$COSSystemvariable,"$zeof")="$ZEOF"
		set map("COS",$$$COSSystemvariable,"$zerror")="$ZError"
		set map("COS",$$$COSSystemvariable,"$zh")="$ZHorolog"
		set map("COS",$$$COSSystemvariable,"$zhorolog")="$ZHorolog"
		set map("COS",$$$COSSystemvariable,"$zj")="$ZJob"
		set map("COS",$$$COSSystemvariable,"$zjob")="$ZJob"
		set map("COS",$$$COSSystemvariable,"$zn")="$ZName"
		set map("COS",$$$COSSystemvariable,"$zname")="$ZName"
		set map("COS",$$$COSSystemvariable,"$znspace")="$ZNspace"
		set map("COS",$$$COSSystemvariable,"$zparent")="$ZParent"
		set map("COS",$$$COSSystemvariable,"$zpi")="$ZPi"
		set map("COS",$$$COSSystemvariable,"$zr")="$ZReference"
		set map("COS",$$$COSSystemvariable,"$zr")="$ZReference"
		set map("COS",$$$COSSystemvariable,"$zs")="$ZStorage"
		set map("COS",$$$COSSystemvariable,"$zs")="$ZStorage"
		set map("COS",$$$COSSystemvariable,"$zt")="$ZTrap"
		set map("COS",$$$COSSystemvariable,"$zts")="$ZTimestamp"
		set map("COS",$$$COSSystemvariable,"$ztimestamp")="$ZTimestamp"
		set map("COS",$$$COSSystemvariable,"$ztz")="$ZTimezone"
		set map("COS",$$$COSSystemvariable,"$ztimezone")="$ZTimezone"
		set map("COS",$$$COSSystemvariable,"$ztrap")="$ZTrap"
		set map("COS",$$$COSSystemvariable,"$zv")="$ZVersion"
		set map("COS",$$$COSSystemvariable,"$zversion")="$ZVersion"
	} else {
		// Things that differ in capatilization beyond just the first letter
		set map("COS",$$$COSFunction,"$bitcount")="$bitcount"
		set map("COS",$$$COSFunction,"$bitfind")="$bitfind"
		set map("COS",$$$COSFunction,"$bitlogic")="$bitlogic"
		set map("COS",$$$COSFunction,"$classmethod")="$classmethod"
		set map("COS",$$$COSFunction,"$classname")="$classname"
		set map("COS",$$$COSFunction,"$fn")="$fnumber"
		set map("COS",$$$COSFunction,"$fnumber")="$fnumber"
		set map("COS",$$$COSFunction,"$isobject")="$isobject"
		set map("COS",$$$COSFunction,"$isvalidnum")="$isvalidnum"
		set map("COS",$$$COSFunction,"$lb")="$listbuild"
		set map("COS",$$$COSFunction,"$ld")="$listdata"
		set map("COS",$$$COSFunction,"$lf")="$listfind"
		set map("COS",$$$COSFunction,"$lfs")="$listfromstring"
		set map("COS",$$$COSFunction,"$lg")="$listget"
		set map("COS",$$$COSFunction,"$listbuild")="$listbuild"
		set map("COS",$$$COSFunction,"$listdata")="$listdata"
		set map("COS",$$$COSFunction,"$listfind")="$listfind"
		set map("COS",$$$COSFunction,"$listfromstring")="$listfromstring"
		set map("COS",$$$COSFunction,"$listget")="$listget"
		set map("COS",$$$COSFunction,"$ll")="$listlength"
		set map("COS",$$$COSFunction,"$listlength")="$listlength"
		set map("COS",$$$COSFunction,"$listnext")="$listnext"
		set map("COS",$$$COSFunction,"$listsame")="$listsame"
		set map("COS",$$$COSFunction,"$listtostring")="$listtostring"
		set map("COS",$$$COSFunction,"$listvalid")="$listvalid"
		set map("COS",$$$COSFunction,"$lts")="$listtostring"
		set map("COS",$$$COSFunction,"$lv")="$listvalid"
		set map("COS",$$$COSFunction,"$nconvert")="$nconvert"
		set map("COS",$$$COSFunction,"$ql")="$qlength"
		set map("COS",$$$COSFunction,"$qlength")="$qlength"
		set map("COS",$$$COSFunction,"$qs")="$qsubscript"
		set map("COS",$$$COSFunction,"$qsubscript")="$qsubscript"
		set map("COS",$$$COSFunction,"$sconvert")="$sconvert"
		set map("COS",$$$COSFunction,"$sortbegin")="$sortbegin"
		set map("COS",$$$COSFunction,"$sortend")="$sortend"
		set map("COS",$$$COSFunction,"$zabs")="$zabs"
		set map("COS",$$$COSFunction,"$zb")="$zboolean"
		set map("COS",$$$COSFunction,"$zbitget")="$zbitget"
		set map("COS",$$$COSFunction,"$zbitlen")="$zbitlen"
		set map("COS",$$$COSFunction,"$zbitor")="$zbitor"
		set map("COS",$$$COSFunction,"$zbitset")="$zbitset"
		set map("COS",$$$COSFunction,"$zbitstr")="$zbitstr"
		set map("COS",$$$COSFunction,"$zboolean")="$zboolean"
		set map("COS",$$$COSFunction,"$zconvert")="$zconvert"
		set map("COS",$$$COSFunction,"$zcrc")="$zcrc"
		set map("COS",$$$COSFunction,"$zcvt")="$zconvert"
		set map("COS",$$$COSFunction,"$zconvert")="$zconvert"
		set map("COS",$$$COSFunction,"$zd")="$zdate"
		set map("COS",$$$COSFunction,"$zdate")="$zdate"
		set map("COS",$$$COSFunction,"$zdateh")="$zdateh"
		set map("COS",$$$COSFunction,"$zdatetime")="$zdatetime"
		set map("COS",$$$COSFunction,"$zdatetimeh")="$zdatetimeh"
		set map("COS",$$$COSFunction,"$zdh")="$zdateh"
		set map("COS",$$$COSFunction,"$zdt")="$zdatetime"
		set map("COS",$$$COSFunction,"$zdth")="$zdatetimeh"
		set map("COS",$$$COSFunction,"$zf")="$zf"
		set map("COS",$$$COSFunction,"$zh")="$zhex"
		set map("COS",$$$COSFunction,"$zhex")="$zhex"
		set map("COS",$$$COSFunction,"$ziswide")="$ziswide"
		set map("COS",$$$COSFunction,"$zlascii")="$zlascii"
		set map("COS",$$$COSFunction,"$zlc")="$zlc"
		set map("COS",$$$COSFunction,"$zlchar")="$zlchar"
		set map("COS",$$$COSFunction,"$zlog")="$zlog"
		set map("COS",$$$COSFunction,"$zname")="$zname"
		set map("COS",$$$COSFunction,"$zo")="$zorder"
		set map("COS",$$$COSFunction,"$zobjclass")="$zobjclass"
		set map("COS",$$$COSFunction,"$zobjclassmethod")="$zobjclassmethod"
		set map("COS",$$$COSFunction,"$zobjexport")="$zobjexport"
		set map("COS",$$$COSFunction,"$zobjmethod")="$zobjmethod"
		set map("COS",$$$COSFunction,"$zobjproperty")="$zobjproperty"
		set map("COS",$$$COSFunction,"$zobjval")="$zobjval"
		set map("COS",$$$COSFunction,"$zpower")="$zpower"
		set map("COS",$$$COSFunction,"$zse")="$zsearch"
		set map("COS",$$$COSFunction,"$zsearch")="$zsearch"
		set map("COS",$$$COSFunction,"$zstrip")="$zstrip"
		set map("COS",$$$COSFunction,"$zt")="$ztime"
		set map("COS",$$$COSFunction,"$zth")="$ztimeh"
		set map("COS",$$$COSFunction,"$ztime")="$ztime"
		set map("COS",$$$COSFunction,"$ztimeh")="$ztimeh"
		set map("COS",$$$COSFunction,"$zu")="$zutil"
		set map("COS",$$$COSFunction,"$zutil")="$zutil"
		set map("COS",$$$COSFunction,"$zv")="$zversion"
		set map("COS",$$$COSFunction,"$zversion")="$zversion"
		set map("COS",$$$COSFunction,"$zwascii")="$zwascii"
		set map("COS",$$$COSFunction,"$zwc")="$zwchar"
		set map("COS",$$$COSFunction,"$zwchar")="$zwchar"
		set map("COS",$$$COSCommand,"elseif")="elseif"
		set map("COS",$$$COSCommand,"tc")="tcommit"
		set map("COS",$$$COSCommand,"tcommit")="tcommit"
		set map("COS",$$$COSCommand,"trollback")="trollback"
		set map("COS",$$$COSCommand,"za")="zallocate"
		set map("COS",$$$COSCommand,"zbreak")="zbreak"
		set map("COS",$$$COSCommand,"zd")="zdeallocate"
		set map("COS",$$$COSCommand,"zkill")="zkill"
		set map("COS",$$$COSCommand,"zn")="znspace"
		set map("COS",$$$COSCommand,"znspace")="znspace"
		set map("COS",$$$COSCommand,"zt")="ztrap"
		set map("COS",$$$COSCommand,"ztrap")="ztrap"
		set map("COS",$$$COSCommand,"zw")="zwrite"
		set map("COS",$$$COSCommand,"zwrite")="zwrite"
		set map("COS",$$$COSSystemvariable,"$ec")="$ec"
		set map("COS",$$$COSSystemvariable,"$ecode")="$ecode"
		set map("COS",$$$COSSystemvariable,"$i")="$io"
		set map("COS",$$$COSSystemvariable,"$io")="$io"
		set map("COS",$$$COSSystemvariable,"$tl")="$tlevel"
		set map("COS",$$$COSSystemvariable,"$tlevel")="$tlevel"
		set map("COS",$$$COSSystemvariable,"$zb")="$zb"
		set map("COS",$$$COSSystemvariable,"$zc")="$zc"
		set map("COS",$$$COSSystemvariable,"$zchild")="$zchild"
		set map("COS",$$$COSSystemvariable,"$ze")="$zerror"
		set map("COS",$$$COSSystemvariable,"$zeof")="$zeof"
		set map("COS",$$$COSSystemvariable,"$zerror")="$zerror"
		set map("COS",$$$COSSystemvariable,"$zh")="$zhorolog"
		set map("COS",$$$COSSystemvariable,"$zhorolog")="$zhorolog"
		set map("COS",$$$COSSystemvariable,"$zj")="$zjob"
		set map("COS",$$$COSSystemvariable,"$zjob")="$zjob"
		set map("COS",$$$COSSystemvariable,"$zn")="$zname"
		set map("COS",$$$COSSystemvariable,"$zname")="$zname"
		set map("COS",$$$COSSystemvariable,"$znspace")="$znspace"
		set map("COS",$$$COSSystemvariable,"$zparent")="$zparent"
		set map("COS",$$$COSSystemvariable,"$zpi")="$zpi"
		set map("COS",$$$COSSystemvariable,"$zr")="$zreference"
		set map("COS",$$$COSSystemvariable,"$zr")="$zreference"
		set map("COS",$$$COSSystemvariable,"$zs")="$zstorage"
		set map("COS",$$$COSSystemvariable,"$zs")="$zstorage"
		set map("COS",$$$COSSystemvariable,"$zt")="$ztrap"
		set map("COS",$$$COSSystemvariable,"$zts")="$ztimestamp"
		set map("COS",$$$COSSystemvariable,"$ztimestamp")="$ztimestamp"
		set map("COS",$$$COSSystemvariable,"$ztz")="$ztimezone"
		set map("COS",$$$COSSystemvariable,"$ztimezone")="$ztimezone"
		set map("COS",$$$COSSystemvariable,"$ztrap")="$ztrap"
		set map("COS",$$$COSSystemvariable,"$zv")="$zversion"
		set map("COS",$$$COSSystemvariable,"$zversion")="$zversion"
	}
	
	do outstream.Rewind()
	
	set (htmlLastType,htmlLastFrag)=""
	set nlcount=0
	
	while 'outstream.AtEnd {
		set line=outstream.ReadLine()
		set tLang=$piece(line,",",1)
		set tType=$piece(line,",",2)
		set tCodeFragment=$piece(line,",",3,*)
		
		if tLang="\n" {
			//count consecutive new lines
			//if more than 3 (i.e. 2 blank lines in a row) then ignore any subsequent ones
			//seems to add extra blank lines around the 32K mark for large methods - so this stops the proliferation
			set nlcount=nlcount+1
			if nlcount<4 do instream.WriteLine()
			continue
		} else {
			set nlcount=0
		}
		
		if tLang="COS" {
			set (htmlLastType,htmlLastFrag)=""
			//##Class
			if tType=$$$COSObjectClass {
				do instream.Write("##class")
				continue
			}
			//&SQL etc....  watch out - also includes <> () ## forms
			if tType=$$$COSSQL {
				set cfl=$zconvert(tCodeFragment,"U")
				do instream.Write(cfl)
				continue
			}
			if tType=$$$COSJavascript {
				set cfl=$zconvert(tCodeFragment,"L")
				if cfl="js" set cfl="javascript"
				do instream.Write(cfl)
				continue
			}
			if tType=$$$COSHTML {
				set cfl=$zconvert(tCodeFragment,"L")
				do instream.Write(cfl)
				continue
			}
			if tType=$$$COSPreProcessorCommand {
				set cfl=$zconvert(tCodeFragment,"L")
				do instream.Write(cfl)
				continue
			}
			if tType=$$$COSComment {
				set cfl=tCodeFragment
				//leave the ;; as there may be some code which still requires it
				if $extract(tCodeFragment,1)=";",$extract(tCodeFragment,1,2)'=";;" set cfl="//"_$extract(tCodeFragment,2,*)
				if $extract(tCodeFragment,1,2)="//" set cfl="//"_$extract(tCodeFragment,3,*)
				if $extract(tCodeFragment,1,2)="##;" set cfl="//"_$extract(tCodeFragment,4,*)
				do instream.Write(cfl)
				continue
			}
			//FUNCTION
			if tType=$$$COSFunction {
				set cfl=$zconvert(tCodeFragment,"L")
				//capture any missing ones to add to the list
				
				set function=$get(map(tLang,tType,cfl),cfl)
				//always lower case
				do instream.Write(function)
				continue
			}
			//COMAND
			set (htmlLastType,htmlLastFrag)=""
			if tType=$$$COSCommand {
				set cfl=$zconvert(tCodeFragment,"l")
				
				//capture any missing ones to add to the list
				set command=$get(map(tLang,tType,cfl),cfl)
				//title case
				
				do instream.Write(command)
				continue
			}
			//SPECIAL VARIABLES
			set (htmlLastType,htmlLastFrag)=""
			if tType=$$$COSSystemvariable {
				set cfl=$zconvert(tCodeFragment,"l")
				
				//capture any missing ones to add to the list
				set var=$get(map(tLang,tType,cfl),cfl)
				//always lower case
				do instream.Write(var)
				continue
			}
			do instream.Write(tCodeFragment)
		} elseif tLang="SQL" {
			set cfl=$zconvert(tCodeFragment,"u") //!!
			// we get every literal and classname, column etc if we do this.
			//SELECT || BY FROM GROUP WHERE
			if tType=$$$SQLStatementkeyword || (tType=$$$SQLQualifierkeyword) || (tType=$$$SQLOperator) {
				do instream.Write(cfl)
			} else {
				do instream.Write(tCodeFragment)
			}
		} elseif tLang="HTML" {
			//<head></head>
			//<csp:parameter> - :parameter part seems to be case insensitive too
			if tType=$$$HTMLTag {
				set cfl=$zconvert(tCodeFragment,"L")
				if cfl="server" {
					set cfl="script"
					if htmlLastType=$$$HTMLDelimiter,htmlLastFrag'="/" set cfl=cfl_" language="""_$$$langObjectScript_""" runat=""server"""
				}
				do instream.Write(cfl)
				set htmlLastType=tType,htmlLastFrag=tCodeFragment
				continue
			}
			set htmlLastType=tType,htmlLastFrag=tCodeFragment
			do instream.Write(tCodeFragment)
		} else {
			do instream.Write(tCodeFragment)
		}
		
	}
}

}
