# oracle_inventory.rb

## Required GEMs
require 'rexml/document'
require 'time'

## Include the REXML namespace
include REXML

## Top scope variables
etc_dir = (Facter.value(:kernel) =~ %r{linux}i)   ? '/etc'
        : (Facter.value(:kernel) !~ %r{windows}i) ? '/var/opt/oracle'
        :                                           nil
inv_pointer = etc_dir.nil? ? nil : etc_dir + '/oraInst.loc'
oratab_file = etc_dir.nil? ? nil : etc_dir + '/oratab'
central_inv = nil
oratab = {}
## This is the hash that will contain the facts
o_inventory = {}

## Find the Central Inventory location if we are not on a Windows platform
if !inv_pointer.nil? and File.readable?(inv_pointer)
  o_inventory['oracle_inventory_pointer'] = inv_pointer
  File.foreach(inv_pointer) { |line| line[%r{^inventory_loc=(.+)$}] && central_inv = Regexp.last_match(1) + '/ContentsXML/inventory.xml' }
## On Windows we already know where it is
elsif Facter.value(:osfamily) =~ %r{windows}i
  if File.readable?('C:/Program Files (x86)/Oracle/Inventory/ContentsXML/inventory.xml')
    central_inv = 'C:/Program Files (x86)/Oracle/Inventory/ContentsXML/inventory.xml'
  else
    central_inv = 'C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml'
  end
end

## Cache the DB home and SID information from /etc/oratab (including ASM)
if !oratab_file.nil? and File.readable?('/etc/oratab')
  File.open('/etc/oratab', 'r').each_line do |line|
    next unless line[%r{^(?:[a-z]|\+asm)}i]
    entry = line.split(':')
    oratab.key?(entry[1]) || oratab[entry[1]] = []
    (oratab[entry[1]] << entry[0]) && oratab[entry[1]].sort!
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

## Return the OPatch version for an Oracle Home
## Parameters:
##   homedir (string): the Oracle Home
def get_opatch_ver(homedir)
  verfile = homedir + '/OPatch/version.txt'
  version = nil
  if File.readable?(verfile)
    File.open(verfile).each do |line|
      version = line.split(':')[-1].chomp if line[%r{^OPATCH_VERSION:[\d\.]+}]
    end
  end
  version
end

## Return the ORACLE_BASE for an Oracle Home
## Parameters:
##   homedir (string): the Oracle Home
def get_oracle_base(homedir)
  oraclehomeprops = homedir + '/inventory/ContentsXML/oraclehomeproperties.xml'
  default_oracle_base = (Facter.value(:kernel) =~ %r{windows}i) ? 'C:\app\oracle' : '/u01/app/oracle'
  oraclebase = nil
  if File.readable?(oraclehomeprops)
    p_root = Document.new(File.new(oraclehomeprops)).root
    p_root.each_element('//PROPERTY') { |prop| oraclebase = prop['VAL'] if prop['NAME'] == 'ORACLE_BASE' }
  end
  oraclebase = default_oracle_base if oraclebase.nil? or oraclebase.sub(%r{^(.+)/$}, '\1') == homedir
  oraclebase
end

