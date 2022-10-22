# Changelog

All notable changes to this project will be documented in this file.

## Release 0.6.6

- Added a default value for oracle_base

## Release 0.6.5

- Added oracle_base to oracle_crs_home and oracle_db_home

## Release 0.6.4

- Updated documentation

>**BREAKING CHANGE:**

- Updated OS compatibility list

## Release 0.6.3

- Bugfix: Prevent oracle_rac_nodes from being defined if empty

## Release 0.6.2

- Added owner to oracle_crs_home
- Changed the source file for oracle_rac_nodes

## Release 0.6.1

- Added OPatch version to oracle_crs_home and oracle_db_home

## Release 0.6.0

>**BREAKING CHANGE:**

- This module now requires stdlib >= 8.0.0 due to changes in ensure_packages function parameters

## Release 0.5.6

- Additional pattern match for WebLogic home

## Release 0.5.5

- Updated to PDK v1.18.1

## Release 0.5.4

- Updated module dependency

## Release 0.5.3

- Updated to PDK v1.15.0

## Release 0.5.2

- Added support for 32 bit program files on 64 bit Windows

## Release 0.5.1

- Added check for Endeca home (oracle_endeca_home fact)

## Release 0.5.0

- Added protection from missing XML tags
- Updated to PDK v1.5.0
- Updated module documentation

## Release 0.4.9

- Updated the PDK template to version 1.4.1

## Release 0.4.8

- Added documentation for oracle_scan_name fact
- Minor update to example script

## Release 0.4.7

- Feature: Added oracle_scan_name fact

## Release 0.4.6

- Documentation formatting changes

## Release 0.4.5

- Travis CI configuration changes

## Release 0.4.4

- Formatting, documentation, and unit test updates

## Release 0.4.3

- Bugfix: Fixed Windows bug with nil oratab_file variable

## Release 0.4.2

- Bugfix: Fixed Windows bug with oracle_inventory_pointer fact

## Release 0.4.1

- Bugfix: Updated oratab location for Unix servers

## Release 0.4.0

- Feature: Added ASM SID to oracle_crs_home fact
- No longer allowing facts to be created with empty string or array values

## Release 0.3.0

- Feature: Added oracle_inventory_pointer fact
- Added license and documentation

## Release 0.2.0

- Bugfix: Changed component lookup from EXT_NAME in first component listed, to standard component ID in NAME (first encounterd match)
- Bugfix: Added function to sort installed PSU list by inst_time, instead of just grabbing the last one in the list
- Feature: Added ensure_packages function to manage xml-simple dependency
- Feature: Standardized fact names to begin with "oracle_" in all cases
- Feature: Added oracle_inventory fact
- Feature: Added several class parameters

## Release 0.1.0

- Initial commit
