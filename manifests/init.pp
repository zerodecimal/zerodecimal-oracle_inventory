# oracle_inventory
#
# This module manages the Oracle central inventory pointer, and provides facts from the inventory.
#
# @summary Provides facts from central inventory interrogation.
#
# @example
#   include oracle_inventory
class oracle_inventory (
  Boolean                    $manage_pointer = true,
  Enum[
    'present',
    'absent'
  ]                          $ensure         = 'present',
  String                     $file_owner     = 'root',
  String                     $file_group     = 'root',
  Stdlib::Filemode           $file_mode      = '0644',
  Optional[Stdlib::UnixPath] $pointer_file   = $::facts[oracle_inventory_pointer],
  Stdlib::UnixPath           $inventory_dir  = '/u01/app/oraInventory',
  String                     $inst_group     = 'oinstall',
){

  ## Take care of Ruby GEM dependency for fact script
  ensure_packages(['xml-simple'], {'ensure' => 'present', 'provider' => 'puppet_gem'})

  ## Manage the inventory pointer file if not on Windows
  if $manage_pointer and $::kernel != 'windows' {
    include ::oracle_inventory::inventory_pointer
  }

}
