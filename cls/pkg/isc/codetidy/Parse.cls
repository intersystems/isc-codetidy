Include (%occStatus, pkg.isc.codetidy.CodeTidy)

Class pkg.isc.codetidy.Parse [ Abstract ]
{

/// This Parameter is updated by Perforce
Parameter SrcVer = "$Id: //projects/AppServices/OpenExchange/zpm/isc.codetidy/latest/cls/pkg/isc/codetidy/Parse.cls#2 $";

ClassMethod ParseDocument(InternalName As %String, RemoveTraps As %Boolean = 0, ByRef Output As %String) As %Status
{
	set status = $$$OK
	set type = ..FileType(InternalName)
	
	if type = "class" {
		if $increment(Output(".fileCount"))
		#; Open the class definition.
		set classDef = ##class(%Dictionary.ClassDefinition).%OpenId($piece(InternalName, ".", 1, $length(InternalName, ".") - 1),,.sc)
		
		if $$$ISOK(sc) {
			#; Iterate the methods from the class.
			set methodKey = ""
			for  {
				set method = classDef.Methods.GetNext(.methodKey)
				if methodKey = "" quit  //
				kill methodTokens

				set resultSetVars = ""
				if RemoveTraps {
					set code = ##class(%Stream.TmpCharacter).%New()

					// Get all variables in the method that are of type %ResultSet
					set commandParser = ##class(pkg.isc.codetidy.vartyping.CommandParser).%New(classDef.Name, method.Name, $namespace)
					do commandParser.GoToEndOfMethod()
					merge methodTokens = commandParser.Tokens
					do method.Implementation.Rewind()
					do commandParser.VariableTracker.OutputVars(.vars)
					set key = $order(vars(""))
					while key '= "" {
						set var = vars(key)
						set type = var.Type
						if (var.Type '= "") && $$$comClassDefined(var.Type) && $classmethod(var.Type, "%Extends", "%SQL.StatementResult") {
							set resultSetVars = resultSetVars _ $listbuild(key)
						}
						set key = $order(vars(key))
					}
				}
				do ..ParseCode(InternalName, method.Name, method.Implementation, .Output, .code, resultSetVars, .methodTokens)
				
				#; Replace the existing stream.
				if RemoveTraps {
					do code.Flush()
					set method.Implementation = code
				}
			}
			
			if RemoveTraps {
				#; Save the changes.
				set status = classDef.%Save()
				if $$$ISERR(status) {
					do $system.Status.DisplayError(status)
				}
			}
		} else {
			quit sc
		}
	} elseif type = "routine" {
		if $increment(Output(".fileCount"))
		#; Open the routine definition.
		set routineDef = ##class(%RoutineMgr).%OpenId(InternalName)
		
		if $isobject(routineDef) {
			#; Check for basic code.  Basic will use different indentation rules.
			set language = $case(routineDef.LanguageModeGet(),9:"basic",:"cache")
			
			if RemoveTraps set code = ##class(%Stream.TmpCharacter).%New()
			do ##class(pkg.isc.codetidy.vartyping.COSTokenizer).GetRoutineImplementation(InternalName, .tokens, $namespace)
			do ..ParseCode(InternalName, routineDef.Name, routineDef.Code, .Output, .code, "", .tokens)
			
			#; Replace the existing stream.
			if RemoveTraps {
				do code.Flush()
				set routineDef.Code = code
				
				#; Save the changes.
				set status = routineDef.%Save()
				if $$$ISERR(status) {
					write !, routineDef.%Id(), $char(9), routineDef.Name
					do $system.Status.DisplayError(status)
				}
			}
		} else {
			quit $$$ERROR($$$GeneralError, "Unable to open routine")
		}
	} elseif type = "javascript" {
	}
	quit status
}

