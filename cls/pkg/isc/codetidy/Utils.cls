Include %syPrompt

/// Utility and command-line APIs for configuring and using CodeTidy
Class pkg.isc.codetidy.Utils
{

Parameter FORMATONSAVEGLOBAL = "^Config(""CodeTidy"", ""formatonsave"")";

Parameter RESEQUENCEGLOBAL = "^Config(""CodeTidy"", ""resequence"")";

Parameter INDENTGLOBAL = "^Config(""CodeTidy"", ""indent"")";

Parameter INDENTSTRINGGLOBAL = "^Config(""CodeTidy"", ""indentString"")";

/// Global should evaluate to either "auto" or "warn" to indicate
/// whether the tweaks should be applied automatically or not.
Parameter ParseGLOBAL = "^Config(""CodeTidy"", ""tweak"")";

Parameter CODETIDYGLOBAL = "^Config(""CodeTidy"", ""codetidy"")";

Parameter USECAPITALSGLOBAL = "^Config(""CodeTidy"", ""capital"")";

Parameter COSCOMMENT = "^Config(""CodeTidy"", ""coscomment"")";

Parameter USEMACROCOMMENTSGLOBAL = "^Config(""CodeTidy"", ""usemacrocomments"")";

Parameter ADDSQLPLAN = "^Config(""CodeTidy"", ""sqlplan"")";

Parameter SQLCASE = "^Config(""CodeTidy"", ""sqlcase"")";

Parameter BRACEPOSITION = "^Config(""CodeTidy"", ""brace"")";

Parameter COSWHITESPACE = "^Config(""CodeTidy"", ""coswhitespace"")";

/// A list of packages and classes that should not be altered by CodeTidy.
Parameter DISABLEDFILESGLOBAL = "^Config(""CodeTidy"", ""disabledfiles"")";

/// A list of % classes that should be modified by CodeTidy.
/// % classes are not formatted by default. Should include the trailing .CLS
Parameter ENABLEDPERCENTGLOBAL = "^Config(""CodeTidy"", ""enabledpercent"")";

/// A list of globals that should not trigger any alerts when modifying.
Parameter ENABLEDGLOBALS = "^Config(""CodeTidy"", ""enabledglobals"")";

/// Whether or not to use eslint
Parameter ESLINTENABLEDGLOBAL = "^Config(""CodeTidy"", ""eslintenabled"")";

ClassMethod Run(pInternalName As %String, pOnlyIfInSourceControl As %Boolean = 0) As %Status
{
	set sc = $$$OK
	set saveOldValue = ..GetFormatOnSave()
	try {
		// Don't run classes mapped from another namespace
		if ##class(%RoutineMgr).IsMapped(pInternalName) {
			quit
		}

		// Make sure the source control object is created
		new %SourceControl
		do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		set sourceControl = %SourceControl
		new %SourceControl
		do ..SetFormatOnSave(0)
		
		set fileExtension = $zconvert($piece(pInternalName, ".", *), "l")
		// Run ESLint on js files
		if (fileExtension = "js") && ..GetESLintEnabled() {
			// exclude .min.js files and anything containing "jquery"
			set isMinJS = ($extract(pInternalName, $length(pInternalName) - 6, *) = ".min.js")
			if 'isMinJS {
				do ##class(pkg.isc.codetidy.Assistant).ESLint(pInternalName)
			}
		}
		// Run all formatting tools for classes and mac routines
		elseif (fileExtension = "cls") || (fileExtension = "mac") {
			// Determine if the class should be formatted
			set shouldNotFormat = 0
			// Check the whitelist for % classes
			if ($extract(pInternalName, 1) = "%") {
				set shouldNotFormat = ($listfind(..GetEnabledPercent(), pInternalName) '= 0)
			}
			// Check the blacklist for everything else
			else {
				set disabledList =..GetDisabledFiles()
				set pointer = 0
				while ($listnext(disabledList, pointer, filterName)) && (shouldNotFormat = 0) {
					if ($extract(pInternalName, 1, $length(filterName)) = filterName) {
						set sameLength = ($length(pInternalName) = $length(filterName))
						set shouldNotFormat = sameLength || ($extract(pInternalName, $length(filterName) + 1) = ".")
					}
				}
			}

			if shouldNotFormat {
				quit
			}
			
			// Attempt checkout if in source control
			$$$ThrowOnError(sourceControl.GetStatus(pInternalName, .inSourceControl))
			if inSourceControl {
				do sourceControl.AfterUserAction(1, 0, pInternalName, 1, "")
			} else {
				if pOnlyIfInSourceControl {
					quit
				}
			}
			
			write !, "Formatting "_pInternalName_"...", !
			if ..GetParse() = "auto" {
				do ##class(pkg.isc.codetidy.Assistant).TweakDocument(pInternalName)
			} elseif ..GetParse() = "warn" {
				do ##class(pkg.isc.codetidy.Assistant).FindTraps(pInternalName)
			}
			if ..GetResquence() {
				do ##class(pkg.isc.codetidy.SourceGen).ResequenceDocument(pInternalName)
			}
			if ..GetCodeTidy() {
				do ##class(pkg.isc.codetidy.CodeTidy).Document(pInternalName)
			}
			if ..GetIndent() {
				do ##class(pkg.isc.codetidy.Assistant).IndentDocument(pInternalName)
			}
			
			do sourceControl.GetSubExtension("pkg.isc.codetidy.Assistant").CheckDocument(pInternalName)
			
			write !, "Done formatting.", !
		}
		
		// Allow source control to export, etc.
		do sourceControl.OnAfterSave(pInternalName)
	} catch e {
		set sc = e.AsStatus()
	}
	do ..SetFormatOnSave(saveOldValue)
	quit sc
}

