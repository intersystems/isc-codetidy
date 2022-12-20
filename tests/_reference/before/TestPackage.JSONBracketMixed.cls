Class TestPackage.JSONBracketMixed
{

ClassMethod TestJSONArray() As %Status
{
    set example = [{"foo":"bar"}
        ,
        {
        "bar":"foo"
    }
        ]
}

}
