require File.join(File.dirname(__FILE__), '..','..','..',
                  'puppet/provider/quantum')

Puppet::Type.type(:quantum_router_interface).provide(
  :quantum,
  :parent => Puppet::Provider::Quantum
) do
  desc <<-EOT
    Quantum provider to manage quantum_router_interface type.

    Assumes that the quantum service is configured on the same host.

    It is not possible to manage an interface for the subnet used by
    the gateway network, and such an interface will appear in the list
    of resources ('puppet resource [type]').  Attempting to manage the
    gateway interfae will result in an error.

  EOT

  commands :quantum => 'quantum'


  def self.prefetch(resources)
    # rebuild the cache for every puppet run
    @instance_cache = nil
  end

  def self.instance_hash
    @instance_hash ||= build_instance_hash
  end

  def instance_hash
    self.class.instance_hash
  end

  def instance
    instance_hash[resource[:name]]
  end

  def self.instances
    instance_hash.collect do |k, v|
      new(
          :name => k,
          :id   => v[:id]
          )
    end
  end

  def self.build_instance_hash
    hash = {}
    subnet_name_hash = {}
    Puppet::Type.type('quantum_subnet').instances.each do |instance|
      subnet_name_hash[instance.provider.id] = instance.provider.name
    end
    Puppet::Type.type('quantum_router').instances.each do |instance|
      list_router_ports(instance.provider.id).each do |port_hash|
        router_name = instance.provider.name
        subnet_name = subnet_name_hash[port_hash['subnet_id']]
        name = "#{router_name}:#{subnet_name}"
        hash[name] = {
          :ensure => :present,
          :name   => name,
          :id     => port_hash['id']
        }
      end
    end
    hash
  end

  def exists?
    instance
  end

  def create
    results = auth_quantum("router-interface-add", '--format=shell',
                           resource[:name].split(':', 2))

    if results =~ /Added interface to router/
      instance_hash[resource[:name]] = {
        :ensure => :present,
        :name   => resource[:name],
      }
    else
      fail("did not get expected message on interface addition, got #{results}")
    end
  end

  def router_name
    name.split(':', 2).first
  end

  def subnet_name
    name.split(':', 2).last
  end

  def id
    # TODO: Need to look this up for newly-added resources since it is
    # not returned on creation
    :absent
  end

  def destroy
    auth_quantum('router-interface-delete', router_name, subnet_name)
    instance[:ensure] = :absent
  end

end
