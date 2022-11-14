Class TestPackage.SQLPLanTestClass
{

Property BGD As %String;

Method MethodA()
{
	#sqlcompile Select= Display
	&sql(select top 1 1 into :a -- ; 
	)
	if SQLCODE<0{write "SQLCODE error ",SQLCODE," ",%msg  quit}
	elseif SQLCODE=100{write "Query returns no results"  quit }
	write "1st date of birth is ",a,!
	do $system.SQL.Util.SetOption("SelectMode",1)
	write "changed select mode to: ",$system.SQL.Util.GetOption("SelectMode"),!
	&sql(SeLeCT tOp 1 1 into :b)
	write "2nd date of birth is ",b
}

}
