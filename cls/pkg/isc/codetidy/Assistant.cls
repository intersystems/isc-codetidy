Include (%occErrors, pkg.isc.codetidy.CodeTidy)

/// <ul><p>This class has functions to check for devaitions fom coding standards, debug globals and standardize indentation.
/// Each of the functions works with the saved code of the current document. 
/// <p>These functiona are mapped to methods as follows:<ul>
/// <li>Code Analysis : <method>CheckDocument</method>
/// <li>Analysis of Edits : <method>CheckEditsToDocument</method>
/// <li>Find Traps : <method>FindTraps</method>
/// <li>Automatic Indentation : <method>IndentDocument</method>
/// <li>Automatic Tweak : <method>TweakDocument</method></ul>
Class pkg.isc.codetidy.Assistant Extends %Studio.Extension.Base [ ProcedureBlock ]
{

Parameter DOMAIN = "Studio";

Parameter MAXLINELENGTH = 256;

Parameter MAXMETHODLINES = 50;

XData Menu
{
<MenuBase>
<Menu Name="CodeTidy" Type="0">
<MenuItem Name="Run"/>
<MenuItem Name="RunSourceControl"/>
</Menu>
</MenuBase>
}

/// List of globals that are used by the system and when set do not 
/// constitute a break in standards.
Property AlertGlobalExceptions As %String [ MultiDimensional ];

/// List of patterns that when found should be considered a breach 
/// of standard practice.
Property AlertPatterns As %String [ MultiDimensional ];

/// Initialise the AlertGlobalExceptions property.
Method BuildAlertGlobalExceptions()
{
    set ..AlertGlobalExceptions("tmp") = ""
    set ..AlertGlobalExceptions("rmac") = ""
    set ..AlertGlobalExceptions("cachetemp") = "" //reports
    set ..AlertGlobalExceptions("Config") = ""
    
    // Add the custom exceptions provided by the configuration
    // These are forced to be lowercase because the compared line text is lowercase
    set customExceptions = ##class(pkg.isc.codetidy.Utils).GetEnabledGlobals()
    set pointer = 0
    while $listnext(customExceptions, pointer, exception) {
        set ..AlertGlobalExceptions($zconvert(exception, "l")) = ""
    }
}

/// Custom Markers:<br><ul>
///   <li><b>TODO:</b><br>
///           Used to mark a section of code that needs further work.
///   <li><b>HACK:</b><br>
///           Used to mark a work around that should be fixed.
/// </ul>
/// Code Review Indicators:<br><ul>
///   <li><b>'#(<i>var</i>)#'</b><br>
///           If used in javascript the variable could be quoted 
///           incorrectly.  Instead #(..QuoteJS(var))# should be used.
///   <li><b>d <i>obj</i>.%Save()</b><br>
///           When an object is being saved the return value should be kept
///           and checked. 
///   <li><b>for (var <i>i</i>=1;<i>i</i>&lt;<i>tbl</i>.rows.length;<i>i</i>++) {</b><br>
///           Tables generated from queries may or may not have the header 
///           shown depending upon the layout setting.  This javascript will
///           loop the number of rows minus one.  If the header is not shown
///           then this will skip the final row.  To avoid this situation we
///           should use <= the number of rows and check whether an element
///           exists with the appropriate id.  
///   <li><b>document.body.onunload = <i>method</i></b><br>
///           Using this event can prevent any child windows from being closed
///           when the session times out.  Use the addEventListener and 
///           attachEvent methods instead.
///           <example language=JavaScript>
/// if (window.addEventListener) {
///  window.addEventListener("unload", unloadHandler, false); 
/// } else if (document.addEventListener) {
///  document.addEventListener("unload", unloadHandler, false); 
/// } else if (window.attachEvent) {
///  window.attachEvent("onunload", unloadHandler); 
/// } else {
///  window.alert('Failed to attach an Event Listener');
/// }</example>
///   <li><b>s <i>var</i>=%request.Get("<i>var</i>") / %session.Get("<i>var</i>")</b><br>
///       <b>s <i>var</i>=%request.Set("<i>var</i>",<i>value</i>) / %session.Set("<i>var</i>",<i>value</i>)</b>
///           Using %request.Data / %session.Data directly accesses the variable
///           rather than running through extra processing and checking globals.  
///   <li><b>i <i>$$checkA</i>!(<i>$$checkB</i>) {</b><br>
///           By changing to use || or && the system will not call the functions
///           unless they are required to evaluate the logical outcome.  This 
///           can be used to improve peformance by skipping extra processing 
///           when possible.
///   <li><b>d <i>obj</i>.%Close()</b><br>
///           To remove an object reference, set the variable to the null 
///           string (""). The obsolete %Close() method cannot be used to 
///           remove an object reference. %Close() performs no operation and 
///           always returns successful completion. 
///   <li><b>s $li(<i>varList</i>, $ll(<i>varList</i>)+1) = <i>var</i></b><br>
///           The linked list can me much more efficiently manipulated by 
///           concatenating the new value using $listbuild at the end of the 
///           existing list.
///   <li><b>s ^<i>global</i>($j) = <i>value</i></b><br>
///           The use of $j indicates the global will only be used by the current
///           process.  Using a process-private global would be faster.  If 
///           possible using a local variable would be much faster.
///   <li><b>n (parref,nam,val)</b></br>
///           Using ProcedureBlock and PublicList can be up to ten times faster 
///           using an exclusive new.  Note that variables starting with % are 
///           implicitly public.
///           <br>Using a method:
/// <example language=objectscript>
/// ClassMethod OnAudit() [ CodeMode = generator, Final, ProcedureBlock = 1, PublicList = gUserRowId ]
/// </example>
///           Using a line label:
/// <example language=objectscript>
/// Audit() [ gUserRowId ] public {
/// </example>
///   <li><b>document.body.onload = <i>method</i></b><br>
///           The body onload DOM event is not supported by FireFox.  Instead use
///           addEventListener("load" / attachEvent("onload" to implement a cross
///           browser solution.
/// <example language=JavaScript>
/// if (window.addEventListener) {
///  window.addEventListener("load", loadHandler, false); 
/// } else if (document.addEventListener) {
///  document.addEventListener("load", loadHandler, false); 
/// } else if (window.attachEvent) {
///  window.attachEvent("onload", loadHandler); 
/// } else {
///  window.alert('Failed to attach an Event Listener');
/// }
/// </example>
///   <li><b>cursor: hand;</b><br>
///           In the past the hand value was Microsoft's way of saying pointer; and IE 5.0 and 5.5 only support
///           hand.  Because it's the cursor value that's used most often, most other browsers have also
///           implemented hand.  Since IE 6 and 7 support pointer, there's no more reason to use hand.
///   <li><b><i>var</i>=<i>var</i>.parentElement;</b><br>
///           Always use parentNode instead of parentElement.
///           parentNode is standard and supported by most browsers, parentElement is proprietary.
///   <li><b>Write ..%ClassName(1)</b><br>
///           This involves a method call and since 2010.1, Write $classname() 
///           is a much faster function that replaces this.
///           If you were calling ..%ClassName(0) or ..%ClassName() then leave that 
///           unchanged as these return the short classname where as $classname() 
///           always returns the long version of the classname.
///   <li><b>Write <i>oref<i>.%ClassName(1)</b><br>
///           It is much faster to replace this with: Write $classname(oref)
///           
/// </ul>
/// Code Review Indicators Only Checked with <method>CheckEditsToDocument</method>:<br><ul>
///   <li><b>lineLabel</b><br>
///           Avoid line labels inside class methods, with exception of fetch methods. 
///           Instead use class methods so code is reusable in other classes if needed.
///   <li><b>;;</b><br>
///           Don't use ";;" as comments unless you really intend to.
///           These comments have CPU time against them whereas ;,//,/*...*/ do not.
Method BuildAlertPatterns()
{
    #; Note: Code is converted to lower case prior to comparison.
    
    #; User alerts
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1P1""todo"".E", "USER", "Incomplete development") ##;noalert
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1P1""hack"".E", "USER", "Work around in place")   ##;noalert
    
    #; Possible issue with coding
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""'#("".E1"")#'"".E", "WARN", "Use QuoteJS to ensure the string isn't terminated by data containing quotes") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""d "",1""do "").A1"".%save("".E", "WARN", "Check the return value of %Save()") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild("1(1""%"",1AN).E", "WARN", "Avoid line labels inside class methods except in fetch methods; use separate class methods instead", "forEditsCheck") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""$zconvert("",1""$zcvt("")1.ANP1""""""u"""""".E", "WARN", "Recommended to use macro '$$$ucase(%string)' to achieve upper case", "forEditsCheck") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""$zconvert("",1""$zcvt("")1.ANP1""""""l"""""".E", "WARN", "Recommended to use macro '$$$lcase(%string)' to achieve lower case", "forEditsCheck") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""$zconvert("",1""$zcvt("")."" ""1""$zstrip(""1.ANP1""""""*p""""""2.P1(1"""""",?"""""",1""""""?,"""""")2.P1""""""u"""""".E", "WARN", "Recommended to use macro '$$$ALPHAUP(%val)' for this purpose", "forEditsCheck") ##;noalert

    #; JavaScript anti-patterns
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1""document.body.onunload""."" ""1""="".E", "WARN", "Use addEventListener/attachEvent to avoid compromising timeout functionality") ##;noalert
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1""for (""0.1""var ""1.AP1""=1;""1.AP1""<""1.AP1"".rows.length;""1.AP1""++)"".E", "WARN", "Use <=table.rows.length and check the row to handle table headers") ##;noalert
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1"".parentelement"".E","WARN","Always use parentNode instead of parentElement") ##;noalert
    
    #; Optimisation available
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""%request.get("".E", "PERF", "Use $Get(%request.Data(""X"",1)) to improve performance") ##;noalert
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""%session.get("".E", "PERF", "Use $Get(%session.Data(""X"")) to improve performance") ##;noalert
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""%request.set("".E", "PERF", "Use Set %request.Data(""X"",1)=value to improve performance") ##;noalert
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""%session.set("".E", "PERF", "Use Set %session.Data(""X"")=value to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1"")"",1A)."" ""1(1""!"",1""&"")."" ""1""("".E", "PERF", "Consider using || or && to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""d "",1""do "").A1"".%close("".E", "PERF", "%Close doesn't close an object") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""s "",1""set "")1(1""$li("",1""$list("").A1"",""."" ""1(1""$ll("",1""$listlength("").A1"")+1)"".E", "PERF", "Set list=list_$lb(var) to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""s "",1""set "")1(1""$li("",1""$list("").A1"",""."" ""1(1""$ll("",1""$listlength("").A1"") + 1)"".E", "PERF", "Set list=list_$lb(var) to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1""s ^"",1""set ^"").A1""("".E1""$job"".E1(1"")="",1"") ="").E", "PERF", "Consider using a local variable or a process-private global to improve performance") ##;noalert
    #; Including a suggestion for each comment line reduces the usability of other code review indicators.
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".P1(1""n ("",1""new ("").A.E", "PERF", "Consider using ProcedureBlock and PublicList instead of exclusive new to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1A,1N)1"".getdatabyname("".E", "PERF", "Use $g(resultSet.Data(col)) to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1A,1N)1"".getdata("".E", "PERF", "Use $g(resultSet.Data(col)) to improve performance") ##;noalert
    #; The pattern match isn't able to inspect the object type.  Instead match the commonly used variable name for %ResultSet objects 'rs'.
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1""rs.get("".E", "PERF", "Use $g(resultSet.Data(col)) to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1""..%classname(1)"".E", "PERF", "Use $classname() to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1(1A,1N)1"".%classname(1)"".E", "PERF", "Use $classname(oref) to improve performance") ##;noalert
    set ..AlertPatterns($$$langObjectScript, $increment(cnt)) = $listbuild(".E1.(1"" "",1C)1"";;"".E", "PERF", "Do not use "";;"" comments unless you really intend to", "forEditsCheck") ##;noalert
    
    #; Compatibility concern
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1""document.body.onload""."" ""1""="".E", "COMPAT", "This technique is Firefox incompatible") ##;noalert
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1"".children"".E", "COMPAT", "Use .childNodes instead of .children") ##;noalert
    set ..AlertPatterns("javascript", $increment(cnt)) = $listbuild(".E1"".parentelement"".E", "COMPAT", "Use .parentNode instead of .parentElement") ##;noalert
    set ..AlertPatterns("generic", $increment(cnt)) = $listbuild(".E1""cursor:""."" ""1""hand"".E", "COMPAT", "Since IE 6+ supports pointer, use standards compliant 'pointer' instead of 'hand'") ##;noalert
    quit
}

/// Strip comments from a given line of code.
ClassMethod StripCode(String As %String, Language As %String = "", SkipPar As %Boolean = 0, SkipQuote As %Boolean = 1)
{
    set alteredStr = String
    
    #; Build list of open and close tags to avoid
    set skipList = ""
    #; Quotes are added to the skip list first so that
    #; they will be stripped from the text first.
    if SkipQuote {
        set skipList=skipList_$listbuild("""","""")
        if Language = "javascript" {
            set skipList=skipList_$listbuild("'","'")
        }
    }
    
    if Language=$$$langObjectScript {
        set skipList=skipList_$listbuild(";","")
        set skipList=skipList_$listbuild("//","")
        set skipList=skipList_$listbuild("/*","*/")
    } elseif Language = "javascript" {
        set skipList=skipList_$listbuild("//","")   // Line Comment
        set skipList=skipList_$listbuild("/*","*/") // Block Comment
        set skipList=skipList_$listbuild("(/","/")  // Regular Expression
    } elseif Language = "basic" {
        set skipList=skipList_$listbuild("'","")
    }
    
    if SkipPar {
        set skipList=skipList_$listbuild("(",")")
    }
    
    for skipIdx = 1:2:$listlength(skipList) {
        set openChar = $list(skipList,skipIdx)
        set closeChar = $list(skipList,skipIdx+1)
        
        set open = $find(alteredStr, openChar, 1) - 1
        while (open > 0) {
            #; Find the end
            if closeChar '= "" {
                set close = $find(alteredStr, closeChar, open + 1) - 1
                set nextOpen = open
                for {
                    set nextOpen = $find(alteredStr, openChar, nextOpen + 1)
                    if nextOpen = 0 || (nextOpen > close) quit
                    set close = $find(alteredStr, closeChar, close + 1) - 1
                    if close = 0 quit
                }
            } else {
                #; Use the end of the line
                set close = $length(alteredStr) + 1
            }
            if close > 0 {
                set alteredStr = $extract(alteredStr, 1, open)_$justify("",close - open - 1)_$extract(alteredStr, close - ($length(closeChar) - 1), $length(alteredStr))
                set open = $find(alteredStr, openChar, close + 1) - 1
            } else {
                set open = 0
            }
        }
    }
    quit alteredStr
}

/// This method runs through the saved source of the current document and changes the indent to match standard
/// practices.  The indentation can be run for classes, routines, and javascript.  
ClassMethod IndentDocument(InternalName As %String) As %Status
{
    write !!,"Auto indent started "_$zdatetime($h)
    set started = $piece($ztimestamp, ",", 2)
    set status = $$$OK
    set type = ..FileType(InternalName)
    if type = "class" {
        #; Open the class definition.
        set classDef = ##class(%Dictionary.ClassDefinition).%OpenId($piece(InternalName, ".", 1, $length(InternalName, ".") - 1),,.sc)
        
        if $$$ISOK(sc) {
            #; Iterate the methods from the class.
            set methodKey = ""
            for  {
                set method = classDef.Methods.GetNext(.methodKey)
                if methodKey = "" quit  //
                
                // Get the tokens for each line so that the command can be determined
                if (method.Language = $$$langObjectScript) || (method.Language = "") {
                    kill tokens
                    $$$ThrowOnError(##class(pkg.isc.codetidy.vartyping.ObjectScriptTokenizer).GetMethodImplementation(classDef.Name, method.Name, .tokens, $namespace))
                    do method.Implementation.Rewind()
                }

                #; Run through each line and build a new stream
                #; with the corrected indentation.
                set lineText = ""
                set indent = 1
                kill handle
                set code = ##class(%Stream.TmpCharacter).%New()
                set lineNumber = 1
                set command = ""
                set isJSON = 0
                for  {
                    kill len
                    set lineText = method.Implementation.ReadLine(.len)
                    if len = -1  quit  //
                    
                    if (method.Language = $$$langObjectScript) || (method.Language = "") {
                        set command = ""
                        set lineTokens = $get(tokens(lineNumber))
                        if lineTokens '= "" {
                            set pointer = 0
                            while $listnext(lineTokens, pointer, token) {
                                set tokenType = $list(token, 2)
                                if (tokenType = "Command") {
                                    set command = $list(token, 3)
                                } elseif (tokenType = "Pre-Processor Command") && ($list(token, 3) '= "#") {
                                    set command = "#"_$list(token, 3)
                                } elseif (tokenType = "Pre-Processor Command") && ($list(token, 3) = "#") {
                                    // do nothing if it is the # before the pre processor command
                                    continue
                                } elseif $list(token, 2) '= "White Space" {
                                    quit
                                }
                            }
                            // Check for JSON code
                            set isJSON = 0
                            set pointer = 0
                            while $listnext(lineTokens, pointer, token) {
                                if $list(token, 2) [ "JSON" {
                                    set isJSON = 1
                                    quit
                                }
                            }
                        }
                        set lineNumber = $increment(lineNumber)
                    }

                    do ..IndentCodeLine(.handle, $case(method.Language, "":$$$langObjectScript, :method.Language), .lineText, .indent, command, isJSON)
                    if 'method.Implementation.AtEnd {
                        do code.WriteLine(lineText)
                    } else {
                        do code.Write(lineText)
                    }
                }
                
                #; Replace the existing stream.
                set method.Implementation = code
            }
            
            #; Iterate the triggers from the class.
            set triggerKey = ""
            for  {
                set trigger = classDef.Triggers.GetNext(.triggerKey)
                if triggerKey = "" quit  //
                
                #; Run through each line and build a new stream
                #; with the corrected indentation.
                set lineText = ""
                set indent = 1
                kill handle
                set code = ""
                for i=1:1:$length(trigger.Code, $char(13,10)) {
                    if code '= "" set code = code _ $char(13,10)
                    set lineText = $piece(trigger.Code, $char(13,10), i)
                    
                    do ..IndentCodeLine(.handle, $case(trigger.Language, "":$$$langObjectScript, :trigger.Language), .lineText, .indent)
                    set code = code _ lineText
                }
                
                #; Replace the existing stream.
                set trigger.Code = code
            }
            
            #; Iterate the queries from the class.
            set queryKey = ""
            for  {
                set query = classDef.Queries.GetNext(.queryKey)
                if queryKey = "" quit  //
                
                #; Run through each line and build a new stream
                #; with the corrected indentation.
                set lineText = ""
                set indent = 1
                kill handle
                set code = ""
                if query.SqlQuery '= "" {
                    for i=1:1:$length(query.SqlQuery, $char(13,10)) {
                        if code '= "" set code = code _ $char(13,10)
                        set lineText = $piece(query.SqlQuery, $char(13,10), i)
                        
                        do ..IndentCodeLine(.handle, "sql", .lineText, .indent)
                        set code = code _ lineText
                    }
                    
                    #; Replace the existing stream.
                    set query.SqlQuery = code
                }
            }
            
            #; Save the changes.
            set status = classDef.%Save()
            if $$$ISERR(status) {
                do $system.Status.DisplayError(status)
            }
        } else {
            quit sc
        }
    } elseif type = "routine" {
        #; Open the routine definition.
        set routineDef = ##class(%RoutineMgr).%OpenId(InternalName)
        
        if $isobject(routineDef) {
            #; Check for basic code.  Basic will use different indentation rules.
            set language = $case(routineDef.LanguageModeGet(),9:"basic",:$$$langObjectScript)
            
            // Get the tokens for each line so that the command can be determined
            if (language = $$$langObjectScript) || (language = "") {
                kill tokens
                $$$ThrowOnError(##class(pkg.isc.codetidy.vartyping.ObjectScriptTokenizer).GetRoutineImplementation(InternalName, .tokens, $namespace))
                do routineDef.Code.Rewind()
            }

            #; Run through each line and build a new stream
            #; with the corrected indentation.
            set lineText = ""
            set indent = 1
            kill handle
            set code = ##class(%GlobalCharacterStream).%New()
            set lineNumber = 1
            set command = ""
            set isJSON = 0
            for  {
                kill len
                set lineText = routineDef.Code.ReadLine(.len)
                if len = -1  quit  //
                
                if (language = $$$langObjectScript) {
                    set command = ""
                    set lineTokens = $get(tokens(lineNumber))
                    if lineTokens '= "" {
                        set pointer = 0
                        while $listnext(lineTokens, pointer, token) {
                            set tokenType = $list(token, 2)
                            if (tokenType = "Command") {
                                set command = $list(token, 3)
                            } elseif (tokenType = "Pre-Processor Command") && ($list(token, 3) '= "#") {
                                set command = "#"_$list(token, 3)
                            } elseif (tokenType = "Pre-Processor Command") && ($list(token, 3) = "#") {
                                // do nothing if it is the # before the pre processor command
                                continue
                            } elseif $list(token, 2) '= "White Space" {
                                quit
                            }
                        }
                        // Check for JSON code
                        set isJSON = 0
                        set pointer = 0
                        while $listnext(lineTokens, pointer, token) {
                            if $list(token, 2) [ "JSON" {
                                set isJSON = 1
                                quit
                            }
                        }
                    }
                    set lineNumber = $increment(lineNumber)
                }
                
                do ..IndentCodeLine(.handle, language, .lineText, .indent, command, isJSON)
                if 'routineDef.Code.AtEnd {
                    do code.WriteLine(lineText)
                } else {
                    do code.Write(lineText)
                }
            }
            
            #; Replace the existing stream.
            do routineDef.Code.Clear()
            for  {
                kill len
                set lineText = code.Read(.len)
                if len = -1 quit  //
                
                do routineDef.Code.Write(lineText)
            }
            
            #; Save the changes.
            set status = routineDef.%Save()
            if $$$ISERR(status) {
                write !, routineDef.%Id(), $char(9), routineDef.Name
                do $system.Status.DisplayError(status)
            }
        } else {
            quit $$$ERROR($$$GeneralError, "Unable to open routine")
        }
    } elseif type = "csp" || (type = "javascript") || (type = "other") {
        #; Open the file.
        set fileName = $system.CSP.GetFileName(InternalName)
        if '##class(%File).Exists(fileName) quit $$$FileNotFound
        
        set file = ##class(%File).%New(fileName)
        set status = file.Open("R")
        
        if $$$ISOK(status) {
            set language = $case($zconvert($piece(fileName, ".", $length(fileName, ".")),"L"), "csp":$$$langObjectScript, "csr":$$$langObjectScript, "js":"javascript", "css":"stylesheet")
            
            #; Run through each line and build a new stream
            #; with the corrected indentation.
            set lineText = ""
            #; JavaScript and CSP are not required to begin with a tab.
            set indent = 0
            kill handle
            set tempFileName = ##class(%File).TempFilename()
            set code = ##class(%File).%New(tempFileName)
            set status = code.Open("WSN")
            for  {
                kill len
                set lineText = file.ReadLine(.len)
                if len = -1  quit  //
                
                do ..IndentCodeLine(.handle, language, .lineText, .indent)
                if 'file.AtEnd {
                    do code.WriteLine(lineText)
                } else {
                    do code.Write(lineText)
                }
            }
            
            #; Save changes.
            do file.Close(),code.Close()
            kill file,code
            do ##class(%File).CopyFile(tempFileName, fileName)
            
        } else {
            quit $$$ERROR($$$GeneralError, "Unable to open file")
        }
    }
    set duration = $fnumber(($piece($ztimestamp, ",", 2) - started),"",3)_"s"
    if $$$ISOK(status) {
        write !, "Indentation finished successfully in "_duration_"."
    } else {
        write !, "Encountered "_$length($system.Status.GetErrorCodes(status), ",")_ " errors during indentation in "_duration_"."
    }
    quit status
}

