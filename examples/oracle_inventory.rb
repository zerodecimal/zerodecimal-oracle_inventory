# oracle_inventory.rb

## Required GEMs
require 'facter'
require 'rexml/document'
require 'time'

## Include the REXML namespace
include REXML

## Top scope variables
etc_dir     = (Facter.value(:kernel) =~ %r{linux}i)   ? '/etc'
            : (Facter.value(:kernel) !~ %r{windows}i) ? '/var/opt/oracle'
            :                                         nil
inv_pointer = etc_dir.nil? ? nil : etc_dir + '/oraInst.loc'
oratab_file = etc_dir.nil? ? nil : etc_dir + '/oratab'
central_inv = nil
oratab      = {}
## This is the hash that will contain the facts
o_inventory = {}

## Find the Central Inventory location if we are not on a Windows platform
if !inv_pointer.nil? and File.readable?(inv_pointer)
  o_inventory['oracle_inventory_pointer'] = inv_pointer
  IO.foreach(inv_pointer) { |line| line[%r{^inventory_loc=(.+)$}] && central_inv = Regexp.last_match(1) + '/ContentsXML/inventory.xml' }
## On Windows we already know where it is
elsif Facter.value(:osfamily) =~ %r{windows}i
  central_inv = 'C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml'
end

## Cache the DB home and SID information from /etc/oratab (including ASM)
if !oratab_file.nil? and File.readable?('/etc/oratab')
  File.open('/etc/oratab', 'r').each_line do |line|
    next unless line[%r{^[\+a-z]}i]
    entry = line.split(':')
    oratab.key?(entry[1]) || oratab[entry[1]] = []
    oratab[entry[1]] << entry[0] && oratab[entry[1]].sort!
  end
end

