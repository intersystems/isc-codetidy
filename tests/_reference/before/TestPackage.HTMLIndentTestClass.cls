Class TestPackage.HTMLIndentTestClass
{

Method HTMLGoodIndent()
{
    &html<
            <html>
                <head></head>
                <body></body>
    >
}

Method HTMLBlockIndent()
{
        &html<
                <html>
                    <head></head>
                    <body></body>
        >
}

Method HTMLBadIndent()
{
    &html<
        <html>
        <head>
        </head>
        <body>
        </body>
        >
}

Method HTMLIfBlock()
{
    if 1 {
            &html<
                <html>
                    <head></head>
                    <body></body>
        >
    }
}

Method HTMLUntidyIfBlock()
{
    if 1 {
            if 1{
                &html<
                        <html>
                            <head></head>
                            <body></body>
                >
            } else {
                        &html<
                        <html>
                        <head>
                        </head>
                        <body>
                        </body>
                    >
                }
    }
}

Method HTMLOneLine()
{
    &html<<a href='url'>Link</a>>
}

Method HTMLMarker()
{
        &htmlabc<
        <html>
            <body>
                4 > 3 
                5>>7 >>>
                4 > 2 >>
            </body>
            >cba
}

}