/// Apply standard indentation to a given line of code.
/// Note: This method is called with each line in sequence.  The Handle is used to keep track of details that effect the indentation of subsequent lines.
ClassMethod IndentCodeLine(ByRef Handle As %Library.Binary, Language As %String, ByRef LineText As %String, ByRef Indent As %Integer, Command As %String = "", IsJSON As %Boolean = 0)
{
    #; Check for line label
    set leadChar = $extract(LineText, 1)
    set lineLabel = (Language=$$$langObjectScript && ((leadChar '= $char(32)) && (leadChar '= $char(9)) && (leadChar '= "#")))
    
    #; Remove leading space.
    set originalText = LineText
    
    set LineText = $zstrip(LineText,"<W")
    set LineText = $zstrip(LineText,">W")
    
    #; Check whether this line should be moved out.
    set decIndent = ..DecIndent(.Handle, (LineText), Language, Command, IsJSON)
    
    set Indent = Indent - decIndent
    if Indent < 0 set Indent = 0
    
    set indentChar = ##class(pkg.isc.codetidy.Utils).GetIndentString()
    set indentLength = $length(indentChar)
    
    #; Build new line.
    set formatLine = ""
    if (Language = $$$langObjectScript) || (Language = "") {
        set formatLine = LineText
        if '$get(Handle("&sql(")),'$get(Handle("&js<")),'$get(Handle("&html<")) {
            // Forget indentation offset for any previous embedded section
            kill Handle("IndentHTML")
        } else {
            // Preserve user indentation of embedded html blocks
            if $get(Handle("&html<")) {
                set numTabs = 0
                while $extract(originalText, numTabs*indentLength + 1, numTabs*indentLength + indentLength) = indentChar {
                    set numTabs = $increment(numTabs)
                }
                if ($get(Handle("IndentHTML")) = "") {
                    set Handle("IndentHTML") = Indent - numTabs
                } else {
                    set Indent = numTabs + +$get(Handle("IndentHTML"))
                }
            }
        }
    } else {
        #; Other languages don't use dot structures.
        set formatLine = LineText
    }
    
    if 'lineLabel {
        #; Check whether the next line should be moved in.
        set incIndent = ..IncIndent(.Handle, LineText, Language, Command, IsJSON)

        // Preserve indentation of /**/ comments
        if (Language = $$$langObjectScript) || (Language = "") {
            // Preserve user indentation of comment blocks
            if $get(Handle("/*")) || ($extract(LineText, $length(LineText) - 1, *) = "*/") {
                set numTabs = 0
                while $extract(originalText, numTabs*indentLength + 1, numTabs*indentLength + indentLength) = indentChar {
                    set numTabs = $increment(numTabs)
                }
                if '$data(Handle("IndentComment")) {
                    set Handle("IndentComment") = Indent - numTabs
                } else {
                    set Indent = numTabs + +$get(Handle("IndentComment"))
                }
            }
            // Forget indentation offset for multiline comments
            if $get(Handle("IndentComment")) && '$get(Handle("/*")) {
                kill Handle("IndentComment")
            }
        }

        #; Return new line.
        for count = 1:1:(Indent+$get(Handle("post-decrement"))) {
            set formatLine = indentChar_formatLine
        }
        set LineText = formatLine

        // Set indent for next line
        set Indent = Indent + incIndent
    } elseif Indent = 0 {
        #; Ensure Object Script code is indented following a line label.
        set Indent = 1
    }
}

