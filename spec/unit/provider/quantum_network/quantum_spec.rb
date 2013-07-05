require 'puppet'
require 'spec_helper'
require 'puppet/provider/quantum_network/quantum'

provider_class = Puppet::Type.type(:quantum_network).provider(:quantum)

describe provider_class do

  let :net_name do
    'net1'
  end

  let :net_attrs do
    {
      :name            => net_name,
      :ensure          => 'present',
      :admin_state_up  => 'True',
      :router_external => 'False',
      :shared          => 'False',
      :tenant_id       => '',
    }
  end

  let :instance_hash do
    { net_name => net_attrs }
  end

  describe 'when updating a network' do
    let :resource do
      Puppet::Type::Quantum_network.new(net_attrs)
    end

    let :provider do
      provider_class.new(resource)
    end

    it 'should call net-update to change admin_state_up' do
      provider.expects(:instance_hash).returns(instance_hash)
      provider.expects(:auth_quantum).with('net-update',
                                           '--admin_state_up=False',
                                           net_name)
      provider.admin_state_up=('False')
    end

    it 'should call net-update to change shared' do
      provider.expects(:instance_hash).returns(instance_hash)
      provider.expects(:auth_quantum).with('net-update',
                                           '--shared=True',
                                           net_name)
      provider.shared=('True')
    end

    it 'should call net-update to change router_external' do
      provider.expects(:instance_hash).returns(instance_hash)
      provider.expects(:auth_quantum).with('net-update',
                                           '--router:external=True',
                                           net_name)
      provider.router_external=('True')
    end

    [:provider_network_type, :provider_physical_network, :provider_segmentation_id].each do |attr|
      it "should fail when #{attr.to_s} is update " do
        expect do
          provider.send("#{attr}=", 'foo')
        end.to raise_error(Puppet::Error, /does not support being updated/)
      end
    end

  end

end
