/// Studio extension to dispatch to multiple other Studio extensions
/// Configuration API provided in pkg.isc.codetidy.extension.CompositeMethodOverrides
Class pkg.isc.codetidy.extension.Composite Extends (%Studio.Extension.Base, pkg.isc.codetidy.extension.Utils, pkg.isc.codetidy.extension.CompositeMethodOverrides) [ Inheritance = right, Owner = {%Developer} ]
{

Query MainMenus(Classname As %String) As %SQLQuery [ SqlProc ]
{
	SELECT Name, Type FROM %Studio_Extension.Menu WHERE MenuBase %INLIST PKG_ISC_CODETIDY_Extension.Composite_GetSubExtensionClasses()
}

Query MenuItems(Classname As %String, MenuName As %String, InternalName As %String, SelectedText As %String) As %SQLQuery [ SqlProc ]
{
	SELECT MenuItem_Name, MenuItem_Enabled, MenuItem_Save, MenuItem_Separator FROM %Studio_Extension.Menu_MenuItem WHERE Menu->MenuBase %INLIST PKG_ISC_CODETIDY_Extension.Composite_GetSubExtensionClasses() AND Menu->Name = :MenuName
}

Method AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = "", ByRef Reload As %Boolean) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = $select(Type:..GetPrimaryExtension(InternalName),1:..GetMenuExtension(Name,InternalName))
	if '$isobject(tExtension) {
		quit ##super(Type,.Name,.InternalName,.Answer,.Msg,.Reload)
	}
	quit $method(tExtension,"AfterUserAction",Type,Name,.InternalName,.Answer,.Msg,.Reload)
}

Method ExternalName(InternalName As %String) As %String
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"ExternalName",.InternalName)
}

Method GetStatus(InternalName As %String, ByRef IsInSourceControl As %Boolean, ByRef Editable As %Boolean, ByRef IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.IsInSourceControl,.Editable,.IsCheckedOut,.UserCheckedOut)
	}
	set tStatus = $method(tExtension,"GetStatus",.InternalName,.IsInSourceControl,.Editable,.IsCheckedOut,.UserCheckedOut)
	
	// Allow non-primary extensions to flag items as uneditable.
	// An item is editable only if all extensions allow editing.
	if $namespace = ..Namespace {
		set tKey = ""
		for {
			set tSubExt = ..SubExtensions.GetNext(.tKey)
			if (tKey = "") {
				quit
			}
			set tSubSC = $method(tSubExt,"GetStatus",.InternalName,,.tSubEditable)
			set Editable = Editable && tSubEditable
			set tStatus = $$$ADDSC(tStatus,tSubSC)
		}
	}
	
	quit tStatus
}

ClassMethod IsGenerated(Name As %String) As %String
{
	set tClass = ..GetPrimaryExtensionClass()
	if (tClass = "") {
		quit ##super(.Name)
	}
	quit $classmethod(tClass,"IsGenerated",.Name)
}

Method IsInSourceControl(InternalName As %String) As %Boolean
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"IsInSourceControl",.InternalName)
}

Method IsReadOnly(InternalName As %String) As %Boolean
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	set tIsReadOnly = $method(tExtension,"IsReadOnly",.InternalName)
	if (tIsReadOnly) quit 1
	
	if $namespace = ..Namespace {
		set tKey = ""
		for {
			set tSubExt = ..SubExtensions.GetNext(.tKey)
			if (tKey = "") {
				quit
			}
			set tIsReadOnly = tIsReadOnly && $method(tSubExt,"IsReadOnly",InternalName)
			if 'tIsReadOnly {
				quit
			}
		}
	}
	
	quit tIsReadOnly
}

Method ItemIconState(InternalName As %String) As %Integer
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"ItemIconState",.InternalName)
}

Method Login(Name As %String, Password As %String) As %Status
{
	// No-op for purposes of this extension; called in %OnNew for others.
	quit $$$OK
}

Method Logout() As %Status
{
	set tStatus = $$$OK
	try {
		set tStatus = ..ForEachExtension("Logout")
	} catch e {
		set tStatus = e.AsStatus()
	}
	quit tStatus
}

ClassMethod OnAfterAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	set tClass = ..GetPrimaryExtensionClass()
	if (tClass = "") {
		quit ##super(.List,.Level,.qstruct,.Status)
	}
	quit $classmethod(tClass,"OnAfterAllClassCompile",.List,.Level,.qstruct,.Status)
}

