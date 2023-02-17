Class TestPackage.MacroCommentTestClass
{

Method TestMethod()
{
    // only changes if ^Config("CodeTidy", "usemacrocomments") is set
    ; these comments should always
    ; change to value of ^Config("CodeTidy", "coscomment")
    
    set foo = "bar"
    set x = "y" ; These should change only on new line or be moved
    ; Like here
    ;; These never change
}

}