/// Runs CodeTidy on all of the files in source control in the current namespace.
ClassMethod RunAll(pOnlyIfInSourceControl As %Boolean = 1) As %Status
{
	set sc = $$$OK
	try {
		// Run all classes in source control
		set result = ##class(%Dictionary.ClassDefinition).SummaryFunc()
		write result.%SQLCODE
		while result.%Next() {
			set classname = result.Get("Name")_".CLS"
			$$$ThrowOnError(##class(pkg.isc.codetidy.Utils).Run(classname, pOnlyIfInSourceControl))
		}
		
		// Run all .mac routines
		set resultSet = ##class(%Library.ResultSet).%New("%RoutineMgr:StudioOpenDialog")
		$$$ThrowOnError(resultSet.Prepare())
		$$$ThrowOnError(resultSet.Execute("*.mac", 1, 1, 0, 1, 0, 0, ""))
		while resultSet.Next() {
			set name = resultSet.Data("Name")
			$$$ThrowOnError(##class(pkg.isc.codetidy.Utils).Run(name, pOnlyIfInSourceControl))
		}

		// Run all .js files
		// Build the spec for StudioOpenDialog
		set spec = ""
		set codeNamespace = $namespace
		set $namespace = "%SYS"
		set result = ##class(%SQL.Statement).%ExecDirect(,"select * from Security.Applications where NameSpace = ?", codeNamespace)
		while result.%Next() {
			// Exclude anything from the itemsetsourcelink web application
			if result.ID '= "/itemsetsourcelink" {
				set entry = $extract(result.ID, 2, *)_"/*.js"
				if spec = "" {
					set spec = entry
				} else {
					set spec = spec_","_entry
				}
			}
		}
		set $namespace = codeNamespace

		// Run StudioOpenDialog to get the .js files
		set resultSet = ##class(%Library.ResultSet).%New("%RoutineMgr:StudioOpenDialog")
		$$$ThrowOnError(resultSet.Prepare())
		$$$ThrowOnError(resultSet.Execute(spec, 1, 1, 0, 1, 0, 0, ""))
		while resultSet.Next() {
			set name = resultSet.Data("Name")
			$$$ThrowOnError(##class(pkg.isc.codetidy.Utils).Run(name, pOnlyIfInSourceControl))
		}
	} catch e {
		set sc = e.AsStatus()
		write !, $system.Status.DisplayError(sc), !
	}
	quit sc
}

/// Prompt the user for their preferred configuration options.
ClassMethod Configure() As %Status
{
	write !, "To access help (for formatting of settings, etc.) enter ?", !
	set result = ..GetFormatOnSave()
	set help = "Whether files should be formatted automatically when they are saved."
	do ##class(%Prompt).GetYesNo("Format on save?", .result, .help)
	set @..#FORMATONSAVEGLOBAL = result

	set result = ..GetResquence()
	set help = "Whether class members should be resequenced to follow the order: properties/parameters, indices, methods/queries, triggers."
	do ##class(%Prompt).GetYesNo("Resequence class members?", .result, .help)
	set @..#RESEQUENCEGLOBAL = result

	set result = ..GetIndent()
	set help = "Whether files should be automatically indented."
	do ##class(%Prompt).GetYesNo("Auto indent documents?", .result, .help)
	set @..#INDENTGLOBAL = result

	set result = ..GetIndentString()
	set result = $Case(result,$c(9):"TAB",:result)
	set help = "String to use for indentation."
	do ##class(%Prompt).GetString("String to use for indent (type TAB for tab, or some number of spaces)", .result, .help)
	set @..#INDENTSTRINGGLOBAL = $Case(result,"TAB":$c(9),:result)

	set result = $Case(..GetParse(),"":0,:1)
	set help = "Identify common coding inefficiencies and mistakes and help to fix them."
	do ##class(%Prompt).GetYesNo("Look for common mistakes/inefficiencies?", .result, .help)
	if result = 1 {
		set result = $Case(..GetParse(),"auto":1,:0)
		set help = "Whether or not to automatically apply the warnings from Parse."
		do ##class(%Prompt).GetYesNo("Fix such issues automatically?", .result, .help)
		if result = 1 {
			set @..#ParseGLOBAL = "auto"
		} else {
			set @..#ParseGLOBAL = "warn"
		}
	} else {
		set @..#ParseGLOBAL = ""
	}

	set result = ..GetCodeTidy()
	set help = "CodeTidy expands commands, functions, and variables as well as making capitilization the same throughout."
	do ##class(%Prompt).GetYesNo("Enforce consistent command/function/system variable case?", .result, .help)
	set @..#CODETIDYGLOBAL = result
	if result = 1 {
		set result = ..GetUseCapitals()
		set help = "Whether to use pascal case in commands, system functions, and system variables. If not chosen, will use lower case."
		do ##class(%Prompt).GetYesNo("Use pascal case commands, system functions, and system variables?", .result, .help)
		set @..#USECAPITALSGLOBAL = result
	}
	
	set result = ..GetCommentStyle()
	set help = "All comments in the code will be converted to the chosen style. Macro comments do not end up in the compiled code."
	do ##class(%Prompt).GetString("Which comment style should be used? Available options - ;, //, and #; (macro comment).", .result, .help)
	set @..#COSCOMMENT = result
	if ($piece(result, 1, 2) = ";#"){
		set @..#USEMACROCOMMENTSGLOBAL = 1
	} else {
		set @..#USEMACROCOMMENTSGLOBAL = 0
	}
	
	set result = ($number(..GetAddSQLPlan())+1)
	write !, "Add the execution plan for SQL statements as a comment following the statement?"
	set help = "Choose if/when an execution plan is added for SQL commands. Whilst using option 1 - Update, developers may insert a comment of ""-- ;"" and save the document to insert the execution plan. "
	set options = ""
	set options(1) = "Disabled"
	set options(2) = "Only insert execution plan when marked (Insert a comment of ""-- ;"" and save the document to insert the execution plan.)"
	set options(3) =  "Always insert execution plan"
	do ##class(%Prompt).GetMenu("Enter the corresponding number", .result, .options, .help, $$$InitialDisplayMask)
	set @..#ADDSQLPLAN = ""_($number(result)-1)

	set result = ..GetSQLCase()
	set result = $case(result, "U":2, "L":3, :1)
	write !, "Which case should SQL be converted to?"
	set help = "Choose which case SQL statements are converted to."
	set options = ""
	set options(1) = "Do not convert"
	set options(2) = "Uppercase"
	set options(3) = "Lowercase"
	do ##class(%Prompt).GetMenu("Enter the corresponding number", .result, .options, .help, $$$InitialDisplayMask)
	set @..#SQLCASE = $case(result, 2:"U", 3:"L", :"")

	set result = ..GetBracePosition()
	set help = "Adjust brace usage to end the line with opening brace and start new lines for closing brace."
	do ##class(%Prompt).GetYesNo("Modify positions of opening and closing braces to be consistent?", .result, .help)
	set @..#BRACEPOSITION = result

	set result = ..GetObjectScriptWhiteSpace()
	set help = "When this parameter is true, white space will be inserted either side of operators and after each argument."
	do ##class(%Prompt).GetYesNo("Add spaces before and after ObjectScript operators and arguments?", .result, .help)
	set @..#COSWHITESPACE = result
	
	set result = ..GetESLintEnabled()
	set help = "ESLint is an external javascript linter that can be run automatically on js files."
	do ##class(%Prompt).GetYesNo("Use ESLint?", .result, .help)
	set @..#ESLINTENABLEDGLOBAL = result
	
	do ..UpdateListGlobal(..#DISABLEDFILESGLOBAL, "Current disabled files:", "Enter Packages and classes to add to the list of excluded files:",
		".CLS extension should be included for classes and packages should not include a trailing ""."" Example class: pkg.isc.codetidy.Utils.CLS Example package: pkg.isc.codetidy")
	
	do ..UpdateListGlobal(..#ENABLEDPERCENTGLOBAL, "Current % classes enabled:", "Enter % classes that should be formatted by CodeTidy:",
		"Must enter with .CLS extension. Example: %Library.Persistent.CLS")
	
	do ..UpdateListGlobal(..#ENABLEDGLOBALS, "Current enabled globals:", "Enter globals that should not issue an alert:",
		"Enter global names without the preceding ^")
}

ClassMethod UpdateListGlobal(pGlobal As %String, pIntro As %String, pPrompt As %String, pHelp As %String)
{
	if $get(@pGlobal) '= "" {
		write !!, pIntro, !
		zwrite @pGlobal
	}
	set result = ""
	do ##class(%Prompt).GetString(pPrompt, .result,,,pHelp)
	while (result '= "") {
		set @pGlobal = $get(@pGlobal) _ $listbuild(result)
		write !
		zwrite @pGlobal
		set result = ""
		do ##class(%Prompt).GetString(pPrompt, .result,,,pHelp)
	}
}

/// Sets the pkg.isc.codetidy.Composite as the source control extension
/// with the current extension as the primary, and CodeTidy
/// as a subextension.
ClassMethod SetupExtension() As %Status
{
	set sc = $$$OK
	try {
		// Install ESLint if enabled
		if ..GetESLintEnabled() {
			$$$ThrowOnError(..InstallESLint())
		}

		set newSourceControlClass = "pkg.isc.codetidy.extension.Composite"
		set codeTidyExtension = "pkg.isc.codetidy.Assistant"
		
		// Get the name of the current extension
		set oldSourceControlClass = ##class(%Studio.SourceControl.Interface).SourceControlClassGet()
		
		// No op if the old source control class is already the composite extension
		if (oldSourceControlClass = newSourceControlClass) {
			quit
		}
		
		// Enable pkg.isc.codetidy.Composite
		$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlClassSet(newSourceControlClass, $namespace))
		
		// Set up primary and sub extensions
		do $classmethod(newSourceControlClass, "SetExtensionClasses", oldSourceControlClass, $listbuild(codeTidyExtension))
	} catch e {
		set sc = e.AsStatus()
	}
	quit sc
}