ClassMethod ParseCode(InternalName As %String, Label As %String, inputCode As %CharacterStream, ByRef Output As %String, ByRef outputCode As %CharacterStream, ResultSetVars As %List = "", Tokens As %List = "") As %Status
{
	set removeTraps = $isobject($get(outputCode))
	kill len
	set lineText = inputCode.ReadLine(.len)
	for  {
		if $increment(lineCount)
		set originalText = lineText
		set strippedText = $zstrip(lineText,"<>W")
		
		if removeTraps {
			#; Apply code changes that should always be used.
			kill msgType
			set msgText = ""
			
			#; %request.Get -> $Get(%request.Data
			#; set charIndex = $find(lineText, "%request.Get(")
			#; if charIndex {
			#; 	set msgType("PERF")=""
			#; 	set msgText = msgText_$listbuild("$Get(%request.Data(""X"",1)) improves performance")
			#; 	set endIndex = $find(lineText, ")", charIndex)
			#; 	if endIndex {
			#; 		#; The second parameter to %request.Get is the default value.
			#; 		set params = $extract(lineText,charIndex,endIndex-2)
			#; 		set lineText = $extract(lineText, 1, charIndex-14)_"$g(%request.Data("_$piece(params,",")_",1)"_$select($length(params,",")>1:","_$piece(params,",",2),1:"")_")"_$extract(lineText, endIndex, *)
			#; 	}
			#; }
			
			#; %session.Get -> $Get(%session.Data
			#; set charIndex = $find(lineText, "%session.Get(")
			#; if charIndex {
			#; 	set msgType("PERF")=""
			#; 	set msgText = msgText_$listbuild("$Get(%session.Data(""X"")) improves performance")
			#; 	set endIndex = $find(lineText, ")", charIndex)
			#; 	if endIndex {
			#; 		#; The second parameter to %session.Get is the default value.
			#; 		set params = $extract(lineText,charIndex,endIndex-2)
			#; 		set lineText = $extract(lineText, 1, charIndex-14)_"$g(%session.Data("_$piece(params,",")_")"_$select($length(params,",")>1:","_$piece(params,",",2),1:"")_")"_$extract(lineText, endIndex, *)
			#; 		write !,lineText
			#; 	}
			#; }
			
			#; rs.GetDataByName( -> $Get(rs.Data(
			#; The functionality should be extended to cater for any variable names.
			#; set charIndex = $find(lineText, ".GetDataByName(")
			#; if charIndex {
			#; 	set msgType("PERF")=""
			#; 	set msgText = msgText_$listbuild("$Get(rs.Data(col)) improves performance")
			#; 	set endIndex = $find(lineText, ")", charIndex)
			#; 	set columnName = $extract(lineText,charIndex,endIndex-2)
			#; 	#; Get the %ResultSet variable
			#; 	set var = ""
			#; 	for charIndex = charIndex-16:-1:0 {
			#; 		set varChar=$extract(lineText,charIndex)
			#; 		if varChar'?1(1A,1N) quit
			#; 		set var = varChar_var
			#; 	}
			#; 	if endIndex {
			#; 		set lineText = $extract(lineText, 1, charIndex)_"$g("_var_".Data("_columnName_"))"_$extract(lineText, endIndex, *)
			#; 	}
			#; }
			
			#; rs.Get( -> $Get(rs.Data(
			#; This now caters to any variable with the %ResultSet type
			#; set pointer = 0
			#; while $listnext(ResultSetVars, pointer, var) {
			#; 	set charIndex = $find(lineText, var_".Get(")
			#; 	if charIndex {
			#; 		set msgType("PERF")=""
			#; 		set msgText = msgText_$listbuild("$get("_var_".Data(col)) improves performance")
			#; 		set endIndex = $find(lineText, ")", charIndex)
			#; 		if endIndex {
			#; 			set lineText = $extract(lineText, 1, charIndex-6-$length(var))_"$g("_var_".Data("_$extract(lineText,charIndex,endIndex-2)_"))"_$extract(lineText, endIndex, *)
			#; 		}
			#; 	}
			#; }
			
			#; cursor:hand -> cursor:pointer
			#if $system.Version.GetMajor()>5
				set alteredText = $replace(lineText, "cursor:hand", "cursor:pointer")
				set alteredText = $replace(lineText, "cursor: hand", "cursor:pointer")
			#else
				set outputText = "cursor:pointer"
				set alteredText=lineText
				for inputText = "cursor:hand", "cursor: hand" {
					set pos=1
					for {
						set pos=$find(alteredText,inputText,pos)
						if pos=0 quit
						set alteredText=$extract(alteredText,1,pos-$length(inputText)-1)_outputText_$extract(alteredText,pos,$length(alteredText))
					}
				}
			#endif
			if alteredText '= lineText {
				set lineText = alteredText
				set msgType("COMPAT")=""
				set msgText = msgText_$listbuild("cursor:hand is not standards compliant")
			}
			
			#; d obj.%Close() -> k obj
			if strippedText?.E1(1"d ",1"do ").A1".%Close()".E {
				set charIndex = $find(lineText, ".%Close()")
				#; Check the character following %Close() is not a comma.
				#; This is to avoid changing from:
				#;  d objA.%Close(),objB.Method(par) to:
				#;  k obj,objB.Method(par)
				if $extract(lineText,charIndex)'="," {
					set msgType("PERF")=""
					set msgText = msgText_$listbuild("%Close doesn't close an object")
					set lineText = $extract(lineText, 1, charIndex-10)_$extract(lineText, charIndex, *)
					set lineText = $reverse(lineText)
					#; Get the character before the reversed variable name
					set charIndex = $length(lineText) - (charIndex - 10)
					set pos = $find($zconvert(lineText,"L"), " d", charIndex)
					if pos {
						#; Change 'D' to 'Kill'
						set lineText = $extract(lineText, 1, pos-3)_" lliK"_$extract(lineText, pos, *)
						set lineText = $reverse(lineText)
					} else {
						set pos = $find($zconvert(lineText,"L"), " od", charIndex)
						if pos {
							#; Change 'Do' to 'Kill'
							set lineText = $extract(lineText, 1, pos-4)_" lliK"_$extract(lineText, pos, *)
							set lineText = $reverse(lineText)
						} else {
							#; 'Do' not found. No change can be applied.
							set lineText=originalText
						}
					}
				}
			}
			
			#; $ZOBJ<xxx> Functions Replaced
			set pos = $find($zconvert(lineText,"L"),"$zobjclassmethod")
			if pos {
				set msgType("UPD")=""
				set msgText = msgText_$listbuild("$ZOBJ<xxx> Functions Replaced")
				set lineText = $extract(lineText,1,pos-17)_"$ClassMethod"_$extract(lineText,pos,*)
			}
			set pos = $find($zconvert(lineText,"L"),"$zobjmethod")
			if pos {
				set msgType("UPD")=""
				set msgText = msgText_$listbuild("$ZOBJ<xxx> Functions Replaced")
				set lineText = $extract(lineText,1,pos-12)_"$Method"_$extract(lineText,pos,*)
			}
			set pos = $find($zconvert(lineText,"L"),"$zobjproperty")
			if pos {
				set msgType("UPD")=""
				set msgText = msgText_$listbuild("$ZOBJ<xxx> Functions Replaced")
				set lineText = $extract(lineText,1,pos-14)_"$Property"_$extract(lineText,pos,*)
			}
			set pos = $find($zconvert(lineText,"L"),"$zobjclass")
			if pos {
				set msgType("UPD")=""
				set msgText = msgText_$listbuild("$ZOBJ<xxx> Functions Replaced")
				set lineText = $extract(lineText,1,pos-11)_"$ClassName"_$extract(lineText,pos,*)
			}
			
			#; Check output line for syntax errors.
			set syntaxErr=$zutil(62, 1, $zstrip(lineText,"<W", "."))
			if syntaxErr'="" {
				set lineText = originalText
			}
			
			#; // or ; comments -> macro comments #;
			if ##class(pkg.isc.codetidy.Utils).GetUseMacroComments() {
				if $extract(strippedText) = ";" {
					set msgType("PERF")=""
					set msgText = msgText_$listbuild("Macro comments improve performance")
					#; Get the index of the character after the semi-colon.
					set charIndex = $find(lineText, ";")
					set lineText = $extract(lineText, 1, charIndex-2)_"#;"_$extract(lineText, charIndex, *)
				} elseif $extract(strippedText,1,2) = "//" {
					set msgType("PERF")=""
					set msgText = msgText_$listbuild("Macro comments improve performance")
					#; Get the index of the character after the double forward slash.
					set charIndex = $find(lineText, "//")
					set lineText = $extract(lineText, 1, charIndex-3)_"#;"_$extract(lineText, charIndex, *)
				}
			}
			
			#; User notification of code changes.
			#; Peformed prior to comment conversion.
			if originalText'=lineText {
				set (displayText,type) = ""
				for  {
					set type=$order(msgType(type))
					if type = "" quit
					
					set displayText = displayText_type_":"
				}
				set displayText = displayText_" "_$listtostring(msgText,",")_$char(13,10)_" TEXT: "_$zstrip(lineText, "<W")
				write !, InternalName_"("_Label_"+"_lineCount_"): "_displayText
				if $increment(Output(".trapCount"))
			}
		}
		
		kill len
		set nextLineText = inputCode.ReadLine(.len)
		#; if '..IsDebugLine(lineText, removeTraps) {
		#; 	if removeTraps {
		#; 		#; Apply standard brace usage.
		#; 		set code = ##class(pkg.isc.codetidy.Assistant).StripCode(strippedText, $$$langObjectScript) ##; Code excludes comment and quoted values
		#; 		set strippedCode = $zstrip(code, "<>W")
		#; 		set strippedNextText = $zstrip(nextLineText,"<>W")
		#; 		set output = lineText, writeOutput = 1
				
		#; 		#; E.g. 	statement }
		#; 		#;      else {
		#; 		#; ->   	statement
		#; 		#;      } else {
		#; 		if ($extract(strippedCode,*)="}")&&($extract(strippedText,*)="}")&&(
		#; 			($extract($zconvert(strippedNextText,"L"),1,4)="else")
		#; 			|| ($extract($zconvert(strippedNextText,"L"),1,5)="catch")) {
		#; 			if $extract(strippedText,1,*-1) '= "" {
		#; 				set output = $extract($zstrip(lineText,">W"),1,*-1)
		#; 			}
		#; 			for charIndex = 1:1:$length(lineText) {
		#; 				if $extract(lineText,charIndex)'?1(1" ",1"	") quit
		#; 			}
		#; 			if $extract(strippedText,1,*-1) '= "" {
		#; 				set nextLineIndent = $char(9)_$extract(lineText,1,charIndex-$case($length(lineText,"{")#2,1:3,:2))
		#; 				set nextLineText = nextLineIndent_"} "_strippedNextText
		#; 			} else {
		#; 				#; Join closing brace and next line.
		#; 				set output = $zstrip(lineText,">W")_" "_strippedNextText
						
		#; 				#; Read next line.
		#; 				kill len
		#; 				set nextLineText = inputCode.ReadLine(.len)
		#; 			}
					
		#; 			set lineText = output
		#; 			set strippedText = $zstrip(lineText,"<>W")
		#; 			set code = ##class(pkg.isc.codetidy.Assistant).StripCode(strippedText, $$$langObjectScript) ##; Code excludes comment and quoted values
		#; 			set strippedCode = $zstrip(code, "<>W")
		#; 			set strippedNextText = $zstrip(nextLineText,"<>W")
		#; 		}
				
		#; 		#; E.g. if condition { statement
		#; 		#; ->   if condition {
		#; 		#;          statement
		#; 		if (strippedCode["{") && ($extract(strippedCode,*)'="{") && ($length(strippedCode,"{")'=$length(strippedCode,"}")) {
		#; 			set output = $piece(lineText,"{")_"{"
					
		#; 			for charIndex = 1:1:$length(lineText) {
		#; 				if $extract(lineText,charIndex)'?1(1" ",1"	") quit
		#; 			}
					
		#; 			#; Immediate output of line to support processing the rest of the line.
		#; 			do outputCode.WriteLine(output)
		#; 			set output = $extract(lineText,1,charIndex-1)_$char(9)_$zstrip($piece(lineText,"{",2,*),"<W")
					
		#; 			set lineText = output
		#; 			set strippedText = $zstrip(lineText,"<>W")
		#; 			set code = ##class(pkg.isc.codetidy.Assistant).StripCode(strippedText, $$$langObjectScript) ##; Code excludes comment and quoted values
		#; 			set strippedCode = $zstrip(code, "<>W")
		#; 		}
				
		#; 		#; E.g. 	statement } 
		#; 		#; ->   	statement
		#; 		#;      } 
		#; 		if (strippedCode'="}") && (strippedCode["}") && ($length(strippedCode,"}")'=$length(strippedCode,"{")) && ($piece(strippedText,"}")'="") {
		#; 			set output = $piece(lineText,"}")
					
		#; 			for charIndex = 1:1:$length(lineText) {
		#; 				if $extract(lineText,charIndex)'?1(1" ",1"	") quit
		#; 			}
		#; 			set output = output _ $char(13,10) _ $char(9)_$extract(lineText,1,charIndex-3)_"} "_$zstrip($piece(lineText,"}",2,*),"<W")
					
		#; 			set lineText = output
		#; 			set strippedText = $zstrip(lineText,"<>W")
		#; 			set code = ##class(pkg.isc.codetidy.Assistant).StripCode(strippedText, $$$langObjectScript) ##; Code excludes comment and quoted values
		#; 			set strippedCode = $zstrip(code, "<>W")
		#; 		}
				
		#; 		#; E.g. if condition
		#; 		#;      {
		#; 		#; ->   if condition {
		#; 		// Make sure that the last character is not [ or , for dynamic objects
		#; 		set lastChar = $extract(strippedCode, $length(strippedCode))
		#; 		if (strippedNextText="{") && ($length(strippedCode) = $length(strippedText)) && (lastChar '= "[") && (lastChar '= ",") {
		#; 			set nextLineText = $zstrip(lineText,">W") _ " {"
		#; 			set strippedNextText = $zstrip(nextLineText,"<>W")
		#; 			set writeOutput = 0, lineText = "", strippedText = "", code = "", strippedCode = ""
		#; 		}

		#; 		/*
		#; 		Applies for if and else
		#; 		if condition
		#; 			statement
		#; 		 ->
		#; 		if condition {
		#; 			statement
		#; 		}
		#; 		*/
		#; 		set lastChar = $extract(strippedCode, *)
		#; 		// account for stripped code ending in comment
		#; 		set offset = 0
		#; 		while ((lastChar = "/") || (lastChar = " ")) && (offset < $length(strippedCode)) {
		#; 			set offset = $increment(offset)
		#; 			set lastChar = $extract(strippedCode, * - offset)
		#; 		}
		#; 		set firstCharNextLine = $extract(strippedNextText)
		#; 		set lastCharNextLine = $extract(strippedNextText, *)
		#; 		if ((lastChar '= "{") && (firstCharNextLine '= "{") && (lastCharNextLine '= ";")) {
		#; 			set splitString = $listfromstring(strippedCode, " ")
		#; 			if splitString '= "" {
		#; 				if ($list(splitString, 1) = "}") && ($listlength(splitString) >= 2) {
		#; 					set command = $list(splitString, 2)
		#; 				} else {
		#; 					set command = $list(splitString, 1)
		#; 				}

		#; 				if ((command = "if") || (command = "else")) && '..HasMultipleCommands(strippedCode) {
		#; 					set output = lineText_" {"
		#; 					set nextLineText = nextLineText_"}"
		#; 				}
		#; 			}
		#; 		}
				
		#; 		if writeOutput {
		#; 			do outputCode.WriteLine(output)
		#; 		}
		#; 	}
		#; } else {
		#; 	write !, InternalName_"("_Label_"+"_lineCount_"): "_$zstrip(lineText, "<W")
		#; 	if $increment(Output(".trapCount"))
		#; }
		
		if len = -1 quit
		set lineText = nextLineText
	}
}

