# oracle_inventory::inventory_loc
#
# This class manages the Oracle central inventory location pointer.
#
# @summary Manages the Oracle central inventory location pointer.
#
# @example
#   include oracle_inventory::inventory_loc
class oracle_inventory::inventory_loc (
  $ensure        = $::oracle_inventory::ensure,
  $file_owner    = $::oracle_inventory::file_owner,
  $file_group    = $::oracle_inventory::file_group,
  $file_mode     = $::oracle_inventory::file_mode,
  $inventory_dir = $::oracle_inventory::inventory_loc,
  $inst_group    = $::oracle_inventory::inst_group,
) inherits oracle_inventory {

  $inventory_loc = defined('$::oracle_inventory') ? {
    true    => regsubst($::oracle_inventory, '/ContentsXML.+', ''),
    default => $inventory_dir
  }

  $inventory_pointer = $::kernel ? {
    'Linux'           => '/etc/oraInst.loc',
    /(Unix|HP|SunOS)/ => '/var/opt/oracle/oraInst.loc',
    default           => undef
  }

  $real_content = $ensure ? {
    'absent' => undef,
    default  => @("EOT")
      inventory_loc=${inventory_loc}
      inst_group=${inst_group}
      | EOT
  }

  file { $inventory_pointer:
    ensure  => $ensure,
    owner   => $file_owner,
    group   => $file_group,
    mode    => $file_mode,
    content => $real_content,
  }

}
