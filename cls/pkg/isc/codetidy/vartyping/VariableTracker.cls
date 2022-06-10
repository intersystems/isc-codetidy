/// This class is used by CommandParser to keep track
/// of the types and UserInput included in variables.
/// Do not use this class directly, use CommandParser instead.
Class pkg.isc.codetidy.vartyping.VariableTracker Extends %RegisteredObject
{

// This is a multidimensional array of pkg.isc.codetidy.vartyping.Variable

// types that is keyed by the entire variable name.

// This includes any ".." or object name (like varTracker.Variables)

// to prevent variables with the same name that are actually different

// from overwriting each other.

Property Variables [ MultiDimensional, Private ];

Property MultiDimensionalProperties As %List;

Property Namespace As %String;

Property Class As %Dictionary.Classname;

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
Method %OnNew(pParameters As %String, pMultiDimensionalProperties As %List = "", pNamespace As %String, pUserInputArgIndices As %List = "", pAllArgsUserInput As %Boolean = 0, pClass As %Dictionary.Classname) As %Status [ Private, ServerOnly = 1 ]
{
	Kill ..Variables
	// Add parameters to Variables property
	Do ..ProcessParameters(pParameters, pUserInputArgIndices, pAllArgsUserInput)
	Set ..MultiDimensionalProperties = pMultiDimensionalProperties
	Set ..Namespace = pNamespace
	Set ..Class = pClass
	Quit $$$OK
}

/// This is the method called by CommandParser to
/// add the new variables to this tracker.
Method ProcessCommand(pCommand As %String, pTokens As %List, pPostconditional As %List) As %Status
{
	// VarsInCommand creates the new variable objects if needed
	Do ..VarsInCommand(pTokens)
	Do ..VarsInCommand(pPostconditional)

	// Now add any type or contributing variable
	// information with the parse methods
	If pCommand = "set" {
		Do ..ParseSet(pTokens)
	} ElseIf pCommand = "dim" {
		Do ..ParseDim(pTokens)
	}
}

Method AddVar(pVarName As %String, pVar As pkg.isc.codetidy.vartyping.Variable) As %Status
{
	If $Data(..Variables(pVarName)) {
		Quit $$$ERROR($$$GeneralError, "Variable already defined")
	} Else {
		Set ..Variables(pVarName) = pVar
		Quit $$$OK
	}
}

/// Get a variable from the array of variables
Method Get(pVarName As %String) As pkg.isc.codetidy.vartyping.Variable
{
	Quit $Get(..Variables(pVarName))
}

/// Add formal parameters to ..Variables, called by %OnNew.
Method ProcessParameters(pParameters As %String, pUserInputArgIndices As %List, pAllArgsUserInput As %Boolean)
{
	Set list = $ListFromString(pParameters, ",")
	Set pointer = 0, i = 0
	While $ListNext(list, pointer, var) {
		Set i = $Increment(i)
		Set varName = $Piece(var, ":")
		Set firstChar = $Extract(varName, 1)
		If (firstChar = "&") || (firstChar = "*") {
			Set varName = $Extract(varName, 2, *)
		}
		Set type = $Piece($Piece(var, ":", 2), "=")
		Set type = $Piece(type, "(")
		Set isObject = ..IsObject(type)
		Set ..Variables(varName) = ##class(pkg.isc.codetidy.vartyping.Variable).%New(isObject, type)
		If pAllArgsUserInput || $ListFind(pUserInputArgIndices, i) {
			Set ..Variables(varName).UserInputFlag = 1
		}
	}
}

/// Adds new variables from the tokens to Variables.
/// If the variable has already been encountered, it is not added.
Method VarsInCommand(pTokens As %List)
{
	Set pointer = 0, i = 0, processedToIndex = -1
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		// continue if this index has already been processed
		Continue:(i <= processedToIndex)
		Set $ListBuild(language, type, value) = token
		// if the token is a local variable or a multidimensional property
		Set isMultidimensionalProperty = (type = "Object member") && $ListFind(..MultiDimensionalProperties, value)
		If (type = "Local variable") || isMultidimensionalProperty {
			If isMultidimensionalProperty {
				Set value = ".." _ value
			}
			Set nextToken = $ListGet(pTokens, i + 1)
			Set isVariable = 1
			If nextToken = $ListBuild("COS", "Object dot operator", ".") {
				Set isVariable = ..GetRemainingAttributes(pTokens, i + 1, .endIndex, .string)
				If isVariable {
					Set value = value _ string
					Set processedToIndex = endIndex
				}
			}
			// find matching parentheses for multidimensional vars and find the whole var name
			ElseIf nextToken = $ListBuild("COS", "Delimiter", "(") {
				Set endIndex = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetMatchingParen(pTokens, i + 1)
				// iterate through the multidimensional array
				While $ListNext(pTokens, pointer, token) {
					Set i = $Increment(i)
					Set value = value _ $List(token, 3)
					Quit:(i = endIndex)
				}
				Set isVariable = ..GetRemainingAttributes(pTokens, i + 1, .endIndex, .string)
				If isVariable {
					Set value = value _ string
					Set processedToIndex = endIndex
				}
			}
			// create the variable if it does not already exist
			If '$Data(..Variables(value)) && isVariable {
				Set ..Variables(value) = ##class(pkg.isc.codetidy.vartyping.Variable).%New()
			}
		} ElseIf type = "Object attribute" {
			Set dotValue = $List($List(pTokens, i - 1), 3)
			If dotValue = ".." {
				Set:('$Data(..Variables(".."_value))) ..Variables(".."_value) = ##class(pkg.isc.codetidy.vartyping.Variable).%New()
			}
		} ElseIf type = "Object property" {
			// Skip pound symbol
			Continue:(value = "#")
			Set:('$Data(..Variables("..#"_value))) ..Variables("..#"_value) = ##class(pkg.isc.codetidy.vartyping.Variable).%New()
		}
	}
}

/// Returns the remaining object attributes in the token list through pString.
/// If the remaining parts suggest this is a method call and not a variable,
/// this will return false, otherwise it will return true.
/// pStartIndex should be the index of the object dot token.
/// pEndIndex is the last index evaluated by the method.
ClassMethod GetRemainingAttributes(pTokens As %List, pStartIndex As %Integer, Output pEndIndex, Output pString) As %Boolean
{
	Set i = 0, pointer = 0
	Set shouldBeDot = 1
	Set pString = ""
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i < pStartIndex)
		If shouldBeDot {
			// if not a dot, then the end of the var has been reached.
			If token '=  $ListBuild("COS", "Object dot operator", ".") {
				Set pEndIndex = i
				Return 1
			} Else {
				Set shouldBeDot = 0
				Continue
			}
		} Else {
			// if not a method call, then add to the output string and expect a dot next
			If ($List(token, 2) = "Object attribute") || ($List(token, 2) = "Object property") {
				Set pString = pString _ "." _ $List(token, 3)
				Set shouldBeDot = 1
			// this is most likely a method call (might be a call to a multidimensional variable but it's not simple to tell)
			} ElseIf $List(token, 2) = "Object member" {
				Return 0
			}
		}
	}
	// return 1 by default since it has reached the end of the line without any problems
	Set pEndIndex = $ListLength(pTokens)
	Quit 1
}

