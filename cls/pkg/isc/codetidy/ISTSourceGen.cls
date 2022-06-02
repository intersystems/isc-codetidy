Include (%occErrors, pkg.isc.codetidy.ISTCodeTidy)

Class pkg.isc.codetidy.ISTSourceGen Extends %RegisteredObject [ Abstract ]
{

/// This method is run prior to opening a document in Studio.
ClassMethod OnBeforeLoad(SourceControl As %Studio.SourceControl.Interface, InternalName As %String, Display As %Boolean = 1) As %Status
{
	quit $$$OK
}

/// This method is run after a document has been saved by Studio.
ClassMethod OnAfterSave(SourceControl As %Studio.SourceControl.Interface, InternalName As %String, Display As %Boolean = 1) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","OnAfterSave"
	if InternalName["/system/" quit $$$OK //skip system JS
	set Status = $$$OK
	try {
		set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
		set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
		
		if Ext="JS" {
			#; JavaScript is not compiled.
			#; Standards must be applied at the point of saving the file.
			set Status = SourceControl.GetStatus(InternalName, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut)
			if $$$ISERR(Status) quit
			
			set Status = ..ApplyStandards(InternalName, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut, .Export)
			if $$$ISERR(Status) quit
		}
	} catch (Ex) {
		set Status = Ex.AsStatus()
	}
	if $$$ISERR(Status) do $system.OBJ.DisplayError(Status)
	quit $$$OK
}

/// This method is run prior to a document being compiled by Studio.
/// It should be used to generate changes that do not apply to the current document.
/// The method which applies any changes is responsible for checking the document may 
/// be modified and exporting the document to the users workspace when the changes are
/// complete.
ClassMethod OnBeforeCompile(SourceControl As %Studio.SourceControl.Interface, InternalName As %String, Display As %Boolean = 1) As %Status
{
	#define IgnorePackages $listbuild("questionnaire","gen","model")
	set Status=$$$OK
	
	if $get(%debug) write !, ..%ClassName(1),"::","OnBeforeCompile"
	try {
		set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
		set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
		
		if (Ext="CLS") {
			if $listfind($$$IgnorePackages,$piece(Name,".",1)) quit
			if $$$defClassKeyGet(Name,$$$cCLASSgeneratedby) '= "" quit
		}
		
		set Status = SourceControl.GetStatus(InternalName, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut)
		if $$$ISERR(Status) quit
		
		set Status = ..ApplyStandards(InternalName, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut, .Export)
		if $$$ISERR(Status) quit
		
		if Ext="CLS" {
			set Status = ..GenerateXMLAdaptor(Name, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut, .Export)
			if $$$ISERR(Status) quit
			#; Check for message enabled environment.
			#if ##class(%Dictionary.CompiledClass).%ExistsId("web.Msg.Common")
				set Status = ..GenerateWebMessage(SourceControl, Name, .IsInSourceControl, .Editable, .IsCheckedOut, .UserCheckedOut)
				if $$$ISERR(Status) quit
			#endif
		}
		
		if $get(Export) {
			set Status = SourceControl.OnAfterSave(InternalName)
		}
	} catch (Ex) {
		set Status = Ex.AsStatus()
	}
	if $$$ISERR(Status) do $system.OBJ.DisplayError(Status)
	quit $$$OK
}

/// This method is run after a document has been compiled by Studio.
/// It should be used to compile any associated documents which have been generated 
/// based on the current document.
ClassMethod OnAfterCompile(SourceControl As %Studio.SourceControl.Interface, InternalName As %String, Display As %Boolean = 1) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","OnAfterCompile"
	set Status = $$$OK
	set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
	
	if Ext="CLS" {
		#if ##class(%Dictionary.CompiledClass).%ExistsId("web.Msg.Common")
			set Status = ..CompileWebMessage(Name)
		#endif
	}
	
	if $$$ISERR(Status) do $system.OBJ.DisplayError(Status)
	quit $$$OK
}

/// Apply standards which can be programmatically enforced.
/// Note: Changes to JavaScript files are not immediately reflected in Studio. (A way to make Studio reload the file has not been found yet)
ClassMethod ApplyStandards(InternalName As %String, IsInSourceControl As %Boolean, Editable As %Boolean, IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String, Export As %Boolean) As %Status
{
	#; ApplyStandards will modify the passed in document
	if '$get(Editable) quit $$$OK
	
	set Status = ..GenerateSrcVer(InternalName, .Export)
	if $$$ISERR(Status) quit Status
	
	set Status = ..SetSqlColumnNumber(InternalName, .Export)
	if $$$ISERR(Status) quit Status

	set Status = ..SetWebMessageStorage(InternalName, .Export)
	if $$$ISERR(Status) quit Status

	set Status = ..SetDoctorReportsAccessCtrl(InternalName, .Export)
	if $$$ISERR(Status) quit Status
	
	set Status = ##class(pkg.isc.codetidy.ISTAssistant).IndentDocument(InternalName)
	if $$$ISERR(Status) quit Status
	#; Indent document does not return an indication of whether the file has changed.
	#; Always export after indentation.
	set Export = 1

	#; TODO: Standard sequence is being tested via source control menu.
	#; If $$$ISERR(Status) Quit Status
	
	quit $$$OK
}

/// For DeepSee web-enabled classes (i.e. extending from %DeepSee.Report.dataPresenter ) set proper access control modifying super class
/// adding that class extend from websys.UI.ZenAccessAbstract (rigth inheritance)
/// and add class parameter ALLOWPORTALONLYACCESS=1 to allow access from management portal with authenticated data platform user (i.e $username<>"")
/// This is a workaround as there is no Source control for DeepSee VR reports and class changes will be overwritten from portal
ClassMethod SetDoctorReportsAccessCtrl(InternalName As %String, Export As %Boolean) As %Status
{
	#define ReportZENPrefix "Report.ZEN."
	#define AccessCtrlSuperClass "websys.UI.ZenAccessAbstract"
	#define DoctorReportsClassPrefix "LBDR"
	
	set sc = $$$OK
	try {
		set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
		if '(Ext="CLS") quit
		set className = $piece(InternalName,".CLS")
		set singleClassName = $piece(className,".",*)
		set isDR=0
		if ($extract(className,1,$length($$$ReportZENPrefix))=$$$ReportZENPrefix) && ($extract(singleClassName,1,$length($$$DoctorReportsClassPrefix))=$$$DoctorReportsClassPrefix) {
			if ##class(%Dictionary.CompiledMethod).%ExistsId(className_"||%IsA") {
				if ($classmethod(className,"%IsA","%DeepSee.Report.dataCollector")) || ($classmethod(className,"%IsA","%DeepSee.Report.dataPresenter")) {
					set isDR=1
				}
			}
		}
		if 'isDR quit
		set superClass = $$$defClassKeyGet(className,$$$cCLASSsuper)
		if superClass="" quit
		
		if '##class(%Dictionary.ParameterDefinition).%ExistsId(className_"||ALLOWPORTALONLYACCESS") {
			set allowPortalParm = ##class(%Dictionary.ParameterDefinition).%New(className_":ALLOWPORTALONLYACCESS")
			set allowPortalParm.Description = "Allow to access from management portal with authenticated user"
			set allowPortalParm.Default = "1"
			set allowPortalParm.Name = "ALLOWPORTALONLYACCESS"
			set allowPortalParm.SequenceNumber = 0
			set sc = allowPortalParm.%Save()
			if $$$ISERR(sc) quit
			set Export=1
		}
		if (superClass '[$$$AccessCtrlSuperClass) {
			set superClass = superClass_","_$$$AccessCtrlSuperClass
			set clsDef = ##class(%Dictionary.ClassDefinition).%OpenId(className)
			set clsDef.Inheritance = "right"
			set clsDef.Super = superClass
			set sc = clsDef.%Save()
			if $$$ISERR(sc) quit
			set Export=1
		}
		
	} catch(ex) {
		set sc = $$$OK
	}
	quit sc
}