/// Temporarily putting this method here
/// it is a rewrite from the basic version to objectscript
ClassMethod DecIndent(ByRef Handle As %Library.Binary, LineText As %String, Language As %String, ObjectScriptCommand As %String, IsJSON As %Boolean) As %Integer
{
    // Decrease Indent
    #dim endOfCommand as %Integer
    #dim command as %String
    set decIndent = 0

    // Strip comments
    set LineText = ..StripCode(LineText, Language)
    if Language = "objectscript" {
        // Use the command determined from the tokens for objectscript
        set command = ObjectScriptCommand
    } else {
        set command = ..GetCommand(LineText)
    }
    set Handle("post-decrement") = ""

    // Basic
    if Language = "basic" {
        set endingCommands = $listbuild("Next", "Loop", "Wend", "Case", "Else", "#Else", "Else:", "#Else:", "ElseIf", "#ElseIf", "End If", "#End If")
        if $listfind(endingCommands, command) '= 0 {
            set decIndent = 1
        } elseif (command = "End") || (command = "#End") {
            if $piece(LineText, " ", 2) = "Select" {
                set decIndent = 2
            } elseif $length(LineText) > 3 {
                set decIndent = 1
            }
        }
    }

    // ObjectScript
    elseif Language = "objectscript" {
        // Check for preprocessor directives
        if (command = "#else") || (command = "#elseif") || (command = "#endif") {
            set decIndent = 1
        } else {
            set decIndent = 0
        }

        set openTags = 5
        set openTags(1) = "{"
        set openTags(2) = "("
        set openTags(3) = "&javascript<"
        set openTags(4) = "&html<"
        set openTags(5) = "/*"
        if IsJSON {
            set openTags(6) = "["
            set openTags = $increment(openTags)
        }

        // if previously in = indent and new command shows up decrease indent
        // also decrease indent for comments
        if $get(Handle("decOnNextCommand")) &&
        ((command '= "") || ($extract(LineText, 1, 2) = "//") ||
            ($extract(LineText, 1) = "}") || ($extract(LineText, 1) = "&")) {
            set decIndent = $increment(decIndent)
            kill Handle("decOnNextCommand")
        }

        for tagIndex = 1:1:openTags {
            if $extract(openTags(tagIndex)) = "&" {
                set openPar = "<"
            } else {
                set openPar = openTags(tagIndex)
            }
            set closePar = $case(
                openPar,
                "{": "}",
                "(": ")",
                "/*": "*/",
                "[": "]",
                : ">"
            )

            // check for block statements
            if (+$get(Handle(openTags(tagIndex)))) > 0 {
                set closeCount = $length(LineText, closePar) - $length(LineText, openPar)
                set Handle(openPar) = Handle(openTags(tagIndex)) - closeCount
                // set Handle(openTags(tagIndex)) = Handle(openPar)
                if closeCount > 0 {
                    if closePar '= "*/" {
                        set decIndent = decIndent + closeCount
                        if $extract(LineText, 1, $length(closePar)) '= closePar {
                            set Handle("post-decrement") = $get(Handle("post-decrement")) + closeCount
                        }
                    }
                } elseif closeCount = 0 {
                    set openPos = $find(LineText, openPar) - $length(openPar)
                    set closePos = $find(LineText, closePar) - $length(closePar)
                    if $extract(LineText, 1, $length(closePar)) = closePar {
                        // Decrement the indent for the line if it begins witha  closing brace/parenthesis
                        set decIndent = $increment(decIndent)
                    } elseif (openPos > 0) && (closePos > 0) && (closePos < openPos) {
                        // Decrement the indent for the next line if this line uses a close bracket/parenthesis first.
                        set decIndent = $increment(decIndent)
                        set Handle("post-decrement") = $get(Handle("post-decrement")) + 1
                    }
                }
            }
        }

        // Check for multi-line commands
        if (+$get(Handle(","))) > 0 {
            if $extract(LineText, $length(LineText)) '= "," {
                set Handle(",") = 0
                set decIndent = $increment(decIndent)
                set Handle("post-decrement") = $get(Handle("post-decrement")) + 1
            }
        }
        if $extract(LineText, 1) = "_" {
            set decIndent = decIndent - 1
        }
    }

    // Javascript/css
    elseif (Language = "javascript") || (Language = "stylesheet") {
        set LineText = ..StripBlock(.Handle, LineText, Language)

        // Check for commands which do not use braces
        if (command = "case") || (command = "default") {
            set decIndent = 1
        } else {
            set decIndent = 0
        }

        set openTags(1) = "{"
        set openTags(2) = "("

        for tagIndex = 1:1:2 {
            set openPar = openTags(tagIndex)
            set closePar = $case(
                openPar,
                "{": "}",
                "(": ")"
            )

            // Check for block statements
            if (+$get(Handle(openTags(tagIndex)))) > 0 {
                set closeCount = $length(LineText, closePar) - $length(LineText, openPar)
                set Handle(openPar) = Handle(openTags(tagIndex)) - closeCount
                set Handle(openTags(tagIndex)) = Handle(openPar)
                if closeCount > 0 {
                    set decIndent = decIndent + closeCount
                    if $extract(LineText, 1, $length(closePar)) '= closePar {
                        set Handle("post-decrement") = $get(Handle("post-decrement")) + closeCount
                    }
                } elseif closeCount = 0 {
                    set openPos = $find(LineText, openPar) - $length(openPar)
                    set closePos = $find(LineText, closePar) - $length(closePar)
                    if $extract(LineText, 1, $length(closePar)) = closePar {
                        // Decrement the indent for the line if it begins with a closing brace/parenthesis.
                        set decIndent = $increment(decIndent)
                    } elseif (openPos > 0) && (closePos > 0) && (closePos < openPos) {
                        // Decrement the indent for the next line if this line uses a close bracket/parenthesis first.
                        set decIndent = $increment(decIndent)
                        set Handle("post-decrement") = $get(Handle("post-decrement")) + 1
                    }
                }
                // Check for close brace for a switch statement
                if (openPar = "{") && (closeCount > 0) && $get(Handle("switch")) {
                    set Handle("switch") = 0
                    set decIndent = $increment(decIndent)
                }
            }
        }
    }

    // SQL
    elseif Language = "sql" {
        set LineText = ..StripBlock(.Handle, LineText, Language)

        // Check for commands which do not use braces.
        set command = $zconvert(command, "l")
        set commandsNoBraces = $listbuild("from", "where", "group", "having", "order")
        if $listfind(commandsNoBraces, command) '= 0 {
            set decIndent = 1
        } else {
            set decIndent = 0
        }
        
        set openPar = "("
        set closePar = ")"
        
        // Check for block statements
        if (+$get(Handle(openPar))) > 0 {
            set closeCount = $length(LineText, closePar) - $length(LineText, openPar)
            set Handle(openPar) = Handle(openPar) - closeCount
            if closeCount > 0 {
                set decIndent = decIndent + closeCount + 1
                if $extract(LineText, 1, $length(closePar)) '= closePar {
                    set Handle("post-decrement") = $get(Handle("post-decrement")) + closeCount
                }
            } elseif closeCount = 0 {
                set openPos = $find(LineText, openPar) - $length(openPar)
                set closePos = $find(LineText, closePar) - $length(closePar)
                if $extract(LineText, 1, $length(closePar)) = closePar {
                    // Decrement the indent for the line if it begins with a closing brace/parenthesis.
                    set decIndent = $increment(decIndent)
                } elseif (openPos > 0) && (closePos > 0) && (closePos < openPos) {
                    // Decrement the indent for the next line if this line uses a close bracket/parenthesis first.
                    set decIndent = $increment(decIndent)
                    set Handle("post-decrement") = $get(Handle("post-decrement")) + 1
                }
            }
        }
    }

    return decIndent
}

