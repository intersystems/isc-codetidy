Class TestPackage.ResequenceTestClass
{

Parameter ABC = "Param";

Property BGD As %String;

Index TestIndex On BGD;

Method MethodA()
{
    write "This is the first method.", !
}

Method MethodB()
{
    write "This is the second method.", !
}

}

