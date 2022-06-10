/// For environments using CCR, this helps to automate CodeTidy configuration in a standard way
Class pkg.isc.codetidy.CodeTidyCCREventHandler Extends %Studio.SourceControl.CCREventHandler
{

/// This method is called by the CCR Refresh logic, after the items have been refreshed into the namespace.  It is intended for any additional configuration work which 
/// may be necessary (e.g. initialization of reference tables, building of 3rd party sources, etc)
Method RefreshFinalize() As %Status
{
	quit ##class(pkg.isc.codetidy.Utils).SetupExtension()
}

}

