require 'spec_helper'

SIMPLE_STACK_NAME = 'cfer-provisioning-simple-' + SecureRandom.uuid

describe 'simple_instance' do
  before(:all) do
    puts "Converging simple instance"
    Cfer.converge! SIMPLE_STACK_NAME, template: 'spec/stacks/simple-instance.rb', follow: true, number: 0,
      parameter_file: 'parameters.yaml',
      parameters: {
        FileContents: "Hello, world!"
      }
    set :host, Cfer::Cfn::Client.new(stack_name: SIMPLE_STACK_NAME).fetch_outputs[:IpAddress]
  end

  after(:all) do
    Cfer.delete! SIMPLE_STACK_NAME
  end

  describe file('/home/ubuntu/test.txt') do
    it { should be_file }
    it { should contain 'Hello, world!' }
  end

  describe process('cfn-hup') do
    it { should be_running }
    its(:count) { should eq 1 }
  end
end