/// Temporarily putting this method here
/// it is a rewrite from the basic version to objectscript
ClassMethod IncIndent(ByRef Handle As %Library.Binary, LineText As %String, Language As %String, ObjectScriptCommand As %String, IsJSON As %Boolean) As %Integer
{
    #dim endOfCommand as %Integer
    #dim command as %String
    set incIndent = 0

    // Strip comments
    set LineText = ..StripCode(LineText, Language)
    if Language = "objectscript" {
        // Use the command determined from the tokens for objectscript
        set command = ObjectScriptCommand
    } else {
        set command = ..GetCommand(LineText)
    }

    // Basic indentation
    if Language = "basic" {
        set controlCommandList = $listbuild("With", "For", "Do", "While", "Case", "Else", "Else:", "#Else", "#Else:", "Sub", "Function", "Property", "Enum", "Type")
        set ifCommandList = $listbuild("If", "#If", "ElseIf", "#ElseIf")
        set otherCommandList = $listbuild("Private", "Public", "Friend")

        if command = "Select" {
            set incIndent = 2
        } elseif $listfind(controlCommandList, command) '= 0 {
            set incIndent = 1
        } elseif $listfind(ifCommandList, command) '= 0 {
            set endOfCommand = $find(LineText, " Then") - $length(" Then")
            set afterCommand = $zstrip($extract(LineText, endOfCommand + 5, $length(LineText) - endOfCommand), "<W")
            set firstChar = $extract(afterCommand, 1)
            if (firstChar = "'") || (firstChar = "") {
                set incIndent = 1
            }
        } elseif $listfind(otherCommandList, command) '= 0 {
            set endOfCommand = $find(LineText, " Static ") - $length(" Static ")
            if endOfCommand '= 0 {
                set endOfCommand = $find(LineText, " ", endOfCommand + 7) - 1
            } else {
                set endOfCommand = $find(LineText, " ", $length(command) + 1) - 1
            }
            set afterCommand = $extract(LineText, endOfCommand + 1, $find(LineText, " ", endOfCommand + 1) - endOfCommand - 2)
            set listToIndent = $listbuild("Sub", "Function", "Property", "Enum", "Type")
            if $listfind(listToIndent, afterCommand) '= 0 {
                set incIndent = 1
            }
        }
    }

    // ObjectScript indentation
    elseif Language = "objectscript" {
        // Check for preprocessor directives
        set preprocessorList = $listbuild("#if", "#ifdef", "#ifndef", "#else", "#elseif")
        if $listfind(preprocessorList, command) '= 0 {
            set incIndent = 1
        } else {
            set incIndent = 0
        }

        set openTags = 5
        set openTags(1) = "{"
        set openTags(2) = "("
        set openTags(3) = "&javascript<"
        set openTags(4) = "&html<"
        set openTags(5) = "/*"
        if IsJSON {
            set openTags(6) = "["
            set openTags = $increment(openTags)

            if ($get(Handle("indentedJSON")) = 1) && ($extract(LineText, $length(LineText)) = ",") {
                kill Handle("indentedJSON")
                set incIndent = incIndent - 1
            }

            // Extra JSON rule: if ending with [{ in JSON, only indent once
            if $extract(LineText, $length(LineText) - 1, *) = "[{" {
                set incIndent = incIndent - 1
            } elseif (LineText = "}]") {
                set incIndent = $increment(incIndent)
            } elseif ($extract(LineText, $length(LineText)) = ":") {
                set incIndent = $increment(incIndent)
                set Handle("indentedJSON") = 1
            }
        }

        // Check for = or _ at the end of the line and indent next line
        set lastChar = $extract(LineText, $length(LineText))
        if ('IsJSON) && (command '= "") && ((lastChar = "=") || (lastChar = "_")) && ('$get(Handle("decOnNextCommand"))) {
            set incIndent = $increment(incIndent)
            set Handle("decOnNextCommand") = 1
        }

        // Convert to lowercase
        set LineText = $zconvert(LineText, "l")
        for tagIndex = 1:1:openTags {
            set openPar = openTags(tagIndex)
            set closePar = $case(
                openPar,
                "{": "}",
                "(": ")",
                "/*": "*/",
                "[": "]",
                : ">"
            )

            // Check for block statements
            set openCount = $length(LineText, openPar) - $length(LineText, closePar)
            if openCount > 0 {
                set Handle(openPar) = $get(Handle(openTags(tagIndex))) + openCount
                if openPar '= "/*" {
                    set incIndent = incIndent + openCount
                }
            } elseif openCount = 0 {
                // Increment the indent for the next line if this line uses an open bracket/parenthesis last.
                set revLineText = $reverse(LineText)
                set openPos = $find(revLineText, $reverse(openPar)) - $length(openPar)
                set closePos = $find(revLineText, $reverse(closePar)) - $length(closePar)
                if (openPos > 0) && (closePos > 0) && (openPos < closePos) {
                    set incIndent = $increment(incIndent)
                }
            }
        }
        
        // Check for multi-line commands
        // Parameters passed on separate lines (inside parenthesis) are already catered for.
        if (+$get(Handle("(")) = 0) && $extract(LineText, $length(LineText) = ",") {
            // Check for a dynamic object line
            set isDynamicObjectLine = LineText?1"".E1""":".E1"".E1""","
            if (+$get(Handle(",")) = 0) && 'isDynamicObjectLine {
                set Handle(",") = 1
                set incIndent = $increment(incIndent)
            }
        }
        if $extract(LineText, 1) = "_" {
            set incIndent = incIndent - 1
        }
    }

    // Javascript and css
    elseif (Language = "javascript") || (Language = "stylesheet") {
        set LineText = ..StripBlock(.Handle, LineText, Language)

        // Check for commands which do not use braces
        if command = "switch" {
            set incIndent = 1
            set Handle("switch") = 1
        } elseif (command = "case") || (command = "default") {
            set incIndent = 1
        } else {
            set incIndent = 0
        }

        set openTags(1) = "{"
        set openTags(2) = "("

        // Convert to lower case
        set LineText = $zconvert(LineText, "l")
        for tagIndex = 1:1:2 {
            set openPar = openTags(tagIndex)
            set closePar = $case(
                openPar,
                "{": "}",
                "(": ")"
            )

            // Check for block statements
            set openCount = $length(LineText, openPar) - $length(LineText, closePar)
            if openCount > 0 {
                set Handle(openPar) = $get(Handle(openTags(tagIndex))) + openCount
                set incIndent = incIndent + openCount
            } elseif openCount = 0 {
                // Increment the indent for the next line if this line uses an open bracket/parenthesis last.
                set revLineText = $reverse(LineText)
                set openPos = $find(revLineText, openPar) - $length(openPar)
                set closePos = $find(revLineText, closePar) - $length(closePar)
                if (openPos > 0) && (closePos > 0) && (openPos < closePos) {
                    set incIndent = $increment(incIndent)
                }
            }
        }
    }

    // SQL
    elseif Language = "sql" {
        set LineText = ..StripBlock(.Handle, LineText, Language)

        // Check for commands which do not use braces
        set command = $zconvert(command, "l")
        set commandsNonBrace = $listbuild("select", "from", "where", "group", "having", "order")
        if $listfind(commandsNonBrace, command) '= 0 {
            set incIndent = 1
        } else {
            set incIndent = 0
        }

        // Convert to lower case
        set LineText = $zconvert(LineText, "l")

        set openPar = "("
        set closePar = ")"

        // Check for block statements
        set openCount = $length(LineText, openPar) - $length(LineText, closePar)
        if openCount > 0 {
            set Handle(openPar) = $get(Handle(openPar)) + openCount
            set incIndent = incIndent + openCount
        } elseif openCount = 0 {
            // Increment the indent for the next line if this line uses an open bracket/parenthesis last.
            set revLineText = $reverse(LineText)
            set openPos = $find(revLineText, openPar) - 1
            set closePos = $find(revLineText, closePar) - 1
            if (openPos > 0) && (closePos > 0) && (openPos < closePos) {
                set incIndent = $increment(incIndent)
            }
        }
    }

    quit incIndent
}

