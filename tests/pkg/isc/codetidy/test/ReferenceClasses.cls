Class pkg.isc.codetidy.test.ReferenceClasses Extends %UnitTest.TestCase
{

Property userConfig [ MultiDimensional ];

Property userSourceControl As %String;

Property deleteFiles As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
	set ..userSourceControl = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
	do ##class(%Studio.SourceControl.Interface).SourceControlClassSet("")
	do ##class(pkg.isc.codetidy.Utils).SetupExtension()
	merge ..userConfig = ^Config("CodeTidy")

	set ^Config("CodeTidy", "brace") = 1
	set ^Config("CodeTidy", "capital") = 0
	set ^Config("CodeTidy", "codetidy") = 1
	set ^Config("CodeTidy", "coscomment") = "//"
	set ^Config("CodeTidy", "coswhitespace") = 1
	set ^Config("CodeTidy", "eslintenabled") = 0
	set ^Config("CodeTidy", "formatonsave") = 0
	set ^Config("CodeTidy", "indent") = 1
	set ^Config("CodeTidy", "indentString") = "    "
	set ^Config("CodeTidy", "resequence") = 0
	set ^Config("CodeTidy", "sqlcase") = "U"
	set ^Config("CodeTidy", "sqlplan") = 1
	set ^Config("CodeTidy", "tweak") = "auto"
	set ^Config("CodeTidy", "usemacrocomments") = 0

	quit $$$OK
}

