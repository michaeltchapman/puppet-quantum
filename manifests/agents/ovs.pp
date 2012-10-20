class quantum::agents::ovs (
  $package_ensure       = true,
  $enabled              = true,

  $bridge_uplinks       = ['br-virtual:eth1'],
  $bridge_mappings      = ['default:br-virtual'],
  $integration_bridge   = 'br-int',
  $enable_tunneling     = true,
  $tunnel_bridge        = 'br-tun'
) {
  include 'quantun::params'

  require 'vswitch::ovs'

  Package['quantum'] ->  Package['quantum-plugin-ovs-agent']
  Package['quantum-plugin-ovs-agent'] -> Quantum_plugin_ovs<||>

  vs_bridge {$integration_bridge:
    external_ids => 'bridge-id=$ingration_bridge',
    ensure       => present,
    require      => Service['quantum-plugin-ovs-service'],
  }

  if $enable_tunneling {
    vs_bridge {$tunnel_bridge:
      external_ids => 'bridge-id=$tunnel_bridge',
      ensure       => present,
      require      => Service['quantum-plugin-ovs-service'],
    }
  }

  quantum::plugins::ovs::bridge{$bridge_mappings:
    require      => Service['quantum-plugin-ovs-service'],
  }
  quantum::plugins::ovs::port{$bridge_uplinks:
    require      => Service['quantum-plugin-ovs-service'],
  }

  package { 'quantum-plugin-ovs-agent':
    name    => $::quantum::params::ovs_agent_package,
    ensure  => $package_ensure,
  }

  if $enabled {
    $service_ensure = 'running'
  } else {
    $service_ensure = 'stopped'
  }

  service { 'quantum-plugin-ovs-service':
    name    => $::quantum::params::ovs_agent_service,
    enable  => $enable,
    ensure  => $service_ensure,
    require => [Package['quantum-plugin-ovs-agent']]
  }
}