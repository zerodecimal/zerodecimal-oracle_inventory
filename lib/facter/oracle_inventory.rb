# oracle_inventory.rb

=begin

  This script will inspect the central Oracle Inventory
  and return the following entries, if they exist:
    oracle_inventory (string): Central inventory file location
    oracle_crs_home (hash): CRS home information
    oracle_rac_nodes (array): List of RAC cluster nodes
    oracle_db_home (hash): Database home information
    oracle_oms_home (hash): OMS (Enterprise Manager) home information
    oracle_em_agent_home (hash): OEM Agent home information
    oracle_ebs_home (hash): EBS application home information
    oracle_wls_home (hash): WebLogic home information
    oracle_client_home (hash): Database Client information

  The Inventory location is defined here:
    UNIX: /var/opt/oracle/oraInst.loc
    LINUX: /etc/oraInst.loc
  On Windows the inventory is always C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml

=end

begin

  ## Required GEMs
  require 'facter'
  require 'xmlsimple'
  require 'time'

  ## Global variables
  oratab      = {}
  ora_inv_loc = Facter.value(:kernel) =~ /linux/i ? '/etc/oraInst.loc'
              : Facter.value(:kernel) =~ /unix/i  ? '/var/opt/oracle/oraInst.loc'
              :                                     nil
  ora_inv     = nil
  o_inventory = {}

  ## Find the Central Inventory location if we are not on a Windows platform
  if (!ora_inv_loc.nil? and File.readable?(ora_inv_loc))
    IO.foreach(ora_inv_loc) do |line|
      line[/^inventory_loc=(.+)$/] && ora_inv = $1 + '/ContentsXML/inventory.xml'
    end
  ## On Windows we already know where it is
  elsif Facter.value(:osfamily) =~ /windows/i
    ora_inv = 'C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml'
  end

  ## Cache the DB home and SID information from /etc/oratab (ignore ASM)
  if File.readable?('/etc/oratab')
    File.open('/etc/oratab','r') do |otab_file|
      otab_file.each_line do |line|
        next unless line[/^[a-z]/i]
        entry = line.split(':')
        oratab.has_key?(entry[1]) || oratab[entry[1]] = []
        oratab[entry[1]] << entry[0] && oratab[entry[1]].sort!
      end
    end
  end

  ## Parse a block of XML and return PSU version/install time data
  ## Parameters:
  ##   oneoff_list (array): the XML array
  ##   type (string): type of home (OCW, Database)
  def get_oneoff_info (oneoff_list, type)
    times = []
    patches = {}
    data = {
      'ver'       => '',
      'inst_time' => '',
    }
    oneoff = oneoff_list[0]['ONEOFF'] || []
    oneoff.each do |patch|
      if patch['DESC'][0][/^#{type} Patch Set Update : (\S+)/]
        patches[$1] = patch['INSTALL_TIME']
        times << patch['INSTALL_TIME']
      end
    end
    if patches.size > 0
      ## Here we have to sort the patches by install time to get the newest one
      if patches.size > 1
        ## This sorts the times array by date/time
        sorted = times.sort_by {|t| Time.parse(t)}
        ## This reduces the patches hash to the newest one
        patches.select! {|k,v| v == sorted[-1]}
        data['ver'] = patches.keys[0]
        data['inst_time'] = patches.values[0]
      else
        data['ver'] = patches.keys[0]
        data['inst_time'] = patches.values[0]
      end
    end
  return data
  end

  ## Parse the Central Inventory and begin setting the Fact variables
  if (ora_inv and File.readable?(ora_inv))
    o_inventory['oracle_inventory'] = ora_inv
    c_inventory = XmlSimple.xml_in(ora_inv)
    if c_inventory['HOME_LIST'][0]['HOME']
      c_inventory['HOME_LIST'].each do |list|
        list['HOME'].each do |home|
          if home['REMOVED'].nil? and File.directory?home['LOC']
            home_dir       = home['LOC']
            home_inv_props = home_dir + '/inventory/ContentsXML/oraclehomeproperties.xml'
            home_inv_comps = home_dir + '/inventory/ContentsXML/comps.xml'
            if File.readable?(home_inv_comps)
              h_inventory = XmlSimple.xml_in(home_inv_comps)
              all_comps = h_inventory['TL_LIST'][0]['COMP'] || []
              if all_comps.length > 0
                all_comps.each do |comp|
                  case comp['NAME']
                  ## CRS Home *note* This can also be found in /etc/oracle/olr.loc
                  when 'oracle.crs'
                    ## Get the PSU information
                    psu_ver = ''
                    psu_inst_time = ''
                    oneoff_list = h_inventory['ONEOFF_LIST'] || []
                    if oneoff_list.length > 0
                      psu_data = get_oneoff_info(oneoff_list, 'OCW')
                      if psu_data.size > 0
                        psu_ver = psu_data['ver']
                        psu_inst_time = psu_data['inst_time']
                      end
                    end
                    ## There can be only one
                    o_inventory['oracle_crs_home'] = {
                      home_dir => {
                        'ver'           => comp['VER'],
                        'inst_time'     => comp['INSTALL_TIME'],
                        'psu_ver'       => psu_ver,
                        'psu_inst_time' => psu_inst_time,
                      }
                    }
                    ## Get the list of cluster nodes
                    if File.readable?(home_inv_props)
                      g_inventory = XmlSimple.xml_in(home_inv_props)
                      cluster_info = g_inventory['CLUSTER_INFO'] || []
                      if cluster_info.length > 0
                        all_nodes = []
                        node_list = cluster_info[0]['NODE_LIST'] || []
                        if node_list.length > 0
                          node_list[0]['NODE'].each do |node|
                            all_nodes << (node['NAME'])
                          end
                        end
                        if all_nodes.length > 0
                          o_inventory['oracle_rac_nodes'] = all_nodes.sort
                        end
                      end
                      g_inventory.clear
                    end
                    break
                  ## Database Home
                  when 'oracle.server'
                    ## Get the PSU information
                    psu_ver = ''
                    psu_inst_time = ''
                    oneoff_list = h_inventory['ONEOFF_LIST'] || []
                    if oneoff_list.length > 0
                      psu_data = get_oneoff_info(oneoff_list, 'Database')
                      if psu_data.size > 0
                        psu_ver = psu_data['ver']
                        psu_inst_time = psu_data['inst_time']
                      end
                    end
                    o_inventory.has_key?('oracle_db_home') || o_inventory['oracle_db_home'] = {}
                    o_inventory['oracle_db_home'][home_dir] = {
                      'ver'           => comp['VER'],
                      'inst_time'     => comp['INSTALL_TIME'],
                      'psu_ver'       => psu_ver,
                      'psu_inst_time' => psu_inst_time,
                      'sid'           => oratab[home_dir] || [],
                    }
                    break
                  ## OMS Home
                  when 'oracle.sysman.top.oms'
                    ## There can be only one
                    o_inventory['oracle_oms_home'] = {
                      home_dir => {
                        'ver'       => comp['VER'],
                        'inst_time' => comp['INSTALL_TIME'],
                      }
                    }
                    break
                  ## EM Agent Home
                  when 'oracle.sysman.top.agent'
                    ## There can be only one
                    o_inventory['oracle_em_agent_home'] = {
                      home_dir => {
                        'ver'       => comp['VER'],
                        'inst_time' => comp['INSTALL_TIME'],
                      }
                    }
                    break
                  ## EBS Home
                  when 'oracle.apps.ebs'
                    ## There can be only one
                    o_inventory['oracle_ebs_home'] = {
                      home_dir.sub(/\/fs.*/, '') => {
                        'ver'       => comp['VER'],
                        'inst_time' => comp['INSTALL_TIME'],
                      }
                    }
                    break
                  ## WebLogic Home
                  when /^oracle\.(wls\.clients|coherence)$/
                    o_inventory.has_key?('oracle_wls_home') || o_inventory['oracle_wls_home'] = {}
                    o_inventory['oracle_wls_home'][home_dir] = {
                      'ver'       => comp['VER'],
                      'inst_time' => comp['INSTALL_TIME'],
                    }
                    break
                  ## Client Home
                  when 'oracle.client'
                    o_inventory.has_key?('oracle_client_home') || o_inventory['oracle_client_home'] = {}
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
              h_inventory.clear
            end
          end
        end
      end
    end
    c_inventory.clear
  end

  ## Add the Inventory elements to Facter
  o_inventory.each do |name, fact|
    Facter.add(name) do
      setcode do
        fact
      end
    end
  end

rescue Exception => e
  # The required file will not be there the first time this fact is loaded
  if e.message[/cannot load such file/i]
    #Puppet.warning e.message
    Puppet.info e.message
    ""
  else
    raise
  end
end