## Parse the Central Inventory and begin setting the Fact variables
if central_inv and File.readable?(central_inv)
  o_inventory['oracle_inventory'] = central_inv
  c_root = Document.new(File.new(central_inv)).root
  c_root.each_element('//HOME') do |home|
    next unless home['REMOVED'].nil? && File.directory?(home['LOC'])
    home_dir = home['LOC'].sub(%r{^(.+)/$}, '\1')
    home_inv_comps = home_dir + '/inventory/ContentsXML/comps.xml'
    next unless File.readable?(home_inv_comps)
    l_root = Document.new(File.new(home_inv_comps)).root
    l_root.each_element('//COMP') do |comp|
      case comp['NAME']
      ## CRS Home (*note* This can also be found in /etc/oracle/olr.loc)
      when 'oracle.crs'
        ## Get the OPatch version
        opatch_ver = get_opatch_ver(home_dir)
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
        o_inventory['oracle_crs_home'] = { home_dir => { 'oracle_base' => get_oracle_base(home_dir) } }
        comp['VER'].nil? || o_inventory['oracle_crs_home'][home_dir]['ver'] = comp['VER']
        oracle_base.nil? || o_inventory['oracle_crs_home'][home_dir]['oracle_base'] = oracle_base
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_crs_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
        opatch_ver.nil? || o_inventory['oracle_crs_home'][home_dir]['opatch_ver'] = opatch_ver
        psu_ver.nil? || o_inventory['oracle_crs_home'][home_dir]['psu_ver'] = psu_ver
        psu_inst_time.nil? || o_inventory['oracle_crs_home'][home_dir]['psu_inst_time'] = psu_inst_time
        oratab.key?(home_dir) && o_inventory['oracle_crs_home'][home_dir]['sid'] = oratab[home_dir][0]
        ## Get the list of cluster nodes
        unless comp['VER'].nil?
          home_inv_props = home_dir + '/inventory/Components21/oracle.has.crs/' + comp['VER'] + '/context.xml'
          if File.readable?(home_inv_props)
            p_root = Document.new(File.new(home_inv_props)).root
            var_list = p_root.elements['VAR_LIST']
            var_list&.each_element('//VAR') do |var|
              case var['NAME']
              when 'OwnerId'
                o_inventory['oracle_crs_home'][home_dir]['owner'] = var['VAL']
              when 's_clusterNodes'
                var['VAL'].empty? || o_inventory['oracle_rac_nodes'] = var['VAL'].split(',').sort
              else
                next
              end
            end
          end
        end
        ## Get the SCAN name
        home_global_vars = home_dir + '/inventory/globalvariables/oracle.crs/globalvariables.xml'
        if File.readable?(home_global_vars)
          g_root = Document.new(File.new(home_global_vars)).root
          domain = Facter.value(:domain)
          n = g_root.find { |node| node.is_a?(Element) and node.attributes['NAME'] == 'oracle_install_crs_SCANName' }
          unless n.nil?
            v = n.attributes['VALUE']
            o_inventory['oracle_scan_name'] = v.sub(%r{^([\w\d-]+).*$}, '\1.' + domain) unless v.empty?
          end
        end
        break
      ## Database Home
      when 'oracle.server'
        ## Get the OPatch version
        opatch_ver = get_opatch_ver(home_dir)
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
        db_home_inventory = { 'oracle_base' => get_oracle_base(home_dir) }
        comp['VER'].nil? || db_home_inventory['ver'] = comp['VER']
        oracle_base.nil? || db_home_inventory['oracle_base'] = oracle_base
        comp['INSTALL_TIME'].nil? || db_home_inventory['inst_time'] = comp['INSTALL_TIME']
        opatch_ver.nil? || db_home_inventory['opatch_ver'] = opatch_ver
        psu_ver.nil? || db_home_inventory['psu_ver'] = psu_ver
        psu_inst_time.nil? || db_home_inventory['psu_inst_time'] = psu_inst_time
        oratab.key?(home_dir) && db_home_inventory['sid'] = oratab[home_dir]
        o_inventory['oracle_db_home'][home_dir] = db_home_inventory
        break
      ## OMS Home
      when 'oracle.sysman.top.oms'
        ## There can be only one
        o_inventory['oracle_oms_home'] = { home_dir => {} }
        comp['VER'].nil? || o_inventory['oracle_oms_home'][home_dir]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_oms_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
        break
      ## EM Agent Home
      when 'oracle.sysman.top.agent'
        ## There can be only one
        o_inventory['oracle_em_agent_home'] = { home_dir => {} }
        comp['VER'].nil? || o_inventory['oracle_em_agent_home'][home_dir]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_em_agent_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
        ## This is hard-coded but seems quite difficult to get to otherwise
        o_inventory['oracle_em_agent_home'][home_dir]['instance_home'] = home_dir.sub(%r{/core/\d.*}, '/agent_inst')
        break
      ## EBS Home
      when 'oracle.apps.ebs'
        ebs_home = home_dir.sub(%r{\/fs.*}, '')
        ## There can be only one
        o_inventory['oracle_ebs_home'] = { ebs_home => {} }
        comp['VER'].nil? || o_inventory['oracle_ebs_home'][ebs_home]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_ebs_home'][ebs_home]['inst_time'] = comp['INSTALL_TIME']
        break
      ## Endeca Home
      when 'oracle.endeca.server.top'
        o_inventory.key?('oracle_endeca_home') || o_inventory['oracle_endeca_home'] = {}
        o_inventory['oracle_endeca_home'][home_dir] = {}
        comp['VER'].nil? || o_inventory['oracle_endeca_home'][home_dir]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_endeca_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
        break
      ## WebLogic Home
      when 'oracle.as.common.top', %r{^oracle\.(wls\.clients|coherence)}
        o_inventory.key?('oracle_wls_home') || o_inventory['oracle_wls_home'] = {}
        o_inventory['oracle_wls_home'][home_dir] = {}
        comp['VER'].nil? || o_inventory['oracle_wls_home'][home_dir]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_wls_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
        break
      ## Client Home
      when 'oracle.client'
        o_inventory.key?('oracle_client_home') || o_inventory['oracle_client_home'] = {}
        o_inventory['oracle_client_home'][home_dir] = {}
        comp['VER'].nil? || o_inventory['oracle_client_home'][home_dir]['ver'] = comp['VER']
        comp['INSTALL_TIME'].nil? || o_inventory['oracle_client_home'][home_dir]['inst_time'] = comp['INSTALL_TIME']
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
