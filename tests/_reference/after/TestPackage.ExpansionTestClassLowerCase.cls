Class TestPackage.ExpansionTestClass
{

Method MethodA()
{
    set a = %session.Get($piece("Data_1", "_", 2))
    set ^TestGlobal = 1
    set b = 3 * 4 / 2 + 7

    if b > 0 {
        write b, " is greater than 0.", !
    }
}

Method MethodB()
{
    write "test output"	set a = $piece("hwd.ejwiop", ".", 2) 	write !, a	write !, $zconvert(a, "u")
    set p = $listbuild("a", "b", "c")
    write p
    set ^TestGlobal = 2147483647
    set ^TestGlobal("what") = "Largest signed 32-bit integer."
    zwrite ^TestGlobal
}

}
