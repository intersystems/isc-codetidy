Class TestPackage.SQLPLanTestClass
{

Property BGD As %String;

Method MethodA()
{
    #sqlcompile Select = Display
    &SQL(SELECT TOP 1 1 INTO :a -- ;
    )
    if SQLCODE < 0 {
        write "SQLCODE error ", SQLCODE, " ", %msg  quit
    }
    elseif SQLCODE = 100 {
        write "Query returns no results"  quit
    }
    write "1st date of birth is ", a, !
    do $system.SQL.Util.SetOption("SelectMode", 1)
    write "changed select mode to: ", $system.SQL.Util.GetOption("SelectMode"), !
    &SQL(SELECT TOP 1 1 INTO :b)
    write "2nd date of birth is ", b
}

}