/// Apply the expect super class and parameters to enabled GUIDs and change control based upon class name.
/// The rules which define whether or not a class is a TrakCare configuration item are in $$IsXMLConfig^SSUTILCLS.
ClassMethod GenerateXMLAdaptor(ClassName As %String, IsInSourceControl As %Boolean, Editable As %Boolean, IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String, Export As %Boolean) As %Status
{
	#; GenerateXMLAdaptor will modify the class passed in
	if '$get(Editable) quit $$$OK
	
	set Rebuild=0
	
	//websys.AbstractTX inherits from websys.Abstract to provide additional capabilities in an abstract class which is different to the normal usage
	if ClassName="websys.AbstractTx" quit $$$OK
	
	set ClassSuper = ","_$$$defClassKeyGet(ClassName,$$$cCLASSsuper)_","
	#; Only classes that inherit from XML.Adaptor, User.Abstract or websys.Abstract must be parsed.
	if (ClassSuper'[",XML.Adaptor,")&&(ClassSuper'[",websys.Abstract,")&&(ClassSuper'[",User.Abstract,") quit $$$OK
	
	if $piece(ClassName,".")="web" {
		#; The web package does not require XML.Adaptor functionality.
		if ClassSuper[",XML.Adaptor," {
			set ClassSuper = $replace(ClassSuper, ",XML.Adaptor,", ",")
			write !, "Remove XML.Adaptor Super Class"
			$$$defClassKeySet(ClassName, $$$cCLASSsuper, $extract(ClassSuper, 2, *-1))
		}
		$$$defMemberKill(ClassName,$$$cCLASSparameter,"XMLTYPE")
		set Rebuild=1
	} else {
		set AbstractSequence = $find(ClassSuper,",websys.Abstract,")
		set AdaptorSequence = $find(ClassSuper,",XML.Adaptor,")
		if AbstractSequence,AdaptorSequence {
			#; Confirm super class sequence.
			#; Use left to right super class priority.
			if $$$defClassKeyGet(ClassName, $$$cCLASSinheritance) = "right" {
				if AbstractSequence < AdaptorSequence {
					write !, "Correct Super Class inheritence order: right"
					set ClassSuper = $replace(ClassSuper, ",XML.Adaptor,",",")
					set ClassSuper = $replace(ClassSuper, ",websys.Abstract,",",XML.Adaptor,websys.Abstract,")
					$$$defClassKeySet(ClassName, $$$cCLASSsuper, $extract(ClassSuper, 2, *-1))
					set Rebuild=1
				}
			} else {
				#; Class inheritence is left.
				if AbstractSequence > AdaptorSequence {
					write !, "Correct Super Class inheritence order: left "
					set ClassSuper = $replace(ClassSuper, ",XML.Adaptor,",",")
					set ClassSuper = $replace(ClassSuper, ",websys.Abstract,",",websys.Abstract,XML.Adaptor,")
					$$$defClassKeySet(ClassName, $$$cCLASSsuper, $extract(ClassSuper, 2, *-1))
					set Rebuild=1
				}
			}
		}
		#; Persistent classes which inherit from websys.Abstract require XML.Adaptor functionality.
		if (ClassSuper[",websys.Abstract,")&&(ClassSuper'[",XML.Adaptor,") {
			#; Add the XML.Adaptor class to the list of super classes.
			write !, "Add XML.Adaptor Super Class"
			set ClassSuper = $replace(ClassSuper, ",websys.Abstract,",",XML.Adaptor,websys.Abstract,")
			$$$defClassKeySet(ClassName, $$$cCLASSsuper, $extract(ClassSuper, 2, *-1))
			set Rebuild=1
		}
	}
	
	#; Determine whether this class is eligible for GUIDENABLED.
	#; The class must be persistent.
	if ($$$defClassKeyGet(ClassName,$$$cCLASSclasstype)="persistent") || (ClassSuper[",%Persistent,") || (ClassSuper[",%Library.Persistent,") {
		#; Use the class name to determine if instances of this class can be exported.
		#; The class names that begin with code table package names will default to being exportable.
		if $$IsXMLConfig^SSUTILCLS(ClassName) {
			set (configItem, guidEnabled) = 1
		}
	}
	
	#; Use COMPLETE XMLREFERENCE for children and serial object properties
	set property=$$$defMemberNext(ClassName,$$$cCLASSproperty,"")
	while property'="" {
		set relationship=$$$defMemberKeyGet(ClassName,$$$cCLASSproperty,property,$$$cPROPrelationship)
		set cardinality=$$$defMemberKeyGet(ClassName,$$$cCLASSproperty,property,$$$cPROPcardinality)
		if relationship {
			if (cardinality=$$$cPROPCARDINALITYCHILDREN) {
				$$$defSubMemberSet(ClassName,$$$cCLASSproperty,property,$$$cPROPparameter,"XMLREFERENCE","COMPLETE")
			} elseif (cardinality = $$$cPROPCARDINALITYPARENT) {
				set configItem = ""
			}
		}
		set propertyType=$$$defMemberKeyGet(ClassName,$$$cCLASSproperty,property,$$$cPROPtype)
		if propertyType'="" {
			set classType=$$$defClassKeyGet(propertyType,$$$cCLASSclasstype)
		} else {
			set classType=""
		}
		if classType'="",classType'="datatype",classType'="stream",classType'="persistent" {
			$$$defSubMemberSet(ClassName,$$$cCLASSproperty,property,$$$cPROPparameter,"XMLREFERENCE","COMPLETE")
		}
		set property=$$$defMemberNext(ClassName,$$$cCLASSproperty,property)
	}
	
	#; Explicit XMLCONFIGITEM values of 0 should not be overriden.
	#; Some classes such as keyword tables should not have this parameter on even though
	#; they are considered code table classes and they do not have a parent relationship.
	if $$$defMemberKeyGet(ClassName,$$$cCLASSparameter,"XMLCONFIGITEM",$$$cPARAMdefault) = 0 {
		set configItem = 0
		set guidEnabled = 0
	}
	
	#; Set the XMLCONFIGITEM parameter based on the class definition.
	if $get(configItem) '= "" {
		if ($$$defMemberKeyGet(ClassName,$$$cCLASSparameter,"XMLCONFIGITEM",$$$cPARAMdefault) '= configItem) {
			$$$defMemberKeySet(ClassName,$$$cCLASSparameter,"XMLCONFIGITEM",$$$cPARAMdefault,configItem)
			write !, "Set XMLCONFIGITEM = " _ configItem
			#; Update developer Studio documents.
			set Rebuild=1
		}
	} else {
		if $$$defMemberKeyDefined(ClassName,$$$cCLASSparameter,"XMLCONFIGITEM",$$$cPARAMdefault) {
			$$$defMemberKill(ClassName,$$$cCLASSparameter,"XMLCONFIGITEM")
			write !, "Removed XMLCONFIGITEM"
			#; Update developer Studio documents.
			set Rebuild=1
		}
	}
	#; Check to see whether there is not an existing definition or XML.Adaptor made the definition.
	if '$$$defMemberKeyDefined(ClassName,$$$cCLASSparameter,"GUIDENABLED",$$$cPARAMdefault) {
		if $get(guidEnabled) {
			$$$defMemberKeySet(ClassName,$$$cCLASSparameter,"GUIDENABLED",$$$cPARAMdefault,guidEnabled)
			write !, "Set GUIDENABLED = " _ guidEnabled
			#; Update developer Studio documents.
			set Rebuild=1
		}
	}
	
	if Rebuild {
		set status = ..ResequenceDocument(ClassName_".CLS")
		$$$defClassKeySet(ClassName,$$$cCLASStimechanged,$ztimestamp)
		do RebuildItemIndex^%R(ClassName,"CLS")
		#; Export the changes.
		set Export = 1
		quit status
	}
	quit $$$OK
}

ClassMethod GenerateWebMessage(SourceControl As %Studio.SourceControl.Interface, DataClassName As %String, IsInSourceControl As %Boolean, Editable As %Boolean, IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String) As %Status [ ProcedureBlock = 1 ]
{
	#; Only relevant for persistent classes.
	if $$$comClassKeyGet(DataClassName, $$$cCLASSclasstype) '= "persistent" quit $$$OK
	
	#; Do not generated message classes for websys.Session*.
	#; These classes are used as super classes for the messages.
	if DataClassName["websys.Session" quit $$$OK
	
	#; Check for a related Message Class
	do ##class(web.Msg.Common).GetClassNames(DataClassName,.WebClassName,.MessageClassName)
	if ($get(MessageClassName) = "") {
		set MessageClassName = DataClassName
		set DataClassName = ""
		do ##class(web.Msg.Common).GetClassNames(.DataClassName,.WebClassName,MessageClassName)
		if (DataClassName = "") quit $$$OK
	}
	
	#; Get source control status of message class.
	set MessageInternalName = MessageClassName_".CLS"
	set Status = SourceControl.GetStatus(MessageInternalName,.MsgIsInSourceControl,.MsgEditable,.MsgIsCheckedOut,.MsgUserCheckedOut)
	if $$$ISERR(Status) quit Status
	
	#; If neither the User or Message classes are checked out then do not make any changes.
	if '$get(IsCheckedOut)||'$get(Editable) {
		#; Data class is not checked out
		
		if ('MsgEditable) {
			#; Message class is not editable
			write !,"Class "_MessageClassName_" is not editable"
			quit $$$OK
		}
	}
	
	if 'MsgIsInSourceControl {
		set Status = SourceControl.AddToSourceControl(MessageInternalName)
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to add message definition to source control."), Status)
	}
	if '$get(MsgEditable) {
		set Status = SourceControl.CheckOut(MessageInternalName)
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to check out message definition."), Status)
	}
	set Status = SourceControl.OnBeforeLoad(MessageInternalName)
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Error happens during OnBeforeLoad."), Status)
	write !,"Generating class "_MessageClassName
	
	#; Open or create message class definition.
	if ##class(%Dictionary.ClassDefinition).%ExistsId(MessageClassName) {
		set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName)
		if '$isobject(MessageDefinition) quit $$$ERROR($$$GeneralError, "Unable to open message definition.")
		
		#; Remove previously generated members.
		if ##class(%Dictionary.ParameterDefinition).%ExistsId(MessageClassName_"||GENERATED") {
			set GeneratedParameter = ##class(%Dictionary.ParameterDefinition).%OpenId(MessageClassName_"||GENERATED")
			if $isobject(MessageDefinition) {
				set GeneratedList = $listfromstring(GeneratedParameter.Default, ",")
				for i = 1:1:$listlength(GeneratedList) {
					set GeneratedItem = $list(GeneratedList, i)
					set GeneratedType = $case($piece(GeneratedItem, ":"),
						$$$cCLASSparameter:"%Dictionary.ParameterDefinition",
						$$$cCLASSproperty:"%Dictionary.PropertyDefinition",
						$$$cCLASSquery:"%Dictionary.QueryDefinition",
						$$$cCLASSmethod:"%Dictionary.MethodDefinition",
						$$$cCLASSindex:"%Dictionary.IndexDefinition",:"")
					if GeneratedType '= "" {
						set Status = $classmethod(GeneratedType, "%DeleteId", MessageClassName_"||"_$piece(GeneratedItem, ":", 2))
					}
				}
			}
		}
	} else {
		set MessageDefinition = ##class(%Dictionary.ClassDefinition).%New()
		if '$isobject(MessageDefinition) quit $$$ERROR($$$GeneralError, "Unable to create message definition.")
	}
	
	set UserDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(DataClassName)
	
	set MessageDefinition.Name = MessageClassName
	if $length(UserDefinition.SqlTableName) {
		set MessageDefinition.SqlTableName = UserDefinition.SqlTableName
	} else {
		do MessageDefinition.SqlTableNameReset()
	}
	set MessageDefinition.ProcedureBlock = 1
	set MessageDefinition.Super = "websys.SessionData,websys.Abstract"
	do MessageDefinition.GeneratedByReset()
	if (MessageDefinition.Description = "") || (MessageDefinition.Description = UserDefinition.Description) {
		set MessageDefinition.Description = "Message class generated based upon "_DataClassName_"."
	}
	set Status = MessageDefinition.%Save()
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save message class."), Status)
	
	#; Set Message Class IndexLocation
	set Status = ..SetWebMessageStorage(MessageClassName_".CLS")
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to set message class IndexLocation."), Status)
	
	#; Set Class Parameters
	if ##class(%Dictionary.ParameterDefinition).%ExistsId(MessageClassName_"||GENERATED") {
		set GeneratedParameter = ##class(%Dictionary.ParameterDefinition).%OpenId(MessageClassName_"||GENERATED")
	} else {
		set GeneratedParameter = ##class(%Dictionary.ParameterDefinition).%New()
		set GeneratedParameter.Name = "GENERATED"
		do GeneratedParameter.parentSetObjectId(MessageClassName)
	}
	set GeneratedParameter.Default = ","
	set GeneratedParameter.SequenceNumber = $increment(SequenceNumber)
	set Status = GeneratedParameter.%Save()
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save GENERATED parameter."), Status)
	
	if ##class(%Dictionary.ParameterDefinition).%ExistsId(MessageClassName_"||SQLFILTER") {
		set Parameter = ##class(%Dictionary.ParameterDefinition).%OpenId(MessageClassName_"||SQLFILTER")
	} else {
		set Parameter = ##class(%Dictionary.ParameterDefinition).%New()
		set Parameter.Name = "SQLFILTER"
		do Parameter.parentSetObjectId(MessageClassName)
	}
	set Parameter.Default = "(SessionParRef = :SessionId)"
	set Parameter.SequenceNumber = $increment(SequenceNumber)
	set Parameter.Description="This parameter is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSparameter_":"_Parameter.Name_","
	set Status = Parameter.%Save()
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save SQLFILTER parameter."), Status)
	
	#; Add RowID
	set SelectList="ID"
	set SqlRowIdName = UserDefinition.SqlRowIdName
	if SqlRowIdName = "",$isobject(UserDefinition.Storages.GetAt(1)) set SqlRowIdName = UserDefinition.Storages.GetAt(1).SqlRowIdName
	if SqlRowIdName = "" set SqlRowIdName = "RowID"
	set PropertyName = $zstrip(SqlRowIdName,"*","_")
	if PropertyName '= "" {
		if ##class(%Dictionary.PropertyDefinition).%ExistsId(MessageClassName_"||"_PropertyName) {
			set Status = ##class(%Dictionary.PropertyDefinition).%DeleteId(MessageClassName_"||"_PropertyName)
			if $$$ISERR(Status) {
				set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to remove existing RowID property '"_PropertyName_"'."), Status)
				quit
			}
		}
		set Property = ##class(%Dictionary.PropertyDefinition).%New()
		do Property.parentSetObjectId(MessageClassName)
		set Property.SqlFieldName = SqlRowIdName
		set Property.Name = PropertyName
		set Property.Type = "%String"
		set Property.SequenceNumber = MessageDefinition.Parameters.Count() + 1
		set SequenceNumber = Property.SequenceNumber
		set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSproperty_":"_Property.Name_","
		set Status = Property.%Save()
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save RowID property '"_PropertyName_"'."), Status)
		set SelectList=SelectList_","_Property.SqlFieldName
		set RowIdPropertyName=PropertyName
	}
	
	set RowSpec=SelectList
	
	set ParRefSqlFieldName=""
	set Key = ""
	for  {
		set Property = UserDefinition.Properties.GetNext(.Key)
		if Key = "" quit
		
		if Property.Calculated continue
		if Property.Transient continue
		if Property.Relationship, ((Property.Cardinality = $$$cPROPCARDINALITYCHILDREN) || (Property.Cardinality = $$$cPROPCARDINALITYMANY)) continue
		
		#; Property to be added to transient class.
		if ##class(%Dictionary.PropertyDefinition).%ExistsId(MessageClassName_"||"_Property.Name) {
			set Status = ##class(%Dictionary.PropertyDefinition).%DeleteId(MessageClassName_"||"_Property.Name)
			if $$$ISERR(Status) {
				set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to remove existing property."), Status)
				quit
			}
		}
		set Property = Property.%ConstructClone()
		
		if Property.Relationship && ((Property.Cardinality = $$$cPROPCARDINALITYPARENT) || (Property.Cardinality = $$$cPROPCARDINALITYONE)) {
			set Property.Relationship = 0
			set Property.Cardinality = ""
			set Property.Inverse = ""
			set ParRefSqlFieldName=Property.SqlFieldName
			set ParRefPropertyName=Property.Name
		}
		if Property.Required {
			set Property.Description = Property.Description _ $char(13,10) _ "Required by "_DataClassName_"."
			set Property.Required = 0
		}
		if Property.Name["Childsub" {
			set Property.InitialExpression = """"""
		}
		
		set PropertyType = Property.Type
		$$$NormalizeClassnameByDef(PropertyType, DataClassName)
		set Property.Type = PropertyType
		do Property.parentSetObjectId(MessageClassName)
		set Property.SequenceNumber = $increment(SequenceNumber)
		set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSproperty_":"_Property.Name_","
		set Status = Property.%Save()
		if $$$ISERR(Status) {
			set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save "_Property.Name_" property."), Status)
			quit
		}
	}
	if $$$ISERR(Status) quit Status
	
	set Index = ##class(%Dictionary.IndexDefinition).%New()
	do Index.parentSetObjectId(MessageClassName)
	set Index.Name="SessionId"_RowIdPropertyName
	set Index.Properties="SessionParRef,"_RowIdPropertyName
	set Index.Unique=1
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSindex_":"_Index.Name_","
	set Index.SequenceNumber=MessageDefinition.Parameters.Count() +  MessageDefinition.Properties.Count() + 1
	set Status = Index.%Save()
	if $$$ISERR(Status) {
		set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save "_Index.Name_" Index."), Status)
		quit Status
	}
	
	#; Build Standard FindAll and Find Query
	if ##class(%Dictionary.QueryDefinition).%ExistsId(MessageClassName_"||FindAll") {
		set Query = ##class(%Dictionary.QueryDefinition).%DeleteId(MessageClassName_"||FindAll")
	}
	if ##class(%Dictionary.QueryDefinition).%ExistsId(MessageClassName_"||Find") {
		set Query = ##class(%Dictionary.QueryDefinition).%DeleteId(MessageClassName_"||Find")
	}
	
	do MessageDefinition.%Reload()
	set Key = ""
	for  {
		set Property = MessageDefinition.Properties.GetNext(.Key)
		if Key = "" quit
		if SqlRowIdName=Property.SqlFieldName continue
		
		#; Build list of columns for FindAll and Find SQL statement
		if Property.SqlFieldName '= "" {
			if Property.Relationship, ((Property.Cardinality = $$$cPROPCARDINALITYCHILDREN) || (Property.Cardinality = $$$cPROPCARDINALITYMANY)) continue
			
			set PropertyType = Property.Type
			$$$NormalizeClassnameByDef(PropertyType, DataClassName)
			
			if Property.Collection = "" {
				if $$$classIsDataType(PropertyType) {
					set ColumnName = Property.SqlFieldName
					set SelectRef = Property.SqlFieldName
				} else {
					set SQLDescription = ""
					set ColumnName = Property.SqlFieldName
					set PropertyTypeWebClass = ""
					if $$IsMsgClass^SSUTILCLS(PropertyType) {
						set Status = ##class(web.Msg.Common).GetClassNames(, .PropertyTypeWebClass, PropertyType)
						if $$$ISERR(Status) set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to get web class for class '"_PropertyType_"'."), Status)
					} else {
						set Status = ##class(web.Msg.Common).GetClassNames(PropertyType, .PropertyTypeWebClass)
						if $$$ISERR(Status) set Status = $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to get web class for class '"_PropertyType_"'."), Status)
					}
					if ##class(%Dictionary.CompiledClass).%ExistsId(PropertyTypeWebClass) {
						set SQLDescription = $classmethod(PropertyTypeWebClass, "%GetParameter", "SQLDESCRIPTION")
					}
					if SQLDescription '="" {
						set SelectRef = Property.SqlFieldName_"->"_SQLDescription
					} else {
						set SelectRef = Property.SqlFieldName
					}
				}
				set RowSpec = RowSpec_","_ColumnName
				set SelectList = SelectList_","_SelectRef
			}
		}
	}
	if $$$ISERR(Status) quit Status
	
	set MessageSqlSchemaName = $$DetermineSchemaName^%occClass(MessageClassName)
	set MessageSqlTableName = $select(MessageDefinition.SqlTableName'="":MessageDefinition.SqlTableName,1:$$$ClassShortName(MessageClassName))
	set (MessageSqlSuffix,Key) = ""
	for  {
		set Parameter = UserDefinition.Parameters.GetNext(.Key)
		if Key = "" quit
		
		if Parameter.Name = "MSGSQLSUFFIX" {
			set MessageSqlSuffix = Parameter.Default
			quit
		}
	}
	
	set Query = ##class(%Dictionary.QueryDefinition).%New()
	set Query.FormalSpec = "SessionId:%String"
	set Query.Name = "FindAll"
	do Query.Parameters.SetAt(1,"CONTAINID")
	do Query.Parameters.SetAt(RowSpec,"ROWSPEC")
	set Query.SqlQuery = "SELECT "_SelectList_" FROM "_MessageSqlSchemaName_"."_MessageSqlTableName_$char(13,10)_
	" WHERE (SessionParRef = :SessionId)"_$char(13,10)_MessageSqlSuffix
	set Query.Type = "%Library.SQLQuery"
	do Query.parentSetObjectId(MessageClassName)
	set Query.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + 1
	set Query.Description="This query is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSquery_":"_Query.Name_","
	set Status = Query.%Save()
	if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save FindAll query."), Status)
	
	#; If Childtable create Find query
	if (ParRefSqlFieldName'="") && (ParRefPropertyName'="") {
		set Query = ##class(%Dictionary.QueryDefinition).%New()
		set Query.FormalSpec = "SessionId:%String,"_ParRefPropertyName_":%String"
		set Query.Name = "Find"
		do Query.Parameters.SetAt(1,"CONTAINID")
		do Query.Parameters.SetAt(RowSpec,"ROWSPEC")
		set Query.SqlQuery = "SELECT "_SelectList_" FROM "_MessageSqlSchemaName_"."_MessageSqlTableName_$char(13,10)_
		" WHERE (SessionParRef = :SessionId) AND ("_ParRefSqlFieldName_"=:"_ParRefPropertyName_")"_$char(13,10)_MessageSqlSuffix
		set Query.Type = "%Library.SQLQuery"
		do Query.parentSetObjectId(MessageClassName)
		set Query.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + 1
		set Query.Description="This query is generated - manual changes will be overwritten"
		set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSquery_":"_Query.Name_","
		set Status = Query.%Save()
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to save FindAll query."), Status)
	}
	
	#; Create Get / Set Methods
	do ..GenerateWebMessageGetAll(DataClassName, WebClassName, MessageClassName, GeneratedParameter)
	do ..GenerateWebMessageSave(DataClassName, WebClassName, MessageClassName, GeneratedParameter)
	do ..GenerateWebMessageDelete(DataClassName, WebClassName, MessageClassName, GeneratedParameter)
	do ..GenerateWebMessageReloadAll(DataClassName, WebClassName, MessageClassName, GeneratedParameter)
	
	#; Write parameter with all class members which have been generated.
	set GeneratedParameter.Description="This parameter is generated - manual changes will be overwritten"
	set Status = GeneratedParameter.%Save()
	if $$$ISERR(Status) quit Status
	
	set Status=##class(pkg.isc.codetidy.ISTCodeTidy).Document(MessageInternalName)
	if $$$ISERR(Status) quit Status
	
	#; Prevent actions from OnAfterSave firing further source control events.
	set Status = SourceControl.OnAfterSave(MessageInternalName)
	
	#; Display success message
	#; No line break used because OnAfterSave will finish on a new line
	#; and the compilation output expects the end of a line.
	if $$$ISOK(Status) write "Generation finished successfully"
	quit Status
}

