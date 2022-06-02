Class pkg.isc.codetidy.extension.UniversalSettings Extends pkg.isc.codetidy.extension.AbstractSettings
{

/// A string to show in the grouping of settings for this class
Parameter DESCRIPTION = "Universal source control options";

/// An inherited IDKey index on this property means that the default value is
/// used as a subscript under <DataLocation> in the storage definition.
Property Key As %String [ InitialExpression = {$classname()}, ReadOnly ];

/// If enabled, source control behavior (including menu item enable/disable) follows mapped resources.
/// That is, if a class is mapped from the default routine database of another namespace that has source control enabled,
/// the source control behavior from that namespace will be used rather than that of the current namespace.
Property MappedSourceControl As %Boolean [ InitialExpression = {($Get(^%SYS("SourceControlClass")) = "pkg.isc.codetidy.extension.Composite")} ];

Parameter MANAGEDEXTENT = 0;

/// Updates an additional ^%SYS flag to enforce mapped source control
Method %OnAfterSave(insert As %Boolean) As %Status [ Private, ServerOnly = 1 ]
{
	if (..MappedSourceControl) {
		set ^%SYS("SourceControlClass") = "pkg.isc.codetidy.extension.Composite"
	} elseif $get(^%SYS("SourceControlClass")) = "pkg.isc.codetidy.extension.Composite" {
		// ZKill because nodes underneath may have namespace-specific settings, in theory.
		zkill ^%SYS("SourceControlClass")
	}
	quit $$$OK
}

/// This class has storage mapped to the global that stores other namespace-specific source control-related settings. The index and stream globals are expected to never be used.
Storage Default
{
<Data name="SettingsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>AutoAdd</Value>
</Value>
<Value name="3">
<Value>AutoMove</Value>
</Value>
<Value name="4">
<Value>MappedSourceControl</Value>
</Value>
</Data>
<DataLocation>^%SYS("SourceControl")</DataLocation>
<DefaultData>SettingsDefaultData</DefaultData>
<Description>
<![CDATA[This class has storage mapped to the global that stores other namespace-specific source control-related settings. The index and stream globals are expected to never be used.]]></Description>
<IdLocation>^%SYS("SourceControl")</IdLocation>
<IndexLocation>^%SYS("SourceControl","pkg.isc.codetidy.extension.UniversalSettingsI")</IndexLocation>
<StreamLocation>^%SYS("SourceControl","pkg.isc.codetidy.extension.UniversalSettingsS")</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

