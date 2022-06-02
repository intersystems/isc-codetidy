Class pkg.isc.codetidy.vartyping.CommandParser Extends %RegisteredObject
{

Property Tokens [ MultiDimensional ];

Property VariableTracker As pkg.isc.codetidy.vartyping.VariableTracker;

Property Pointer As %Integer [ Private ];

Property NextCommand As %String [ Private ];

Property Line As %Integer;

Property PreviousLine As %Integer;

Property CurrentCommand As %String;

Property CurrentTokens As %List;

Property Postconditional As %List;

/// This callback method is invoked by the <METHOD>%New</METHOD> method to 
/// provide notification that a new instance of an object is being created.
/// 
/// <P>If this method returns an error then the object will not be created.
/// <p>It is passed the arguments provided in the %New call.
/// When customizing this method, override the arguments with whatever variables and types you expect to receive from %New().
/// For example, if you're going to call %New, passing 2 arguments, %OnNew's signature could be:
/// <p>Method %OnNew(dob as %Date = "", name as %Name = "") as %Status
/// If instead of returning a %Status code this returns an oref and this oref is a subclass of the current
/// class then this oref will be the one returned to the caller of %New method.
/// pUserInputArgIndices is used when the a method is being called with user input in some of its arguments.
/// The indices in this list are the argument indices that contain user input.
Method %OnNew(pClass As %Dictionary.CacheClassname, pMethod As %Dictionary.CacheIdentifier, pNamespace As %String, pUserInputArgIndices As %List = "", pAllArgsUserInput As %Boolean = 0) As %Status [ Private, ServerOnly = 1 ]
{
	// Get tokens from the class and store in ..Tokens
	Set sc = ##class(pkg.isc.codetidy.vartyping.COSTokenizer).GetMethodImplementation(pClass, pMethod, .tokens, pNamespace)
	$$$ThrowOnError(sc)
	Merge ..Tokens = tokens

	// Initialize positional properties
	Set ..Line = 1
	Set ..Pointer = 0
	Set ..CurrentCommand = ""

	// get formal parameters and make new variable tracker with those parameters
	Set codeNamespace = $Namespace
	New $Namespace
	Set $Namespace = pNamespace
	Set method = ##class(%Dictionary.MethodDefinition).IDKEYOpen(pClass,pMethod,,.sc)
	$$$ThrowOnError(sc)
	// get the multidimensional properties from this class and add them to the variable tracker
	Set result = ##class(%SQL.Statement).%ExecDirect(,
	"select Name from %Dictionary.PropertyDefinition where parent = ? and MultiDimensional = 1", pClass)
	If result.%SQLCODE < 0 {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
	}
	Set multidimensionalProps = ""
	While result.%Next(.sc) {
		$$$ThrowOnError(sc)
		Set multidimensionalProps = multidimensionalProps _ $ListBuild(result.Name)
	}
	$$$ThrowOnError(sc)
	Set $Namespace = codeNamespace

	// create new variable tracker
	Set ..VariableTracker = ##class(pkg.isc.codetidy.vartyping.VariableTracker).%New(method.FormalSpec, multidimensionalProps, pNamespace, pUserInputArgIndices, pAllArgsUserInput, pClass)

	// if this is not a classmethod, add all properties with their types to the variable tracker
	// any properties with zenurl parameter should be initialized with user input
	If 'method.ClassMethod {
		Set $Namespace = pNamespace
		Set result = ##class(%SQL.Statement).%ExecDirect(,
		"select Name, MultiDimensional, Parameters, Type from %Dictionary.PropertyDefinition where parent = ?", pClass)
		If result.%SQLCODE < 0 {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(result.%SQLCODE,result.%Message)
		}
		Set $Namespace = codeNamespace
		Set multidimensionalProps = ""
		While result.%Next(.sc) {
			$$$ThrowOnError(sc)
			Continue:(result.MultiDimensional)
			Set type = result.Type
			Try {
				Set isObject = $ClassMethod(type, "%Extends", "%RegisteredObject")
			} Catch e {
				Set isObject = 0
			}
			Set var = ##class(pkg.isc.codetidy.vartyping.Variable).%New(isObject, type)
			Set sc = ..VariableTracker.AddVar(".."_result.Name, var)
		}
		$$$ThrowOnError(sc)
	}

	// This gets rid of the first empty call to NextCommand()
	Do ..NextCommand()

	Quit $$$OK
}

