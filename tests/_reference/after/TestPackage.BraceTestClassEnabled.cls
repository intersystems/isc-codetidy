Class TestPackage.BraceTestClass
{

Method MethodA()
{
    set b = 3 * 4 / 2 + 7
    set c = b / 3 + 5
    set sc = $$$OK
    if b > 0 {
        write b, " is greater than 0.", !
    }
    if b < 0 {
        write "error ", sc, " "  quit
    }
    elseif c = 100 {
        write "c is 100" quit
    }
    &SQL(SELECT InternalName INTO :b FROM SourceControl_Git.Change)
    write "InternalName is ", b
}

}