ClassMethod GenerateWebMessageGetAll(DataClassName As %String, WebClassName As %String, MessageClassName As %String, GeneratedParameter As %Dictionary.ParameterDefinition) As %String
{
	#define MethodName "websysGetMsg"
	
	if ##class(%Dictionary.MethodDefinition).%ExistsId(MessageClassName_"||"_$$$MethodName) {
		do ##class(%Dictionary.MethodDefinition).%DeleteId(MessageClassName_"||"_$$$MethodName)
	}
	
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName,0)
	set Method = ##class(%Dictionary.MethodDefinition).%New()
	set Method.ClassMethod = 1
	set Method.FormalSpec = "Request:web.Msg.Common,&Response:"_MessageClassName_",*LockWarning:%String="""""
	set Method.ReturnType = "%Status"
	set Method.Name = $$$MethodName
	set Method.Description = "Fetch all the data from the "_$piece(DataClassName, ".", 2)_" instance whose RowID is contained in the Request message."_$char(13,10)
		_"Return the data populated in "_MessageClassName_" as the Response message."
		_$char(13,10)_"This method is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSmethod_":"_Method.Name_","
	set Method.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + MessageDefinition.Queries.Count() + 1
	do Method.parentSetObjectId(MessageClassName)
	kill MessageDefinition
	
	set UserDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(DataClassName,0)
	set SqlRowIdName = UserDefinition.SqlRowIdName
	if SqlRowIdName = "",$isobject(UserDefinition.Storages.GetAt(1)) set SqlRowIdName = UserDefinition.Storages.GetAt(1).SqlRowIdName
	if SqlRowIdName = "" set SqlRowIdName = "RowID"
	set RowIdPropertyName = $zstrip(SqlRowIdName,"*","_")
	kill UserDefinition
	
	set Code = ##class(%GlobalCharacterStream).%New()
	do Code.WriteLine(" set obj = ##class("_DataClassName_").%OpenId(Request.RowID,0,.sc)")
	do Code.WriteLine(" if $$$ISERR(sc) quit sc")
	#;
	do Code.WriteLine(" set exists=..SessionId"_RowIdPropertyName_"Exists($s($d(%session):%session.SessionId,1:$job),Request.RowID,.MsgID)")
	do Code.WriteLine(" if exists&&(MsgID'="""")&&Request.Unique {")
	do Code.WriteLine("  set msg = ##class("_MessageClassName_").%OpenId(MsgID,,.sc)")
	do Code.WriteLine("  if $$$ISERR(sc) quit sc")
	do Code.WriteLine(" } else {")
	do Code.WriteLine("  set msg = ##class("_MessageClassName_").%New()")
	do Code.WriteLine(" }")
	do Code.WriteLine(" if Request.Lock&&'##class(websys.Lock).Lock($$$oidCompose(Request.RowID,"""_DataClassName_"""), $select($data(%session):%session.SessionId,1:$Job), $select($data(%session):$get(%session.Data(""LOGON.USERID"")),1:""""), .LockWarning) do msg.MakeReadOnly()")
	do Code.WriteLine(" if 'Request.Lock||'Request.Unique do msg.MakeReadOnly()")
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName, 0)
	set PropertyKey = ""
	for {
		set Property = MessageDefinition.Properties.GetNext(.PropertyKey)
		if PropertyKey = "" quit
		
		if Property.Calculated continue
		
		#; RowID properties use %Id() rather than a corresponding user class property.
		#; All other properties must have a corresponding property on the user class.
		if (Property.SqlFieldName '= "")&&(Property.SqlFieldName = SqlRowIdName) {
			#; RowID
			do Code.WriteLine(" set msg."_Property.Name_" = $s(Request.Unique:obj.%Id(),1:"""")")
		} elseif ##class(%Dictionary.PropertyDefinition).%ExistsId(DataClassName_"||"_Property.Name) {
			#; Both the message and user class have a property with a matching name.
			set PropertyType = Property.Type
			$$$NormalizeClassnameByDef(PropertyType, DataClassName)
			if $$$classIsDataType(PropertyType) {
				#; Data Type
				if Property.Collection = "" {
					do Code.WriteLine(" set msg."_Property.Name_" = obj."_Property.Name)
				} elseif Property.Collection = "list" {
					do Code.WriteLine(" for  set value=obj."_Property.Name_".GetNext(.key) quit:key=""""  do msg."_Property.Name_".SetAt(value,key)")
				}
			} else {
				#; Object Reference
				if (Property.Collection = "") {
					do Code.WriteLine(" do msg."_Property.Name_"SetObject(obj."_Property.Name_"GetObject())")
					if PropertyType="%Stream.GlobalCharacter" {
						do Code.WriteLine(" set sc=msg."_Property.Name_".CopyFrom(obj."_Property.Name_")")
						do Code.WriteLine(" if $$$ISERR(sc) quit sc")
					}
				} elseif (Property.Collection = $$$cPROPCOLLECTIONLIST) || (Property.Collection = $$$cPROPCOLLECTIONARRAY) {
					do Code.WriteLine(" do msg."_Property.Name_".Clear()")
					do Code.WriteLine(" set key = """"")
					do Code.WriteLine(" for  set oid=obj."_Property.Name_".GetObjectNext(.key) quit:key=""""  do msg."_Property.Name_".SetObjectAt(oid,key)")
				}
			}
		}
	}
	do Code.WriteLine(" set Response = msg")
	do Code.WriteLine(" quit $$$OK")
	
	set Method.Implementation = Code
	set Status = Method.%Save()
	quit Status
}

