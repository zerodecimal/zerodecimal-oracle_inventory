# oracle_inventory

[![License](https://img.shields.io/github/license/zerodecimal/zerodecimal-oracle_inventory.svg)](https://github.com/zerodecimal/zerodecimal-oracle_inventory/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/zerodecimal/zerodecimal-oracle_inventory.svg?branch=master)](https://travis-ci.org/zerodecimal/zerodecimal-oracle_inventory)
<!---
[![Puppet Forge Version](https://img.shields.io/puppetforge/v/zerodecimal/oracle_inventory.svg)](https://forge.puppet.com/zerodecimal/oracle_inventory)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/zerodecimal/oracle_inventory.svg)](https://forge.puppet.com/zerodecimal/oracle_inventory)
[![Puppet Forge Score](https://img.shields.io/puppetforge/f/zerodecimal/oracle_inventory.svg)](https://forge.puppet.com/zerodecimal/oracle_inventory)
--->

## Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with oracle_inventory](#setup)
    * [What oracle_inventory affects](#what-oracle_inventory-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with oracle_inventory](#beginning-with-oracle_inventory)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

This module provides an Oracle inventory parser that produces a set of facts showing what Oracle products are installed on your system. For non-Windows servers, it also includes a class to manage the contents of the inventory pointer file.

The inventory parser begins with the central inventory XML file, then inspects all installed (not removed) homes referenced therein. If there is a product installed in a home that matches a known component ID (see [Reference](#reference) section below), a fact is created with that home location, version, and install date/time. In the case of CRS and Database homes, PSU (patch set update) versions and install date/times are included.

These facts can be useful in configuring servers with Oracle products installed. For example, when the Puppet agent runs after a database home is installed, a fact called "oracle_db_home" is created and can then be used to set the oracle user's environment.

The facts can also be useful for inventory reports. For example, to see the latest patch set update (PSU) applied to all the databases in an environment.

*Puppet version 4.3 is required because this module makes use of features such as strong data typing.*

## Setup

Install the oracle_inventory module to add the facts and classes to your environment.

### What oracle_inventory affects

 Agent nodes will need to be able to install the xml-simple Ruby gem using the puppet_gem provider. The ensure_packages function is used for this, to give users the freedom to manage this package resource in another module.

 If you wish to avoid the xml-simple requirement, there is a REXML version of the fact script under examples. Feel free to pull it out and put it under some other module. It produces the same output but takes a little bit longer to run.

### Setup Requirements

puppetlabs/stdlib >= 4.13.1 is required.

### Beginning with oracle_inventory

The module can simply be installed with a Puppetfile entry and the facts will be available (as long as the xml-simple gem is installed). To manage the inventory pointer file, include the oracle_inventory class in some profile manifest. To accept the default parameters:

```puppet
include ::oracle_inventory
```

## Usage

To manage the Oracle inventory pointer file with non-default parameters, declare the class in this format:

```puppet
class { '::oracle_inventory':
  file_owner    => 'oracle',
  file_group    => 'oinstall',
  inventory_dir => '/home/oracle/oraInventory',
}
```

To install the xml-simple gem and use the facts, but not manage the Oracle inventory pointer file, declare the class as such:

```puppet
class { '::oracle_inventory':
  manage_pointer => false,
}
```

## Reference

### Facts

#### `oracle_inventory_pointer`

Description: Central inventory pointer file location

Datatype: String

#### `oracle_inventory`

Description: Central inventory file location

Datatype: String

#### `oracle_crs_home`

Description: CRS home information, including ASM ORACLE_SID from oratab

Datatype: Hash

#### `oracle_rac_nodes`

Description: List of RAC cluster nodes

Datatype: Array

#### `oracle_scan_name`

Description: Single Client Access Name for RAC clusters

Datatype: String

#### `oracle_db_home`

Description: Database home information, including ORACLE_SID(s) from oratab

Datatype: Hash

#### `oracle_oms_home`

Description: OMS (Enterprise Manager) home information

Datatype: Hash

#### `oracle_em_agent_home`

Description: Enterprise Manager Agent home information

Datatype: Hash

#### `oracle_ebs_home`

Description: EBS application (Fusion Middleware) home information

Datatype: Hash

#### `oracle_wls_home`

Description: WebLogic home information

Datatype: Hash

#### `oracle_client_home`

Description: Database Client home information

Datatype: Hash

### Classes

#### `oracle_inventory`

* The main class. Any other classes are declared internally.

#### Parameters

##### `manage_pointer`

Data type: `Boolean`

Whether or not to manage the inventory pointer file

Default value: `true`

##### `ensure`

Data type: `Enum['present', 'absent']`

Should the pointer file exist

Default value: 'present'

##### `file_owner`

Data type: `String`

Pointer file owner

Default value: 'root'

##### `file_group`

Data type: `String`

Pointer file group

Default value: 'root'

##### `file_mode`

Data type: `Stdlib::Filemode`

Pointer file permissions

Default value: '0644'

##### `pointer_file`

Data type: `Optional[Stdlib::UnixPath]`

Full path to the pointer file

Default value: $::facts[oracle_inventory_pointer]

##### `inventory_dir`

Data type: `Stdlib::UnixPath`

Directory for the inventory_loc entry in the pointer file

Default value: '/u01/app/oraInventory'

##### `inst_group`

Data type: `String`

Value for the inst_group entry in the pointer file

Default value: 'oinstall'

## Limitations

### Supported Operating Systems

* RedHat
* CentOS
* Oracle Linux
* Scientific Linux
* Ubuntu
* Solaris
* Windows

### Supported Oracle versions

The included facts are known to work on the following Oracle software versions. They have not been tested against any others.

* CRS: 11g, 12c
* Database: 11g, 12c
* Database Client: 11g, 12c
* Enterprise Manager (and agent): 12c, 13c
* E-Business Suite: 12.2 (when there is a single pointer file and central inventory)
* WebLogic: 11g, 12c

## Development

Contributions are always welcome - please submit a pull request or issue on [GitHub](https://github.com/zerodecimal/zerodecimal-oracle_inventory).

## Contributors

The list of contributors can be found at: [https://github.com/zerodecimal/zerodecimal-oracle_inventory/graphs/contributors](https://github.com/zerodecimal/zerodecimal-oracle_inventory/graphs/contributors).
