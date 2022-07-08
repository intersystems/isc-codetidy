Class TestPackage.IndentationTestClass
{

Property BGD As %String;

Method MethodA()
{
    set a = %session.Get($piece("Data_1", "_", 2))
    set ^TestGlobal = 1
    set b = 3 * 4 / 2 + 7

    if b > 0 {
        write b, " is greater than 0.", !
    }
}

Index TestIndex On BGD;

Method MethodB()
{
    write "test output"
    set a = $piece("hwd.ejwiop", ".", 2)
    write !, a
    write !, $zconvert(a, "u")
}

Parameter ABC = "Param";

}

