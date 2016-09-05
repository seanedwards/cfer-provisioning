require 'spec_helper'

describe 'cfn_instance' do
  with_stack(self, 'cfn-instance', 'spec/stacks/cfn-instance.rb', FileContents: "Hello, cfn-init!")

  describe file('/home/ubuntu/test.txt') do
    it { should be_file }
    it { should contain 'Hello, cfn-init!' }
  end

  describe process('cfn-hup') do
    it { should be_running }
    its(:count) { should eq 1 }
  end
end