/// Remove block comments.
/// Note: This method is called with each line in sequence.  The Handle is used to keep track of whether or not a block comment is open.
ClassMethod StripBlock(ByRef Handle As %Library.Binary, LineText As %String, Language As %String, OpenBlock As %String = "/*", CloseBlock As %String = "*/") As %String [ Language = basic ]
{
    ' Check for block comments
    If Handle(OpenBlock) Then
        startComment = 1
        nextChar = 1
    Else
        Set startComment = InStr(LineText, OpenBlock)
        If startComment > 0 Then
            Set nextChar = startComment + Len(OpenBlock)
        End If
    End If
    If startComment > 0 Then
        Set Handle(OpenBlock) = 1
        Set nextChar = InStr(nextChar, LineText & " ", CloseBlock)
        If nextChar > 0 Then
            LineText = Left(LineText, startComment - 1) & Mid(LineText, nextChar + Len(CloseBlock) + 1, Len(LineText))
            Set Handle(OpenBlock) = 0
        Else
            LineText = Left(LineText, startComment - 1)
        End If
    End If
    
    Return LineText
}

/// Returns the opening command from a line of code.
ClassMethod GetCommand(LineText As %String) As %String
{
    set lineTextLength = $length(LineText), endOfCommand = 0
    for index = 1:1:lineTextLength {
        set char = $extract(LineText, index)
        if char?1(1A,1N,1"#") continue
        set endOfCommand = index -1
        quit
    }
    #; Commands such as '#Else' are not required to be followed by any non-alphanumeric characters.
    if endOfCommand < 1 set endOfCommand = lineTextLength
    quit $extract(LineText, 1, endOfCommand)
}

/// The saved version of the entire current document is searched for indicators that the code deviates from the guidelines.
/// Not all output from this check needs to be changed.  It is only an indication that it may need review.
/// The method calls <method>CreateListOfAlerts</method> to find all alerts in document and then 
/// <method>PrintAlerts</method> to print desired alerts and sub-totals of alert types
/// <p>This function is used when a document is saved to display a summary.  The summary shows the details of the 
/// first alert and the sub-totals of alert types.  If no alerts are found then there is no output.  
/// This functionality is implemented using <class>Studio.SourceControl.ISTComposite</class>.
/// <p>This function is used when Studio menu item Assistant > Code Analysis is selected to display full list
/// of alerts and the sub-totals of alert types and when a checked out file is compiled to display a summary of alerts with 
/// only the first alert and sub-totals of alert types shown. If no alerts are found then there is no output.
Method CheckDocument(InternalName As %String, Display As %Integer = 2) As %Status
{
    
    set started = 0
    if Display {
        write !
        set started = $zhorolog
        if Display>1 write !,"Code analysis started "_$zdatetime($h)
    }
    
    set sc = ..CreateListOfAlerts(InternalName, .listOfAlerts, .count)
    if $$$ISOK(sc) {
        set sc  = ..DisplayCheckOutcome(InternalName, Display, listOfAlerts, .count, started)
        if $$$ISERR(sc) {
            quit sc
        }
    } else {
        quit sc
    }

    quit $$$OK
}

