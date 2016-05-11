$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'serverspec'
require 'cfer'
require 'cfer/provisioning'
require 'pry'

set :backend, :ssh
set :ssh_options, :user => 'ubuntu'

VPC_STACK_NAME = 'cfer-provisioning-vpc'

RSpec.configure do |config|
  config.before(:suite) do
    puts "Converging VPC"
    Cfer.converge! VPC_STACK_NAME, template: 'spec/stacks/vpc.rb', follow: true, number: 0
  end

  config.after(:suite) do
    #Cfer.delete! VPC_STACK_NAME, follow: true, number: 0
  end
end

