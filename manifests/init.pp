# oracle_inventory
#
# This module manages the Oracle central inventory pointer, and provides facts from the inventory.
#
# @summary Provides facts from central inventory interrogation.
#
# @example
#   include oracle_inventory
class oracle_inventory (
  Enum[
    'present',
    'absent'
  ]                $ensure        = 'present',
  Stdlib::UnixPath $inventory_dir = '/u01/app/oraInventory',
  String           $inst_group    = 'oinstall',
){

  ## Manage the inventory pointer file if not on Windows
  if $::kernel != 'windows' {
    include ::oracle_inventory::inventory_loc
  }

}