/// Compares lists of alerts in have revision and workspace version and returns a list of alerts unique to the workspace version and count of those alerts
Method GetUniqueAlerts(WorkspaceVersionListOfAlerts As %String, HaveRevisionListOfAlerts As %String, Output ListOfUniqueAlerts As %String, Output Count As %Integer) As %Status
{
    set Count = 0
    set ListOfUniqueAlerts = $listbuild()
    if (('$listvalid(WorkspaceVersionListOfAlerts)) || ('$listvalid(HaveRevisionListOfAlerts))) {
        quit $$$ERROR($$$GeneralError, "Method requires lists to work as intended")
    }
    
    // Checks each alert in workspace version against all alerts in have revision to find unique alerts
    set workspacePointer = 0
    while ($listnext(WorkspaceVersionListOfAlerts, workspacePointer, workspaceAlertList)) {
        if (('$data(workspaceAlertList)) || ('$listvalid(workspaceAlertList))) {
            continue
        }
        
        set isUnique = 1
        set havePointer = 0
        while($listnext(HaveRevisionListOfAlerts, havePointer, haveAlertList)) {
            if (('$data(haveAlertList)) || ('$listvalid(haveAlertList))) {
                continue
            }
            
            // Compares 'Category', 'alertText', and 'code' from alert to check for uniqueness ('label', 'labelLine', and 'documentLine' can change too easily)
            if (($list(workspaceAlertList,1,3) = $list(haveAlertList,1,3))) {
                // This check is for alerts specific to labeled code like methods, queries, properties, etc. such as missing method description
                if (($list(workspaceAlertList,3) = 0) && ($list(workspaceAlertList,4) '= $list(haveAlertList,4))) {
                    continue
                }
                set isUnique = 0
                quit
            }
        }
        // Unique alerts added to ListOfUniqueAlerts
        if (isUnique) {
            if $increment(Count),$increment(Count($list(workspaceAlertList,1)))
            set ListOfUniqueAlerts = $listupdate(ListOfUniqueAlerts, Count, workspaceAlertList)
        }
    }
    quit $$$OK
}

/// Prints list of alerts. Output is formatted so user can double click on results to go to line.
/// Bottom lines display sub-totals of alert types, total number of alerts and time to generate and print summary.
/// Each alert is a list containing all relevant information for that given alert.
/// Alert list has the following format: alertList = $listbuild(category, alertText, code, label, labelLine, documentLine) 
Method DisplayCheckOutcome(InternalName As %String, Display As %Integer, ListToDisplay As %String, ByRef Count As %Integer, Started As %Integer) As %Status
{
    if Display {
        
        set ptr = 0
        while ($listnext(ListToDisplay, ptr, alertList)) {
            if (('$data(alertList)) || ('$listvalid(alertList))) {
                continue
            }
            
            #; Format output so that the user can double click on results
            #; to go directly to the line.
            #; NOTE: Output designed to match standard used to show compilation errors
            #; zDEMO.NCK.temp.1.INT(318) ERROR #1026: Invalid command : 'dog' : Offset:5 [zCat+4^zDEMO.NCK.temp.1]
            #;  TEXT:   dog
            set displayText = InternalName
            if ..FileType(InternalName) = "class" {
                if ($list(alertList, 4) '= 0) {
                    set displayText = displayText_"("_$list(alertList, 4)
                    if ($list(alertList, 5) '= 0) {
                        set displayText = displayText_"+"_$list(alertList, 5)
                    }
                    set displayText = displayText_") "
                } else {
                    set displayText = displayText_" "
                }
            } else {
                set displayText = displayText_"("_$list(alertList, 6)_") "
            }
            set displayText = displayText_$list(alertList, 1)_": "_$list(alertList, 2)
            if ($list(alertList, 3) '= 0) {
                set displayText = displayText_$char(13,10)_" TEXT: "_$zstrip($list(alertList, 3), "<W")
            }
            
            #; Write to the Studio Output window.
            write !, displayText
            
            #; Summary, only show the first alert
            quit:(Display = 1)
        }
        
        set category="", displaySummary=""
        for category="WARN","COMPAT","USER","PERF" {
            if $get(Count(category)) set displaySummary = displaySummary_$listbuild(" "_category_": "_Count(category))
        }
        if displaySummary'="" write !,$listtostring(displaySummary,",")
        set duration = $fnumber($zhorolog - Started,"",3)_"s"
        if Count||(Display>1) write !,"Detected a total of "_Count_" alert/s in "_duration_"."
    }
    quit $$$OK
}

/// Checks the entire document and makes list of alerts of deviations from guidelines 
/// Each alert is a list containing all relevant information for that given alert
/// Alert list has the following format: alertList = $listbuild(category, alertText, code, label, labelLine, documentLine) 
/// <p>The method uses pattern matching to determine whether or not developers need to be alerted to a given line of 
/// code.  These patterns are set up by <method>BuildAlertPatterns</method>.
/// <p>All direct global sets or merges are noted unless they are included in a predefined list of globals that 
/// are excempt to the rules.  These are set up by <method>BuildAlertGlobalExceptions</method>.
/// <p>In addition to these checks JavaScript gets run through an open source verification tool.  This tool 
/// performs some fairly strict checks and optimisation tips for JavaScript.  For example the tool will indicate 
/// if a line is missing a semi-colon or if a variable has already been defined.
Method CreateListOfAlerts(InternalName As %String, Output ListOfAlerts As %String, Output Count As %Integer, BackupFile As %String = "", IsEditsCheck As %Boolean = 0) As %Status
{
    #; Methods such as <Property>Get or <Query>Execute override generated methods.
    #; In these cases the property or query may have a sufficient description.
    #define MemberOverride(%methodName)  (%methodName?1.E1(1"Get",1"Set",1"GetObject",1"SetObject",1"Execute",1"Fetch",1"Close"))
    #define SuppressAlerts(%description) (%description?.E1P1"noalert".E)
    
    if '$data(..AlertGlobalExceptions) do ..BuildAlertGlobalExceptions()
    if '$data(..AlertPatterns) do ..BuildAlertPatterns()
    
    set Count = 0
    set ListOfAlerts = $listbuild()
    
    set documentLine = 0
    set lastSequence = 0
    set type = ..FileType(InternalName)
    if type = "class" {
        #; Begin documentLine at -1 because the sequence calculation caters
        #; for the close brace or final line of the previous sequence item.
        set documentLine = -1
        #; Open the class definition.
        if (BackupFile = "") {
            set classDef = ##class(%Dictionary.ClassDefinition).%OpenId($piece(InternalName, ".", 1, $length(InternalName, ".") - 1),,.sc)
        } else {
            set classDef = ##class(%Dictionary.ClassDefinition).%OpenId($piece(BackupFile, ".", 1, $length(BackupFile, ".") - 1),,.sc)
        }
        if $$$ISOK(sc) {
            #; Count the description lines.
            if classDef.Description '= "" {
                set documentLine = $length(classDef.Description, $char(13,10))
            } else {
                if $increment(Count),$increment(Count("WARN"))
                set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Missing class description", 0, 0, 0, 0))
            }
            #; Count the opening class definition and curly brace.
            set documentLine = documentLine + 2
            
            #; Iterate the methods from the class.
            set methodKey = ""
            for  {
                set method = classDef.Methods.GetNext(.methodKey)
                if methodKey = "" quit
                
                #; Cater for lines that are in a class but not part of a method.
                set documentLine = documentLine + ((method.SequenceNumber - lastSequence) * 2)
                set lastSequence = method.SequenceNumber
                
                #; Count the description lines.
                if method.Description '= "" {
                    set documentLine = documentLine + $length(method.Description, $char(13,10))
                } else {
                    if '$$$MemberOverride(method.Name) {
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Missing method description", 0, method.Name, 0, 0))
                    }
                }
                #; Count the opening class definition.
                set documentLine = documentLine + 2
                //if IsEditsCheck {
                #; Check that each method parameter is explicitly assigned a type
                if (method.FormalSpec'="") {
                    for i = 1:1:$length(method.FormalSpec, ",") {
                        if ($length($piece(method.FormalSpec, ",", i), ":") = 1) {
                            set parameterName = $piece($piece(method.FormalSpec, ",", i), ":", 1)
                            if (($find(parameterName, "*") = 1) || ($find(parameterName, "&") = 1)) {
                                set parameterName = $extract(parameterName, 2, *)
                            }
                            if $increment(Count),$increment(Count("WARN"))
                            set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Type not assigned for method parameter: "_parameterName, 0, method.Name, 0, 0))
                        }
                    }
                }
                //}
                set outStream = ""
                #; Creates a stream of the syntax coloring of the current method
                //if (IsEditsCheck && ($zversion(1) = 2)) {
                if ($zversion(1) = 2) {
                    set outStream = ##class(%Stream.TmpCharacter).%New()
                    set colorer = ##class(%SyntaxColor).%New()
                    if (method.Language = "") {
                        set lang = $$$langObjectScript
                    } else {
                        set lang = method.Language
                    }
                    set flags = "PFCE"
                    set ret = colorer.Color(method.Implementation, .outStream, lang, flags,,, .langs, .coloringErrors)
                    if ('ret) {
                        return $$$ERROR($$$GeneralError, "Fatal error with syntax coloring: "_colorer.DLLResultCode)
                    }
                    #; Checks if there is any syntax error in the method
                    if (coloringErrors) {
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Syntax error(s) found during syntax coloring of method", 0, method.Name, 0, 0))
                    }
                    do outStream.Rewind()
                }
                set colorSyntaxStream = ""
                #; Run through each line and check for possible issues or standards deviations.
                set labelLine = 0
                do method.Implementation.Rewind()
                for  {
                    kill len
                    set lineText = method.Implementation.ReadLine(.len)
                    if len = -1  quit  //
                    #; Creates a stream of the syntax coloring of each line to allow for more checks of possible issues
                    //if (IsEditsCheck && $isobject(outStream)) {
                    if ($isobject(outStream)) {
                        set colorSyntaxStream = ##class(%Stream.TmpCharacter).%New()
                        set colorSyntaxLine = ""
                        while (colorSyntaxLine '= "\n") {
                            set colorSyntaxLine = outStream.ReadLine()
                            set sc = colorSyntaxStream.WriteLine(colorSyntaxLine)
                            if ($$$ISERR(sc)) return sc
                        }
                    }
                    do ..CheckCode(InternalName, method.Name, method.Language, lineText, .Count, .documentLine, .labelLine, .ListOfAlerts, colorSyntaxStream, IsEditsCheck)
                }
                if IsEditsCheck {
                    #; Check if method has more than defined max number of lines
                    if (labelLine > ..#MAXMETHODLINES) {
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Method has more than "_..#MAXMETHODLINES_" lines of code", 0, method.Name, 0, 0))
                    }
                }
            }
            #; Check class properties.
            #; Iterate the properties from the class.
            #dim property as %Dictionary.PropertyDefinition
            set propertyKey = ""
            for  {
                set property = classDef.Properties.GetNext(.propertyKey)
                if propertyKey = "" quit  //
                
                #; Ignore line if there is a suppress alerts command.
                if $$$SuppressAlerts(property.Description) continue
            }
            #; Check class queries.
            #; Iterate the queries from the class.
            #dim query as %Dictionary.QueryDefinition
            set queryKey = ""
            for  {
                set query = classDef.Queries.GetNext(.queryKey)
                if queryKey = "" quit  //
                
                #; Queries used from the VB should be marked as SqlProc.
                if query.Name["VB" {
                    if 'query.SqlProc {
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "CacheActiveX version 2009.1+ requires SqlProc = 1", 0, query.Name, 0, 0))
                    }
                }
            }
        } else {
            quit sc
        }
    } elseif type = "routine" {
        #; Open the routine definition.
        set routineDef = ##class(%RoutineMgr).%OpenId(InternalName)
        #; Check for basic code.
        set language = $case(routineDef.LanguageModeGet(),9:"basic",:$$$langObjectScript)
        set label=""
        
        if $isobject(routineDef) {
            #; Run through each line and check for possible issues or standards deviations.
            if (BackupFile = "") {
                set routineStream = routineDef.Code
            } else {
                set routineStream = ##class(%Stream.FileCharacter).%New()
                set sc = routineStream.LinkToFile(BackupFile)
                if ($$$ISERR(sc)) quit sc
            }
            for  {
                kill len
                set lineText = routineStream.ReadLine(.len)
                if len = -1  quit  //
                
                #; Check to see if this is a new line label.
                if $piece(lineText, $char(32)) '= "" {
                    set label = $piece(lineText, $char(32))
                    set labelLine = 0
                }
                do ..CheckCode(InternalName, label, language, lineText, .Count, .documentLine, .labelLine, .ListOfAlerts,, IsEditsCheck)
            }
            
        } else {
            quit $$$ERROR($$$GeneralError, "Unable to open routine")
        }
    } elseif type = "csp" || (type = "javascript") {
        if (BackupFile '= "") {
            set fileName = BackupFile
        } else {
            set fileName = $system.CSP.GetFileName(InternalName)
        }
        if '##class(%File).Exists(fileName) quit $$$FileNotFound
        set language = type
        
        #; Execute external javascript checker.
        if (type = "javascript") {
            set outputFileName = ##class(%File).TempFilename("jslint")
            set cmd = "cscript "_$system.Util.ManagerDirectory()_"wknck.jslint.js {eqeqeq:false,glovar:false,passfail:false,sub:true} <"_fileName_" //B //NoLogo > "_outputFileName
            set exitStatus = $zf(-1, cmd)
            
            set outputFile = ##class(%File).%New(outputFileName)
            set status = outputFile.Open("R")
            if $$$ISOK(status) {
                #; Run through each line and add the text to the output window
                for  {
                    kill len
                    set lineText = outputFile.ReadLine(.len)
                    if len = -1  quit  //
                    
                    #; Lint at line 8 character 5: Missing 'new' prefix when invoking a constructor.
                    if lineText?1"Lint at line ".N1" character ".N1":".E {
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", $piece(lineText, ":", 2), 0, 0, 0, $piece(lineText, " ", 4)))
                    } elseif $zstrip(lineText, "<W") '="" {
                        set currentAlert = $list(ListOfAlerts, Count)
                        set $list(currentAlert, 3) = lineText
                    }
                }
                do outputFile.Close()
                kill outputFile
                
                do ##class(%File).Delete(outputFileName)
            } else {
                quit $$$ERROR($$$GeneralError, "Unable to open JSLint output")
            }
        }
        
        #; Open the file.
        set file = ##class(%File).%New(fileName)
        set status = file.Open("R")
        
        if $$$ISOK(status) {
            #; Run through each line and check for possible issues or standards deviations.
            for  {
                kill len
                set lineText = file.ReadLine(.len)
                if len = -1  quit  //
                
                set lineText=$piece(lineText,"//",1)
                
                do ..CheckCode(InternalName, "", language, lineText, .Count, .documentLine,, .ListOfAlerts,, IsEditsCheck)
            }
            
        } else {
            quit $$$ERROR($$$GeneralError, "Unable to open file")
        }
    }
    
    
    quit $$$OK
}