/// Parses a set command, calls FindVars on the expression
/// and tries to get a type from the expression.
/// Adds that information to the variable being set
Method ParseSet(pTokens As %List)
{
	// get the variable name and position of equals sign
	Set pointer = 0, varname = "", i = 0
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		If token = $ListBuild("COS", "Operator", "=") {
			Quit
		} Else {
			Set varname = varname _ $List(token, 3)
		}
	}
	// get the expression from the set command (anything to the left of =)
	Set expression = $List(pTokens, i + 1, $ListLength(pTokens))
	// Now set the info we can find for the var being set
	// the new Variable object is already created
	// for this varname when VarsInCommand is called before this
	Set userInputFlag = 0
	Set contributingVars = ..FindContributingVars(expression, .userInputFlag)
	If '$Data(..Variables(varname)) {
		// debugging write statement to expose unimplemented variable patterns
		//Write "could not process the left half of the set command: ", varname, !
		Quit
	}
	Set ..Variables(varname).ContributingVariables = contributingVars
	// set input flag
	If userInputFlag {
		Set ..Variables(varname).UserInputFlag = 1
	} Else {
		// set the variable from the set statement to have user input
		// if one of the contributing vars has user input
		Set pointer = 0
		While $ListNext(contributingVars, pointer, var) {
			If '$Data(..Variables(var)) {
				// debugging write statement to expose unimplemented variable patterns
				//Write "Could not find variable ", var, " in variables array, attempting to find it when parsing the set command", !
				Continue
			}
			If ..Variables(var).UserInputFlag {
				// set the variable from the set statement to have user input
				Set ..Variables(varname).UserInputFlag = 1
				Quit
			}
		}
	}
	Set methodCalls = ##class(pkg.isc.codetidy.vartyping.MethodsCalled).MethodCallsInCommand(expression)
	Set type = ..GetTypeFromExpression(methodCalls)

	Set ..Variables(varname).Type = type
	Set ..Variables(varname).Object = ..IsObject(type)
}