ClassMethod GenerateWebMessageSave(DataClassName As %String, WebClassName As %String, MessageClassName As %String, GeneratedParameter As %Dictionary.ParameterDefinition) As %String
{
	#define MethodName "websysSaveByMsg"
	
	if ##class(%Dictionary.MethodDefinition).%ExistsId(MessageClassName_"||"_$$$MethodName) {
		do ##class(%Dictionary.MethodDefinition).%DeleteId(MessageClassName_"||"_$$$MethodName)
	}
	
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName,0)
	set Method = ##class(%Dictionary.MethodDefinition).%New()
	set Method.ClassMethod = 1
	set Method.FormalSpec = "Request:"_MessageClassName_",&Response:web.Msg.Common"
	set Method.ReturnType = "%Status"
	set Method.Name = $$$MethodName
	set Method.Description = "Save an instance of "_$piece(DataClassName, ".", 2)_" from Request message "_MessageClassName_"."_$char(13,10)
		_"Return web.Msg.Common with the inserted or used RowId."
		_$char(13,10)_"This method is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSmethod_":"_Method.Name_","
	set Method.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + MessageDefinition.Queries.Count() + 2
	do Method.parentSetObjectId(MessageClassName)
	kill MessageDefinition
	
	set UserDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(DataClassName,0)
	set SqlRowIdName = UserDefinition.SqlRowIdName
	if SqlRowIdName = "",$isobject(UserDefinition.Storages.GetAt(1)) set SqlRowIdName = UserDefinition.Storages.GetAt(1).SqlRowIdName
	if SqlRowIdName = "" set SqlRowIdName = "RowID"
	set RowIdPropertyName = $zstrip(SqlRowIdName,"*","_")
	kill UserDefinition
	
	set Code = ##class(%GlobalCharacterStream).%New()
	do Code.WriteLine(" if Request.ReadOnly {")
	do Code.WriteLine("  if '$data(t(""XLOCKED"")),$data(%session) do ##class(websys.Component).GetComponentMessages(.t,""websys.SYSTEM"")")
	do Code.WriteLine("  set LockedUser=##class(websys.Lock).GetLockedUser($$$oidCompose(Request."_RowIdPropertyName_","""_DataClassName_"""))")
	do Code.WriteLine("  if LockedUser'="""" quit $$$ERROR($$$GeneralError, $get(t(""XLOCKED""),""RECORD IS LOCKED BY ANOTHER USER"")_"" ("_DataClassName_" ""_Request."_RowIdPropertyName_"_"", ""_LockedUser_"")"")")
	do Code.WriteLine("  quit $$$ERROR($$$GeneralError, $get(t(""XLOCKMSGISREADONLY""),""Record is read only"")_"" ("_MessageClassName_" ""_Request.%Id()_"")"")")
	do Code.WriteLine(" }")
	do Code.WriteLine(" if (($l(Request."_RowIdPropertyName_"))&&(##class("_DataClassName_").%ExistsId(Request."_RowIdPropertyName_"))) {")
	do Code.WriteLine("  set obj = ##class("_DataClassName_").%OpenId(Request."_RowIdPropertyName_",,.sc)")
	do Code.WriteLine("  if $$$ISERR(sc) quit sc")
	do Code.WriteLine(" } else {")
	do Code.WriteLine("  set obj = ##class("_DataClassName_").%New()")
	do Code.WriteLine(" }")
	do Code.WriteLine(" set msg = Request")
	
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName)
	set PropertyKey = ""
	for {
		#dim Property as %Dictionary.PropertyDefinition
		set Property = MessageDefinition.Properties.GetNext(.PropertyKey)
		if PropertyKey = "" quit
		#; Properties must have a corresponding property on the user class.
		if ##class(%Dictionary.PropertyDefinition).%ExistsId(DataClassName_"||"_Property.Name) {
			set PropertyType = Property.Type
			$$$NormalizeClassnameByDef(PropertyType, DataClassName)
			if $$$classIsDataType(PropertyType) {
				#; Do not save computed field.
				if Property.SqlComputed continue
				
				#; Data Type
				if Property.Collection = "" {
					if Property.Name["Childsub" {
						do Code.WriteLine(" if msg."_Property.Name_"'="""" set obj."_Property.Name_" = msg."_Property.Name)
					} else {
						do Code.WriteLine(" set obj."_Property.Name_" = msg."_Property.Name)
					}
				} elseif (Property.Collection = $$$cPROPCOLLECTIONLIST) || (Property.Collection = $$$cPROPCOLLECTIONARRAY) {
					do Code.WriteLine(" do obj."_Property.Name_".Clear()")
					do Code.WriteLine(" set key = """"")
					do Code.WriteLine(" for  set value=msg."_Property.Name_".GetNext(.key) quit:key=""""  do obj."_Property.Name_".SetAt(value,key)")
				}
			} elseif (PropertyType="%Stream.GlobalCharacter") {
				do Code.WriteLine(" set sc=obj."_Property.Name_".CopyFrom(msg."_Property.Name_")")
				do Code.WriteLine(" if $$$ISERR(sc) quit sc")
			}else {
				#; Object Reference
				if (Property.Collection = "") {
					do Code.WriteLine(" if obj."_Property.Name_"GetObject()'=msg."_Property.Name_"GetObject() do obj."_Property.Name_"SetObject(msg."_Property.Name_"GetObject())")
				} elseif (Property.Collection = $$$cPROPCOLLECTIONLIST) || (Property.Collection = $$$cPROPCOLLECTIONARRAY) {
					do Code.WriteLine(" do obj."_Property.Name_".Clear()")
					do Code.WriteLine(" set key = """"")
					do Code.WriteLine(" for  set oid=msg."_Property.Name_".GetObjectNext(.key) quit:key=""""  do obj."_Property.Name_".SetObjectAt(oid,key)")
				}
			}
		}
	}
	
	do Code.WriteLine(" set Response = ##class(web.Msg.Common).%New()")
	do Code.WriteLine(" set sc = obj.%Save()")
	do Code.WriteLine(" if $$$ISERR(sc) quit sc")
	do Code.WriteLine(" set Response.RowID = obj.%Id()")
	do Code.WriteLine(" if ('$length(Request."_RowIdPropertyName_")||('##class("_DataClassName_").%ExistsId(Request."_RowIdPropertyName_"))) {")
	do Code.WriteLine("  set Request."_RowIdPropertyName_" = obj.%Id()")
	do Code.WriteLine("  if $length(Request.%Id()) set sc = Request.%Save()")
	do Code.WriteLine(" }")
	do Code.WriteLine(" quit sc")
	
	set Method.Implementation = Code
	set Status = Method.%Save()
	quit Status
}

ClassMethod GenerateWebMessageDelete(DataClassName As %String, WebClassName As %String, MessageClassName As %String, GeneratedParameter As %Dictionary.ParameterDefinition) As %String
{
	#define MethodName "websysDeleteByMsg"
	
	if ##class(%Dictionary.MethodDefinition).%ExistsId(MessageClassName_"||"_$$$MethodName) {
		do ##class(%Dictionary.MethodDefinition).%DeleteId(MessageClassName_"||"_$$$MethodName)
	}
	
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName,0)
	set Method = ##class(%Dictionary.MethodDefinition).%New()
	set Method.ClassMethod = 1
	set Method.FormalSpec = "Request:web.Msg.Common"
	set Method.ReturnType = "%Status"
	set Method.Name = $$$MethodName
	set Method.Description = "Delete an instance of "_$piece(DataClassName, ".", 2)_" specified by the Ensemble message web.Msg.Common."_$char(13,10)
		_"No response is returned, except for %Status."_$char(13,10)
		_"Data dependent on the deleted instance will also be removed, and all indices updated."_$char(13,10)
		_"Note that this does NOT check if the record (or its dependents) are in use."
		_$char(13,10)_"This method is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSmethod_":"_Method.Name_","
	
	set Method.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + MessageDefinition.Queries.Count() + 3
	do Method.parentSetObjectId(MessageClassName)
	kill MessageDefinition
	
	set Code = ##class(%GlobalCharacterStream).%New()
	do Code.WriteLine(" set sc = ##class("_DataClassName_").%DeleteId(Request.RowID)")
	do Code.WriteLine(" quit sc")
	
	set Method.Implementation = Code
	set Status = Method.%Save()
	quit Status
}

ClassMethod GenerateWebMessageReloadAll(DataClassName As %String, WebClassName As %String, MessageClassName As %String, GeneratedParameter As %Dictionary.ParameterDefinition) As %String
{
	#define MethodName "websysReloadMsg"
	if ##class(%Dictionary.MethodDefinition).%ExistsId(MessageClassName_"||"_$$$MethodName) {
		do ##class(%Dictionary.MethodDefinition).%DeleteId(MessageClassName_"||"_$$$MethodName)
	}
	
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName,0)
	set Method = ##class(%Dictionary.MethodDefinition).%New()
	set Method.ClassMethod = 1
	set Method.FormalSpec = "RowID:%String="""",&Response:"_MessageClassName
	set Method.ReturnType = "%Status"
	set Method.Name = $$$MethodName
	set Method.Description = "Reload all the data from the "_$piece(DataClassName, ".", 2)_" instance whose RowID equals to the passed-in RowID."_$char(13,10)
		_"Return the data populated in "_MessageClassName_" as the Response message."
		_$char(13,10)_"This method is generated - manual changes will be overwritten"
	set GeneratedParameter.Default = GeneratedParameter.Default_$$$cCLASSmethod_":"_Method.Name_","
	set Method.SequenceNumber = MessageDefinition.Parameters.Count() + MessageDefinition.Properties.Count() + MessageDefinition.Indices.Count() + MessageDefinition.Queries.Count() + 4
	do Method.parentSetObjectId(MessageClassName)
	kill MessageDefinition
	
	set UserDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(DataClassName,0)
	set SqlRowIdName = UserDefinition.SqlRowIdName
	if SqlRowIdName = "",$isobject(UserDefinition.Storages.GetAt(1)) set SqlRowIdName = UserDefinition.Storages.GetAt(1).SqlRowIdName
	if SqlRowIdName = "" set SqlRowIdName = "RowID"
	set RowIdPropertyName = $zstrip(SqlRowIdName,"*","_")
	kill UserDefinition
	
	set Code = ##class(%GlobalCharacterStream).%New()
	do Code.WriteLine(" set obj = ##class("_DataClassName_").%OpenId(RowID,0,.sc)")
	do Code.WriteLine(" if $$$ISERR(sc) quit sc")
	#;
	do Code.WriteLine(" set exists=..SessionId"_RowIdPropertyName_"Exists($select($data(%session):%session.SessionId,1:$job),RowID,.MsgID)")
	do Code.WriteLine(" if 'exists||(MsgID="""") quit sc")
	do Code.WriteLine(" set msg = ##class("_MessageClassName_").%OpenId(MsgID,,.sc)")
	do Code.WriteLine(" if $$$ISERR(sc) quit sc")
	set MessageDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(MessageClassName, 0)
	set PropertyKey = ""
	for {
		set Property = MessageDefinition.Properties.GetNext(.PropertyKey)
		if PropertyKey = "" quit
		
		#; RowID properties use %Id() rather than a corresponding user class property.
		#; All other properties must have a corresponding property on the user class.
		if (Property.SqlFieldName '= "")&&(Property.SqlFieldName = SqlRowIdName) {
			#; RowID
			do Code.WriteLine(" set msg."_Property.Name_" = obj.%Id()")
		} elseif ##class(%Dictionary.PropertyDefinition).%ExistsId(DataClassName_"||"_Property.Name) {
			#; Both the message and user class have a property with a matching name.
			set PropertyType = Property.Type
			$$$NormalizeClassnameByDef(PropertyType, DataClassName)
			if $$$classIsDataType(PropertyType) {
				#; Data Type
				if Property.Collection = "" {
					do Code.WriteLine(" set msg."_Property.Name_" = obj."_Property.Name)
				} elseif Property.Collection = "list" {
					do Code.WriteLine(" for  set value=obj."_Property.Name_".GetNext(.key) quit:key=""""  do msg."_Property.Name_".SetAt(value,key)")
				}
			} else {
				#; Object Reference
				if (Property.Collection = "") {
					do Code.WriteLine(" do msg."_Property.Name_"SetObject(obj."_Property.Name_"GetObject())")
					if PropertyType="%Stream.GlobalCharacter" {
						do Code.WriteLine(" set sc=msg."_Property.Name_".CopyFrom(obj."_Property.Name_")")
						do Code.WriteLine(" if $$$ISERR(sc) quit sc")
					}
				} elseif (Property.Collection = $$$cPROPCOLLECTIONLIST) || (Property.Collection = $$$cPROPCOLLECTIONARRAY) {
					do Code.WriteLine(" do msg."_Property.Name_".Clear()")
					do Code.WriteLine(" set key = """"")
					do Code.WriteLine(" for  set oid=obj."_Property.Name_".GetObjectNext(.key) quit:key=""""  do msg."_Property.Name_".SetObjectAt(oid,key)")
				}
			}
		}
	}
	do Code.WriteLine(" set Response = msg")
	do Code.WriteLine(" set sc= Response.%Save()")
	do Code.WriteLine(" quit sc")
	
	set Method.Implementation = Code
	set Status = Method.%Save()
	quit Status
}

ClassMethod CompileWebMessage(DataClassName As %String) As %Status
{
	#; Check for a related Message Class
	do ##class(web.Msg.Common).GetClassNames(DataClassName,.WebClassName,.MessageClassName)
	if $get(MessageClassName) = "" quit $$$OK
	if '##class(%Dictionary.ClassDefinition).%ExistsId(MessageClassName) quit $$$OK
	
	quit $system.OBJ.Compile(MessageClassName,,,1)
}

ClassMethod GenerateSrcVer(InternalName As %String, Export As %Boolean) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","GenerateSrcVer"
	set Status = $$$OK
	
	set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
	if Ext = "CLS" {
		#; Do not modify system classes
		if $$$defClassKeyGet(Name,$$$cCLASSsystem) quit $$$OK
		
		if '##class(%Dictionary.ParameterDefinition).%ExistsId(Name_"||SrcVer") {
			
			set SrcVer = ##class(%Dictionary.ParameterDefinition).%New(Name_":SrcVer")
			set SrcVer.Description = "This Parameter is updated by Perforce"
			set SrcVer.Default = "$Id"_"$"
			set SrcVer.Name = "SrcVer"
			set SrcVer.SequenceNumber = 0
			set Status = SrcVer.%Save()
			set Export = 1
		}
		
	} elseif Ext = "MAC" {
		if $text(@("SrcVer^"_Name))="" {
			#; Open the routine definition.
			set RoutineDef = ##class(%RoutineMgr).%OpenId(InternalName)
			
			if $isobject(RoutineDef) {
				set OutputCode = ##class(%Stream.TmpCharacter).%New()
				set Status = ..AddSrcVerToRoutine(InternalName, RoutineDef.Code, .OutputCode)
				if $$$ISERR(Status) quit Status
				
				#; Replace the existing stream.
				if $get(OutputCode) '= ""  {
					do OutputCode.Flush()
					set RoutineDef.Code = OutputCode
					
					#; Save the changes.
					set Status = RoutineDef.%Save()
					if $$$ISERR(Status) quit Status
					set Export = 1
				}
			} else {
				quit $$$ERROR($$$GeneralError, "GenerateSrcVer unable to open routine definition")
			}
		}
	} elseif Ext = "JS" {
		#; Open the file.
		set FileName = $system.CSP.GetFileName(InternalName)
		if '##class(%File).Exists(FileName) quit $$$FileNotFound
		set File = ##class(%File).%New(FileName)
		set Status = File.Open("R")
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Failed to open file for read ("_FileName_")"), Status)
		
		set OutputCode = ##class(%Stream.TmpCharacter).%New()
		if $$$ISERR(Status) quit Status
		
		set Status = ..AddSrcVerToJavaScript(InternalName, .File, .OutputCode)
		do File.Close()
		if $$$ISERR(Status) quit Status
		
		if $get(OutputCode) '= ""  {
			#; Save changes.
			set Status = File.Open("WSN")
			if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Failed to open file for write ("_FileName_")"), Status)
			
			set Status = OutputCode.Rewind()
			while 'OutputCode.AtEnd {
				set Status = File.WriteLine(OutputCode.ReadLine())
				if $$$ISERR(Status) quit
			}
			do File.Close()
		} else {
			quit $$$ERROR($$$GeneralError, "Unable to open file")
		}
	} elseif Ext = "CSP" {
		#; Open the file.
		set FileName = $system.CSP.GetFileName(InternalName)
		if '##class(%File).Exists(FileName) quit $$$FileNotFound
		set File = ##class(%File).%New(FileName)
		set Status = File.Open("R")
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Failed to open file for read ("_FileName_")"), Status)
		
		set OutputCode = ##class(%Stream.TmpCharacter).%New()
		if $$$ISERR(Status) quit Status
		
		set Status = ..AddParamsToCSP(InternalName, .File, .OutputCode)
		do File.Close()
		if $$$ISERR(Status) quit Status
		
		if $get(OutputCode) '= ""  {
			#; Save changes.
			set Status = File.Open("WSN")
			if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Failed to open file for write ("_FileName_")"), Status)
			
			set Status = OutputCode.Rewind()
			while 'OutputCode.AtEnd {
				set Status = File.WriteLine(OutputCode.ReadLine())
				if $$$ISERR(Status) quit
			}
			do File.Close()
		}
	}
	quit Status
}

