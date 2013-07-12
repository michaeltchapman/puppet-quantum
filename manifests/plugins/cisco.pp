class quantum::plugins::cisco(
  $vswitch_plugin = 'quantum.plugins.openvswitch.ovs_quantum_plugin.OVSQuantumPluginV2'

  # Database connection
  $database_name = 'quantum',
  $database_user = 'cisco_quantum',
  $database_pass = 'quantum',
  $database_host = 'localhost',

  # l2network plugin
  $vlan_start        = '100',
  $vlan_end          = '3000',
  $vlan_name_prefix  = 'q-',
  $max_ports         = '100',
  $max_port_profiles = '65568',
  $max_networks      = '65568',
  $model_class       = 'quantum.plugins.cisco.models.virt_phy_sw_v2.VirtualPhysicalSwitchModelV2',
  $manager_class     = 'quantum.plugins.cisco.segmentation.l2network_vlan_mgr_v2.L2NetworkVLANMgr',
  $test_host         = undef
)
{
  Quantum_cisco_plugins_config<||> ~> Service['quantum-server']
  Quantum_cisco_db_conn_config<||> ~> Service['quantum-server']
  Quantum_cisco_l2network_plugin_config<||> ~> Service['quantum-server']

  file { '/etc/quantum/plugins':
    ensure => directory,
    require => File['/etc/quantum'],
  }

  file { '/etc/quantum/plugins/cisco':
    ensure => directory,
    require => File['/etc/quantum/plugins'],
  }

  quantum_cisco_plugins_config {
    'PLUGINS/vswitch_plugin' : value => $vswitch_plugin;
  }

  quantum_cisco_db_conn_config {
    'DATABASE/name': value => $database_name;
    'DATABASE/user': value => $database_user;
    'DATABASE/pass': value => $database_pass;
    'DATABASE/host': value => $database_host;
  }

  quantum_cisco_l2network_plugin_config {
    'VLANS/vlan_start' : value => $vlan_start;
    'VLANS/vlan_end'   : value => $vlan_end;
    'VLAN/vlan_name_prefix' : value => $vlan_name_prefix;
    'PORTS/max_ports'  : value => $max_ports;
    'PORTPROFILES/max_port_profiles' : value => $max_port_profiles;
    'NETWORKS/max_networks': value => $max_networks;
    'MODEL/model_class' : value => $model_class;
    'SEGMENTATION/manager_class' : value => $manager_class;
  }

  if $test_host {
    quantum_cisco_l2network_plugin_config {
      'TEST/host' : value => $test_host
    }
  }
}
