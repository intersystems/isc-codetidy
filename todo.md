# De-Trakifying CodeTidy

- Anywhere we see "TrakCare" (or TrakCareCare) e.g. in code, kill it
- Strip IST from class names
- `Assistant`:
  - Hard-coded global exceptions in `BuildAlertGlobalExceptions`
  - Any reference to `websys`
  - `tkmakeservercall`
  - `InternalName["/system/"` in `CheckDocument` (generally, any reference to `/system/`)
  - Hard-coded `^Z` global list (in `FindTraps`)
  - `GetAssociatedClass`/`GetAssociatedClassEx`/`GetAssociatedClassExEnabled`
- `Parse`:
  - `ParseTrak` - rename!?
  - `ParseClasses` - instead use class exclusion list and ALWAYS exclude mapped items
    - Check with: `##class(%Library.RoutineMgr).IsMapped("Foo.Bar.CLS")`
  - `ParseRoutines` - same story
  - `ParseApp` - need to think about this more carefully, should either do all web apps for the namespace or expect a web app as input, let's not look at `^websys.ConfigurationD`. (find callers + update appropriately)
- `SourceGen`:
  - Remove `GenerateXMLAdaptor`, `GenerateWebMessage\*`, `CompileWebMessage`, `SetDoctorReportsAccessCtrl`, `GenerateSrcVer`, `AddSrcVerToRoutine`, `AddSrcVerToJavaScript`, `SetWebMessageStorage`, `AddParamsToCSP`, `SetSqlColumnNumber` - in short, everything except `Resequence`
