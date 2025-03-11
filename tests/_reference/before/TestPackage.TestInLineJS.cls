Class TestPackage.TestInLineJS
{
/// indentation be handled properly and only ';' outside js treated as comment
Method MethodA(p As %String = "", q As %Numeric = 0)
{
	if $$$ISERR(sc) {
	&js<zenPage.showAlert("#($system.Status.GetOneStatusText(sc, 1))#", "error");> // comment 1
		} else {
		&js<location.reload();> ; comment 2
	}
}

}