/// Installs ESLint (assumes npm is installed and on the path)
/// in installroot/devuser
ClassMethod InstallESLint() As %Status
{
	set sc = $$$OK
	try {
		set installDir = $system.Util.InstallDirectory()
		set eslintFolder = installDir_"devuser\CodeTidyESLint"

		set args = 1
		set args(1) = eslintFolder
		set result = $zf(-100, "/SHELL", "mkdir", .args)

		// run: npm install eslint --prefix devuser
		set args = 4
		set args(1) = "install"
		set args(2) = "eslint"
		set args(3) = "--prefix"
		set args(4) = eslintFolder
		set result = $zf(-100, "/ASYNC /SHELL", "npm", .args)
		// should return 0 since it is an async process
		if result '= 0 {
			write "got result: ", result, !
			Throw $$$ERROR($$$GeneralError, "Could not fork ESLint install process")
		}

		// setup the configuration file
		set configFileName = eslintFolder_"\.eslintrc.js"
		if '##class(%File).Exists(configFileName) {
			set configFile = ##class(%File).%New(configFileName)
			$$$ThrowOnError(configFile.Open("WSN"))
			set config = $listbuild(
				"module.exports = {",
				"	""env"": {",
				"		""browser"": true,",
				"		""es2020"": true",
				"	},",
				"	""extends"": ""eslint:recommended"",",
				"	""parserOptions"": {",
				"		""ecmaVersion"": 11",
				"	},",
				"	""rules"": {",
				"	}",
				"};"
			)
			set pointer = 0
			while $listnext(config, pointer, line) {
				do configFile.WriteLine(line)
			}
			do configFile.Close()
		}
	} catch e {
		set sc = e.AsStatus()
	}
	quit sc
}