/// Parse a block of code looking for potential improvements.
Method CheckCode(Document As %String, Label As %String = "", Language As %String, Code As %String, ByRef Count As %Integer, ByRef DocumentLine As %Integer, ByRef LabelLine As %Integer = 0, ByRef ListOfAlerts As %String, ColorSyntaxStream As %Stream.TmpCharacter = "", IsEditsCheck As %Boolean = 0) As %Status
{
    #define SuppressAlerts(%line) %line?.E1P1"noalert".E
    
    set status = $$$OK
    if Language = "" set Language = $$$langObjectScript
    #; Iterate each line in the given code.
    for line = 1:1:$length(Code, $char(13,10)) {
        set showLine = 0
        set msgText = ""
        
        #; Increment the line counts for the current document and method/line label.
        set DocumentLine = DocumentLine + 1
        set LabelLine = LabelLine + 1
        
        #; Get the code for the line.
        set lineText = $piece(Code, $char(13,10), line)
        
        #; Convert to lower case for comparison.
        set lineTextLower = $zconvert(lineText,"L")
        
        #; Ignore line if there is a suppress alerts command.
        if $$$SuppressAlerts(lineTextLower) continue
        
        #; Extremely long lines of code should be reviewed and broken up.
        if $length(lineText) > ..#MAXLINELENGTH {
            set showLine = 1
            if $increment(Count),$increment(Count("WARN"))
            set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Line exceeds "_..#MAXLINELENGTH_" characters", lineText, Label, LabelLine, DocumentLine))
        }
        
        if Language=$$$langObjectScript {
            #; Check for any patterns that indicate direct global sets are being used.
            for globalSet = "s ^", "set ^", "m ^", "merge ^" {
                ##;noalert
                if lineTextLower[globalSet {
                    for instance = 2:1:$length(lineTextLower, globalSet) {
                        #; Get the name of the global being set.
                        set global = $zstrip($piece($piece($piece(lineTextLower, globalSet, instance),"("),"="), ">W")
                        
                        #; Check that the global is not an exception.
                        #; Note: the global name has already been converted to lower case.
                        if global'="", $extract(global,1,2)'="||", '$data(..AlertGlobalExceptions(global)) {
                            set showLine = 1
                            if $increment(Count),$increment(Count("WARN"))
                            set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Use objects or SQL to update data", lineText, Label, LabelLine, DocumentLine))
                        }
                    }
                }
            }
            #; check for variable length>31
            #; but methods can be upto 180
            #; Exclude macros, as they can be up to 500 chars: https://docs.intersystems.com/irisforhealth20201/csp/docbook/Doc.View.cls?KEY=GCOS_macros
            try {
                #; See explanation and tests: https://regex101.com/r/W2XZYp/2
                set regexExpr="(?m)(?<!\#define|\#def1arg)[^a-zA-Z0-9\$]([a-zA-Z]{1}[a-zA-Z0-9]{31,})([^a-zA-Z0-9]|$)"
                set matcher=##class(%Regex.Matcher).%New(regexExpr, lineTextLower)
                if ($isobject(matcher) && matcher.Locate()) {
                    set lineVariableName=matcher.Group(1)
                    set isMethod=((matcher.GroupCount = 2) && (matcher.Group(2)="("))
                    if ('isMethod || ($length(lineVariableName) > 180)) {
                        set showLine = 1
                        if $increment(Count),$increment(Count("WARN"))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Local variable names are limited to 31 characters, method names are limited to 180 characters", lineText, Label, LabelLine, DocumentLine))
                    }
                }
            } catch(ex) {
                #; Ignore regex errors
            }
            //if IsEditsCheck {
            #; Check for process private globals naming convention when setting variable
            if (lineTextLower?.E1(1"s ",1"set ")1"^||tmp".E) {
                set pattern = ".E1""^||tmp(""."" ""1"""""""_$$$lcase($piece(Document, ".", 1, *-1))_"""""""."" ""1"",""."" ""1"""""""_$$$lcase(Label)_""""""".E"
                if (lineTextLower'?@pattern) {
                    if $increment(Count),$increment(Count("WARN"))
                    set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Names of process private globals should have format: ^||TMP(""class/routine name"",""method/query name"",""someFunctionality"")", lineText, Label, LabelLine, DocumentLine)) //noalert
                }
            }
            #; Checks using syntax color.
            #; Using conditions filetype "class" and language "objectscript" because all current checks with syntax color
            #; only relevant to this filetype/language. These conditions not required for more general checks.
            if ((..FileType(Document) = "class") && ($isobject(ColorSyntaxStream))) {
                set commandCount = 0
                set previousCommand = ""
                set multipleCommandAlertThrown = 0
                set afterCommand = 0
                do ColorSyntaxStream.Rewind()
                while 'ColorSyntaxStream.AtEnd {
                    #; There is a line in the ColorSyntaxStream with comma delimited components for each syntax element.
                    #; The first componenent is language name, the second component is terminal index, the third component
                    #; is the source code fragment and can contain commas, see %Library.SyntaxColor documentation and
                    #; Studio.Extension.CodeTidy for more information/reference
                    set lineElement = ColorSyntaxStream.ReadLine()
                    set elementLanguage = $piece(lineElement, ",", 1)
                    set elementType = $piece(lineElement, ",", 2)
                    set elementContent = $piece(lineElement, ",", 3, *)
                    
                    if elementLanguage = "COS" {
                        #; check if line element is a COS command
                        if elementType = 20 {
                            set commandCount = commandCount + 1
                            #; Check for multiple commands per line with exception of single command following if statement
                            if (((commandCount = 2) && (previousCommand '= "if")) || (commandCount > 2)) {
                                #; Will not throw alert multiple times on same line
                                if 'multipleCommandAlertThrown {
                                    if $increment(Count),$increment(Count("WARN"))
                                    set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Write only one statement per line (except one simple command following simple if statement", lineText, Label, LabelLine, DocumentLine))
                                    set multipleCommandAlertThrown = 1
                                }
                            }
                            set previousCommand = elementContent
                            set afterCommand = 1
                        }
                        #; check if post conditions are being used
                        elseif (elementType = "D") {
                            #; Checks if post conditions are being used, exception is use of quit:condition
                            if ((elementContent = ":") && (afterCommand) && (previousCommand '= "quit")) {
                                if $increment(Count),$increment(Count("WARN"))
                                set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild("WARN", "Use if statements in preference to post conditions to aid readability", lineText, Label, LabelLine, DocumentLine))
                            }
                            set afterCommand = 0
                        } else {
                            set afterCommand = 0
                        }
                    }
                }
            }
            //}
        }
        
        #; Check for custom markers
        for category = "generic", Language {
            if category '= "" {
                set index = ""
                for  {
                    set index = $order(..AlertPatterns(category, index))
                    if index = "" quit
                    /*if 'IsEditsCheck {
                    if ($list(..AlertPatterns(category, index), *) = "forEditsCheck") {
                    continue
                    }
                    }*/
                    
                    if lineTextLower?@$list(..AlertPatterns(category, index)) {
                        set showLine = 1
                        if $increment(Count),$increment(Count($list(..AlertPatterns(category, index),2)))
                        set ListOfAlerts = $listupdate(ListOfAlerts, Count, $listbuild($list(..AlertPatterns(category, index),2),$list(..AlertPatterns(category, index),3), lineText, Label, LabelLine, DocumentLine))
                    }
                }
            }
        }
        
    }
    quit status
}

