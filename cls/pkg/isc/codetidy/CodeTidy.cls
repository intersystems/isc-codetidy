Include (%occErrors, pkg.isc.codetidy.CodeTidy)

/// Code Cleanup Methods
/// Process class methods and MAC routines
/// Expand / contract / upper  / lower / title case commands, special variables, intrinsic functions and embedded SQL keywords
Class pkg.isc.codetidy.CodeTidy Extends %RegisteredObject
{

Parameter DEBUG = 0;

/// Process a document - main entry point
ClassMethod Document(InternalName) As %Status
{
	set status = $$$OK
	
	set type = ##class(pkg.isc.codetidy.Assistant).FileType(InternalName)
	set Name = $piece(InternalName, ".", 1, $length(InternalName, ".")-1)
	
	if type = "class" {
		quit ..Class(Name, 1)
	}
	
	if type = "routine" {
		quit ..Routine(Name, 1)
	}
	
	if type = "csp" {
		quit ..CSP(InternalName, 1)
	}
	
	
	quit status
}

/// Process all methods in a class
ClassMethod Class(pClassName As %String, pSaveChanges = 0) As %Status
{
	set oClass = ##class(%Dictionary.ClassDefinition).%OpenId(pClassName, , .tSc)
	if $$$ISERR(tSc) quit tSc
	
	set sqlSchemaName = $$DetermineSchemaName^%occClass(pClassName)
	for j = 1:1:oClass.Methods.Count() {
		set oMth = oClass.Methods.GetAt(j)
		
		if oMth.CodeMode = "expression" continue
		if oMth.ClientMethod {
			do ..ProcessStream(oMth.Implementation, oMth.Language, "Method:" _ pClassName _ ":" _ oMth.Name)
		} else {
			do ..ProcessStream(oMth.Implementation, , "Method:" _ pClassName _ ":" _ oMth.Name)
		}
	}
	for j = 1:1:oClass.Queries.Count() {
		set oQuery = oClass.Queries.GetAt(j)
		// copy to a stream
		set querystream = ##class(%Stream.TmpCharacter).%New()
		do querystream.Rewind()
		for jj = 1:1:$length(oQuery.SqlQuery, $char(13, 10)) {
			do querystream.WriteLine($piece(oQuery.SqlQuery, $char(13, 10), jj))
		}
		// process the stream
		do ..ProcessStream(querystream, "SQL", "Query:" _ pClassName _ ":" _ oQuery.Name)
		// and copy from stream back to string
		do querystream.Rewind()
		set querystring = ""
		while 'querystream.AtEnd {
			set line = querystream.ReadLine()
			set querystring = querystring _ $select(querystring '= "":$char(13, 10), 1:"")_line
		}
		set oQuery.SqlQuery = querystring
	}
	for j = 1:1:oClass.Triggers.Count() {
		set triggerDefinition = oClass.Triggers.GetAt(j)
		
		// Copy to a stream
		set triggerStream = ##class(%Stream.TmpCharacter).%New()
		do triggerStream.Rewind()
		
		set lineCount = $length(triggerDefinition.Code, $char(13, 10))
		for lineNumber = 1:1:lineCount {
			do triggerStream.WriteLine($piece(triggerDefinition.Code, $char(13, 10) , lineNumber) )
		}
		// Process the stream
		do ..ProcessStream(triggerStream, triggerDefinition.Language, sqlSchemaName, "Trigger:" _ pClassName _ ":" _ triggerDefinition.Name)
		// and copy from stream back to string
		do triggerStream.Rewind()
		set triggerString = ""
		while 'triggerStream.AtEnd {
			set line = triggerStream.ReadLine()
			set triggerString = triggerString _ $select(triggerString '= "":$char(13, 10) , 1:"") _ line
		}
		set triggerDefinition.Code = triggerString
	}
	if pSaveChanges {
		set tSc = oClass.%Save()
		quit tSc
	}
	quit $$$OK
}

/// Process a routine
ClassMethod Routine(pRoutineName As %String, pSaveChanges = 0) As %Status
{
	set oRtn = ##class(%Library.Routine).%OpenId(pRoutineName, .tSc)
	do ..ProcessStream(oRtn, , "Routine:" _ pRoutineName)
	
	if pSaveChanges {
		set tSc = oRtn.%Save()
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
	// copy from file to stream
	set streamout = ##class(%Stream.FileCharacter).%New()
	set streamout.Filename = cspfilename
	
	// replace the stream was HTML
	do ..ProcessStream(streamout, "CSP", "CSP:" _ pCspName)
	
	if pSaveChanges {
		// write stream back to file
		do streamout.Rewind()
		set status = streamout.%Save()
		if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	}
	
	quit $$$OK
}

/// Process a stream
ClassMethod ProcessStream(ByRef instream As %AbstractStream, lang As %String = "COS", sqlSchemaName As %String = "", pInfo As %String = "")
{
	set outstream = ##class(%Stream.TmpCharacter).%New()
	do outstream.Rewind()
	
	set debug = 0
	set colorer = ##class(%SyntaxColor).%New()
	set flags = "PFCE"
	set ret = colorer.Color(instream, .outstream, lang, flags, , , .langs, .coloringerrors)
	if 'ret {
		write "Fatal error: ", pInfo, " ", colorer.DLLResultCode, ! quit
	}
	if coloringerrors {
		write "Syntax error(s):", pInfo, !
		quit
	}
	
	do ..InitialiseMap()
	
	do outstream.Rewind()

	// Each line of syntax stream is broken down into Language, Type, and Fragment.
	// We will keep track of the last, current (this) and next values.
	set (last("Lang"), last("Type"), last("Frag")) = ""
	set (last("NonSpaceLang"), last("NonSpaceType"), last("NonSpaceFrag")) = ""
	set (this("Lang"), this("Type"), this("Frag")) = ""
	set (next("Lang"), next("Type"), next("Frag")) = ""
	// Manipulations are temporarily kept as converted fragment and built up into a converted line of code.
	set (last("Line"), conv("Frag"), conv("Line")) = ""
	set (last("LineStripped"), conv("LineStripped")) = ""
	set this("Indent") = 0, next("Indent") = 0
	set this("SyntaxStream") = outstream, this("AtEnd") = 0
	set conv("PostConditional") = 0, conv("JSSwitch") = 0, conv("JSONSwitch") = 0, conv("PatternMatch") = 0
	set conv("CodeStream") = instream

	if ##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() {
		// SQL Schema is used in execution plan analysis
		set conv("SQLSchema") = $get(sqlSchemaName)
	}
	
	set newLineCount = 0, atEnd = 0
	for {
		// All syntax data processed
		if this("AtEnd") quit
		do ..ReadFragment(.last, .this, .next)
		
		if this("Lang") = "\n" {
			// Count consecutive new lines
			// if more than 3 (i.e. 2 blank lines in a row) then ignore any subsequent ones
			// seems to add extra blank lines around the 32K mark for large methods - so this stops the proliferation
			set newLineCount = newLineCount + 1
			
			if newLineCount > 3 continue
			
			do ..ParseLine(.last, .this, .next, .conv)
			continue
			
		} else {
			// Reset count of consecutive new lines
			set newLineCount = 0
		}
		
		do ..ParseFragment(.last, .this, .next, .conv)
	}

	if lang = "SQL" {
		if $data(conv("SQL")) {
			if ((##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 1) && $get(conv("SQLPLAN")))
			|| (##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 2) {
				// Calculate SQL Execution Plan
				do ..InsertQueryPlan(.last, .this, .next, .conv)
			}
			kill conv("SQL"), conv("SQLPLAN")
			
		}
	}
}

ClassMethod InsertQueryPlan(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	set schema = conv("SQLSchema")
	merge sql = conv("SQL")
	do ..GetSQLPlan(.sql, schema, .plan)
	for i = 1:1 {
		if '$data(plan(i)) quit
		if plan(i) = "</sql>" quit
	}
	for i = i + 1:1 {
		if '$data(plan(i)) quit
		if plan(i) = "</plan>" quit
		if plan(i) = "</module>" continue
		if plan(i) = "<frozenPlan />" continue
		
		// Use current indent + 1 because current indent will match the closing bracket.
		set indent = ##class(pkg.isc.codetidy.Utils).GetIndentString() _ $translate($justify("", this("Indent") + 1), $char(32), $char(9))
		if $piece(plan(i), " ") = "<cost" {
			do conv("CodeStream").WriteLine(indent _ "-- ; Relative Cost = " _ $piece(plan(i), """", 2))
			do conv("CodeStream").WriteLine(indent _ "-- ; ")
		} elseif $piece(plan(i), " ") = "<module" {
			do conv("CodeStream").WriteLine(indent _ "-- ; ")
			do conv("CodeStream").WriteLine(indent _ "-- ; ** Module " _ $piece(plan(i), """", 2) _ " ** ")
		} else {
			do conv("CodeStream").WriteLine(indent _ "-- ; " _ plan(i))
		}
	}
}

/// Output line to converted stream.
ClassMethod WriteLine(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	do conv("CodeStream").WriteLine(conv("Line"))
	do ..ProgressLine(.last, .this, .next, .conv)
	quit
}

/// Move to next line.
ClassMethod ProgressLine(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	set last("Line") = conv("Line")
	set conv("Line") = ""
	set last("LineStripped") = conv("LineStripped")
	set conv("LineStripped") = ""
	quit
}

ClassMethod ParseLine(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() {
		// Exclude existing execution plan as comment.
		if $extract($zstrip(conv("Line"), "<W"), 1, 4) = "-- ;" {
			set conv("SQLPLAN") = 1
			do ..ProgressLine(.last, .this, .next, .conv)
			quit
		}
	}
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		set multiLineCommand = 0
		
		// Ignore comments by referencng LineStripped
		// Use an extra indent for multi-line commands
		if last("Lang") = "COS" {
			set firstChar = $extract($zstrip(conv("LineStripped"), "<W"), 1)
			set multiLineCommand = (firstChar '= "")
			&& ('conv("JSONSwitch"))
			&& ('$get(conv("Bracket", ")")))
			&& ($case(last("Lang"), "COS":",_&|", "SQL":"", :",") [ firstChar)
			&& ($case(last("NonSpaceType"), $$$COSSQL:0, $$$COSHTML:0, $$$COSJavascript:0, $$$COSEmbeddingOpen:0, $$$COSEmbeddingClose:0, :1))
		}
		
		if 'multiLineCommand {
			set lastWord = $piece($zstrip(last("LineStripped"), ">W"), " ", *)
			set lastChar = $extract($zstrip(last("LineStripped"), ">W"), *)
			set multiLineCommand = (lastChar '= "")
			&& ('conv("JSONSwitch"))
			&& ('$get(conv("Bracket", ")")))
			&& ($case(last("Lang"), "COS":",_&|(", "SQL":"", :",") [ lastChar)
		}
		
		if ..#DEBUG, $increment(%debug) < 1000 write this("Indent"), ":", next("Indent"), ":", multiLineCommand, ":", conv("Line"), !
		
		set indentString = ##class(pkg.isc.codetidy.Utils).GetIndentString()
		set indented = ($extract(conv("Line"), 1, $length(indentString)) = indentString)
		if (indented) && (last("Lang") '= "HTML") {
			// Indentation
			set conv("Frag") = indentString _ $replace($justify("", this("Indent") + multiLineCommand), $char(32), indentString)
			set conv("Line") = conv("Frag") _ $extract(conv("Line"), 1+$length(indentString), *)
		} else {
			// Ignore indentation for ObjectScript line labels
			// NOTE: Reference last language as "this" is the new line with no language.
			if (last("Lang") = "COS") {
				set next("Indent") = 0
			}
		}
	}
	
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		set this("Indent") = this("Indent") + next("Indent")
		set next("Indent") = 0
	}
	
	do ..WriteLine(.last, .this, .next, .conv)
}

/// newLine is an optional parameter which can be used to insert fragements 
ClassMethod InsertFragment(ByRef last, ByRef this)
{
	set last("Lang") = this("Lang")
	set last("Type") = this("Type")
	set last("Frag") = this("Frag")
	if this("Type") '= $$$COSWhiteSpace {
		set last("NonSpaceLang") = this("Lang")
		set last("NonSpaceType") = this("Type")
		set last("NonSpaceFrag") = this("Frag")
	}
}

ClassMethod ReadFragment(ByRef last, ByRef this, ByRef next)
{
	set thisIsWhiteSpace = 0
	set nextIsWhiteSpace = 0

	set last("Lang") = this("Lang")
	set last("Type") = this("Type")
	set last("Frag") = this("Frag")
	if this("Type") '= $$$COSWhiteSpace {
		set last("NonSpaceLang") = this("Lang")
		set last("NonSpaceType") = this("Type")
		set last("NonSpaceFrag") = this("Frag")
	}
	
	set this("Lang") = next("Lang")
	set this("Type") = next("Type")
	set this("Frag") = next("Frag")

	// Prevent auto-indentation of embedded HTML
	if (this("Type") = $$$HTMLWhiteSpace) && (this("Lang") = "HTML") {
		set this("Type") = $$$HTMLText
	}
	
	if 'this("SyntaxStream").AtEnd {
		// Get next code fragment, combining white space characters
		set mixedIndent = 1
		while mixedIndent {
			set nextLine = this("SyntaxStream").ReadLine()
			set next("Lang") = $piece(nextLine, ",", 1)
			set next("Type") = $piece(nextLine, ",", 2)
			set next("Frag") = $piece(nextLine, ",", 3, *)

			// Checks if "next" is a different white space character than "this" and combines
			set thisIsWhiteSpace = ($extract(this("Frag")) = $c(9)) || ($extract(this("Frag")) = $c(32))
			set nextIsWhiteSpace = ($extract(next("Frag")) = $c(9)) || ($extract(next("Frag")) = $c(32))
			set mixedIndent = (thisIsWhiteSpace) && (nextIsWhiteSpace)
			if mixedIndent {
				set this("Frag") = this("Frag") _ next("Frag")
			}
		}
	} else {
		set this("AtEnd") = 1
	}

	// Resume auto-indentation at close of embedded block
	if (($extract(this("Frag")) = $c(32)) || ($extract(this("Frag")) = $c(9))) && (next("Lang") [ "COS") && (next("Frag") = ">") {
		set this("Type") = $$$HTMLWhiteSpace
	}
	
	if ..#DEBUG, $data(nextLine) write nextLine, !
}

ClassMethod ParseFragment(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	// Indentation
	if $case(this("Lang"),
		"COS":$case(this("Type"), $$$COSWhiteSpace:1, :0),
		"CSS":$case(this("Type"), $$$CSSWhiteSpace:1, $$$CSSCstyleComment:1, :0),
		"HTML":$case(this("Type"), $$$HTMLWhiteSpace:1, $$$HTMLComment:1, :0),
		"JAVASCRIPT":$case(this("Type"), $$$JAVASCRIPTWhiteSpace:1, $$$JAVASCRIPTComment:1, :0),
		"SQL":$case(this("Type"), $$$SQLWhiteSpace:1, $$$SQLComment:1, :0),
		:0)
	&& (conv("Line") = "") {
		// Whitespace
		if ##class(pkg.isc.codetidy.Utils).GetIndent() {
			// Indentation applied with the line
			set conv("Line") = conv("Line") _ ##class(pkg.isc.codetidy.Utils).GetIndentString() _ $zstrip(this("Frag"), "<W")
		} else {
			set conv("Line") = conv("Line") _ this("Frag")
		}
		// Note whitespace in SQL statements
		if (this("Lang") = "SQL") && ($data(conv("SQL"))) {
			set conv("SQL", $increment(conv("SQL"))) = this("Frag")
		}
		quit
	}
	
	if this("Lang") = "COS" {
		do ..ParseFragmentCOS(.last, .this, .next, .conv)
		
	} elseif this("Lang") = "SQL" {
		do ..ParseFragmentSQL(.last, .this, .next, .conv)
		
	} elseif this("Lang") = "JAVASCRIPT" {
		do ..ParseFragmentJS(.last, .this, .next, .conv)
		
	} elseif this("Lang") = "HTML" {
		do ..ParseFragmentHTML(.last, .this, .next, .conv)
		
	} else {
		set conv("Line") = conv("Line") _ this("Frag")
	}
	
	// Maintain line excluding comments
	if ($case(this("Lang") _ ":" _ this("Type"), "COS:" _ $$$COSComment:0, "HTML:" _ $$$HTMLComment:0, "JAVASCRIPT:" _ $$$JAVASCRIPTComment:0, "SQL:"_$$$SQLComment:0, :1)) {
		set conv("LineStripped") = conv("LineStripped") _ this("Frag")
	}
}

ClassMethod ApplyIndentation(ByRef this, ByRef next, ByRef conv, OpenChars As %String = "{(", CloseChars As %String = "})")
{
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		if OpenChars [ this("Frag") {
			set next("Indent") = next("Indent") + 1
			if (this("Type") = $$$COSJSONBracket) {
				do $increment(conv("JSONSwitch", "braceCount"))
				set conv("JSONSwitch") = 1
			}
			if (this("Type") = $$$JAVASCRIPTDelimiter)
			&& conv("JSSwitch")
			&& (this("Frag") = "{") {
				if $increment(conv("JSSwitch", conv("JSSwitch"), "braceCount"))
			}
			
		} elseif CloseChars [ this("Frag") {
			set i = 1
			if (this("Type") = $$$JAVASCRIPTDelimiter)
			&& conv("JSSwitch")
			&& (this("Frag") = "}") {
				if $increment(conv("JSSwitch", conv("JSSwitch"), "braceCount"), -1)
				if conv("JSSwitch", conv("JSSwitch"), "braceCount") = 0 {
					set i = 2
					if $increment(conv("JSSwitch"), -1)
				}
			}
			if conv("JSONSwitch") && (this("Type") = $$$COSJSONBracket) {
				if $increment(conv("JSONSwitch", "braceCount"), -1)
				if conv("JSONSwitch", "braceCount") = 0 {
					set conv("JSONSwitch") = 0
				}
			}
			if conv("Line") = ##class(pkg.isc.codetidy.Utils).GetIndentString() {
				set this("Indent") = this("Indent") - i
			} else {
				set next("Indent") = next("Indent") - i
			}
		}
	}
}

ClassMethod ParseFragmentCOS(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		// Indentation Adjustments
		if (this("Type") = $$$COSBrace) || (this("Type") = $$$COSJSONBracket) || (this("Type") = $$$COSJSONDelimiter) {
			do ..ApplyIndentation(.this, .next, .conv, "({[", "]})")
		}
	}
	// Embedding Languages
	if (this("Type") = $$$COSEmbeddingOpen) {
		set this("Type") = last("Type")
		set conv("Embedding") = last("Type")
	}
	if (this("Type") = $$$COSEmbeddingClose) {
		set this("Type") = conv("Embedding")
	}
	
	// ##class
	if this("Type") = $$$COSObjectClass {
		set conv("Frag") = this("Frag")
		set conv("Line") = conv("Line") _ "##class"
		quit
	}
	// &sql
	
	if this("Type") = $$$COSSQL {
		set conv("Frag") = this("Frag")
		if ##class(pkg.isc.codetidy.Utils).GetSQLCase() '= "" {
			set conv("Frag") = $zconvert(conv("Frag"), ##class(pkg.isc.codetidy.Utils).GetSQLCase())
		}
		if ##class(pkg.isc.codetidy.Utils).GetIndent() {
			do ..ApplyIndentation(.this, .next, .conv, "(", ")")
			do ..ApplyIndentation(.this, .next, .conv, "(", ")")
		}
		
		// To force insertion of SQL execution plan separate COSSQL open and close.
		if (this("Type") = $$$COSSQL) && (this("Frag") = ")") {
			if (##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 2) {
				if (..UseSQLPlan(conv("SQLCommand"))) && (last("NonSpaceLang") '= "\n") {
					// Note existing values
					set temp("This", "Lang") = this("Lang")
					set temp("This", "Type") = this("Type")
					set temp("This", "Frag") = this("Frag")
					set temp("Conv", "Frag") = conv("Frag")
					
					// Insert new line and opening whitespace
					set this("Lang") = "\n"
					set this("Type") = this("Lang")
					set this("Frag") = ""
					do ..InsertFragment(.last, .this)
					do ..ParseLine(.last, .this, .next, .conv)
					
					set this("Lang") = this("Lang")
					set this("Type") = $case(this("Lang"),
						"COS":$$$COSWhiteSpace,
						"CSS":$$$CSSWhiteSpace,
						"HTML":$$$HTMLWhiteSpace,
						"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace,
						"SQL":$$$SQLWhiteSpace,
						:"")
					set this("Frag") = ##class(pkg.isc.codetidy.Utils).GetIndentString()
					do ..InsertFragment(.last, .this)
					do ..ParseFragment(.last, .this, .next, .conv)
					
					// Restore Frag to be appended to conv("Line")
					// Strip leading white space as the fragment will start on a new line.
					set conv("Frag") = $zstrip(temp("Conv", "Frag"), "<W")
					// Restore this values to reflect sequence
					set this("Lang") = temp("This", "Lang")
					set this("Type") = temp("This", "Type")
					set this("Frag") = temp("This", "Frag")
				}
			}
			if $data(conv("SQL")) {
				if ((##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 1) && $get(conv("SQLPLAN")))
				|| (##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 2) {
					// Calculate SQL Execution Plan
					do ..InsertQueryPlan(.last, .this, .next, .conv)
				}
				kill conv("SQL"), conv("SQLPLAN")
			}
		}
		
		set conv("Line") = conv("Line") _ conv("Frag")
		
		// To force insertion of SQL execution plan the embedded SQL
		// open and close tags will be moved to separate lines.
		if (##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() = 2) {
			if (this("Type") = $$$COSSQL) && (this("Frag") = "(") {
				set conv("SQLCommand") = $zconvert(next("Frag"), "U")
				if (..UseSQLPlan(conv("SQLCommand"))) {
					// Ignore subsequent whitespace
					set currentWhiteSpace = ""
					while $case(next("Lang"),
						"COS":next("Type") = $$$COSWhiteSpace,
						"CSS":next("Type") = $$$CSSWhiteSpace,
						"HTML":next("Type") = $$$HTMLWhiteSpace,
						"JAVASCRIPT":next("Type") = $$$JAVASCRIPTWhiteSpace,
						"SQL":next("Type") = $$$SQLWhiteSpace,
						:"") {
						do ..ReadFragment(.last, .this, .next)
						set currentWhiteSpace = currentWhiteSpace _ this("Frag")
					}
					
					if next("Lang") '= "\n" {
						// Insert new line and opening whitespace
						set this("Lang") = "\n"
						set this("Type") = ""
						set this("Frag") = ""
						do ..InsertFragment(.last, .this)
						do ..ParseLine(.last, .this, .next, .conv)
						
						set this("Lang") = this("Lang")
						set this("Type") = $case(this("Lang"),
							"COS":$$$COSWhiteSpace,
							"CSS":$$$CSSWhiteSpace,
							"HTML":$$$HTMLWhiteSpace,
							"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace,
							"SQL":$$$SQLWhiteSpace,
							:"")
						set this("Frag") = ##class(pkg.isc.codetidy.Utils).GetIndentString()
						do ..InsertFragment(.last, .this)
						do ..ParseFragment(.last, .this, .next, .conv)
					}
				}
			}
		}
		quit
	}
	// &javascript
	if this("Type") = $$$COSJavascript {
		set conv("Frag") = this("Frag")
		if $zconvert(conv("Frag"), "L") = "js" set conv("Frag") = "javascript"
		if ##class(pkg.isc.codetidy.Utils).GetUseCapitals() = 0 {
			set conv("Frag") = $zconvert(conv("Frag"), "l")
		} else {
			set conv("Frag") = $zconvert(conv("Frag"), "w")
		}
		do ..ApplyIndentation(.this, .next, .conv, "<", ">")
		
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	// &html
	if this("Type") = $$$COSHTML {
		set conv("Frag") = $zconvert(this("Frag"), "L")
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	if this("Type") = $$$COSPreProcessorCommand {
		set conv("Frag") = $zconvert(this("Frag"), "L")
		set conv("Line") = conv("Line") _ conv("Frag")
		if ##class(pkg.isc.codetidy.Utils).GetIndent() {
			if $case(this("Frag"), "if":1, "ifdef":1, "ifndef":1, :0)  {
				set next("Indent") = next("Indent") + 1
			} elseif $case(this("Frag"), "else":1, "elseif":1, :0) {
				set this("Indent") = this("Indent") - 1
				set next("Indent") = next("Indent") + 1
			} elseif $case(this("Frag"), "endif":1, :0) {
				set this("Indent") = this("Indent") - 1
			}
		}
		quit
	}
	if this("Type") = $$$COSComment {
		set conv("Frag") = this("Frag")
		do ..ParseFragmentCOSComment(.last, .this, .next, .conv)
		
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	
	// Function or Command or Special Variables
	if (this("Type") = $$$COSFunction) || (this("Type") = $$$COSCommand) || (this("Type") = $$$COSSystemvariable) {
		set conv("Frag") = this("Frag")
		
		if (this("Type") = $$$COSCommand) {
			set conv("PostConditional") = 0
		}
		
		if ($data($$$MappedValue(this("Lang"), this("Type"), $zconvert(conv("Frag"), "L")))) {
			set conv("Frag") = $get($$$MappedValue(this("Lang"), this("Type"), $zconvert(conv("Frag"), "L")), conv("Frag"))
		} elseif ##class(pkg.isc.codetidy.Utils).GetUseCapitals() = 0 {
			set conv("Frag") = $zconvert(conv("Frag"), "l")
		} else {
			set conv("Frag") = $zconvert(conv("Frag"), "w")
		}
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	
	// Operators and Braces
	if (this("Type") = $$$COSOperator) || (this("Type") = $$$COSBrace) {
		set conv("Frag") = $zconvert(this("Frag"), "L")
		
		if ##class(pkg.isc.codetidy.Utils).GetObjectScriptWhiteSpace() {
			// Recognise pattern match operators
			set conv("PatternMatch") = ((conv("Frag") = "?") || (conv("Frag") = "'?"))
			
			// Include whitespace either side of operators except for
			//  by reference, not, and post conditions.
			// Post conditional expressions can only use spaces inside parenthesis.
			// Pattern match cannot be broken up with spaces.
			if ('conv("PostConditional")) && (".'" '[ conv("Frag")) && (((conv("Frag") '= "+") && (conv("Frag") '= "-")) || $case(last("NonSpaceType"), $$$COSLocalvariable:1, $$$COSNumber:1, :0)) {
				if $case(last("Type"), $$$COSWhiteSpace:0, "":0, :1) set conv("Frag") = " " _ conv("Frag")
				if $case(next("Type"), $$$COSWhiteSpace:0, "":0, :1) set conv("Frag") = conv("Frag") _ " "
			}
		}
		
		if ##class(pkg.isc.codetidy.Utils).GetBracePosition() {
			if (this("Frag") = "}") {
				
				if (last("NonSpaceLang") '= "\n") {
					// Note existing values
					set temp("This", "Lang") = this("Lang")
					set temp("This", "Type") = this("Type")
					set temp("This", "Frag") = this("Frag")
					set temp("Conv", "Frag") = conv("Frag")
					
					// Insert new line and opening whitespace
					set this("Lang") = "\n"
					set this("Type") = ""
					set this("Frag") = ""
					do ..InsertFragment(.last, .this)
					do ..ParseLine(.last, .this, .next, .conv)
					
					set this("Lang") = this("Lang")
					set this("Type") = $case(this("Lang"),
						"COS":$$$COSWhiteSpace,
						"CSS":$$$CSSWhiteSpace,
						"HTML":$$$HTMLWhiteSpace,
						"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace,
						"SQL":$$$SQLWhiteSpace,
						:"")
					set this("Frag") = ##class(pkg.isc.codetidy.Utils).GetIndentString()
					do ..InsertFragment(.last, .this)
					do ..ParseFragment(.last, .this, .next, .conv)
					
					// Restore Frag to be appended to conv("Line")
					// Strip leading white space as the fragment will start on a new line.
					set conv("Frag") = $zstrip(temp("Conv", "Frag"), "<W")
					// Restore this values to reflect sequence
					set this("Lang") = temp("This", "Lang")
					set this("Type") = temp("This", "Type")
					set this("Frag") = temp("This", "Frag")
				}
			}
		}
		
		set conv("Line") = conv("Line") _ conv("Frag")
		
		if (##class(pkg.isc.codetidy.Utils).GetBracePosition()) && (this("Type") = $$$COSBrace) {
			// Ignore subsequent whitespace
			set currentWhiteSpace = ""
			while $case(next("Lang"),
				"COS":next("Type") = $$$COSWhiteSpace,
				"CSS":next("Type") = $$$CSSWhiteSpace,
				"HTML":next("Type") = $$$HTMLWhiteSpace,
				"JAVASCRIPT":next("Type") = $$$JAVASCRIPTWhiteSpace,
				"SQL":next("Type") = $$$SQLWhiteSpace,
				:"") {
				do ..ReadFragment(.last, .this, .next)
				set currentWhiteSpace = currentWhiteSpace _ this("Frag")
			}
			
			if (next("Lang") '= "\n")
			&& (next("Frag") '= "else")
			&& (next("Frag") '= "elseif")
			&& (next("Frag") '= "catch")
			&& (next("Frag") '= "while") {
				// Insert new line and opening whitespace
				set this("Lang") = "\n"
				set this("Type") = ""
				set this("Frag") = ""
				do ..InsertFragment(.last, .this)
				do ..ParseLine(.last, .this, .next, .conv)
				
				set this("Lang") = this("Lang")
				set this("Type") = $case(this("Lang"),
					"COS":$$$COSWhiteSpace,
					"CSS":$$$CSSWhiteSpace,
					"HTML":$$$HTMLWhiteSpace,
					"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace,
					"SQL":$$$SQLWhiteSpace,
					:"")
				set this("Frag") = ##class(pkg.isc.codetidy.Utils).GetIndentString()
				do ..InsertFragment(.last, .this)
				do ..ParseFragment(.last, .this, .next, .conv)
			} else {
				set conv("Line") = conv("Line") _ currentWhiteSpace
			}
		}
		quit
	}
	// Delimiter
	if this("Type") = $$$COSDelimiter {
		set conv("Frag") = $zconvert(this("Frag"), "L")
		
		if ##class(pkg.isc.codetidy.Utils).GetObjectScriptWhiteSpace() {
			if ('conv("PatternMatch")) && (conv("Frag") = ",") {
				// Include whitespace before the next parameter.
				if next("Type") '= $$$COSWhiteSpace set conv("Frag") = conv("Frag") _ " "
			}
			// Post Conditional code may include all types of code.
			// Incorrect spacing will invalidate Post Conditional code.
			// Retain the setting for the rest of the line.
			if 'conv("PostConditional") {
				set conv("PostConditional") = (conv("Frag") = ":")
			}
		}
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	set conv("Line") = conv("Line") _ this("Frag")
}

ClassMethod ParseFragmentCOSComment(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ##class(pkg.isc.codetidy.Utils).GetCommentStyle() '= "" {
		set cosComment = ##class(pkg.isc.codetidy.Utils).GetCommentStyle()
		if (##class(pkg.isc.codetidy.Utils).GetCommentStyle() = "#;") && (last("NonSpaceType") '= "") {
			// Comment is after the start of the line
			set cosComment = "##;"
		}
		
		// Convert single line comment style
		// Leave the double semi-colon as this acts differently to other styles.
		// Double semi-colon retains the comment in depolyed output.
		if $extract(this("Frag"), 1) = ";", $extract(this("Frag"), 1, 2) '= ";;" set conv("Frag") = ##class(pkg.isc.codetidy.Utils).GetCommentStyle() _ $extract(conv("Frag"), 2, *)
		if $extract(this("Frag"), 1, 2) = "#;" set conv("Frag") = ##class(pkg.isc.codetidy.Utils).GetCommentStyle() _ $extract(conv("Frag"), 3, *)
		if $extract(this("Frag"), 1, 3) = "##;" set conv("Frag") = ##class(pkg.isc.codetidy.Utils).GetCommentStyle() _ $extract(conv("Frag"), 4, *)
		if ##class(pkg.isc.codetidy.Utils).GetObjectScriptWhiteSpace() {
			if $extract(conv("Frag"), 1, 2) = "//", $extract(conv("Frag"), 3) '= " " set conv("Frag") = ##class(pkg.isc.codetidy.Utils).GetCommentStyle() _ " " _ $extract(conv("Frag"), 3, *)
		}
	}
}

ClassMethod ParseFragmentSQL(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ##class(pkg.isc.codetidy.Utils).GetAddSQLPlan() {
		// Capture SQL statements
		if $extract(this("Frag"), 1, 4) '= "-- ;" {
			if '$data(conv("SQL")) || (this("Type") = $$$SQLStatementkeyword) || (this("Type") = $$$SQLQualifierkeyword) || (this("Type") = $$$SQLOperator) {
				set conv("SQL", $increment(conv("SQL"))) = this("Frag")
			} else {
				set conv("SQL", conv("SQL")) = conv("SQL", conv("SQL")) _ this("Frag")
			}
		} else {
			set conv("SQLPLAN") = 1
		}
	}
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		// Indentation Adjustments
		if (this("Type") = $$$SQLDelimiter) {
			do ..ApplyIndentation(.this, .next, .conv, "(", ")")
		}
		if ($case(this("Type"), $$$SQLStatementkeyword:1, $$$SQLQualifierkeyword:1, $$$SQLExpressionkeyword:1, :0)) {
			set keyword = $zconvert(this("Frag"), "U")
			if $case(keyword, "CASE":1, :0)  {
				// Double indent
				set next("Indent") = next("Indent") + 2
			} elseif $case(keyword, "END":1, :0) {
				// Double outdent
				if (conv("LineStripped") = "") {
					set this("Indent") = this("Indent") - 2
				} else {
					set next("Indent") = next("Indent") - 2
				}
			} elseif (conv("LineStripped") = "") {
				// NOTE: When not used as the first word in a line the indentation effect is skipped.
				//
				// Outdent from this word
				// Indent subsequent words
				if this("Indent") > 0 set this("Indent") = this("Indent") - 1
				set next("Indent") = next("Indent") + 1
			}
			
		}
	}
	// SQL keywords and operators
	if ($case(this("Type"), $$$SQLStatementkeyword:1, $$$SQLQualifierkeyword:1, $$$SQLExpressionkeyword:1, $$$SQLOperator:1, :0)) {
		set conv("Frag") = this("Frag")
		if ##class(pkg.isc.codetidy.Utils).GetSQLCase() '= "" {
			// Upper case SQL keywords and operators
			set conv("Frag") = $zconvert(this("Frag"), ##class(pkg.isc.codetidy.Utils).GetSQLCase())
		}
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	set conv("Line") = conv("Line") _ this("Frag")
}

ClassMethod ParseFragmentJS(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ##class(pkg.isc.codetidy.Utils).GetIndent() {
		// Indentation Adjustments
		if (this("Type") = $$$JAVASCRIPTDelimiter) {
			do ..ApplyIndentation(.this, .next, .conv, "{(", "})")
		}
	}
	if (this("Type") = $$$JAVASCRIPTStatementkeyword) {
		if $case(this("Frag"), "switch":1, :0)  {
			set next("Indent") = next("Indent") + 1
			if $increment(conv("JSSwitch"))
		} elseif $case(this("Frag"), "case":1, "default":1, :0) {
			set this("Indent") = this("Indent") - 1
			set next("Indent") = next("Indent") + 1
		}
	}
	set conv("Line") = conv("Line") _ this("Frag")
}

ClassMethod ParseFragmentHTML(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	// <head></head>
	// <csp:parameter>
	if this("Type") = $$$HTMLTag {
		set conv("Frag") = $zconvert(this("Frag"), "L")
		// Convert <server> to <script language="cache" runat="server">
		if conv("Frag") = "server" {
			set conv("Frag") = "script"
			if last("Type") = $$$HTMLDelimiter, last("Frag") '= "/" set conv("Frag") = conv("Frag") _ " language=""cache"" runat=""server"""
		}
		set conv("Line") = conv("Line") _ conv("Frag")
		quit
	}
	set conv("Line") = conv("Line") _ this("Frag")
}

/// Indicate whether a SQL command should note the execution plan.
ClassMethod UseSQLPlan(Command As %String) As %Boolean
{
	quit $case(Command, "OPEN":0, "FETCH":0, "CLOSE":0, :1)
}

/// SQL is an array of strings which defines the SQL statement.
ClassMethod GetSQLPlan(ByRef SQL As %String, Schema As %String, Output Plan As %String) As %Status
{

	set started = $piece($ztimestamp, ",", 2)
	new %plan
	merge sql = SQL
	
	set command = $piece($translate(sql(1), $char(9), " "), " ")
	set command = $zconvert(command, "U")
	if ..UseSQLPlan(command) {
		
		// Replace constant macros in SQL statement.
		// These are not handled by the SQL query planner.
		// E.g.	$$$OK, $$$IntervalWeek are not handled.
		// 		Functions such as $$$SQLLit(...), $$$BPRuleActionSQLOrder(...) are handled.
		for i = 1:1 {
			if '$data(sql(i)) quit
			
			set sqlLine = sql(i)
			set chunkLength = $length(sqlLine, "$$$")
			for chunkNo = 2:1:chunkLength {
				set macro = $piece(sqlLine, "$$$", chunkNo, *)
				for charNo = 1:1 {
					set nextChar = $extract(macro, charNo)
					if nextChar '? 1(1A,1N) quit
				}
				if nextChar = "(" continue
				
				// Note full macro name
				set macro = "$$$" _ $extract(macro, 1, charNo - 1)
				set sql(i) = $replace(sql(i), macro, "?")
			}
		}
		
		set packages = ""
		if Schema '= "" set packages = packages _ $listbuild(Schema)
		if Schema '= "SQLUser" set packages = packages _ $listbuild("SQLUser")

		// Version detection as $system.SQL.ShowPlan is now deprecated
		if $$$comMemberDefined("%System.SQL", $$$cCLASSmethod, "Explain") {
			do $system.SQL.Explain(.sql, {"quiet":1, "preparse":1, "selectmode":1}, , .%plan)
		}
		else {
			do $system.SQL.ShowPlan(.sql, 1, 0, packages, , , , , 1)
		}
		
		// Check for plan
		if $data(%plan(1)) {
			merge Plan = %plan
		}
	}
	
	quit $$$OK
}

ClassMethod InitialiseMap()
{
	set $$$MappedValue("COS", $$$COSFunction, "$a") = "$ascii"
	set $$$MappedValue("COS", $$$COSFunction, "$ascii") = "$ascii"
	set $$$MappedValue("COS", $$$COSFunction, "$bit") = "$bit"
	set $$$MappedValue("COS", $$$COSFunction, "$case") = "$case"
	set $$$MappedValue("COS", $$$COSFunction, "$c") = "$char"
	set $$$MappedValue("COS", $$$COSFunction, "$char") = "$char"
	set $$$MappedValue("COS", $$$COSFunction, "$d") = "$data"
	set $$$MappedValue("COS", $$$COSFunction, "$data") = "$data"
	set $$$MappedValue("COS", $$$COSFunction, "$decimal") = "$decimal"
	set $$$MappedValue("COS", $$$COSFunction, "$double") = "$double"
	set $$$MappedValue("COS", $$$COSFunction, "$e") = "$extract"
	set $$$MappedValue("COS", $$$COSFunction, "$extract") = "$extract"
	set $$$MappedValue("COS", $$$COSFunction, "$f") = "$find"
	set $$$MappedValue("COS", $$$COSFunction, "$find") = "$find"
	set $$$MappedValue("COS", $$$COSFunction, "$g") = "$get"
	set $$$MappedValue("COS", $$$COSFunction, "$get") = "$get"
	set $$$MappedValue("COS", $$$COSFunction, "$i") = "$increment"
	set $$$MappedValue("COS", $$$COSFunction, "$increment") = "$increment"
	set $$$MappedValue("COS", $$$COSFunction, "$j") = "$justify"
	set $$$MappedValue("COS", $$$COSFunction, "$justify") = "$justify"
	set $$$MappedValue("COS", $$$COSFunction, "$l") = "$length"
	set $$$MappedValue("COS", $$$COSFunction, "$length") = "$length"
	set $$$MappedValue("COS", $$$COSFunction, "$li") = "$list"
	set $$$MappedValue("COS", $$$COSFunction, "$list") = "$list"
	set $$$MappedValue("COS", $$$COSFunction, "$locate") = "$locate"
	set $$$MappedValue("COS", $$$COSFunction, "$match") = "$match"
	set $$$MappedValue("COS", $$$COSFunction, "$method") = "$method"
	set $$$MappedValue("COS", $$$COSFunction, "$na") = "$name"
	set $$$MappedValue("COS", $$$COSFunction, "$name") = "$name"
	set $$$MappedValue("COS", $$$COSFunction, "$normalize") = "$normalize"
	set $$$MappedValue("COS", $$$COSFunction, "$now") = "$now"
	set $$$MappedValue("COS", $$$COSFunction, "$number") = "$num"
	set $$$MappedValue("COS", $$$COSFunction, "$number") = "$number"
	set $$$MappedValue("COS", $$$COSFunction, "$o") = "$order"
	set $$$MappedValue("COS", $$$COSFunction, "$order") = "$order"
	set $$$MappedValue("COS", $$$COSFunction, "$parameter") = "$parameter"
	set $$$MappedValue("COS", $$$COSFunction, "$p") = "$piece"
	set $$$MappedValue("COS", $$$COSFunction, "$piece") = "$piece"
	set $$$MappedValue("COS", $$$COSFunction, "$property") = "$property"
	set $$$MappedValue("COS", $$$COSFunction, "$q") = "$query"
	set $$$MappedValue("COS", $$$COSFunction, "$query") = "$query"
	set $$$MappedValue("COS", $$$COSFunction, "$r") = "$random"
	set $$$MappedValue("COS", $$$COSFunction, "$random") = "$random"
	set $$$MappedValue("COS", $$$COSFunction, "$re") = "$reverse"
	set $$$MappedValue("COS", $$$COSFunction, "$replace") = "$replace"
	set $$$MappedValue("COS", $$$COSFunction, "$reverse") = "$reverse"
	set $$$MappedValue("COS", $$$COSFunction, "$s") = "$select"
	set $$$MappedValue("COS", $$$COSFunction, "$select") = "$select"
	set $$$MappedValue("COS", $$$COSFunction, "$stack") = "$stack"
	set $$$MappedValue("COS", $$$COSFunction, "$t") = "$text"
	set $$$MappedValue("COS", $$$COSFunction, "$text") = "$text"
	set $$$MappedValue("COS", $$$COSFunction, "$tr") = "$translate"
	set $$$MappedValue("COS", $$$COSFunction, "$translate") = "$translate"
	set $$$MappedValue("COS", $$$COSFunction, "$xecute") = "$xecute"
	
	set $$$MappedValue("COS", $$$COSCommand, "as") = "as"
	set $$$MappedValue("COS", $$$COSCommand, "b") = "break"
	set $$$MappedValue("COS", $$$COSCommand, "break") = "break"
	set $$$MappedValue("COS", $$$COSCommand, "catch") = "catch"
	set $$$MappedValue("COS", $$$COSCommand, "c") = "close"
	set $$$MappedValue("COS", $$$COSCommand, "close") = "close"
	set $$$MappedValue("COS", $$$COSCommand, "continue") = "continue"
	set $$$MappedValue("COS", $$$COSCommand, "d") = "do"
	set $$$MappedValue("COS", $$$COSCommand, "do") = "do"
	set $$$MappedValue("COS", $$$COSCommand, "e") = "else"
	set $$$MappedValue("COS", $$$COSCommand, "else") = "else"
	set $$$MappedValue("COS", $$$COSCommand, "f") = "for"
	set $$$MappedValue("COS", $$$COSCommand, "for") = "for"
	set $$$MappedValue("COS", $$$COSCommand, "g") = "goto"
	set $$$MappedValue("COS", $$$COSCommand, "goto") = "goto"
	// leave H as is (due to HANG x   versus HALT)
	set $$$MappedValue("COS", $$$COSCommand, "h") = "h"
	set $$$MappedValue("COS", $$$COSCommand, "hang") = "hang"
	set $$$MappedValue("COS", $$$COSCommand, "i") = "if"
	set $$$MappedValue("COS", $$$COSCommand, "if") = "if"
	set $$$MappedValue("COS", $$$COSCommand, "j") = "job"
	set $$$MappedValue("COS", $$$COSCommand, "job") = "job"
	set $$$MappedValue("COS", $$$COSCommand, "k") = "kill"
	set $$$MappedValue("COS", $$$COSCommand, "kill") = "kill"
	set $$$MappedValue("COS", $$$COSCommand, "l") = "lock"
	set $$$MappedValue("COS", $$$COSCommand, "lock") = "lock"
	set $$$MappedValue("COS", $$$COSCommand, "m") = "merge"
	set $$$MappedValue("COS", $$$COSCommand, "merge") = "merge"
	set $$$MappedValue("COS", $$$COSCommand, "n") = "new"
	set $$$MappedValue("COS", $$$COSCommand, "new") = "new"
	set $$$MappedValue("COS", $$$COSCommand, "o") = "open"
	set $$$MappedValue("COS", $$$COSCommand, "open") = "open"
	set $$$MappedValue("COS", $$$COSCommand, "p") = "print"
	set $$$MappedValue("COS", $$$COSCommand, "print") = "print"
	set $$$MappedValue("COS", $$$COSCommand, "q") = "quit"
	set $$$MappedValue("COS", $$$COSCommand, "quit") = "quit"
	set $$$MappedValue("COS", $$$COSCommand, "r") = "read"
	set $$$MappedValue("COS", $$$COSCommand, "read") = "read"
	set $$$MappedValue("COS", $$$COSCommand, "ret") = "ret"
	set $$$MappedValue("COS", $$$COSCommand, "return") = "return"
	set $$$MappedValue("COS", $$$COSCommand, "s") = "set"
	set $$$MappedValue("COS", $$$COSCommand, "set") = "set"
	set $$$MappedValue("COS", $$$COSCommand, "throw") = "throw"
	set $$$MappedValue("COS", $$$COSCommand, "try") = "try"
	set $$$MappedValue("COS", $$$COSCommand, "ts") = "tstart"
	set $$$MappedValue("COS", $$$COSCommand, "tstart") = "tstart"
	set $$$MappedValue("COS", $$$COSCommand, "u") = "use"
	set $$$MappedValue("COS", $$$COSCommand, "use") = "use"
	set $$$MappedValue("COS", $$$COSCommand, "v") = "view"
	set $$$MappedValue("COS", $$$COSCommand, "view") = "view"
	set $$$MappedValue("COS", $$$COSCommand, "while") = "while"
	set $$$MappedValue("COS", $$$COSCommand, "w") = "write"
	set $$$MappedValue("COS", $$$COSCommand, "write") = "write"
	set $$$MappedValue("COS", $$$COSCommand, "x") = "xecute"
	set $$$MappedValue("COS", $$$COSCommand, "xecute") = "xecute"
	
	
	set $$$MappedValue("COS", $$$COSSystemvariable, "$j") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$job") = "$job"
	
	// leave as $h...
	set $$$MappedValue("COS", $$$COSSystemvariable, "$h") = "$h"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$horolog") = "$h"
	
	set $$$MappedValue("COS", $$$COSSystemvariable, "$j") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$job") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$k") = "$key"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$key") = "$key"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ns") = "$namespace"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$namespace") = "$namespace"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$principal") = "$principal"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$roles") = "$roles"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$s") = "$storage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$storage") = "$storage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$stack") = "$stack"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$system") = "$system"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$t") = "$test"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$test") = "$test"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$this") = "$this"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$username") = "$username"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$x") = "$x"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$q") = "$quit"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$quit") = "$quit"

	if ##class(pkg.isc.codetidy.Utils).GetUseCapitals() {
		// Iterate over the current values in map and capitalize them
		for sub = $$$COSFunction, $$$COSCommand, $$$COSSystemvariable {
			set key = $order(map("COS", sub, ""))
			while key '= "" {
				set currentValue = $$$MappedValue("COS", sub, key)
				
				if sub = $$$COSCommand {
					set $$$MappedValue("COS", sub, key) = $zconvert(currentValue, "w")
				} else {
					set word = $extract(currentValue, 2, *)
					set newValue = "$" _ $zconvert(word, "w")
					set $$$MappedValue("COS", sub, key) = newValue
				}
				
				set key = $order(map("COS", sub, key))
			}
		}
		// Things that differ in capatilization beyond just the first letter
		set $$$MappedValue("COS", $$$COSFunction, "$bitcount") = "$BitCount"
		set $$$MappedValue("COS", $$$COSFunction, "$bitfind") = "$BitFind"
		set $$$MappedValue("COS", $$$COSFunction, "$bitlogic") = "$BitLogic"
		set $$$MappedValue("COS", $$$COSFunction, "$classmethod") = "$ClassMethod"
		set $$$MappedValue("COS", $$$COSFunction, "$classname") = "$ClassName"
		set $$$MappedValue("COS", $$$COSFunction, "$fn") = "$FNumber"
		set $$$MappedValue("COS", $$$COSFunction, "$fnumber") = "$FNumber"
		set $$$MappedValue("COS", $$$COSFunction, "$isobject") = "$IsObject"
		set $$$MappedValue("COS", $$$COSFunction, "$isvalidnum") = "$IsValidNum"
		set $$$MappedValue("COS", $$$COSFunction, "$lb") = "$ListBuild"
		set $$$MappedValue("COS", $$$COSFunction, "$ld") = "$ListData"
		set $$$MappedValue("COS", $$$COSFunction, "$lf") = "$ListFind"
		set $$$MappedValue("COS", $$$COSFunction, "$lfs") = "$ListFromString"
		set $$$MappedValue("COS", $$$COSFunction, "$lg") = "$ListGet"
		set $$$MappedValue("COS", $$$COSFunction, "$listbuild") = "$ListBuild"
		set $$$MappedValue("COS", $$$COSFunction, "$listdata") = "$ListData"
		set $$$MappedValue("COS", $$$COSFunction, "$listfind") = "$ListFind"
		set $$$MappedValue("COS", $$$COSFunction, "$listfromstring") = "$ListFromString"
		set $$$MappedValue("COS", $$$COSFunction, "$listget") = "$ListGet"
		set $$$MappedValue("COS", $$$COSFunction, "$ll") = "$ListLength"
		set $$$MappedValue("COS", $$$COSFunction, "$listlength") = "$ListLength"
		set $$$MappedValue("COS", $$$COSFunction, "$listnext") = "$ListNext"
		set $$$MappedValue("COS", $$$COSFunction, "$listsame") = "$ListSame"
		set $$$MappedValue("COS", $$$COSFunction, "$listtostring") = "$ListToString"
		set $$$MappedValue("COS", $$$COSFunction, "$listvalid") = "$ListValid"
		set $$$MappedValue("COS", $$$COSFunction, "$lts") = "$ListToString"
		set $$$MappedValue("COS", $$$COSFunction, "$lv") = "$ListValid"
		set $$$MappedValue("COS", $$$COSFunction, "$nconvert") = "$NConvert"
		set $$$MappedValue("COS", $$$COSFunction, "$ql") = "$QLength"
		set $$$MappedValue("COS", $$$COSFunction, "$qlength") = "$QLength"
		set $$$MappedValue("COS", $$$COSFunction, "$qs") = "$QSubscript"
		set $$$MappedValue("COS", $$$COSFunction, "$qsubscript") = "$QSubscript"
		set $$$MappedValue("COS", $$$COSFunction, "$sconvert") = "$SConvert"
		set $$$MappedValue("COS", $$$COSFunction, "$sortbegin") = "$SortBegin"
		set $$$MappedValue("COS", $$$COSFunction, "$sortend") = "$SortEnd"
		set $$$MappedValue("COS", $$$COSFunction, "$zabs") = "$ZAbs"
		set $$$MappedValue("COS", $$$COSFunction, "$zb") = "$ZBoolean"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitget") = "$ZBitGet"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitlen") = "$ZBitLen"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitor") = "$ZBitOr"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitset") = "$ZBitSet"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitstr") = "$ZBitStr"
		set $$$MappedValue("COS", $$$COSFunction, "$zboolean") = "$ZBoolean"
		set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$ZConvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zcrc") = "$ZCRC"
		set $$$MappedValue("COS", $$$COSFunction, "$zcvt") = "$ZConvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$ZConvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zd") = "$ZDate"
		set $$$MappedValue("COS", $$$COSFunction, "$zdate") = "$ZDate"
		set $$$MappedValue("COS", $$$COSFunction, "$zdateh") = "$ZDateH"
		set $$$MappedValue("COS", $$$COSFunction, "$zdatetime") = "$ZDateTime"
		set $$$MappedValue("COS", $$$COSFunction, "$zdatetimeh") = "$ZDateTimeH"
		set $$$MappedValue("COS", $$$COSFunction, "$zdh") = "$ZDateH"
		set $$$MappedValue("COS", $$$COSFunction, "$zdt") = "$ZDateTime"
		set $$$MappedValue("COS", $$$COSFunction, "$zdth") = "$ZDateTimeH"
		set $$$MappedValue("COS", $$$COSFunction, "$zf") = "$ZF"
		set $$$MappedValue("COS", $$$COSFunction, "$zh") = "$ZHex"
		set $$$MappedValue("COS", $$$COSFunction, "$zhex") = "$ZHex"
		set $$$MappedValue("COS", $$$COSFunction, "$ziswide") = "$ZIsWide"
		set $$$MappedValue("COS", $$$COSFunction, "$zlascii") = "$ZLAscii"
		set $$$MappedValue("COS", $$$COSFunction, "$zlc") = "$ZLC"
		set $$$MappedValue("COS", $$$COSFunction, "$zlchar") = "$ZLChar"
		set $$$MappedValue("COS", $$$COSFunction, "$zlog") = "$ZLog"
		set $$$MappedValue("COS", $$$COSFunction, "$zname") = "$ZName"
		set $$$MappedValue("COS", $$$COSFunction, "$zo") = "$ZOrder"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjclass") = "$ZObjClass"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjclassmethod") = "$ZObjClassMethod"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjexport") = "$ZObjExport"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjmethod") = "$ZObjMethod"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjproperty") = "$ZObjProperty"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjval") = "$ZObjVal"
		set $$$MappedValue("COS", $$$COSFunction, "$zpower") = "$ZPower"
		set $$$MappedValue("COS", $$$COSFunction, "$zse") = "$ZSearch"
		set $$$MappedValue("COS", $$$COSFunction, "$zsearch") = "$ZSearch"
		set $$$MappedValue("COS", $$$COSFunction, "$zstrip") = "$ZStrip"
		set $$$MappedValue("COS", $$$COSFunction, "$zt") = "$ZTime"
		set $$$MappedValue("COS", $$$COSFunction, "$zth") = "$ZTimeH"
		set $$$MappedValue("COS", $$$COSFunction, "$ztime") = "$ZTime"
		set $$$MappedValue("COS", $$$COSFunction, "$ztimeh") = "$ZTimeH"
		set $$$MappedValue("COS", $$$COSFunction, "$zu") = "$ZUtil"
		set $$$MappedValue("COS", $$$COSFunction, "$zutil") = "$ZUtil"
		set $$$MappedValue("COS", $$$COSFunction, "$zv") = "$ZVersion"
		set $$$MappedValue("COS", $$$COSFunction, "$zversion") = "$ZVersion"
		set $$$MappedValue("COS", $$$COSFunction, "$zwascii") = "$ZWAscii"
		set $$$MappedValue("COS", $$$COSFunction, "$zwc") = "$ZWChar"
		set $$$MappedValue("COS", $$$COSFunction, "$zwchar") = "$ZWChar"
		set $$$MappedValue("COS", $$$COSCommand, "elseif") = "ElseIf"
		set $$$MappedValue("COS", $$$COSCommand, "tc") = "TCommit"
		set $$$MappedValue("COS", $$$COSCommand, "tcommit") = "TCommit"
		set $$$MappedValue("COS", $$$COSCommand, "trollback") = "TRollback"
		set $$$MappedValue("COS", $$$COSCommand, "za") = "ZAllocate"
		set $$$MappedValue("COS", $$$COSCommand, "zbreak") = "ZBreak"
		set $$$MappedValue("COS", $$$COSCommand, "zd") = "ZDeallocate"
		set $$$MappedValue("COS", $$$COSCommand, "zkill") = "ZKill"
		set $$$MappedValue("COS", $$$COSCommand, "zn") = "ZNspace"
		set $$$MappedValue("COS", $$$COSCommand, "znspace") = "ZNspace"
		set $$$MappedValue("COS", $$$COSCommand, "zt") = "ZTrap"
		set $$$MappedValue("COS", $$$COSCommand, "ztrap") = "ZTrap"
		set $$$MappedValue("COS", $$$COSCommand, "zw") = "ZWrite"
		set $$$MappedValue("COS", $$$COSCommand, "zwrite") = "ZWrite"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ec") = "$EC"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ecode") = "$ECode"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$i") = "$IO"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$io") = "$IO"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$tl") = "$TLevel"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$tlevel") = "$TLevel"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zb") = "$ZB"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zc") = "$ZC"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zchild") = "$ZChild"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ze") = "$ZError"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zeof") = "$ZEOF"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zerror") = "$ZError"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zh") = "$ZHorolog"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zhorolog") = "$ZHorolog"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zj") = "$ZJob"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zjob") = "$ZJob"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zn") = "$ZName"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zname") = "$ZName"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$znspace") = "$ZNspace"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zparent") = "$ZParent"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zpi") = "$ZPi"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$ZReference"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$ZReference"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$ZStorage"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$ZStorage"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zt") = "$ZTrap"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zts") = "$ZTimestamp"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimestamp") = "$ZTimestamp"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztz") = "$ZTimezone"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimezone") = "$ZTimezone"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztrap") = "$ZTrap"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zv") = "$ZVersion"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zversion") = "$ZVersion"
	} else {
		// Things that differ in capatilization beyond just the first letter
		set $$$MappedValue("COS", $$$COSFunction, "$bitcount") = "$bitcount"
		set $$$MappedValue("COS", $$$COSFunction, "$bitfind") = "$bitfind"
		set $$$MappedValue("COS", $$$COSFunction, "$bitlogic") = "$bitlogic"
		set $$$MappedValue("COS", $$$COSFunction, "$classmethod") = "$classmethod"
		set $$$MappedValue("COS", $$$COSFunction, "$classname") = "$classname"
		set $$$MappedValue("COS", $$$COSFunction, "$fn") = "$fnumber"
		set $$$MappedValue("COS", $$$COSFunction, "$fnumber") = "$fnumber"
		set $$$MappedValue("COS", $$$COSFunction, "$isobject") = "$isobject"
		set $$$MappedValue("COS", $$$COSFunction, "$isvalidnum") = "$isvalidnum"
		set $$$MappedValue("COS", $$$COSFunction, "$lb") = "$listbuild"
		set $$$MappedValue("COS", $$$COSFunction, "$ld") = "$listdata"
		set $$$MappedValue("COS", $$$COSFunction, "$lf") = "$listfind"
		set $$$MappedValue("COS", $$$COSFunction, "$lfs") = "$listfromstring"
		set $$$MappedValue("COS", $$$COSFunction, "$lg") = "$listget"
		set $$$MappedValue("COS", $$$COSFunction, "$listbuild") = "$listbuild"
		set $$$MappedValue("COS", $$$COSFunction, "$listdata") = "$listdata"
		set $$$MappedValue("COS", $$$COSFunction, "$listfind") = "$listfind"
		set $$$MappedValue("COS", $$$COSFunction, "$listfromstring") = "$listfromstring"
		set $$$MappedValue("COS", $$$COSFunction, "$listget") = "$listget"
		set $$$MappedValue("COS", $$$COSFunction, "$ll") = "$listlength"
		set $$$MappedValue("COS", $$$COSFunction, "$listlength") = "$listlength"
		set $$$MappedValue("COS", $$$COSFunction, "$listnext") = "$listnext"
		set $$$MappedValue("COS", $$$COSFunction, "$listsame") = "$listsame"
		set $$$MappedValue("COS", $$$COSFunction, "$listtostring") = "$listtostring"
		set $$$MappedValue("COS", $$$COSFunction, "$listvalid") = "$listvalid"
		set $$$MappedValue("COS", $$$COSFunction, "$lts") = "$listtostring"
		set $$$MappedValue("COS", $$$COSFunction, "$lv") = "$listvalid"
		set $$$MappedValue("COS", $$$COSFunction, "$nconvert") = "$nconvert"
		set $$$MappedValue("COS", $$$COSFunction, "$ql") = "$qlength"
		set $$$MappedValue("COS", $$$COSFunction, "$qlength") = "$qlength"
		set $$$MappedValue("COS", $$$COSFunction, "$qs") = "$qsubscript"
		set $$$MappedValue("COS", $$$COSFunction, "$qsubscript") = "$qsubscript"
		set $$$MappedValue("COS", $$$COSFunction, "$sconvert") = "$sconvert"
		set $$$MappedValue("COS", $$$COSFunction, "$sortbegin") = "$sortbegin"
		set $$$MappedValue("COS", $$$COSFunction, "$sortend") = "$sortend"
		set $$$MappedValue("COS", $$$COSFunction, "$zabs") = "$zabs"
		set $$$MappedValue("COS", $$$COSFunction, "$zb") = "$zboolean"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitget") = "$zbitget"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitlen") = "$zbitlen"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitor") = "$zbitor"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitset") = "$zbitset"
		set $$$MappedValue("COS", $$$COSFunction, "$zbitstr") = "$zbitstr"
		set $$$MappedValue("COS", $$$COSFunction, "$zboolean") = "$zboolean"
		set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$zconvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zcrc") = "$zcrc"
		set $$$MappedValue("COS", $$$COSFunction, "$zcvt") = "$zconvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$zconvert"
		set $$$MappedValue("COS", $$$COSFunction, "$zd") = "$zdate"
		set $$$MappedValue("COS", $$$COSFunction, "$zdate") = "$zdate"
		set $$$MappedValue("COS", $$$COSFunction, "$zdateh") = "$zdateh"
		set $$$MappedValue("COS", $$$COSFunction, "$zdatetime") = "$zdatetime"
		set $$$MappedValue("COS", $$$COSFunction, "$zdatetimeh") = "$zdatetimeh"
		set $$$MappedValue("COS", $$$COSFunction, "$zdh") = "$zdateh"
		set $$$MappedValue("COS", $$$COSFunction, "$zdt") = "$zdatetime"
		set $$$MappedValue("COS", $$$COSFunction, "$zdth") = "$zdatetimeh"
		set $$$MappedValue("COS", $$$COSFunction, "$zf") = "$zf"
		set $$$MappedValue("COS", $$$COSFunction, "$zh") = "$zhex"
		set $$$MappedValue("COS", $$$COSFunction, "$zhex") = "$zhex"
		set $$$MappedValue("COS", $$$COSFunction, "$ziswide") = "$ziswide"
		set $$$MappedValue("COS", $$$COSFunction, "$zlascii") = "$zlascii"
		set $$$MappedValue("COS", $$$COSFunction, "$zlc") = "$zlc"
		set $$$MappedValue("COS", $$$COSFunction, "$zlchar") = "$zlchar"
		set $$$MappedValue("COS", $$$COSFunction, "$zlog") = "$zlog"
		set $$$MappedValue("COS", $$$COSFunction, "$zname") = "$zname"
		set $$$MappedValue("COS", $$$COSFunction, "$zo") = "$zorder"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjclass") = "$zobjclass"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjclassmethod") = "$zobjclassmethod"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjexport") = "$zobjexport"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjmethod") = "$zobjmethod"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjproperty") = "$zobjproperty"
		set $$$MappedValue("COS", $$$COSFunction, "$zobjval") = "$zobjval"
		set $$$MappedValue("COS", $$$COSFunction, "$zpower") = "$zpower"
		set $$$MappedValue("COS", $$$COSFunction, "$zse") = "$zsearch"
		set $$$MappedValue("COS", $$$COSFunction, "$zsearch") = "$zsearch"
		set $$$MappedValue("COS", $$$COSFunction, "$zstrip") = "$zstrip"
		set $$$MappedValue("COS", $$$COSFunction, "$zt") = "$ztime"
		set $$$MappedValue("COS", $$$COSFunction, "$zth") = "$ztimeh"
		set $$$MappedValue("COS", $$$COSFunction, "$ztime") = "$ztime"
		set $$$MappedValue("COS", $$$COSFunction, "$ztimeh") = "$ztimeh"
		set $$$MappedValue("COS", $$$COSFunction, "$zu") = "$zutil"
		set $$$MappedValue("COS", $$$COSFunction, "$zutil") = "$zutil"
		set $$$MappedValue("COS", $$$COSFunction, "$zv") = "$zversion"
		set $$$MappedValue("COS", $$$COSFunction, "$zversion") = "$zversion"
		set $$$MappedValue("COS", $$$COSFunction, "$zwascii") = "$zwascii"
		set $$$MappedValue("COS", $$$COSFunction, "$zwc") = "$zwchar"
		set $$$MappedValue("COS", $$$COSFunction, "$zwchar") = "$zwchar"
		set $$$MappedValue("COS", $$$COSCommand, "elseif") = "elseif"
		set $$$MappedValue("COS", $$$COSCommand, "tc") = "tcommit"
		set $$$MappedValue("COS", $$$COSCommand, "tcommit") = "tcommit"
		set $$$MappedValue("COS", $$$COSCommand, "trollback") = "trollback"
		set $$$MappedValue("COS", $$$COSCommand, "za") = "zallocate"
		set $$$MappedValue("COS", $$$COSCommand, "zbreak") = "zbreak"
		set $$$MappedValue("COS", $$$COSCommand, "zd") = "zdeallocate"
		set $$$MappedValue("COS", $$$COSCommand, "zkill") = "zkill"
		set $$$MappedValue("COS", $$$COSCommand, "zn") = "znspace"
		set $$$MappedValue("COS", $$$COSCommand, "znspace") = "znspace"
		set $$$MappedValue("COS", $$$COSCommand, "zt") = "ztrap"
		set $$$MappedValue("COS", $$$COSCommand, "ztrap") = "ztrap"
		set $$$MappedValue("COS", $$$COSCommand, "zw") = "zwrite"
		set $$$MappedValue("COS", $$$COSCommand, "zwrite") = "zwrite"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ec") = "$ec"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ecode") = "$ecode"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$i") = "$io"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$io") = "$io"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$tl") = "$tlevel"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$tlevel") = "$tlevel"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zb") = "$zb"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zc") = "$zc"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zchild") = "$zchild"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ze") = "$zerror"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zeof") = "$zeof"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zerror") = "$zerror"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zh") = "$zhorolog"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zhorolog") = "$zhorolog"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zj") = "$zjob"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zjob") = "$zjob"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zn") = "$zname"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zname") = "$zname"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$znspace") = "$znspace"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zparent") = "$zparent"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zpi") = "$zpi"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$zreference"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$zreference"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$zstorage"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$zstorage"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zt") = "$ztrap"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zts") = "$ztimestamp"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimestamp") = "$ztimestamp"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztz") = "$ztimezone"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimezone") = "$ztimezone"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$ztrap") = "$ztrap"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zv") = "$zversion"
		set $$$MappedValue("COS", $$$COSSystemvariable, "$zversion") = "$zversion"
	}
}

}
