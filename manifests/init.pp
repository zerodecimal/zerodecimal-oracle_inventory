# oracle_inventory
#
# This module manages the Oracle central inventory pointer, and provides facts from the inventory.
#
# @summary Provides facts from central inventory interrogation.
#
# @param manage_pointer
#   Whether or not to manage the inventory pointer file
#
# @param ensure
#   Should the pointer file exist
#
# @param file_owner
#   Pointer file owner
#
# @param file_group
#   Pointer file group
#
# @param file_mode
#   Pointer file permissions
#
# @param pointer_file
#   Full path to the pointer file
#
# @param inventory_dir
#   Directory for the inventory_loc entry in the pointer file
#
# @param inst_group
#   Value for the inst_group entry in the pointer file
#
# @example
#   include ::oracle_inventory
class oracle_inventory (
  Boolean                    $manage_pointer = true,
  Enum['present', 'absent']  $ensure         = 'present',
  String                     $file_owner     = 'root',
  String                     $file_group     = 'root',
  Stdlib::Filemode           $file_mode      = '0644',
  Optional[Stdlib::UnixPath] $pointer_file   = $::facts[oracle_inventory_pointer],
  Stdlib::UnixPath           $inventory_dir  = '/u01/app/oraInventory',
  String                     $inst_group     = 'oinstall',
) {
  ## Take care of Ruby GEM dependency for fact script
  ensure_packages(['xml-simple'], {
    ensure   => installed,
    provider => puppet_gem
  })

  ## Manage the inventory pointer file if not on Windows
  if $manage_pointer and $facts['kernel'] != 'windows' {
    include ::oracle_inventory::inventory_pointer
  }
}
