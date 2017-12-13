# oracle_inventory.rb

=begin
  This script will inspect the central Oracle Inventory
  and return the following entries, if they exist:
    oracle_home (semicolon-delimited list of Oracle database homes)
   *oracle_db (associative array of db home parameter/value pairs)
    grid_home
   *oracle_crs (associative array of grid home parameter/value pairs)
    oms_home
    agent_home
   *oracle_emagent (associative array of agent home parameter/value pairs)
    db_client_home
    ebs_env_home
    wls_home
    cluster_nodes (comma-delimited list of RAC cluster nodes)

    [* = These facts return non-string objects, which was not possible before 2015.3]

  The Inventory location is defined here:
    UNIX: /var/opt/oracle/oraInst.loc
    LINUX: /etc/oraInst.loc
  On Windows the inventory is always C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml
=end

begin
  ## Required GEMs
  require 'facter'
  require 'xmlsimple'
  ## Global variables
  oratab      = {}
  ora_inv_loc = Facter.value(:kernel) =~ /linux/i ? '/etc/oraInst.loc'
              ## There are currently no plans to manage any Unix servers
              #: Facter.value(:kernel) =~ /unix/i  ? '/var/opt/oracle/oraInst.loc'
              :                                     nil
  ora_inv     = nil
  db_homes    = []
  o_inventory = {
    'oracle_db'      => {},
    'oracle_emagent' => {},
  }
  ## Find the Central Inventory location if we are not on a Windows platform
  if (ora_inv_loc and File.readable?(ora_inv_loc))
    IO.foreach(ora_inv_loc) do |line|
      line[/^inventory_loc=(.+)$/] && ora_inv = $1 + '/ContentsXML/inventory.xml'
    end
  ## On Windows we already know where it is
  elsif Facter.value(:osfamily) =~ /windows/i
    ora_inv = 'C:/Program Files/Oracle/Inventory/ContentsXML/inventory.xml'
  end
  ## Cache the DB home entries from /etc/oratab (ignore ASM)
  if File.readable?('/etc/oratab')
    File.open('/etc/oratab','r') do |otab_file|
      otab_file.each_line do |line|
        next unless line[/^[a-z]/i]
        entry = line.split(':')
        oratab[entry[1]] = entry[0]
      end
    end
  end
  ## Parse the Central Inventory and begin setting the Fact variables
  if (ora_inv and File.readable?(ora_inv))
    c_inventory = XmlSimple.xml_in(ora_inv)
    if c_inventory['HOME_LIST'][0]['HOME']
      c_inventory['HOME_LIST'].each do |list|
        list['HOME'].each do |home|
          if home['REMOVED'].nil? and File.directory?home['LOC']
            home_dir       = home['LOC']
            home_inv_props = home_dir + '/inventory/ContentsXML/oraclehomeproperties.xml'
            home_inv_comps = home_dir + '/inventory/ContentsXML/comps.xml'
            if home['CRS']
              ## GRID_HOME *note* This can also be found in /etc/oracle/olr.loc
              o_inventory['grid_home'] = home_dir
              if File.readable?(home_inv_comps)
                h_inventory = XmlSimple.xml_in(home_inv_comps)
                if h_inventory['TL_LIST'][0]['COMP']
                  o_inventory['oracle_crs'] = {
                    home_dir => {
                      'ver'       => h_inventory['TL_LIST'][0]['COMP'][0]['VER'],
                      'inst_time' => h_inventory['TL_LIST'][0]['COMP'][0]['INSTALL_TIME'],
                    }
                  }
                end
                h_inventory.clear
              end
              ## This is a RAC node, go to the GRID_HOME Inventory and get the list of cluster nodes
              if File.readable?(home_inv_props)
                g_inventory = XmlSimple.xml_in(home_inv_props)
                if g_inventory['CLUSTER_INFO']
                  node_list = []
                  g_inventory['CLUSTER_INFO'].each do |cluster|
                    cluster['NODE_LIST'].each do |list|
                      list['NODE'].each do |node|
                        node_list.push(node['NAME'])
                      end
                    end
                  end
                  if node_list.length
                    o_inventory['cluster_nodes'] = node_list.sort.join(',')
                  end
                end
                g_inventory.clear
              end
            elsif File.readable?(home_inv_comps)
              h_inventory = XmlSimple.xml_in(home_inv_comps)
              if h_inventory['TL_LIST'][0]['COMP']
                case h_inventory['TL_LIST'][0]['COMP'][0]['EXT_NAME'][0]
                when /^Oracle Database\s+\d/i              ## DB_HOME
                  db_homes.push(home_dir)
                  psu_ver = ''
                  psu_inst_time = ''
                  if h_inventory['ONEOFF_LIST'][0]['ONEOFF']
                    h_inventory['ONEOFF_LIST'][0]['ONEOFF'].each do |patch|
                      if patch['DESC'][0] =~ /^Database Patch Set Update : ([\d\.]+) /
                        psu_ver = $1
                        psu_inst_time = patch['INSTALL_TIME']
                      end
                    end
                  end
                  o_inventory['oracle_db'][home_dir] = {
                    'ver'           => h_inventory['TL_LIST'][0]['COMP'][0]['VER'],
                    'inst_time'     => h_inventory['TL_LIST'][0]['COMP'][0]['INSTALL_TIME'],
                    'psu_ver'       => psu_ver,
                    'psu_inst_time' => psu_inst_time,
                    'sid'           => oratab[home_dir] || '',
                  }
                when /^EM Platform \(OMS\)/i               ## OMS_HOME
                  o_inventory['oms_home'] = home_dir
                when /^EM Platform \(Agent\)/i             ## AGENT_HOME
                  o_inventory['agent_home'] = home_dir
                  o_inventory['oracle_emagent'][home_dir] = {
                    'ver'       => h_inventory['TL_LIST'][0]['COMP'][0]['VER'],
                    'inst_time' => h_inventory['TL_LIST'][0]['COMP'][0]['INSTALL_TIME'],
                  }
                when /^Oracle E-Business Suite Component/i ## EBS_ENV_HOME
                  o_inventory['ebs_env_home'] = home_dir.sub(/\/fs.*/, '')
                when /^oracle.*(wls|coherence)/            ## WLS_HOME
                  o_inventory['wls_home'] = home_dir
                when /Oracle Client/i                      ## DB_CLIENT_HOME
                  o_inventory['db_client_home'] = home_dir
                end
              end
              h_inventory.clear
            end
          end
        end
      end
    end
    c_inventory.clear
    ## Join the db_homes into a string
    if db_homes.length
      o_inventory['oracle_home'] = db_homes.join(';')
    end
  end
  ## Add the Inventory elements to Facter
  o_inventory.each{|name,fact|
    Facter.add(name) do
      setcode do
        fact
      end
    end
  }
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