/// Add a SrcVer line label to the routine unless it already exists.
/// If no changes are made then there will be no OutputCode returned.
ClassMethod AddSrcVerToRoutine(InternalName As %String, InputCode As %CharacterStream, ByRef OutputCode As %CharacterStream) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","AddSrcVerToRoutine"
	
	#define SrcVerLabel "SrcVer ;; $Id"_"$"
	#define NotSrcVerLabel(%val) %val'?1"SrcVer ;; $Id".E1"$"
	
	set Status = $$$OK
	set SrcVer = 0, Changed = 0
	set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	
	while 'InputCode.AtEnd {
		kill Len
		if $increment(LineCount)
		set Line = InputCode.ReadLine(.Len)
		set StrippedText = $zstrip(Line,"<>W")
		
		#; SrcVer is always expected to be after the top line comment.
		#; For example:
		#;  SSUTILCLS	//utils for class definitions. checks if class is code table
		#;  SrcVer ;; $ Id: //trak/main/DEV/rtn/ss/SSUTILCLS.rtn#21 $
		
		#; Check for line label matching routine name.
		set IsRountineLineLabel = ($piece($piece($piece(StrippedText," "),$char(9)),"(")=Name)
		#; Check for first line comments.
		set IsHeaderComment = LineCount=1&&(($extract(StrippedText)=";")||($extract(StrippedText,1,2)="//")||($extract(StrippedText,1,2)="#;"))
		
		if SrcVer=0,('IsRountineLineLabel)&&('IsHeaderComment) {
			set SrcVer = 1
			if $$$NotSrcVerLabel(StrippedText) {
				set Status = OutputCode.WriteLine($$$SrcVerLabel)
				if $$$ISOK(Status) {
					set Status = OutputCode.WriteLine(Line)
					if $$$ISOK(Status) set Changed = 1
				}
				if $$$ISERR(Status) quit
			} else {
				#; SrcVer line label exists.  No changes required.
				quit
			}
		} else {
			if Len > -1 {
				set Status = OutputCode.WriteLine(Line)
			}
		}
	}
	
	if 'Changed {
		#; Do not return outputCode.
		kill OutputCode
	}
	quit Status
}

