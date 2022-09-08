# oracle_inventory::inventory_pointer
#
# This class manages the Oracle central inventory location pointer.
#
# @summary Manages the Oracle central inventory location pointer.
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
#   include ::oracle_inventory::inventory_pointer
class oracle_inventory::inventory_pointer (
  Enum['present', 'absent']  $ensure        = $::oracle_inventory::ensure,
  String                     $file_owner    = $::oracle_inventory::file_owner,
  String                     $file_group    = $::oracle_inventory::file_group,
  Stdlib::Filemode           $file_mode     = $::oracle_inventory::file_mode,
  Optional[Stdlib::UnixPath] $pointer_file  = $::oracle_inventory::pointer_file,
  Stdlib::UnixPath           $inventory_dir = $::oracle_inventory::inventory_dir,
  String                     $inst_group    = $::oracle_inventory::inst_group,
) inherits oracle_inventory {
  if defined('$pointer_file') and !empty($pointer_file) {
    $inventory_loc = defined('$::oracle_inventory') ? {
      true    => regsubst($::oracle_inventory, '/ContentsXML.+', ''),
      default => $inventory_dir
    }

    $real_content = $ensure ? {
      'absent' => undef,
      default  => @("EOT")
        inventory_loc=${inventory_loc}
        inst_group=${inst_group}
        | EOT
    }

    file { $pointer_file:
      ensure  => $ensure,
      owner   => $file_owner,
      group   => $file_group,
      mode    => $file_mode,
      content => $real_content,
    }
  }
}
