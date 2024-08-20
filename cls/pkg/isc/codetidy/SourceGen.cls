Include (%occErrors, pkg.isc.codetidy.CodeTidy)

/// Supports reordering class members according to standards
Class pkg.isc.codetidy.SourceGen Extends %RegisteredObject
{

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
			for list = class.Parameters, class.Properties, class.ForeignKeys, class.Indices, class.Methods, class.Queries, class.Triggers, class.Storages {
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
					} elseif ($classname(item) = "%Dictionary.ForeignKeyDefinition") {
						set weight = 30
					} elseif ($classname(item) = "%Dictionary.IndexDefinition") {
						set weight = 40
					} elseif ($classname(item) = "%Dictionary.MethodDefinition") || ($classname(item) = "%Dictionary.QueryDefinition") {
						set weight = 50
					} elseif ($classname(item) = "%Dictionary.TriggerDefinition") {
						set weight = 60
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

}
