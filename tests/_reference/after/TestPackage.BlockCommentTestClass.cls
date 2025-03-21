Class TestPackage.BlockCommentTestClass
{

Method BlockCommentTest()
{
    /*
        Do not change
            my indentation
        even if inconsistent
            or containing "code"
                set foo = "bar"
            if (foo = "bar") {
                do thing
                }
    */

    set foo = "bar"

    /* Or even if
        there are 
            multiple blocks,
        multiple openings /* 
    or misaligned closings
                    within the block
        */

    if 1 {
        /*
			    Or if inside a conditional
        block with inconsistent indentation
		*/
    }

    /* And do not negatively affect
        indentation of code even if blocks
        are opened and not closed
        set commentArray = {
            "a":[{
    */
    set testArray = [{
        "foo":"bar"
    }]
}

}
