Class TestPackage.JSONNested
{

Method oneDimArrayInMultiDimArray()
{
    set testArray = [{
        "x":{
            "y":1,
            "z":2
        }
    }]
    if 1 {
        write "register no longer JSON"
    }
}

Method multiDimArrayInOneDimArray()
{
    set testArray = {
        "foo":[{
            "bar":1
        }]
    }
    if 1 {
        write "register no longer JSON"
    }
}

Method oneDimArrayInOneDimArray()
{
    set testArray = {
        "x":{
            "foo":{
                "bar":1
            }
        },
        "y":"z"
    }
    if 1 {
        write "register no longer JSON"
    }
}

Method squareArrayInCurlyArray()
{
    set testArray = {
        "x":["a","b","c"],
        "y":2
    }
}

}