## Parse a block of XML and return PSU version/install time data
## Parameters:
##   oneoff_list (array): the XML array
##   type (string): type of home (OCW, Database)
def get_oneoff_info(oneoff_list, type)
  times = []
  patches = {}
  oneoff_list.each_element('//ONEOFF') do |patch|
    patch.elements['DESC'].text.nil? && next
    if patch.elements['DESC'].text[%r{^#{type} Patch Set Update : (\S+)}]
      patches[Regexp.last_match(1)] = patch['INSTALL_TIME']
      times << patch['INSTALL_TIME']
    end
  end
  return {} if patches.empty?
  ## Here we have to sort the patches by install time to get the newest one
  if patches.size > 1
    ## This sorts the times array by date/time
    sorted = times.sort_by { |t| Time.parse(t) }
    ## This reduces the patches hash to the newest one
    patches.select! { |_k, v| v == sorted[-1] }
  end
  { 'ver' => patches.keys[0], 'inst_time' => patches.values[0] }
end

## Parse the Central Inventory and begin setting the Fact variables
if central_inv and File.readable?(central_inv)
  o_inventory['oracle_inventory'] = central_inv
  c_root = Document.new(File.new(central_inv)).root
  c_root.each_element('//HOME') do |home|
    next unless home['REMOVED'].nil? && File.directory?(home['LOC'])
    home_dir       = home['LOC']
    home_inv_props = home_dir + '/inventory/ContentsXML/oraclehomeproperties.xml'
    home_inv_comps = home_dir + '/inventory/ContentsXML/comps.xml'
    next unless File.readable?(home_inv_comps)
    l_root = Document.new(File.new(home_inv_comps)).root
    l_root.each_element('//COMP') do |comp|
      case comp['NAME']
      ## CRS Home (*note* This can also be found in /etc/oracle/olr.loc)
      when 'oracle.crs'
        ## Get the PSU information
        psu_ver = nil
        psu_inst_time = nil
        oneoff_list = l_root.elements['ONEOFF_LIST']
        unless oneoff_list.nil?
          psu_data = get_oneoff_info(oneoff_list, 'OCW')
          unless psu_data.empty?
            psu_ver = psu_data['ver']
            psu_inst_time = psu_data['inst_time']
          end
        end
        ## There can be only one
        o_inventory['oracle_crs_home'] = {
          home_dir => {
            'ver'       => comp['VER'],
            'inst_time' => comp['INSTALL_TIME'],
          },
        }
        psu_ver.nil? || o_inventory['oracle_crs_home'][home_dir]['psu_ver'] = psu_ver
        psu_inst_time.nil? || o_inventory['oracle_crs_home'][home_dir]['psu_inst_time'] = psu_inst_time
        oratab.key?(home_dir) && o_inventory['oracle_crs_home'][home_dir]['sid'] = oratab[home_dir][0]
        ## Get the list of cluster nodes
        if File.readable?(home_inv_props)
          all_nodes = []
          p_root = Document.new(File.new(home_inv_props)).root
          unless p_root.elements['CLUSTER_INFO'].nil?
            node_list = p_root.elements['CLUSTER_INFO'].elements['NODE_LIST']
            unless node_list.nil?
              node_list.each_element('//NODE') { |node| all_nodes << (node['NAME']) }
              o_inventory['oracle_rac_nodes'] = all_nodes.sort
            end
          end
        end
        break
      ## Database Home
      when 'oracle.server'
        ## Get the PSU information
        psu_ver = nil
        psu_inst_time = nil
        oneoff_list = l_root.elements['ONEOFF_LIST']
        unless oneoff_list.nil?
          psu_data = get_oneoff_info(oneoff_list, 'Database')
          unless psu_data.empty?
            psu_ver = psu_data['ver']
            psu_inst_time = psu_data['inst_time']
          end
        end
        o_inventory.key?('oracle_db_home') || o_inventory['oracle_db_home'] = {}
        o_inventory['oracle_db_home'][home_dir] = {
          'ver'       => comp['VER'],
          'inst_time' => comp['INSTALL_TIME'],
        }
        psu_ver.nil? || o_inventory['oracle_db_home'][home_dir]['psu_ver'] = psu_ver
        psu_inst_time.nil? || o_inventory['oracle_db_home'][home_dir]['psu_inst_time'] = psu_inst_time
        oratab.key?(home_dir) && o_inventory['oracle_db_home'][home_dir]['sid'] = oratab[home_dir]
        break
      ## OMS Home
      when 'oracle.sysman.top.oms'
        ## There can be only one
        o_inventory['oracle_oms_home'] = {
          home_dir => {
            'ver'       => comp['VER'],
            'inst_time' => comp['INSTALL_TIME'],
          },
        }
        break
      ## EM Agent Home
      when 'oracle.sysman.top.agent'
        ## There can be only one
        o_inventory['oracle_em_agent_home'] = {
          home_dir => {
            'ver'       => comp['VER'],
            'inst_time' => comp['INSTALL_TIME'],
          },
        }
        break
      ## EBS Home
      when 'oracle.apps.ebs'
        ## There can be only one
        o_inventory['oracle_ebs_home'] = {
          home_dir.sub(%r{\/fs.*}, '') => {
            'ver'       => comp['VER'],
            'inst_time' => comp['INSTALL_TIME'],
          },
        }
        break
      ## WebLogic Home
      when %r{^oracle\.(wls\.clients|coherence)}
        o_inventory.key?('oracle_wls_home') || o_inventory['oracle_wls_home'] = {}
        o_inventory['oracle_wls_home'][home_dir] = {
          'ver'       => comp['VER'],
          'inst_time' => comp['INSTALL_TIME'],
        }
        break
      ## Client Home
      when 'oracle.client'
        o_inventory.key?('oracle_client_home') || o_inventory['oracle_client_home'] = {}
        o_inventory['oracle_client_home'][home_dir] = {
          'ver'       => comp['VER'],
          'inst_time' => comp['INSTALL_TIME'],
        }
        break
      else
        next
      end
    end
  end
end

## Add the Inventory elements to Facter
o_inventory.each do |name, fact|
  Facter.add(name) do
    setcode do
      fact
    end
  end
end
