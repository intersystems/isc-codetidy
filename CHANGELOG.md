# isc.codetidy

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.8] - 2024-08-23

### Fixed
-Fixed auto indent of comments inside dynamic arrays removing white space (#50)
-Fixed conversion of #; comments at start of line in routines causing syntax error (#55)
-Fixed resequencing of Projections and XDatas to give assigned positions (#54)

## [1.1.7] - 2024-08-20

### Fixed
- Add Foreign Keys to class items to resequence (#51)
- Prevented auto-indentation of embedded Python lines until Python linting is implemented (#52)

## [1.1.6] - 2024-07-29

### Fixed
- Fixed .js files in other namespaces' /itemsetsourcelink web app being editing during ##class(pkg.isc.codetidy.Utils).RunAll (#45)
- Fixed .js files being re-exported without edit during ##class(pkg.isc.codetidy.Utils).RunAll() even though ESLint is disabled so no reason to export (#44)

## [1.1.5] - 2023-02-23

### Fixed
- Fixed insertion of new line even though JSON array was empty
- Fixed JSON Linting being applied to JSON arrays within arguments of a macro

## [1.1.4] - 2023-02-07

### Fixed
- Fixed incorrect conversion of ##; comments to #; comments
- Fixed incorrect conversion of ;; comments to ; ; comments

### Added
- Added unit tests for "usemacrocomments" and "capital" configuration options

## [1.1.3] - 2023-01-31

### Fixed
- Fixed `<UNDEFINED>` error parsing empty method implementation
- Fixed indentation of JSON arrays that have mappings to different dimension JSON arrays
- Fixed outer indentation of subroutines within routines
- Fixed CodeTidy indenting line labels in methods and routines
- Fixed CodeTidy not exiting indentation rules of some arrays and block comments

## [1.1.2] - 2023-01-18

### Fixed
- JSON linting and bracket matching now working
- Fixed preserving indentation of embedded HTML and block comments
- Fixed parsing of custom markers for embedded block open/close brackets
- Removed expansion of "&js<" to "&javascript" and fixed parsing of "&js<"
- Fixed indentation inconsistencies when user inputs mix of spaces and tabs

## [1.1.1] - 2022-12-06

### Fixed
- Fixed another `<UNDEFINED>` error parsing triggers

## [1.1.0] - 2022-12-06

### Added 
- Automatic tweaks have been reintroduced (after being removed due to breaking issues)
- Pulled in a variety of minor changes from internal development

### Fixed
- Bracket matching for automatic tweaks now works
- Configuration method doesn't prompt for an indentation string if automatic indentation is disabled
- Unit tests described in module.xml
- Added unit tests!
- module.xml works with latest package manager version(s) and git-source-control - for some reason, Directory is needed. (This smells like a package manager bug, but the change is backward-compatible.)
- Fixed `<UNDEFINED>` error parsing triggers
- Fixed SQL plan options for earlier IRIS version without $System.SQL.Explain (#25)

## [1.0.3] - 2022-07-19
### Fixed
- #21: Fixes an issue on older IRIS versions in which embedded SQL would cause CodeTidy extension code to run in other namespaces

## [1.0.2] - 2022-06-23
### Fixed
- #13: ##class(pkg.isc.codetidy.Utils).Configure() defaults to current settings

## [1.0.1] - 2022-06-23
### Fixed
- Fixes an issue where AutoTweak removed method implementations (!)

## [1.0.0] - 2022-06-21
- First released version

