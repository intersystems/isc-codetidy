Class pkg.isc.codetidy.test.ReferenceClasses Extends %UnitTest.TestCase
{

Method TestAllReferenceClasses()
{
    // TODO: Automate setting all the settings properly before running this test,
    //      restoring after running this test
    // TODO: Somehow capture/automate CodeTidy configuration for each class (?)
    // TODO: Somehow capture expected set of warnings / output for each class
    //      Recommendation: Open + Use a file when calling Utils:Run and
    //      have a parallel folder in _reference where <classname>.cls contains
    //      the expected set of warnings.

    Set referenceRoot = ##class(%Library.File).NormalizeDirectory(..Manager.CurrentDir_"/../../../../_reference")
    Write !,referenceRoot

    // Iterate over reference classes
    Set referenceClasses = ##class(%Library.File).FileSetFunc(referenceRoot_"before")
    While referenceClasses.%Next(.sc) {
        $$$ThrowOnError(sc)
        Do $$$AssertStatusOK($System.OBJ.Load(referenceClasses.Name,"ck"))
        // Run CodeTidy with everything enabled
        Do $$$AssertStatusOK(##class(pkg.isc.codetidy.Utils).Run(referenceClasses.ItemName))
        Set exportFile = referenceRoot_"compare/"_referenceClasses.ItemName
        Set truthFile = referenceRoot_"after/"_referenceClasses.ItemName
        // Note: this appends an extra newline at the end. "after" files need this.
        Do $$$AssertStatusOK($System.OBJ.ExportUDL(referenceClasses.ItemName,exportFile))
        Do $$$AssertFilesSame(exportFile,truthFile,"Files match: "_referenceClasses.ItemName)
        Do ##class(%Library.File).Delete(exportFile)
    }
    $$$ThrowOnError(sc)
}

}
