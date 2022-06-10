/// Finds methods called from an ObjectScript command
Class pkg.isc.codetidy.vartyping.MethodsCalled
{

/// Returns all method calls in the method in pMethodCalls.
ClassMethod GetMethodCalls(pClass As %Dictionary.Classname, pMethod As %Dictionary.Identifier, pNamespace As %String, Output pMethodCalls) As %Status
{
	Set sc = $$$OK
	Try {
		Kill pMethodCalls
		Set commandParser = ##class(pkg.isc.codetidy.vartyping.CommandParser).%New(pClass, pMethod, pNamespace)
		While commandParser.NextCommand(0) {
			Set methodCalls = ..MethodCallsInCommand(commandParser.CurrentTokens)
			Set methodCallsInPostconditional = ..MethodCallsInCommand(commandParser.Postconditional)
			Do ..AddListToArray(.pMethodCalls, methodCalls)
			Do ..AddListToArray(.pMethodCalls, methodCallsInPostconditional)
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Quit sc
}

ClassMethod AddListToArray(ByRef pArray, pList As %ListOfDataTypes)
{
	Set key = ""
	For {
		Set element = pList.GetNext(.key)
		Quit:(key = "")
		Set pArray($Increment(pArray)) = element
	}
}

ClassMethod MethodCallsInCommand(pTokens As %List) As %ListOfDataTypes
{
	Set pointer = 0, i = 0
	Set lastPos = 1
	Set methodCalls = ##class(%ListOfDataTypes).%New()
	Set pTokens = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).ReplaceClass(pTokens)
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i < lastPos)
		Set $ListBuild(language, type, value) = token
		If (type = "Object member") || (type = "Object method") {
			Set dotOperator = $List($List(pTokens, i - 1), 3)
			If dotOperator = ".." {
				Set caller = "."
			} ElseIf dotOperator = "." {
				Set caller = $List($List(pTokens, i - 2), 3)
			}
			If $ListGet(pTokens, i + 1) = $ListBuild("COS", "Delimiter", "(") {
				Set args = ##class(pkg.isc.codetidy.vartyping.TokenProcessors).GetArguments(pTokens, i + 1, .lastPos)
			}
			Do methodCalls.Insert(##class(pkg.isc.codetidy.vartyping.MethodCall).%New(args, caller, value))
		}
	}
	Quit methodCalls
}

}