Method OnAfterClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	set tExtension = ..GetPrimaryExtension()
	if '$isobject(tExtension) {
		quit ##super(.List,.Level,.qstruct,.Status)
	}
	quit $method(tExtension,"OnAfterClassCompile",.List,.Level,.qstruct,.Status)
}

Method OnAfterCompile(InternalName As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"OnAfterCompile",.InternalName)
}

Method OnAfterDelete(InternalName As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"OnAfterDelete",.InternalName)
}

Method OnAfterLoad(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.Object)
	}
	quit $method(tExtension,"OnAfterLoad",.InternalName,.Object)
}

Method OnAfterSave(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.Object)
	}
	
	// Code required to run CodeTidy's OnAfterSave function
	set classes = ..GetSubExtensionClasses()
	set pointer = 0
	while $listnext(classes, pointer, class) {
		set extension = ..GetSubExtension(class)
		if $isobject(extension) {
			do $method(extension, "OnAfterSave", .InternalName, .Object)
		}
	}
	
	quit $method(tExtension,"OnAfterSave",.InternalName,.Object)
}

Method OnAfterStorage(InternalName As %String, Location As %String = "") As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.Location)
	}
	quit $method(tExtension,"OnAfterStorage",.InternalName,.Location)
}

ClassMethod OnBeforeAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	set tClass = ..GetPrimaryExtensionClass()
	if (tClass = "") {
		quit ##super(.List,.Level,.qstruct)
	}
	quit $classmethod(tClass,"OnBeforeAllClassCompile",.List,.Level,.qstruct)
}

Method OnBeforeClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	set tExtension = ..GetPrimaryExtension()
	if '$isobject(tExtension) {
		quit ##super(.List,.Level,.qstruct)
	}
	quit $method(tExtension,"OnBeforeClassCompile",.List,.Level,.qstruct)
}

Method OnBeforeCompile(InternalName As %String, ByRef qstruct As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.qstruct)
	}
	quit $method(tExtension,"OnBeforeCompile",.InternalName,.qstruct)
}

Method OnBeforeDelete(InternalName As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"OnBeforeDelete",.InternalName)
}

Method OnBeforeLoad(InternalName As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName)
	}
	quit $method(tExtension,"OnBeforeLoad",.InternalName)
}

Method OnBeforeSave(InternalName As %String, Location As %String = "", Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		quit ##super(.InternalName,.Location,.Object)
	}
	quit $method(tExtension,"OnBeforeSave",.InternalName,.Location,.Object)
}

Method OnBeforeTimestamp(InternalName As %String)
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetPrimaryExtension(InternalName)
	if '$isobject(tExtension) {
		do ##super(.InternalName)
		quit
	}
	do $method(tExtension,"OnBeforeTimestamp",.InternalName)
}

Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = ..GetMenuExtension(MenuName,InternalName)
	if '$isobject(tExtension) {
		quit ##super(MenuName,InternalName,SelectedText,.Enabled,.DisplayName)
	}
	quit $method(tExtension,"OnMenuItem",MenuName,InternalName,SelectedText,.Enabled,.DisplayName)
}

Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status
{
	new $namespace
	set InternalName = ..CorrectInternalNames(InternalName)
	set tExtension = $select(Type:..GetPrimaryExtension(InternalName),1:..GetMenuExtension(Name,InternalName))
	if '$isobject(tExtension) {
		quit ##super(Type,Name,.InternalName,.SelectedText,.Action,.Target,.Msg,.Reload)
	}
	quit $method(tExtension,"UserAction",Type,Name,.InternalName,.SelectedText,.Action,.Target,.Msg,.Reload)
}

/// Dispatch unknown class methods to primary extension class.
ClassMethod %DispatchClassMethod(Class As %String, Method As %String, Args...) [ ServerOnly = 1 ]
{
	set tPrimaryClass = ..GetPrimaryExtensionClass()
	if (tPrimaryClass '= "") {
		if $quit {
			quit $classmethod(tPrimaryClass,Method,Args...)
		} else {
			do $classmethod(tPrimaryClass,Method,Args...)
		}
	}
}

/// Dispatch unknown methods to primary extension class.
Method %DispatchMethod(Method As %String, Args...) [ ServerOnly = 1 ]
{
	set tExtension = ..GetPrimaryExtension()
	if $isobject(tExtension) {
		if $quit {
			quit $method(tExtension,Method,Args...)
		} else {
			do $method(tExtension,Method,Args...)
		}
	}
}

}

