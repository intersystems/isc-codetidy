Class TestPackage.TestPreProcIf
{

ClassMethod Foo()
{
		set a = 1
	#if $piece("foo,bar",",",1) = "foo"
	set a ="a"
	#endif
}

}
