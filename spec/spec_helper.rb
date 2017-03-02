$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'serverspec'
require 'cfer'
require 'cfer/provisioning'

set :backend, :ssh

ssh_options = {:user => 'ubuntu'}
ssh_options.merge! keys: [ ENV['CI_SSH_KEY'] ] if ENV['CI_SSH_KEY']
set :ssh_options, ssh_options

VPC_STACK_NAME = 'cfer-provisioning-vpc'

KEEP_STACK = ENV['KEEP_STACK']

def with_stack(caller_self, stack_name, file_name, parameters = {})
  stack_name =
    if KEEP_STACK
      "cfer-provisioning-#{stack_name}"
    else
      "cfer-provisioning-#{stack_name}-#{SecureRandom.uuid}"
    end

  caller_self.before(:all) do
    puts "Converging #{stack_name}"
    Cfer.converge! stack_name, template: file_name,
      follow: true, number: 0, backoff: 2, backoff_max_wait: 60,
      parameter_file: ENV['CI_PARAMETERS_YAML'] || 'parameters.yaml',
      parameters: parameters
    set :host, Cfer::Cfn::Client.new(stack_name: stack_name).fetch_outputs[:IpAddress]
  end

  caller_self.after(:all) do
    unless KEEP_STACK
      puts "Deleting #{stack_name}"
      Cfer.delete! stack_name
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    puts "Converging VPC"
    Cfer.converge! VPC_STACK_NAME,
      template: 'spec/stacks/vpc.rb',
      follow: true, number: 0, backoff: 2, backoff_max_wait: 60,
      parameter_file: ENV['CI_PARAMETERS_YAML'] || 'parameters.yaml'
  end
end

