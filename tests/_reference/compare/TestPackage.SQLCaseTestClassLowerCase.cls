Class TestPackage.SQLCaseTestClass
{

Property BGD As %String;

Method MethodA()
{
    #sqlcompile Select = Display
    &sql(select Action into :a from SourceControl_Git.Change -- ;
        -- ; Relative Cost = 1447000
        -- ;
        -- ; Read index map SourceControl_Git.Change.ChangeList, looping on %SQLUPPER(ItemFile), CommittedTime, and ID.
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
    &sql(select InternalName into :b from SourceControl_Git.Change)
    write "2nd date of birth is ", b
}

}
