# oracle_inventory::inventory_pointer
#
# This class manages the Oracle central inventory location pointer.
#
# @summary Manages the Oracle central inventory location pointer.
#
# @example
#   include oracle_inventory::inventory_pointer
class oracle_inventory::inventory_pointer (
  $ensure        = $::oracle_inventory::ensure,
  $file_owner    = $::oracle_inventory::file_owner,
  $file_group    = $::oracle_inventory::file_group,
  $file_mode     = $::oracle_inventory::file_mode,
  $pointer_file  = $::oracle_inventory::pointer_file,
  $inventory_dir = $::oracle_inventory::inventory_dir,
  $inst_group    = $::oracle_inventory::inst_group,
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
