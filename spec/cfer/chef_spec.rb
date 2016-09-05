require 'spec_helper'

describe 'chef_instance' do
  with_stack(self, 'chef-instance', 'spec/stacks/chef-instance.rb')

  describe process('nginx') do
    it { should be_running }
  end
end