/// Moves to the next command in the tokens and calls
/// ProcessCommand to handle the new command tokens.
Method NextCommand(pProcessVars As %Boolean = 1) As %Boolean
{
	Set ..PreviousLine = ..Line
	Set ..CurrentCommand = ..NextCommand
	Set pointer = ..Pointer
	Set tokens = ""
	Set firstWhiteSpace = 0
	While $Data(..Tokens(..Line)) {
		Set i = 0
		While $ListNext(..Tokens(..Line), pointer, token) {
			Set i = $Increment(i)
			Set type = $List(token, 2)
			Set command = $zconvert($List(token, 3), "l")
			If ((type = "Command") || (type = "Pre-Processor Command") || (type = "SQL") || (type = "HTML") || (type = "Javascript")) && (command '= "as") && (command '= "#") {
				Set ..NextCommand = ..GetCommand(command)
				Set ..Pointer = pointer
				Set ..CurrentTokens = tokens
				Do ..ProcessCommand(firstWhiteSpace, pProcessVars)
				Return 1
			}
			If (type '= "White Space") && (type '= "Comment") && (type '= "Brace") && (type '= "Pre-Processor Command") {
				Set tokens = tokens _ $ListBuild(token)
			} ElseIf (type = "White Space") && 'firstWhiteSpace {
				Set firstWhiteSpace = i
			}
		}
		Set pointer = 0
		Set ..Line = ..Line + 1
	}
	If tokens '= "" {
		Set ..CurrentTokens = tokens
		Do ..ProcessCommand(firstWhiteSpace, pProcessVars)
		Quit 1
	}
	Quit 0
}

/// Contains any commands that need to be run
/// to process the new command after NextCommand is called
Method ProcessCommand(pFirstWhiteSpace As %Integer, pProcessVars As %Boolean)
{
	Do ..ProcessPostconditional(pFirstWhiteSpace)
	If pProcessVars {
		Do ..VariableTracker.ProcessCommand(..CurrentCommand, ..CurrentTokens, ..Postconditional)
	}
}

/// If there is a postconditional to the command
/// it is added to the Postconditional property
/// and then the CurrentTokens property is trimmed
/// to no longer include the postconditional.
Method ProcessPostconditional(pFirstWhiteSpace As %Integer) [ Private ]
{
	Set ..Postconditional = ""
	If $ListGet(..CurrentTokens, 1) '= $ListBuild("COS", "Delimiter", ":") {
		Quit
	}
	Set pointer = 0, i = 0, conditionalEnd = pFirstWhiteSpace - 1
	While $ListNext(..CurrentTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i = 1)
		// set conditional end if there is a paranthesis
		If (i = 2) && (token = $ListBuild("COS", "Delimiter", "(")) {
			Set conditionalEnd = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetMatchingParen(..CurrentTokens, 2)
		}
		// add token to postconditional if paren is used:
		Set ..Postconditional = ..Postconditional _ $ListBuild(token)
		Quit:(i = conditionalEnd)
	}
	// exclude postconditional from curent tokens
	Set ..CurrentTokens = $List(..CurrentTokens, conditionalEnd + 1, $ListLength(..CurrentTokens))
}

/// Access variable information for pVarName
/// from the variable tracker.
Method GetVar(pVarName As %String) As pkg.isc.codetidy.vartyping.Variable
{
	Quit ..VariableTracker.Get(pVarName)
}

/*Method GetCurrentCode() As %String
{
	Set code = ""
	For i = ..PreviousLine:1:(..Line - 1) {
		Set tokens = ..Tokens(i)
		Set code = code _ ##class(WBScanner.Util.CodeFromTokens).CodeFromTokens(tokens) _ $$$NL
	}
	Quit code
}*/
/// Gets the actual code at the line
/// the parser is currently at.
/// Creates standard lowercase command format for common commands.
/// Converts the following short commands into their full name:
/// d, s, k, i, w, zw, m, f, b, q
/// Commands not included in the list will be unmodified
ClassMethod GetCommand(pCommand As %String) As %String [ Private ]
{
	Set lcVal = $ZConvert(pCommand, "L")
	Quit:(lcVal = "s") "set"
	Quit:(lcVal = "d") "do"
	Quit:(lcVal = "k") "kill"
	Quit:(lcVal = "i") "if"
	Quit:(lcVal = "w") "write"
	Quit:(lcVal = "zw") "zwrite"
	Quit:(lcVal = "m") "merge"
	Quit:(lcVal = "f") "for"
	Quit:(lcVal = "b") "break"
	Quit:(lcVal = "q") "quit"
	Quit lcVal
}

/// Send the parser back to the first command
Method Rewind() As %Status
{
	Set ..Line = 1
	Set ..Pointer = 0
	Set ..CurrentCommand = ""
	Do ..NextCommand()
}

/// Debugging method.
Method GoToEndOfMethod(pPrint As %Boolean = 0, pProcessVars As %Boolean = 1)
{
	While ..NextCommand(pProcessVars) {
		If pPrint {
			Write ..CurrentCommand, !
			ZWrite ..Postconditional
			Write !
			ZWrite ..CurrentTokens
			Write !!
		}
	}
}

}