/// Returns the value from the global if it exists.
/// Defaults to 1
ClassMethod GetFormatOnSave() As %Boolean
{
	if $data(@..#FORMATONSAVEGLOBAL) {
		quit @..#FORMATONSAVEGLOBAL
	}
	quit 1
}

/// Sets the format on save to pSave.
/// Used to temporarily not format on save
/// in the Run method.
ClassMethod SetFormatOnSave(pSave As %Boolean)
{
	set @..#FORMATONSAVEGLOBAL = pSave
}

/// Returns the value from the global if it exists.
/// Defaults to 0
ClassMethod GetResquence() As %Boolean
{
	if $data(@..#RESEQUENCEGLOBAL) {
		quit @..#RESEQUENCEGLOBAL
	}
	quit 0
}

/// Returns the value from the global if it exists.
/// Defaults to 1
ClassMethod GetIndent() As %Boolean
{
	if $data(@..#INDENTGLOBAL) {
		quit @..#INDENTGLOBAL
	}
	quit 1
}

/// Returns the value from the global if it exists.
/// Defaults to $c(9)
ClassMethod GetIndentString() As %String
{
	if $data(@..#INDENTSTRINGGLOBAL) {
		quit @..#INDENTSTRINGGLOBAL
	}
	quit $c(9)
}

