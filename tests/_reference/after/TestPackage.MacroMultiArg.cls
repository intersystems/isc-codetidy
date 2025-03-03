Class TestPackage.MacroMultiArg Extends %RegisteredObject
{

ClassMethod TidyArgsInMethods()
{
    set a = 4
    set b = 5
    set b = ..DoNotTidyMacroArgs(a, b) // this should add spacing between ',' and b
    write b
}

ClassMethod DoNotTidyMacroArgs(foo, bar) As %String
{
    #define macro2args(%x, %y) set %y = %x // spacing can be applied to the definition of a macro as well
    $$$macro2args(foo,bar) // macro call should not adjust spacing
    return bar
}

}
