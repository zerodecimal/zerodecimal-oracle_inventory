# oracle_inventory::inventory_loc
#
# This class manages the Oracle central inventory location pointer.
#
# @summary Manages the Oracle central inventory location pointer.
#
# @example
#   include oracle_inventory::inventory_loc
class oracle_inventory::inventory_loc {

  $oracle_inventory_loc = hiera('oracle_inventory_loc')
  $oracle_primary_group = hiera('oracle_primary_group')

  file { '/etc/oraInst.loc':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/oraInst.loc.erb"),
  }

}