/// This function will search the saved code of the current document for lines that set globals beginning with the
/// letter Z.  This check only identifies lines that it thinks should be deleted.  It is a conservative search that
/// ignores the line if it begins will any logic other than a set or merge statement.
/// <p>The globals excluded from the check are:<ul>
/// <li>^ZPATCH
/// <li>^ZUPGRADE
/// <li>^ZBUILD
/// <li>^ZDATETR
/// <li>^ZSSC
/// </ul>
ClassMethod FindTraps(InternalName As %String) As %Status
{
    write !!,"Searching for traps"
    set sc = ##class(pkg.isc.codetidy.Parse).ParseDocument(InternalName, 0, .output)
    write !,"Found "_+$get(output(".trapCount"))_" occurrence/s", !!
    quit $get(sc)
}

/// This function will parse the saved code of the current document.  It will identify and update some patterns of code
/// that are sub-optimal.
/// <p>The list of patterns that are updated are:<ul>
/// <li>%request.Get(<i>var</i>) 
/// <li>%session.Get(<i>var</i>)
/// <li>rs.GetDataByName(<i>var</i>)
/// <li>rs.Get(<i>var</i>)
/// <li>cursor:hand
/// <li>d <i>obj</i>.%Close()
/// </ul><p>In addition to these patterns it will delete any traps identified by <method>FindTraps</method>.
ClassMethod TweakDocument(InternalName As %String) As %Status
{
    write !!,"Applying automated tweaks"
    set sc = ##class(pkg.isc.codetidy.Parse).ParseDocument(InternalName, 1, .output)
    write !,"Found "_+$get(output(".trapCount"))_" occurrence/s", !!
    quit $get(sc)
}

/// helper function to determine project item type
ClassMethod FileType(InternalName As %String) As %String
{
    if $zconvert(InternalName,"U")[".CLS" quit "class"
    if $zconvert(InternalName,"U")[".CSP" quit "csp"
    if $zconvert(InternalName,"U")[".CSR" quit "csp"
    if $zconvert(InternalName,"U")[".PRJ" quit "project"
    if $zconvert(InternalName,"U")[".INC" quit "routine"
    if $zconvert(InternalName,"U")[".INT" quit ""
    if $zconvert(InternalName,"U")[".MAC" quit "routine"
    if $zconvert(InternalName,"U")[".BAS" quit "routine"
    if $zconvert(InternalName,"U")[".JS"  quit "javascript"
    if $zconvert(InternalName,"U")[".CSS"  quit "javascript"
    quit "other"
}

/// helper function to automatically lint custom javascript. 
/// Uses the ESLint and its configuration installed in installDirectory/devuser
/// which is installed when SetupExtension is run from the Utils class (also run every CCR Refresh)
ClassMethod ESLint(InternalName As %String = "") As %Status
{
    write "Running ESLint on ", InternalName
    set eslintJS = ##class(pkg.isc.codetidy.Utils).GetESLintFile()
    set eslintConfig = ##class(pkg.isc.codetidy.Utils).GetESLintConfig()
    
    // run the following command:
    // node (path to eslint.js file) --fix -c (path to eslint config) (path to csp file)
    set outFile = ##class(%File).TempFilename("out")
    set errFile = ##class(%File).TempFilename("err")
    set args = 5
    set args(1) = eslintJS
    set args(2) = "--fix"
    set args(3) = "-c"
    set args(4) = ##class(pkg.isc.codetidy.Utils).GetESLintConfig()
    set args(5) = $system.CSP.GetFileName(InternalName)
    set result = $zf(-100, "/SHELL /STDOUT="_outFile_" /STDERR="_errFile, "node", .args)
    
    // output any errors
    set errStream = ##class(%FileCharacterStream).%New()
    set errStream.Filename = errFile
    if errStream.Size > 0 {
        do errStream.Rewind()
        while 'errStream.AtEnd {
            write !, errStream.ReadLine()
        }
    }
    
    // output the response from ESLint
    set outStream = ##class(%FileCharacterStream).%New()
    set outStream.Filename = outFile
    if outStream.Size > 0 {
        do outStream.Rewind()
        while 'outStream.AtEnd {
            write !, outStream.ReadLine()
        }
    }
    
    quit $$$OK
}

/// This is called when the user performs an action that may need to interact with
/// the server, such as selecting a menu or adding a new document. This encompases what the deprecated Flags
/// parameter did and allows additional flexibility.<p>
/// The Type argument values are:<ul>
/// <li>0 : Server defined menu item selected</li>
/// <li>1 : Other Studio action</li></ul>
/// When a menu item is selected the Name argument is the name of this menu item in the format
/// '&lt;MainMenu&gt;,&lt;SubMenu&gt;'. For other Studio actions the Name argument is one of:<ul>
/// <li>0 : User has tried to change a document that is locked in source control</li>
/// <li>1 : User has created a new document</li>
/// <li>2 : User has deleted a document</li>
/// <li>3 : User has opened a document</li>
/// <li>4 : User has closed a document</li></ul>
/// The InternalName argument is the name of the document about which this action occurs.
/// If there is any selected text in the document which has focus this is sent in the SelectedText
/// argument.
/// The Action argument is set by this method to tell Studio what to do. Possible return
/// values for this are:<ul>
/// <li>0 : Do nothing, note that this method can still perform some action such as check
/// an item out of source control, but Studio will not ask for user input.</li>
/// <li>1 : Display the default Studio dialog with a yes/no/cancel button.
/// The text for this dialog is provided in the 'Target' return argument.</li>
/// <li>2 - Run a CSP page/Template. The Target is the full url to the CSP page/Template, as usual the page will be
/// passed the current document name, any selected text, the project name, the namespace.</li>
/// <li>3 - Run an EXE on the client. The Target is the name of an executable file on the client machine.
/// It is the responsibility of the customer to ensure this EXE is installed in a suitable location.</li>
/// <li>4 - Insert the text in Target in the current document at the current selection point</li>
/// <li>5 - Studio will open the documents listed in Target, if there are multiple documents to open they
/// will be separated with commas. If the document name is 'test.mac:label+10' it will open the document
/// 'test.mac' and goto 'label+10'.</li>
/// <li>6 - Display an alert dialog in Studio with the text from the Target variable</li>
/// <li>7 - Display a dialog with a textbox and Yes/No/Cancel buttons. The text for this dialog is
/// provided by the 'Target' return argument. The initial text for the textbox is provided by the
/// 'Msg' return argument.</li></ul>
/// If the <var>Reload</var> argument is set to true then the current document will be reloaded in Studio,
/// this is useful if you change the document to change its attribute so Studio will pick up these changes.
Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status
{
    set Action=0, Target="", Reload=0
    set sc = $$$OK
    if Name = "CodeTidy,Run" {
        set sc = ##class(pkg.isc.codetidy.Utils).Run(InternalName)
        set Reload = 1
    } elseif Name = "CodeTidy,RunSourceControl" {
        set sc = ##class(pkg.isc.codetidy.Utils).RunAll(1)
    } elseif Name = "CodeTidy,RunAll" {
        set sc = ##class(pkg.isc.codetidy.Utils).RunAll(0)
    }
    quit sc
}

/// This is called for every menu item returned to Studio to allow the menu to be enabled/disabled without
/// having to write a custom query for <query>MenuItems</query>. The <var>DisplayName</var> of this menu is
/// also passed by reference and this may be modified to change the appearance of this menu item. The <var>MenuName</var>
/// is the main menu name then the submenu name separated by a ','.
Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
    set DisplayName = ""
    set Enabled = 1
    
    if MenuName = "CodeTidy" {
        set DisplayName = "&CodeTidy"
    } elseif MenuName = "CodeTidy,Run" {
        set DisplayName = "&Run"
    } elseif MenuName = "CodeTidy,RunSourceControl" {
        set DisplayName = "&Run on files in source control"
    } elseif MenuName = "CodeTidy,RunAll" {
        set DisplayName = "&Run on all files in namespace"
    }
    quit $$$OK
}

/// Always enabled.
/// Previously only enabled on Windows
ClassMethod GetCodeTidyEnabled(InternalName As %String) As %Boolean
{
    
    //for now always enable
    quit 1
}

/// This is called after the item has been saved to the database.
/// It may be passed a reference to the object representing the item
/// just saved. It can be use to export this documement to an external form for example.
Method OnAfterSave(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
    if ##class(pkg.isc.codetidy.Utils).GetFormatOnSave() {
        do ##class(pkg.isc.codetidy.Utils).Run(InternalName)
    }
    quit $$$OK
}

}
