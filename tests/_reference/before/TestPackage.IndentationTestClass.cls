Class TestPackage.IndentationTestClass
{

Property BGD As %String;

Method MethodA()
{
	set a= %session.Get($piece("Data_1", "_", 2))
				set ^TestGlobal = 1
	  set b=3*4/2+7

	if b>0{write b," is greater than 0.",!}
}

Index TestIndex On BGD;

Method MethodB()
{
	    w "test output"	
 s a=$p("hwd.ejwiop",".",2) 	
    w !,a	
                  w !,$zcvt(a,"u")
}

    Parameter ABC = "Param";

}
