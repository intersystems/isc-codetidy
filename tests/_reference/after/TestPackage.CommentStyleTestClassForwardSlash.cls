Class TestPackage.CommentStyleTestClass
{

// This is a class to test automatic comment style formatting

Method MethodA()
{
    set a = %session.Get($piece("Data_1", "_", 2))
    set ^TestGlobal = 1
    set b = 3 * 4 / 2 + 7

    if b > 0 {
        write b, " is greater than 0.", !
    }

    // Forward slash comment
    // macro comment

    // Interesting comment style
    
    ;; Should be alerted about this comment style
}

}