ClassMethod HasMultipleCommands(line As %String) As %Boolean
{
	set newStream = ##class(%Stream.TmpCharacter).%New()
	// make sure there is whitespace, that way stripped code can be passed into this method
	// without errors
	do newStream.Write("    ")
	do newStream.Write(line)
	set sc = ##class(%Library.SyntaxColorReader).FromCode(newStream,"COS","A",.reader)
	do reader.NextLine(.testTokens)

	set numCommands = 0
	set pointer = 0
	while $listnext(testTokens, pointer, token) {
		if $list(token, 2) = "Command" {
			set numCommands = $increment(numCommands)
			if (numCommands = 2) return 1
		}
	}
	return 0
}

ClassMethod IsDebugLine(line As %String, IncludeCommentedCode As %Boolean = 0) As %Boolean
{
	set lineLower = $zconvert($zstrip(line, "<W", "."), "L")
	#; Take just the first four characters into account.
	#; This approach that should only remove lines that immediately set debug information.
	#; Some programs have debug sets embeded in program logic.
	#; E.g. i $g(x) s ^zTRAK("CAT",0)=$H q  ;
	set lineFragment = $extract(lineLower, 1, 4)
	set isDebug=(lineFragment="s ^z"||(lineFragment="m ^z")&&(lineLower'["^zpatch")&&(lineLower'["^zupgrade")&&(lineLower'["^zbuild")&&(lineLower'["^zdatetr")&&(lineLower'["^zssc"))
	
	if IncludeCommentedCode,'isDebug {
		if $extract(lineLower)=";" {
			set commentLine = $zstrip($extract(lineLower,2,*),"<W")
		} elseif $case($extract(lineLower,1,2),"#;":1,"//":1,:0) {
			set commentLine = $zstrip($extract(lineLower,3,*),"<W")
		}
		
		#; Check the line is not null and doesn't begin with comment characters.
		if $get(commentLine)'="",$extract(commentLine)'=";",$case($extract(commentLine,1,2),"#;":0,"//":0,:1) {
			#; Check for commented out line of code.
			set syntaxErr=$zutil(62, 1, commentLine)
			if syntaxErr="" set isDebug=1
		}
	}
	quit isDebug
}

/// helper function to determine project item type
ClassMethod FileType(InternalName As %String) As %String [ Private ]
{
	if $zconvert(InternalName,"U")[".CLS" quit "class"
	if $zconvert(InternalName,"U")[".CSP" quit "csp"
	if $zconvert(InternalName,"U")[".CSR" quit "csp"
	if $zconvert(InternalName,"U")[".PRJ" quit "project"
	if $zconvert(InternalName,"U")[".INC" quit "routine"
	if $zconvert(InternalName,"U")[".INT" quit "routine"
	if $zconvert(InternalName,"U")[".MAC" quit "routine"
	if $zconvert(InternalName,"U")[".BAS" quit "routine"
	if $zconvert(InternalName,"U")[".JS"  quit "javascript"
	quit "other"
}

}
