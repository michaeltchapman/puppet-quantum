class quantum::plugins::cisco::csr (
  # Keystone Credentials
  $keystone_url       => 'http://127.0.0.1:5000/v2.0/'
  $l3_admin_user      => 'quantum',
  $l3_admin_role      => 'admin',
  $l3_admin_tenant    => 'l3admintenant',
  $l3_admin_password  => 'quantum',

  # Nova flavor for the router VM
  $csr1kv_flavor_id   => '621',
  $csr1kv_flavor_name => 'csr1kv_router',

  # Nova host aggregate for nodes running virtual fouter
  $aggregate_metadata_key       => 'network_host',
  $aggregate_metadata_value     => 'True',
  $network_hosts_aggregate_name => 'compute_network_hosts',

  # The hostnames of the compute hosts to be used
  # to run the virtual router. This will be passed directly
  # to a bash for loop so separate using spaces like so:
  # 'compute-node1 compute-node2 compute-node3'
  $network_hosts,

  # Management network
  $osn_mgmt_network_name => 'osn_mgmt_network',
  $mgmt_security_group   => 'mgmt_sec_grp',
  $mgmt_provider_nw_name => 'mgmt_net'
  $mgmt_provider_vlan_id => '140'

  # Management subnet
  $osn_mgmt_subnet_name  => 'mgmt_subnet'
  $osn_mgmt_subnet       => '10.0.100.0/24'
  $osn_mgmt_range_start  => '10.0.100.10'
  $osn_mgmt_range_end    => '10.0.100.254'

  $csr1k_image_name      => 'csr1kv_openstack_img',
  $csr1k_image_source    => '/home/stack/csr1000v-XE310_Throttle_20130506.qcow2'
)
{
  keystone_tenant { $l3_admin_tenant:
    ensure      => present,
    enabled     => true,
    description => "Tenant used to launch router VMs"
  } ->

  keystone_user  { $l3_admin_user:
    ensure  => present,
    enabled => true,
  } ->

  # the admin role should be installed by default
  keystone_user_role { "${l3_admin_user}@${l3_admin_tenant}":
    ensure => present,
    roles  => $l3_admin_role
  }

  $environment = ["OS_USERNAME=${l3_admin_user}",
                  "OS_TENANT=${l3_admin_tenant}",
                  "OS_PASSWORD=${l3_admin_password}",
                  "OS_AUTH_URL=${keystone_uri}",
                  "OS_NO_CACHE=true,"
                  "OS_AUTH_STRATEGY=keystone"]

  exec {'csr_flavor':
    command     => "nova flavor-create ${csr1kv_flavor_name} ${csr1kv_flavor_id} 8192 0 4 --is-public False",
    unless      => 'nova flavor-show ${csr1kv_flavor_id}',
    environment => $environment,
    require     => Keystone_user_role["${l3_admin_user}@${l3_admin_tenant}"]
  } ->

  exec {'csr_flavor_metadata':
    command     => "nova flavor-key $csr1kv_flavor_id set ${aggregate_metadata_key}=${aggregate_metadata_value}"
    unless      => "nova flavor-show ${csr1kv_flavor_id} | grep ${aggregate_metadata_key} | grep ${aggregate_metadata_value}"
    environment => $environment,
  }

  exec {'network_hosts_aggregate':
    command     => "nova aggregate-create ${network_hosts_aggregate_name}",
    unless      => "nova aggregate-list | grep ${network_hosts_aggregate_name}",
    environment => $environment,
    require     => Keystone_user_role["${l3_admin_user}@${l3_admin_tenant}"]
  } ->

  exec {'network_hosts_aggregate_metadata':
    command     => "nova aggregate-set-metadata `nova aggregate-list | grep ${network_hosts_aggregate_name} | cut -d ' ' -f 2` ${aggregate_metadata_key}=${aggregate_metadata_value}",
    environment => $environment
  } ->

  #### Add hosts to host-aggregate somehow ####
  exec {'network_hosts_aggregate_populate':
    command     => "for host in ${network_nodes}; do nova aggregate-add-host `nova aggregate-list | grep ${network_hosts_aggregate_name} | cut -d ' ' -f 2` \$host; done;",
    environment => $environment,
    require     => Keystone_user_role["${l3_admin_user}@${l3_admin_tenant}"]
  }

  $csr1k_image_glance_params = '--property hw_vif_model=e1000 --property hw_disk_bus=ide --property hw_cdrom_bus=ide'

  # Glance_image native type doesn't support adding under a different tenant
  exec {'add glance image':
    command     => 'glance image-create --name $csr1k_image_name  --owner $tenant_id --disk-format qcow2 --container-format bare --file $csr1k_image_source $csr1k_image_glance_params',
    environment => $environment,
    unless      => "nova image-list | grep ${csr1k_image_name}",
    require     => Keystone_user_role["${l3_admin_user}@${l3_admin_tenant}"]
  }
}