/// Add a SrcVer comment to the JavaScript unless it already exists.
/// If no changes are made then there will be no OutputCode returned.
ClassMethod AddSrcVerToJavaScript(InternalName As %String, InputCode As %CharacterStream, ByRef OutputCode As %CharacterStream) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","AddSrcVerToJavaScript"
	
	#define SrcVerComment "// SrcVer: $Id"_"$"
	#define NotSrcVerComment(%val) %val'?1"// SrcVer: $Id".E1"$"
	
	set Status = $$$OK
	set SrcVer = 0, Changed = 0
	
	while 'InputCode.AtEnd {
		kill Len
		if $increment(LineCount)
		set Line = InputCode.ReadLine(.Len)
		set StrippedText = $zstrip(Line,"<>W")
		
		#; SrcVer is always expected to be after the top line comment.
		#; For example:
		#;  // Copyright (c) 2001 TrakHealth Pty Limited. ALL RIGHTS RESERVED.
		#;  // SrcVer: $ Id: //trak/main/DEV/web/scripts/websys.js#347 $
		
		#; Check for copyright comment line.
		set IsCopyright = StrippedText["Copyright"
		
		if SrcVer=0,('IsCopyright) {
			set SrcVer = 1
			if $$$NotSrcVerComment(StrippedText) {
				set Status = OutputCode.WriteLine($$$SrcVerComment)
				if $$$ISOK(Status) {
					set Status = OutputCode.WriteLine(Line)
					if $$$ISOK(Status) set Changed = 1
				}
				if $$$ISERR(Status) quit
			} else {
				#; SrcVer line label exists.  No changes required.
				quit
			}
		} else {
			if Len > -1 {
				set Status = OutputCode.WriteLine(Line)
			}
		}
	}
	
	if 'Changed {
		#; Do not return outputCode.
		kill OutputCode
	}
	quit Status
}

