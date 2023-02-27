Class TestPackage.JSONInMacro Extends %UnitTest.TestCase
{

Method TestMacroJSON()
{
    do $$$AssertEquals({"foo":1,"bar":2}, 2)
}

}

