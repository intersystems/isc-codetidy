Class TestPackage.SpacingTestClass
{

Method MethodA(p As %String = "", q As %Numeric = 0)
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
    write "InternalName is ", b, !
    write p, q, !
}

Method MethodB()
{
    write "test output"	set a = $piece("hwd.ejwiop", ".", 2) 	write !, a	write !, $zconvert(a, "u")
}

}

