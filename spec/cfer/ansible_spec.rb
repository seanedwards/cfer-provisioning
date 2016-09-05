require 'spec_helper'

describe 'ansible_instance' do
  with_stack(self, 'ansible-instance', 'spec/stacks/ansible-instance.rb', FileContents: "Hello, ansible!")

  describe file('/home/ubuntu/test.txt') do
    it { should be_file }
    it { should contain 'Hello, ansible!' }
  end

  describe process('cfn-hup') do
    it { should be_running }
    its(:count) { should eq 1 }
  end
end


