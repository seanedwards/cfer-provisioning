$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'serverspec'
require 'cfer'
require 'cfer/provisioning'
require 'pry-byebug'

set :backend, :ssh
set :ssh_options, :user => 'ubuntu'

VPC_STACK_NAME = 'cfer-provisioning-vpc'

def with_stack(caller_self, stack_name, file_name, parameters = {})
  stack_name = "cfer-provisioning-#{stack_name}-#{SecureRandom.uuid}"

  caller_self.before(:all) do
    puts "Converging #{stack_name}"
    Cfer.converge! stack_name, template: file_name, follow: true, number: 0,
      parameter_file: 'parameters.yaml',
      parameters: parameters
    set :host, Cfer::Cfn::Client.new(stack_name: stack_name).fetch_outputs[:IpAddress]
  end

  caller_self.after(:all) do
    puts "Deleting #{stack_name}"
    Cfer.delete! stack_name
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    puts "Converging VPC"
    Cfer.converge! VPC_STACK_NAME,
      template: 'spec/stacks/vpc.rb',
      follow: true,
      number: 0,
      parameter_file: 'parameters.yaml'
  end

  config.after(:suite) do
    #Cfer.delete! VPC_STACK_NAME, follow: true, number: 0 unless ENV['KEEP_STACK']
  end
end

