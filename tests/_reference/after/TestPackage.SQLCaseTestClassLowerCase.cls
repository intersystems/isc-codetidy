Class TestPackage.SQLCaseTestClass
{

Property BGD As %String;

Method MethodA()
{
    #sqlcompile Select = Display
    &sql(select top 1 1 into :a -- ;
        -- ; Relative Cost = 600400
        -- ;
        -- ; Read master map %TSQL_sys.snf.Map1, looping on ID.
        -- ; For each row:
        -- ;     Output the row.
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
    &sql(select top 1 1 into :b)
    write "2nd date of birth is ", b
}

}
