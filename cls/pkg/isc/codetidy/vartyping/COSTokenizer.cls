/// In all methods, <var>pTokens</var> will take the format:
/// <code>
/// pTokens(lineNumber) = $ListBuild(token1,token2,...,tokenN)
/// </code>
/// Where the format of an individual token is: <br />
/// <code>
/// $ListBuild(language,type,text)
/// </code>
Class pkg.isc.codetidy.vartyping.COSTokenizer
{

/// Returns an array of lists (per line) of tokens for a method's implementation
ClassMethod GetMethodImplementation(pClass As %Dictionary.CacheClassname, pMethod As %Dictionary.CacheIdentifier, Output pTokens, pNamespace As %String) As %Status
{
	If $Data(pNamespace) {
		New $Namespace
		Set $Namespace = pNamespace
	}
	Kill pTokens
	Set sc = $$$OK
	Try {
		Set method = ##class(%Dictionary.MethodDefinition).IDKEYOpen(pClass,pMethod,,.sc)
		$$$ThrowOnError(sc)
		//Only set tokens if the language is ObjectScript
		If (method.Language = "") || (method.Language = "cache") {
			Set sc = ##class(%Library.SyntaxColorReader).FromCode(method.Implementation,"COS","A",.reader)
			$$$ThrowOnError(sc)
			
			While reader.NextLine(.lineTokenList) {
				Set pTokens($Increment(pTokens)) = lineTokenList
			}
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Quit sc
}

ClassMethod GetRoutineImplementation(pRoutine As %String, Output pTokens, pNamespace As %String) As %Status
{
	If $Data(pNamespace) {
		New $Namespace
		Set $Namespace = pNamespace
	}
	Kill pTokens
	Set sc = $$$OK
	Try {
		set routine = ##class(%RoutineMgr).%OpenId(pRoutine)

		//Only set tokens if the language is ObjectScript (in this case 9 means basic)
		set langMode = routine.LanguageModeGet()
		If (langMode '= 9) {
			Set sc = ##class(%Library.SyntaxColorReader).FromCode(routine.Code,"COS","A",.reader)
			$$$ThrowOnError(sc)
			
			While reader.NextLine(.lineTokenList) {
				Set pTokens($Increment(pTokens)) = lineTokenList
			}
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Quit sc
}

/// Returns an array of lists (per line) of tokens for an SQL query
ClassMethod GetSQL(pQuery As %String, Output pTokens) As %Status
{
	Kill pTokens
	Set sc = $$$OK
	Try {
		Set stream = ##class(%Stream.TmpCharacter).%New()
		Do stream.Write(pQuery)
		
		Set sc = ##class(%Library.SyntaxColorReader).FromCode(stream,"SQL","A",.reader)
		$$$ThrowOnError(sc)
		
		While reader.NextLine(.lineTokenList) {
			Set pTokens($Increment(pTokens)) = lineTokenList
		}
	} Catch e {
		Set sc = e.AsStatus()
	}
	Quit sc
}

}

