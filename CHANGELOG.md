# Changelog

All notable changes to this project will be documented in this file.

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
