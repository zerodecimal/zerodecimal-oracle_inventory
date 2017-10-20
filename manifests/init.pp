# oracle_inventory
#
# This module manages the Oracle central inventory pointer, and provides facts from the inventory.
#
# @summary Provides facts from central inventory interrogation.
#
# @example
#   include oracle_inventory
class oracle_inventory {

  include ::oracle_inventory::inventory_loc

}
