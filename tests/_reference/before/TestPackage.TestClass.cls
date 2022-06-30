Class TestPackage.TestClass Extends %Persistent [ DdlAllowed ]
{

Property BGD As %String;

Method MethodA()
{
	set a= %session.Get($piece("Data_1", "_", 2))
				set ^TestGlobal = 1
	  set b=3*4/2+7

	if b>0{write b," is greater than 0.",!}

	#; testing 123

	#sqlcompile Select= Display
	&sql(select Action into :a from SourceControl_Git.Change -- ; 
	)
	if SQLCODE<0{write "SQLCODE error ",SQLCODE," ",%msg  quit}
	elseif SQLCODE=100{write "Query returns no results"  quit }
	write "1st date of birth is ",a,!
	do $system.SQL.Util.SetOption("SelectMode",1)
	write "changed select mode to: ",$system.SQL.Util.GetOption("SelectMode"),!
	&sql(select InternalName into :b from SourceControl_Git.Change)
	write "2nd date of birth is ",b

	; Interesting comment style
	
	;; Should be alerted about this comment style
}

Index TestIndex On BGD;

Method MethodB()
{
	w "test output"	s a=$p("hwd.ejwiop",".",2) 	w !,a	w !,$zcvt(a,"u")
}

Parameter ABC = "Param";

Storage Default
{
<Data name="TestClassDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>BGD</Value>
</Value>
</Data>
<DataLocation>^TestPackage.TestClassD</DataLocation>
<DefaultData>TestClassDefaultData</DefaultData>
<IdLocation>^TestPackage.TestClassD</IdLocation>
<IndexLocation>^TestPackage.TestClassI</IndexLocation>
<StreamLocation>^TestPackage.TestClassS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