ClassMethod SetWebMessageStorage(InternalName As %String, Export As %Boolean) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","SetWebMessageStorage"
	set Status = $$$OK
	
	set Ext = $zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
	
	if Ext = "CLS" {
		set ClassName = $piece(InternalName,".",1,$length(InternalName,".")-1)
		
		#; Do not modify system classes
		if $$$defClassKeyGet(ClassName,$$$cCLASSsystem) quit $$$OK
		
		#; Only classes that inherit from websys.SessionData or websys.SessionStatic must be parsed.
		set ListOfSuperClasses = $listfromstring($$$defClassKeyGet(ClassName,$$$cCLASSsuper),",")
		set ExtendsMessageSuper = 0
		for SuperClassName = "websys.SessionRequest", "websys.SessionData", "websys.SessionStatic" {
			if $listfind(ListOfSuperClasses, SuperClassName) {
				set ExtendsMessageSuper = 1
				quit
			}
		}
		if 'ExtendsMessageSuper quit $$$OK
		
		#; websys.SessionRequest Extends websys.SessionData.
		#; Classes which inherit from websys.SessionRequest will follow websys.SessionData storage.
		if SuperClassName = "websys.SessionRequest" set SuperClassName = "websys.SessionData"
		
		#; Set Message Class IndexLocation
		set SuperClass = ##class(%Dictionary.ClassDefinition).%OpenId(SuperClassName)
		set SuperClassIndexLocation = SuperClass.Storages.GetAt(1).IndexLocation
		if ##class(%Dictionary.StorageDefinition).%ExistsId(ClassName_"||Default") {
			set MessageClassStorage = ##class(%Dictionary.StorageDefinition).%OpenId(ClassName_"||Default")
		} else {
			set MessageClassStorage=##class(%Dictionary.StorageDefinition).%New()
			do MessageClassStorage.parentSetObjectId(ClassName)
			set MessageClassStorage.Name="Default"
			set MessageClassStorage.Type=$$$persistentStorageClass
		}
		set UniqueSubscript = $piece(ClassName,"web.Msg.",2)
		if UniqueSubscript '= "" {
			set MessageClassStorage.IndexLocation = $name(@SuperClassIndexLocation@($piece(ClassName,"web.Msg.",2)))
		} else {
			set MessageClassStorage.IndexLocation = ""
		}
		set Status = MessageClassStorage.%Save()
		if $$$ISERR(Status) quit $$$EMBEDSC($$$ERROR($$$GeneralError, "Unable to set message class IndexLocation."), Status)
}
	quit Status
}

ClassMethod ResequenceDocument(InternalName As %String, Export As %Boolean) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","ResequenceDocument"
	set Status = $$$OK
	
	set Name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	set Ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
	if Ext = "CLS" {
		set class = ##class(%Dictionary.ClassDefinition).%OpenId(Name)
		
		if $isobject(class) {
			#; Parameters
			for list = class.Parameters, class.Properties, class.Indices, class.Methods, class.Queries, class.Triggers, class.Storages {
				set key = ""
				for {
					set item = list.GetNext(.key)
					if key = "" quit
					
					if item.Name = "SrcVer" {
						#; SrcVer to be shown at the top.
						set weight = 0
					} elseif ($classname(item) = "%Dictionary.ParameterDefinition") && (item.Name = $zconvert(item.Name,"U")) {
						#; Mixed case parameters are sometimes used in relation to a property.
						#; In these cases it the parameter may be kept with the property.
						if $extract(item.Name,1,7) = "SQLDATE" {
							#; SQLDATE parameters show after other SQL* parameters
							set weight = 11
						} elseif $extract(item.Name,1,3) = "SQL" {
							#; SQLCODE, SQLDESCRIPTION, SQLROWID are used to identify records.
							set weight = 10
						} else {
							set weight = 15
						}
					} elseif ($classname(item) = "%Dictionary.ParameterDefinition") || ($classname(item) = "%Dictionary.PropertyDefinition") {
						set weight = 20
					} elseif ($classname(item) = "%Dictionary.IndexDefinition") {
						set weight = 30
					} elseif ($classname(item) = "%Dictionary.MethodDefinition") || ($classname(item) = "%Dictionary.QueryDefinition") {
						set weight = 40
					} elseif ($classname(item) = "%Dictionary.TriggerDefinition") {
						set weight = 50
					} else {
						set weight = 99
					}
					set sequence(weight, item.SequenceNumber, item.Name) = item
				}
			}
			set weight = "", SequenceNumber = ""
			for {
				set weight = $order(sequence(weight))
				if weight = "" quit
				
				set number = ""
				for {
					set number = $order(sequence(weight, number))
					if number = "" quit
					
					set name = ""
					for {
						set name = $order(sequence(weight, number, name),1,item)
						if name = "" quit
						
						set item.SequenceNumber = $increment(SequenceNumber)
					}
				}
			}
			set Status = class.%Save()
		}
	}
	quit Status
}

