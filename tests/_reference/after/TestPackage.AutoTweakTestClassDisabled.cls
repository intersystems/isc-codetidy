Class TestPackage.AutoTweakTestClass
{

Method MethodA()
{
    set a = %session.Get($piece("Data_1", "_", 2))
    set col = "ABC"
    set b = %request.Get(col, 1)
    set c = b.GetDataByName("col_A")
    set cols = "A, B, C, D, EE"
    set d = b.Get($piece(cols, ", ", 2))
}

}
