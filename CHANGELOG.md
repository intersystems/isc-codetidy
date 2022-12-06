# isc.codetidy

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

