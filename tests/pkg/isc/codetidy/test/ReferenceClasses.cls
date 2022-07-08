Class pkg.isc.codetidy.test.ReferenceClasses Extends %UnitTest.TestCase
{

Property userConfig [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    merge ..userConfig = ^Config("CodeTidy")

    set ^Config("CodeTidy","brace")=1
    set ^Config("CodeTidy","capital")=0
    set ^Config("CodeTidy","codetidy")=1
    set ^Config("CodeTidy","coscomment")="//"
    set ^Config("CodeTidy","coswhitespace")=1
    set ^Config("CodeTidy","eslintenabled")=0
    set ^Config("CodeTidy","formatonsave")=0
    set ^Config("CodeTidy","indent")=1
    set ^Config("CodeTidy","indentString")="    "
    set ^Config("CodeTidy","resequence")=0
    set ^Config("CodeTidy","sqlcase")="U"
    set ^Config("CodeTidy","sqlplan")=1
    set ^Config("CodeTidy","tweak")="auto"
    set ^Config("CodeTidy","usemacrocomments")=0

    quit $$$OK
}

Method TestResequenceOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.ResequenceTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with resequencing enabled
    set ^Config("CodeTidy","resequence") = 1
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.ResequenceTestClassEnabled.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
    

    // Run CodeTidy with resequencing disabled
    set ^Config("CodeTidy","resequence") = 0
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.ResequenceTestClassDisabled.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
}

Method TestIndentationOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.IndentationTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    
    
    // Run CodeTidy with automatic indentation set to 4 spaces
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.IndentationTestClassSpaces.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }

    // Run CodeTidy with automatic indentation set to tabs
    set ^Config("CodeTidy","indentString") = $c(9)
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.IndentationTestClassTabs.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with automatic indentation disabled
    set ^Config("CodeTidy","indent") = 0 
    set ^Config("CodeTidy","indentString") = ""
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    Set truthFile = referenceRoot_"after/"_referenceClassItemName
    Set exportFile = referenceRoot_"compare/"_referenceClassItemName
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }

    set ^Config("CodeTidy","indent") = 1 
    set ^Config("CodeTidy","indentString") = "    "
}

Method TestExpansionOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.ExpansionTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with lower-case expansion
    set ^Config("CodeTidy","capital")=0
    set ^Config("CodeTidy","codetidy")=1
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.ExpansionTestClassLowerCase.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with Pascal-case expansion
    set ^Config("CodeTidy","codetidy") = 1
    set ^Config("CodeTidy","capital") = 1
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.ExpansionTestClassPascalCase.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with expansion disabled
    set ^Config("CodeTidy","codetidy") = 0
    set ^Config("CodeTidy","capital") = 0
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.ExpansionTestClass.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }

    set ^Config("CodeTidy","codetidy") = 1
}

Method TestCommentStyleOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.CommentStyleTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with lower-case expansion
    set ^Config("CodeTidy","coscomment")=";"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.CommentStyleTestClassSemicolon.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with Pascal-case expansion
    set ^Config("CodeTidy","coscomment")="#;"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.CommentStyleTestClassMacro.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with expansion disabled
    set ^Config("CodeTidy","coscomment")="//"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    
    set resultClass = "TestPackage.CommentStyleTestClassForwardSlash.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
}

Method TestSQLPlanOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.SQLPLanTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with lower-case expansion
    set ^Config("CodeTidy","sqlplan")="0"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLPLanTestClass.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with Pascal-case expansion
    set ^Config("CodeTidy","sqlplan")="1"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLPLanTestClassExplicit.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with expansion disabled
    set ^Config("CodeTidy","sqlplan")="2"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLPLanTestClassAlways.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
}

Method TestSQLCaseOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.SQLCaseTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with lower-case expansion
    set ^Config("CodeTidy","sqlcase")=""
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLCaseTestClass.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with Pascal-case expansion
    set ^Config("CodeTidy","sqlcase")="L"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLCaseTestClassLowerCase.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }


    // Run CodeTidy with expansion disabled
    set ^Config("CodeTidy","sqlcase")="U"
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.SQLCaseTestClassUpperCase.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass

    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
}

Method TestBraceOptions(DeleteCompFiles As %Numeric = 1)
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.BraceTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    

    // Run CodeTidy with resequencing enabled
    set ^Config("CodeTidy","brace") = 0
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.BraceTestClassDisabled.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
    

    // Run CodeTidy with resequencing disabled
    set ^Config("CodeTidy","brace") = 1
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))

    set resultClass = "TestPackage.BraceTestClassEnabled.cls"
    Set truthFile = referenceRoot_"after/"_resultClass
    Set exportFile = referenceRoot_"compare/"_resultClass
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    if DeleteCompFiles{
        Do ##class(%Library.File).Delete(exportFile)
    }
}

Method %OnClose() As %Status
{
    merge ^Config("CodeTidy") = ..userConfig
    quit $$$OK
}

}