/*
Method TestResequenceOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.ResequenceTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	// Run CodeTidy with resequencing enabled
	set ^Config("CodeTidy", "resequence") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.ResequenceTestClassEnabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
	

	// Run CodeTidy with resequencing disabled
	set ^Config("CodeTidy", "resequence") = 0
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.ResequenceTestClassDisabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestIndentationOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.IndentationTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	
	// Run CodeTidy with automatic indentation set to 4 spaces
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.IndentationTestClassSpaces.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	// Run CodeTidy with automatic indentation set to tabs
	set ^Config("CodeTidy", "indentString") = $char(9)
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.IndentationTestClassTabs.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with automatic indentation disabled
	set ^Config("CodeTidy", "indent") = 0
	set ^Config("CodeTidy", "indentString") = ""
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
	set truthFile = referenceRoot _ "after/" _ referenceClassItemName
	set exportFile = referenceRoot _ "compare/" _ referenceClassItemName
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "indent") = 1
	set ^Config("CodeTidy", "indentString") = "    "
}

Method TestAutoTweakOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.AutoTweakTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with auto-tweak enabled
	set ^Config("CodeTidy", "tweak") = "auto"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.AutoTweakTestClassEnabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
	

	// Run CodeTidy with auto-tweak disabled
	set ^Config("CodeTidy", "tweak") = ""
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.AutoTweakTestClassDisabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestExpansionOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.ExpansionTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with lower-case expansion
	set ^Config("CodeTidy", "capital") = 0
	set ^Config("CodeTidy", "codetidy") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.ExpansionTestClassLowerCase.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with Pascal-case expansion
	set ^Config("CodeTidy", "codetidy") = 1
	set ^Config("CodeTidy", "capital") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.ExpansionTestClassPascalCase.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with expansion disabled
	set ^Config("CodeTidy", "codetidy") = 0
	set ^Config("CodeTidy", "capital") = 0
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.ExpansionTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "codetidy") = 1
}

Method TestCommentStyleOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.CommentStyleTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with lower-case expansion
	set ^Config("CodeTidy", "coscomment") = ";"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.CommentStyleTestClassSemicolon.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with Pascal-case expansion
	set ^Config("CodeTidy", "coscomment") = "#;"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.CommentStyleTestClassMacro.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with expansion disabled
	set ^Config("CodeTidy", "coscomment") = "//"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
	
	set resultClass = "TestPackage.CommentStyleTestClassForwardSlash.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestSQLPlanOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.SQLPLanTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with lower-case expansion
	set ^Config("CodeTidy", "sqlplan") = "0"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLPLanTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with Pascal-case expansion
	set ^Config("CodeTidy", "sqlplan") = "1"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLPLanTestClassExplicit.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with expansion disabled
	set ^Config("CodeTidy", "sqlplan") = "2"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLPLanTestClassAlways.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestSQLCaseOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.SQLCaseTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with lower-case expansion
	set ^Config("CodeTidy", "sqlcase") = ""
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLCaseTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with Pascal-case expansion
	set ^Config("CodeTidy", "sqlcase") = "L"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLCaseTestClassLowerCase.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}


	// Run CodeTidy with expansion disabled
	set ^Config("CodeTidy", "sqlcase") = "U"
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SQLCaseTestClassUpperCase.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestBraceOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.BraceTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with resequencing enabled
	set ^Config("CodeTidy", "brace") = 0
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.BraceTestClassDisabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
	

	// Run CodeTidy with resequencing disabled
	set ^Config("CodeTidy", "brace") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.BraceTestClassEnabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestSpacingOptions()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.SpacingTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	

	// Run CodeTidy with resequencing enabled
	set ^Config("CodeTidy", "coswhitespace") = 0
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SpacingTestClassDisabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
	

	// Run CodeTidy with resequencing disabled
	set ^Config("CodeTidy", "coswhitespace") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.SpacingTestClassEnabled.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass
	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestJSONLinting()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.JSONBracketMatching.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONBracketMatching.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONBracketOneLine.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONBracketOneLine.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONIndent.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONIndent.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONBracketMixed.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONBracketMixed.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONOneDimArray.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONOneDimArray.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONNested.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONNested.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONEmptyArray.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONEmptyArray.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceClassItemName = "TestPackage.JSONInMacro.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSONInMacro.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestHTMLIndent()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.HTMLIndentTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.HTMLIndentTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestJSIndent()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.JSIndentTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.JSIndentTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestRoutine()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.BasicTestRoutine.mac"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.BasicTestRoutine.mac"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestBlockComment()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.BlockCommentTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.BlockCommentTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestCapital()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.CapitalTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	set oldConfig = $get(^Config("CodeTidy", "capital"))
	set ^Config("CodeTidy", "capital") = 1
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set ^Config("CodeTidy", "capital") = oldConfig

	set resultClass = "TestPackage.CapitalOnTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.CapitalTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")

	set oldConfig = $get(^Config("CodeTidy", "capital"))
	set ^Config("CodeTidy", "capital") = 0
	
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set ^Config("CodeTidy", "capital") = oldConfig

	set resultClass = "TestPackage.CapitalOffTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
}

Method TestUseMacroComment()
{
	set oldCommentStyle = $get(^Config("CodeTidy", "coscomment"))
	set oldUseMacro = $get(^Config("CodeTidy", "usemacrocomments"))
	set oldTweak = $get(^Config("CodeTidy", "tweak"))

	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.MacroCommentTestClass.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName

	set ^Config("CodeTidy", "tweak") = "auto"
	set ^Config("CodeTidy", "usemacrocomments") = 0
	set ^Config("CodeTidy", "coscomment") = "//"
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOffSlashTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "coscomment") = "#;"
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOffMacroTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "coscomment") = ";"
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOffSemicolon.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "usemacrocomments") = 1
	set ^Config("CodeTidy", "coscomment") = "//"

	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOnSlashTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}
	
	set ^Config("CodeTidy", "coscomment") = "#;"

	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOnMacroTestClass.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "coscomment") = ";"
	
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set resultClass = "TestPackage.MacroCommentOnSemicolon.cls"
	set truthFile = referenceRoot _ "after/" _ resultClass
	set exportFile = referenceRoot _ "compare/" _ resultClass

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	// In pre 2024.1.2 this adds an additional newline, breaking unit tests. Local development should be against latest IRIS version.
	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	set ^Config("CodeTidy", "tweak") = oldTweak
	set ^Config("CodeTidy", "usemacrocomments") = oldUseMacro
	set ^Config("CodeTidy", "coscomment") = oldCommentStyle
}

Method TestMacroMultiArg()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.MacroMultiArg.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName

	// turn on white space tidying for function arguments
	set oldCodeTidy = $get(^Config("CodeTidy","codeitdy"))
	set ^Config("CodeTidy","codetidy") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set truthFile = referenceRoot _ "after/" _ referenceClassItemName
	set exportFile = referenceRoot _ "compare/" _ referenceClassItemName

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	if oldCodeTidy '= "" {
		set ^Config("CodeTidy", "codetidy") = oldCodeTidy
	} else {
		kill ^Config("CodeTidy", "codetidy")
	}
}
*/
Method TestInLineJS()
{
	set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir _ "/../../../../_reference")
	set referenceClassItemName = "TestPackage.TestInLineJS.cls"
	set referenceClassName = referenceRoot _ "before/" _ referenceClassItemName

	// turn on white space tidying for function arguments
	set oldIndent = $get(^Config("CodeTidy","indent"))
	set ^Config("CodeTidy","indent") = 1
	do $$$AssertStatusOK($system.OBJ.Load(referenceClassName), "ck")
	do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

	set truthFile = referenceRoot _ "after/" _ referenceClassItemName
	set exportFile = referenceRoot _ "compare/" _ referenceClassItemName

	set currentDir = ..Manager.CurrentDir
	zwrite currentDir, referenceRoot, exportFile

	do $$$AssertStatusOK($system.OBJ.ExportUDL(referenceClassItemName, exportFile))
	do $$$AssertFilesSame(exportFile, truthFile, "Files match: " _ referenceClassItemName)
	if ..deleteFiles {
		do ##class(%Library.File).Delete(exportFile)
	}

	if oldIndent '= "" {
		set ^Config("CodeTidy", "indent") = oldIndent
	} else {
		kill ^Config("CodeTidy", "indent")
	}
}

Method %OnClose() As %Status
{
	do ##class(%Studio.SourceControl.Interface).SourceControlClassSet(..userSourceControl)
	kill ^Config("CodeTidy")
	merge ^Config("CodeTidy") = ..userConfig
	quit $$$OK
}

}
