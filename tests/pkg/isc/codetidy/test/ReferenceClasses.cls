Class pkg.isc.codetidy.test.ReferenceClasses Extends %UnitTest.TestCase
{

Property userConfig [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    merge ..userConfig = ^Config("CodeTidy")

    set ^Config("CodeTidy","brace")=0
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

Method TestResequenceOptions()
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.ResequenceTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName

    Set exportFile = referenceRoot_"compare/"_referenceClassItemName
    
    // Run CodeTidy with resequencing enabled
    set ^Config("CodeTidy","resequence") = 1
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    Set truthFile = referenceRoot_"after/"_referenceClassItemName
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    Do ##class(%Library.File).Delete(exportFile)


    // Run CodeTidy with resequencing disabled
    set ^Config("CodeTidy","resequence") = 0
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    Set truthFile = referenceRoot_"before/"_referenceClassItemName
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    Do ##class(%Library.File).Delete(exportFile)
}

Method TestIndentationOptions()
{
    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    set referenceClassItemName = "TestPackage.IndentationTestClass.cls"
    set referenceClassName = referenceRoot_"before/"_referenceClassItemName
    
    // Run CodeTidy with automatic indentation set to 4 spaces
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")
    
    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    Set truthFile = referenceRoot_"after/"_"TestPackage.IndentationTestClassSpaces.cls"
    Set exportFile = referenceRoot_"compare/"_referenceClassItemName
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    Do ##class(%Library.File).Delete(exportFile)


    // Run CodeTidy with automatic indentation set to tabs
    set ^Config("CodeTidy","indentString") = $c(9)
    Do $$$AssertStatusOK($System.OBJ.Load(referenceClassName), "ck")

    Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClassItemName))
    Set truthFile = referenceRoot_"after/"_"TestPackage.IndentationTestClassTabs.cls"
    Set exportFile = referenceRoot_"compare/"_referenceClassItemName
    // Note: this appends an extra newline at the end. "after" files need this.
    Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClassItemName,exportFile))
    Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClassItemName)
    Do ##class(%Library.File).Delete(exportFile)


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
    Do ##class(%Library.File).Delete(exportFile)
}

Method %OnClose() As %Status
{
    merge ^Config("CodeTidy") = ..userConfig
    quit $$$OK
}

}
