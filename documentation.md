# User Documentation

## Installation

1. ZPM (latest release)

```
zpm "install isc-codetidy"
```

2. Clone `main` (latest, as yet unreleased version)

```
git clone https://github.com/intersystems/isc-codetidy.git
zpm "load <absolute path to repository root>"
```

## Setup

1. CodeTidy needs to configured to work alongside your source control to ensure consistency between the server and file-system. To do this, run:

```
do ##class(pkg.isc.codetidy.Utils).SetupExtension()
```

2. Configure Settings for CodeTidy. To do this, run:

```
do ##class(pkg.isc.codetidy.Utils).Configure()
```

This method will let you customize CodeTidy according to your requirements. The section below discusses the available customizations.

## Configuration Options

1.  **When to format:** You can choose whether to automatically format a file when it is saved. If you choose not to do this, you can always manually run CodeTidy on a file. We recommend switching on automatic formatting for most use-cases.
2.  **Resequencing:** You can choose whether you want CodeTidy to change the order in which parameters, methods etc. occur in the source file. Note that this option is only applicable to classes. If you choose to enable this option, items will be resequenced as follows:

    1. `SrcVer` will always be at the top
    2. Special Parameters:
       1. `SQL*` Parameters
       2. `SQLDATE`
       3. Parameters with names in upper case (e.g. `Parameter EXAMPLEPARAM = 1`)
    3. Parameters and Properties
    4. Indices
    5. Methods and Queries
    6. Triggers
    7. Everything else

    Resequencing the document ensures consistency and improves readability.

3.  **Fix indentation:** You can choose whether to fix the indentation for classes, routines, and JavaScript files.
4.  **Pick indentation character:** You can choose to use tabs or spaces for indenting your code. If you want to use spaces, enter the number of spaces you'd like to indent with. Type "TAB" if you want to use tabs instead. This will convert the indentation the desired format across the file.
5.  **Common issues/inefficiencies:** If you enable this option, CodeTidy will warn you if there are direct references to globals in your code.
6.  **Consistent case:** When this is enabled, CodeTidy will change the case of all the commands, functions and variables to be the select character case. You can choose between making everything lower-case (this will affect all variables) and Pascal case(this will only affect system variables). It works for classes, routines and CSP files only.
7.  **Macro comments:** You can pick this option if you don't want any of your comments to make their way into the compiled code, reducing the amount of storage needed for the program. If enabled, all comments will be converted to macro-comments.
8.  **ESLint:** You can enable this if you want to use ESLint to lint your JavaScript files.
9.  **Exclude files:** You can specify the classes or packages that you never want to run CodeTidy on. Make sure to include the ".CLS" for classes at the end. Do **not** include ".PKG" for packages.
10. **% classes to be formatted:** If you want some "%" classes to be formatted, you can add them here.
11. **Ignored globals:** If you don't want to receive alerts about the usage of specific globals, you can add them here.