/// Add csp:parameter lines to csp file
/// Check the first four lines...
/// If they are what we expect then quit
/// Otherwise try and find the copyright and the param lines we want, and rewrite first four lines keeping the values
/// and then write out rest of file, exluding any possible duplicates of the four lines.
ClassMethod AddParamsToCSP(InternalName As %String, InputCode As %CharacterStream, ByRef OutputCode As %CharacterStream) As %Status
{
	#define ExclusionList ",upload.csp,zTranslationTemplate.csp,"
	
	#define NewCopyright "<!-- Copyright (c) "_$e($zd($h,3),1,4)_" InterSystems Corporation. ALL RIGHTS RESERVED. -->"
	#define Copyright "<!-- Copyright (c) 2001 TrakHealth Pty Limited. ALL RIGHTS RESERVED. -->"
	#define IsCopyright(%val) ($e(%val,1,14)="<!-- Copyright")&&($e(%val,*-2,*)="-->"&&(%val["InterSystems"))
	
	#define DocTypeHTML5 "<!DOCTYPE html>"
	#define DocTypeFrameset "<!DOCTYPE html PUBLIC ""-//W3C//DTD HTML 4.01 Frameset//EN"" ""http://www.w3.org/TR/html4/frameset.dtd"">"
	#define IsDocType(%val) ((%val="<!DOCTYPE html>")||(%val["<!DOCTYPE html PUBLIC ""-//W3C//DTD HTML 4.01 Frameset//EN"" ""http://www.w3.org/TR/html4/frameset.dtd"">"))
	#define IsDocTypeOld(%val) (%val["##class(websys.Page).GetDocType")
	
	#define HTML5 "<script language="""_$$$langObjectScript_""" runat=""server"">i $g(%session.Data(""LOGON.MOBILE"")) w ""<!DOCTYPE html>"",!</script>"
	#define IsHTML5(%val) (%val?1"<script language="""_$$$langObjectScript_""" runat=""server"">i $g(%session.Data(""LOGON.MOBILE"")) w ""<!DOCTYPE html>"",!</script>")
	#define IsOldHTML5(%val) (%val?1"<server>i $g(%session.Data(""LOGON.MOBILE"")) w ""<!DOCTYPE html>"",!</server>")
	
	#define SrcVerParameter "<csp:parameter name=""SrcVer"" value=""$Id"_"$"">"
	#define IsSrcVerParameter(%val) (%val?1"<csp:parameter name=""SrcVer"" value=""$Id".E1"$"">")
	#define CSPListParameter(%val) "<csp:parameter name=""CSPLIST"" value="""_%val_""">"
	#define IsCSPListParameter(%val) (%val?1"<csp:parameter name=""CSPLIST"" value=""".E1""">")
	#define ComponentListParameter(%val) "<csp:parameter name=""COMPONENTLIST"" value="""_%val_""">"
	#define IsComponentListParameter(%val) (%val?1"<csp:parameter name=""COMPONENTLIST"" value=""".E1""">")
	
	if $get(%debug) write !, ..%ClassName(1),"::","AddParamsToCSP"
	set Status = $$$OK
	set SrcVer = 0, Changed = 0, RewriteFile=1, FormatCheck=0
	
	#; Remove this part after everything has been initialised
	set (csplist,complist)=""
	set csp=$piece(InternalName,"/",$length(InternalName,"/"))
	if $$$ExclusionList[(","_csp_",") {
		kill OutputCode
		quit $$$OK
	}
	
	kill NewLine
	set NewLine(1)=$select($listfind(##class(websys.Page).GetFramesetPages(),csp):$$$DocTypeFrameset,1:$$$DocTypeHTML5)
	set NewLine(2)=$$$NewCopyright
	set NewLine(3)=$$$SrcVerParameter
	set NewLine(4)=$$$CSPListParameter(csplist)
	set NewLine(5)=$$$ComponentListParameter(complist)
	#; Basic Check, and pull out params
	while 'InputCode.AtEnd {
		kill Len
		if $increment(LineCount)
		set Line = InputCode.ReadLine(.Len)
		set StrippedText = $zstrip(Line,"<>W")
		
		#; SrcVer is always expected to be after the top line comment.
		#; For example:
		#;  <!DOCTYPE html>
		#;  <!-- Copyright (c) 2013 InterSystems Corporation. ALL RIGHTS RESERVED. -->
		#;  <csp:parameter name="SrcVer" value="$ Id: //trak/main/DEV/web/csp/websys.csp#73 $">
		#;  <csp:parameter name="CSPLIST" value="">
		#;  <csp:parameter name="COMPONENTLIST" value="">
		
		
		#; Set is ok format if all first five lines are what we expect
		if LineCount=1 && $$$IsDocType(StrippedText) set FormatCheck=FormatCheck+1
		if LineCount=2 && $$$IsCopyright(StrippedText) set FormatCheck=FormatCheck+1
		if LineCount=3 && $$$IsSrcVerParameter(StrippedText) set FormatCheck=FormatCheck+1
		if LineCount=4 && $$$IsCSPListParameter(StrippedText) set FormatCheck=FormatCheck+1
		if LineCount=5 && $$$IsComponentListParameter(StrippedText) set FormatCheck=FormatCheck+1
		
		#; All lines match.  No changes required.
		if (LineCount=5) && (FormatCheck=5) set RewriteFile=0 quit
		
		#; Sort lines 1-5
		if $$$IsDocType(StrippedText) set NewLine(1)=Line
		if $$$IsCopyright(StrippedText) set NewLine(2)=$$$NewCopyright
		if $$$IsSrcVerParameter(StrippedText) set NewLine(3)=Line
		if $$$IsCSPListParameter(StrippedText) set NewLine(4)=Line
		if $$$IsComponentListParameter(StrippedText) set NewLine(5)=Line
		
	}
	if RewriteFile {
		do InputCode.Rewind()
		
		//Always write HTML5 tag first, some browsers won't parse as HTML5 otherwise
		set Status = OutputCode.WriteLine(NewLine(1))
		if $$$ISERR(Status) quit
		//Always write new copyright
		set Status = OutputCode.WriteLine($$$NewCopyright)
		if $$$ISERR(Status) quit
		
		set Status = OutputCode.WriteLine(NewLine(3))
		if $$$ISERR(Status) quit
		
		set Status = OutputCode.WriteLine(NewLine(4))
		if $$$ISERR(Status) quit
		
		set Status = OutputCode.WriteLine(NewLine(5))
		if $$$ISERR(Status) quit
		set Changed = 1
		while 'InputCode.AtEnd {
			kill Len
			set Line = InputCode.ReadLine(.Len)
			set StrippedText = $zstrip(Line,"<>W")
			
			if ($$$IsDocType(StrippedText)||$$$IsDocTypeOld(StrippedText)||$$$IsHTML5(StrippedText)||$$$IsOldHTML5(StrippedText)) continue
			//any copyright - old or new....
			if ($extract(StrippedText,1,14)="<!-- Copyright") continue
			if $$$IsSrcVerParameter(StrippedText) continue
			if $$$IsCSPListParameter(StrippedText) continue
			if $$$IsComponentListParameter(StrippedText) continue
			
			set Status = OutputCode.WriteLine(Line)
		}
	}
	if 'Changed {
		#; Do not return outputCode.
		kill OutputCode
	}
	quit Status
}

/// SqlColumnNumber is referenced by Visual Rule generated code.  
/// Classes which have a corresponding TCDS.Cube must specify SqlColumnNumber.
/// Once an SqlColumnNumber has been established the class source will be updated with the compiled value.
/// This means the source will only be updated on second compile.
ClassMethod SetSqlColumnNumber(InternalName As %String, Export As %Boolean) As %Status
{
	if $get(%debug) write !, ..%ClassName(1),"::","SetSqlColumnNumber"
	set status = $$$OK, Export = $get(Export)
	
	set name=$piece(InternalName,".",1,$length(InternalName,".")-1)
	set ext=$zconvert($piece(InternalName,".",$length(InternalName,".")),"U")
	
	#; Only apply changes to data classes which have visual rule cubes.
	if (ext = "CLS") && ($piece(name, ".")="User") && (##class(%Dictionary.ClassDefinition).%ExistsId("TCDS.Cubes."_$piece(name,".",2,*))) {
		set class = ##class(%Dictionary.ClassDefinition).%OpenId(name)
		
		if $isobject(class) {
			#; Properties
			set list = class.Properties
			set key = ""
			for {
				#dim item as %Dictionary.PropertyDefinition
				
				set item = list.GetNext(.key)
				if key = "" quit
				
				if item.SqlColumnNumber '= "" continue
				set compiledSqlColumnNumber = $get($$$EXTPROPsqlcolumnnumber($$$pEXT,name,item.Name))
				#; ParRef properties should not be specified.  These use SqlColumnNumber 0.
				if +compiledSqlColumnNumber < 1 continue
				
				#; Update class with compiled value.
				set item.SqlColumnNumber = compiledSqlColumnNumber
				if 'Export set Export = 1
			}
			set status = class.%Save()
		}
	}
	quit status
}

}