/// Parse a dim command to find the type of the variable
Method ParseDim(pTokens As %List)
{
	Set foundAs = 0, pointer = 0, var = "", type = ""
	While $ListNext(pTokens, pointer, token) {
		Set value = $List(token, 3)
		If 'foundAs {
			Set lcValue = $ZConvert(value, "L")
			If lcValue = "as" {
				Set foundAs = 1
				Continue
			}
			Set var = var _ value
		} Else {
			// quit if initial value is started
			Quit:(value = "=")
			Continue:($List(token, 2) = "Delimiter")
			Set type = type _ value
		}
	}
	If '$Data(..Variables(var)) {
		// debugging write statement to expose unimplemented variable patterns
		//Write "Could not find var ", var, " in variables array from #dim statement.", !
		// Quit
		Set ..Variables(var) = ##class(pkg.isc.codetidy.vartyping.Variable).%New(..IsObject(type), type)
	}
	//} else {
	Set ..Variables(var).Type = type
	Set ..Variables(var).Object = ..IsObject(type)
	//}
}

/// Finds and returns all variables that contribute directly
/// to the expression.
ClassMethod FindContributingVars(pTokens As %List, Output pUserInputFlag, pMultiDimensionalProperties As %List = "") As %List
{
	Set vars = ""
	// iterate through this expression
	Set pointer = 0, i = 0, lastPos = -1
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i <= lastPos)
		// Exception: $case
		Set lcValue = $ZConvert($List(token, 3), "L")
		If (lcValue = "$case") && ($List(token, 2) = "Function") {
			Set vars = vars _ ..ProcessCaseArgs(##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetArguments(pTokens, i + 1, .lastPos), .pUserInputFlag)
			Continue
		}
		// Exception: $select
		ElseIf ((lcValue = "$select") || (lcValue = "$s")) && ($List(token, 2) = "Function") {
			Set vars = vars _ ..ProcessSelectVars(##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetArguments(pTokens, i + 1, .lastPos), .pUserInputFlag)
		}

		// Default behavior
		Set $ListBuild(language, type, value) = token
		Set isMultidimensionalProperty = (type = "Object member") && $ListFind(pMultiDimensionalProperties, value)
		If (type = "Local variable") || isMultidimensionalProperty {
			If isMultidimensionalProperty {
				Set value = ".." _ value
			}
			Set isVariable = 1
			Set nextToken = $ListGet(pTokens, i + 1)
			If nextToken = $ListBuild("COS", "Object dot operator", ".") {
				Set postDotToken = $ListGet(pTokens, i + 2)
				// hard-coded exception for %request.Get/Data("var")
				If (value = "%request") && ($List(postDotToken, 2) = "Object member") {
					Set postDotValue = $List(postDotToken, 3)
					If (postDotValue = "Get") || (postDotValue = "Data") {
						Set pUserInputFlag = 1
						Set isVariable = 0
						// set the last position to the end parenthesis
						Set lastPos = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetMatchingParen(pTokens, i + 3)
						Continue
					}
				}
				Set isVariable = ..GetRemainingAttributes(pTokens, i + 1, .endIndex, .string)
				If isVariable {
					Set value = value _ string
					Set lastPos = endIndex
				}
			}
			// find matching parentheses for multidimensional vars and find the whole var name
			ElseIf nextToken = $ListBuild("COS", "Delimiter", "(") {
				Set endIndex = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetMatchingParen(pTokens, i + 1)
				While $ListNext(pTokens, pointer, token) {
					Set i = $Increment(i)
					Set value = value _ $List(token, 3)
					Quit:(i = endIndex)
				}
				Set isVariable = ..GetRemainingAttributes(pTokens, i + 1, .endIndex, .string)
				If isVariable {
					Set value = value _ string
					Set lastPos = endIndex
				}
			}
			If isVariable {
				Set vars = vars _ $ListBuild(value)
			}
		} ElseIf type = "Object attribute" {
			Set dotValue = $List($ListGet(pTokens, i - 1), 3)
			If dotValue = ".." {
				Set vars = vars _ $ListBuild(".."_value)
			}
		} ElseIf type = "Object property" {
			// The pound symbol comes up as an object property
			Continue:(value = "#")
			Set vars = vars _ $ListBuild("..#"_value)
		}
	}
	Quit vars
}

