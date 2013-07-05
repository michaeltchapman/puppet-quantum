require File.join(File.dirname(__FILE__), '..','..','..',
                  'puppet/provider/quantum')

Puppet::Type.type(:quantum_network).provide(
  :quantum,
  :parent => Puppet::Provider::Quantum
) do
  desc <<-EOT
    Quantum provider to manage quantum_network type.

    Assumes that the quantum service is configured on the same host.
  EOT

  commands :quantum => 'quantum'

  def self.has_provider_extension?
    list_quantum_extensions.include?('provider')
  end

  def has_provider_extension?
    self.class.has_provider_extension?
  end

  has_feature :provider_extension if has_provider_extension?

  def self.has_router_extension?
    list_quantum_extensions.include?('router')
  end

  def has_router_extension?
    self.class.has_router_extension?
  end

  has_feature :router_extension if has_router_extension?

  def self.prefetch(resources)
    # rebuild the cache for every puppet run
    @instance_hash = nil
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
    quantum_type = 'net'
    list_quantum_resources(quantum_type).collect do |id|
      attrs = get_quantum_resource_attrs(quantum_type, id)
      hash[attrs['name']] = {
        :ensure                    => :present,
        :name                      => attrs['name'],
        :id                        => attrs['id'],
        :admin_state_up            => attrs['admin_state_up'],
        :provider_network_type     => attrs['provider:network_type'],
        :provider_physical_network => attrs['provider:physical_network'],
        :provider_segmentation_id  => attrs['provider:segmentation_id'],
        :router_external           => attrs['router:external'],
        :shared                    => attrs['shared'],
        :tenant_id                 => attrs['tenant_id']
      }
    end
    hash
  end

  def exists?
    instance
  end

  def create
    network_opts = Array.new

    if @resource[:shared]
      network_opts << '--shared'
    end

    if @resource[:tenant_name]
      tenant_id = self.class.get_tenant_id(model.catalog,
                                           @resource[:tenant_name])
      network_opts << "--tenant_id=#{tenant_id}"
    elsif @resource[:tenant_id]
      network_opts << "--tenant_id=#{@resource[:tenant_id]}"
    end

    if @resource[:provider_network_type]
      network_opts << \
        "--provider:network_type=#{@resource[:provider_network_type]}"
    end

    if @resource[:provider_physical_network]
      network_opts << \
        "--provider:physical_network=#{@resource[:provider_physical_network]}"
    end

    if @resource[:provider_segmentation_id]
      network_opts << \
        "--provider:segmentation_id=#{@resource[:provider_segmentation_id]}"
    end

    if @resource[:router_external]
      network_opts << "--router:external=#{@resource[:router_external]}"
    end

    results = auth_quantum('net-create', '--format=shell',
                           network_opts, resource[:name])

    if results =~ /Created a new network:/
      attrs = self.class.parse_creation_output(results)
      instance_hash[resource[:name]] = {
        :ensure                    => :present,
        :name                      => resource[:name],
        :id                        => attrs['id'],
        :admin_state_up            => attrs['admin_state_up'],
        :provider_network_type     => attrs['provider:network_type'],
        :provider_physical_network => attrs['provider:physical_network'],
        :provider_segmentation_id  => attrs['provider:segmentation_id'],
        :router_external           => attrs['router:external'],
        :shared                    => attrs['shared'],
        :tenant_id                 => attrs['tenant_id'],
      }
    else
      fail("did not get expected message on network creation, got #{results}")
    end
  end

  def destroy
    auth_quantum('net-delete', name)
    instance[:ensure] = :absent
  end

  def admin_state_up=(value)
    auth_quantum('net-update', "--admin_state_up=#{value}", name)
    instance[:admin_state_up] = value
  end

  def shared=(value)
    auth_quantum('net-update', "--shared=#{value}", name)
    instance[:shared] = value
  end

  def router_external=(value)
    auth_quantum('net-update', "--router:external=#{value}", name)
    instance[:router_external] = value
  end

  [
   :id,
   :admin_state_up,
   :shared,
   :router_external,
   :tenant_id,
  ].each do |attr|
    define_method(attr.to_s) do
      instance[attr] || :absent
    end
  end

  [
   :provider_network_type,
   :provider_physical_network,
   :provider_segmentation_id,
   :tenant_id,
  ].each do |attr|
    define_method(attr.to_s + "=") do |value|
      fail("Property #{attr.to_s} does not support being updated")
    end
  end

end
