require 'spec_helper'

describe 'cloudinit_instance' do
  with_stack self, 'cloudinit-instance', 'spec/stacks/cloudinit-instance.rb', FileContents: "Hello, cloud-init!"

  describe file('/home/ubuntu/test.txt') do
    it { should be_file }
    it { should contain 'Hello, cloud-init!' }
  end
end


