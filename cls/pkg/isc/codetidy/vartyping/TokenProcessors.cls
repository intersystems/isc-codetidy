Class pkg.isc.codetidy.vartyping.TokenProcessors
{

/// Returns a list of the arguments (which are themselves lists of tokens)
/// the pStartAt should be the index of the "(" token, otherwise "" will be returned
/// pEndPosition retuns the position of the closing paranthesis
ClassMethod GetArguments(pTokens As %List, pStartAt As %Integer = 1, Output pEndPosition) As %List
{
	Set pointer = 0, i = 0, parenReq = 0
	Set args = "", currentArg = ""
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i < pStartAt)
		If token = $ListBuild("COS", "Delimiter", "(") {
			Set parenReq = $Increment(parenReq)
			If parenReq > 1 {
				Set currentArg = currentArg _ $ListBuild(token)
			}
		} ElseIf token = $ListBuild("COS", "Delimiter", ")") {
			Set parenReq = $Increment(parenReq, -1)
			If parenReq = 0 {
				Set args = args _ $ListBuild(currentArg)
				Set pEndPosition = i
				Quit
			} Else {
				Set currentArg = currentArg _ $ListBuild(token)
			}
		} ElseIf (token = $ListBuild("COS", "Delimiter", ",")) && (parenReq = 1) {
			Set args = args _ $ListBuild(currentArg)
			Set currentArg = ""
		} Else {
			Set currentArg = currentArg _ $ListBuild(token)
		}
	}
	Quit args
}

/// Returns the index of the matching Parenthesis
/// pStartAt is the index of the opening parenthesis
ClassMethod GetMatchingParen(pTokens As %List, pStartAt As %Integer = 1) As %Integer
{
	Set pointer = 0, i = 0, parenReq = 0
	While $ListNext(pTokens, pointer, token) {
		Set i = $Increment(i)
		Continue:(i < pStartAt)
		If token = $ListBuild("COS", "Delimiter", "(") {
			Set parenReq = $Increment(parenReq)
		} ElseIf token = $ListBuild("COS", "Delimiter", ")") {
			Set parenReq = $Increment(parenReq, -1)
			If parenReq = 0 {
				Return i
			}
		}
	}
	Quit 0
}

/// Replace ##class() syntax with custom token so caller can be detected easier
/// class call tokens will now look like: $ListBuild("Custom", "Object (Class)", 
ClassMethod ReplaceClass(pTokens As %List) As %List
{
	Set pointer = 0
	Set result = ""
	While $ListNext(pTokens, pointer, token) {
		If $List(token, 2) = "Object (Class)" {
			Set caller = ""
			While $ListNext(pTokens, pointer, token) {
				Set caller = caller _ $List(token, 3)
				Quit:(token = $ListBuild("COS", "Delimiter", ")"))
			}
			Set caller = $Extract(caller, 2, *-1)
			Set result = result _ $ListBuild($ListBuild("Custom", "Object (Class)", caller))
		} Else {
			Set result = result _ $ListBuild(token)
		}
	}
	Quit result
}

}

