Class TestPackage.JSIndentTestClass
{

Method JavaScriptTidy()
{
    &javascript<
        function foo(bar)
        {
            // This is a comment
            return true
        }
    >
}

Method JavaScriptUnindent()
{
    &javascript<
        function foo(bar)
        {
            // This is a comment
            return true
        }
    >
}

Method JavaScriptNeedsIndent()
{
    &javascript<
        function foo(bar)
        {
            // This is a comment
            return true
        }
    >
}

Method JavaScriptTwoBlocks()
{
    &javascript<
        function foo(bar)
        {
            // This is a comment
            return true
        }
    >
    &javascript<
        function foo(bar)
        {
            // This is a comment
            return true
        }
    >
}

Method JavaScriptOneLine()
{
    &javascript<function foo(bar) {return true}>
}

Method JavaScriptVeryMessy()
{
    if 1 {
        &javascript<
            function foo(bar)
            {
                return true
            }


        >
    }
}

Method JavaScriptMarker()
{
    &javascript123<
        function foo(bar)
        {
            if (6 > 5) {
                return True
            }
        }
    >321
}

Method JavaScriptAbbrev()
{
    if 1 {
        &js<
            function foo(bar)
            {
                return true
            }


        >
    }

    &jsabc<
        function foo(bar)
        {
            if (6 > 5) {
                return True
            }
        }
    >cba
}

}