/// Returns the value from the global if it exists.
/// Defaults to "auto"
ClassMethod GetParse() As %String
{
	if $data(@..#ParseGLOBAL) {
		quit @..#ParseGLOBAL
	}
	quit "auto"
}

/// Returns the value from the global if it exists.
/// Defaults to 1
ClassMethod GetCodeTidy() As %Boolean
{
	if $data(@..#CODETIDYGLOBAL) {
		quit @..#CODETIDYGLOBAL
	}
	quit 1
}

/// Returns the value from the global if it exists.
/// Defaults to "auto"
/// Returns the value from the global if it exists.
/// Defaults to 0
ClassMethod GetUseCapitals() As %Boolean
{
	if $data(@..#USECAPITALSGLOBAL) {
		quit @..#USECAPITALSGLOBAL
	}
	quit 0
}

ClassMethod GetCommentStyle() As %String
{
	if ($data(@..#COSCOMMENT)) {
		quit @..#COSCOMMENT
	}
	quit $case(..GetUseMacroComments(), 1:"#;", :"//")
}

/// Returns the value from the global if it exists.
/// Defaults to 0
ClassMethod GetUseMacroComments() As %Boolean
{
	if $data(@..#USEMACROCOMMENTSGLOBAL) {
		quit @..#USEMACROCOMMENTSGLOBAL
	}
	quit 0
}

ClassMethod GetAddSQLPlan() As %String
{
	if $data(@..#ADDSQLPLAN) {
		quit @..#ADDSQLPLAN
	}
	quit "0"
}

ClassMethod GetSQLCase() As %String
{
	if $data(@..#SQLCASE) {
		quit @..#SQLCASE
	}
	quit ""
}

ClassMethod GetBracePosition() As %Boolean
{
	if $data(@..#BRACEPOSITION) {
		quit @..#BRACEPOSITION
	}
	quit 1
}

ClassMethod GetObjectScriptWhiteSpace() As %Boolean
{
	if $data(@..#COSWHITESPACE) {
		quit @..#COSWHITESPACE
	}
	quit 1
}

/// Returns the value from the global if it exists.
/// Defaults to 0
ClassMethod GetESLintEnabled() As %Boolean
{
	if $data(@..#ESLINTENABLEDGLOBAL) {
		quit @..#ESLINTENABLEDGLOBAL
	}
	quit 0
}

ClassMethod GetDisabledFiles() As %List
{
	quit $get(@..#DISABLEDFILESGLOBAL)
}

ClassMethod GetEnabledPercent() As %List
{
	quit $get(@..#ENABLEDPERCENTGLOBAL)
}

ClassMethod GetEnabledGlobals() As %List
{
	quit $get(@..#ENABLEDGLOBALS)
}

ClassMethod GetESLintFile() As %String
{
	quit $system.Util.InstallDirectory()_"devuser\CodeTidyESLint\node_modules\eslint\bin\eslint.js"
}

ClassMethod GetESLintConfig() As %String
{
	quit $system.Util.InstallDirectory()_"devuser\CodeTidyESLint\.eslintrc.js"
}

}