/// Takes in arguments of $case and determines the variables
/// that could directly contribute to the output of $case.
ClassMethod ProcessCaseArgs(pArgs As %List, ByRef pUserInputFlag) As %List
{
	Set pointer = 0
	Set vars = ""
	Set skip = 1
	While $ListNext(pArgs, pointer, arg) {
		// skip the first argument since it has no direct output
		If skip {
			Set skip = 0
			Continue
		}
		// get the direct output (after ":")
		Set colonPos = $ListFind(arg, $ListBuild("COS", "Delimiter", ":"))
		Set expression = $List(arg, colonPos + 1, $ListLength(arg))
		Set vars = vars _ ..FindContributingVars(expression, .pUserInputFlag)
	}
	Quit vars
}

/// Takes in arguments to $select and determines variables that
/// directly contribute to the output of $select.
ClassMethod ProcessSelectVars(pArgs As %List, ByRef pUserInputFlag) As %List
{
	Set pointer = 0
	Set vars = ""
	While $ListNext(pArgs, pointer, arg) {
		Set colonPos = $ListFind(arg, $ListBuild("COS", "Delimiter", ":"))
		Set expression = $List(arg, colonPos + 1, $ListLength(arg))
		Set vars = vars _ ..FindContributingVars(expression, .pUserInputFlag)
	}
	Quit vars
}

/// Searches for use of %New or %OpenId and returns the class that called it
Method GetTypeFromExpression(pMethodCalls As %ListOfDataTypes) As %String
{
	// iterate through all method calls in the command
	Set key = ""
	For {
		Set call = pMethodCalls.GetNext(.key)
		Quit:(key = "")
		// if 
		If (call.MethodName = "%New") || (call.MethodName = "%OpenId") {
			// if the caller is a defined variable, then return that var's type
			Set caller = call.Caller
			If (call.Caller = ".") {
				Return ..Class
			}
			If $Data(..Variables(caller)) {
				Return ..Variables(caller).Type
			}
			// Otherwise, it should be a ##class call
			Return caller
		} ElseIf (call.Caller '= ".") {
			// Lookup the return type
			set id = call.Caller_"||"_call.MethodName
			set method = ##class(%Dictionary.MethodDefinition).%OpenId(id,,.sc)
			if $$$ISOK(sc) {
				return method.ReturnType
			}
		}
	}
	Quit ""
}

/// Deterimines whether a type is an object
Method IsObject(pType As %Dictionary.Classname) As %Boolean
{
	// quit 0 if no type defined
	Quit:(pType = "") 0
	Try {
		New $Namespace
		Set $Namespace = ..Namespace
		Set isObject = $ClassMethod(pType, "%Extends", "%RegisteredObject")
	} Catch e {
		// debugging write statement to expose what types are failing
		//Write "Could not determine object status of type: ", pType, !
		Return 0
	}
	// otherwise its an object if it extends Registered Object
	Quit isObject
}

/// Prints all current variables and their properties
Method Print()
{
	// iterate through Variables and print its properties
	Set key = $Order(..Variables(""))
	While (key '= "") {
		w "Variable: ", key, !
		w "IsObject: ", ..Variables(key).Object, !
		w "UserInputFlag: ", ..Variables(key).UserInputFlag, !
		w "Type: ", ..Variables(key).Type, !
		w "contributing to: ", key, !
		zw ..Variables(key).ContributingVariables
		w !!
		Set key = $Order(..Variables(key))
	}
}

Method OutputVars(Output pVariables)
{
	Kill pVariables
	Merge pVariables = ..Variables
}

}

