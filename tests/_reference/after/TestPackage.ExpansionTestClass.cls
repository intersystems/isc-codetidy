Class TestPackage.ExpansionTestClass
{

Method MethodA()
{
    s a= %session.Get($p("Data_1", "_", 2))
    s ^TestGlobal = 1
    s b=3*4/2+7

    i b>0{w b," is greater than 0.",!}
}

Method MethodB()
{
    w "test output"	s a=$p("hwd.ejwiop",".",2) 	w !,a	w !,$zcvt(a,"u")
    s p = $lb("a","b","c")
    w p
    s ^TestGlobal = 2147483647
    s ^TestGlobal("what")="Largest signed 32-bit integer."
    zw ^TestGlobal
}

}
