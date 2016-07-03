require "cfer/provisioning/version"
require "cfer/cfizer"
require 'cfer'

require 'base64'
require 'yaml'

module Cfer
  module Provisioning
  end
end

require 'cfer/provisioning/extensions'

require 'cfer/provisioning/cloud-init'
require 'cfer/provisioning/cfn-bootstrap'
require 'cfer/provisioning/chef'

Cfer::Core::Resource.extend_resource "AWS::EC2::Instance" do
  include Cfer::Provisioning
end

Cfer::Core::Resource.extend_resource "AWS::AutoScaling::LaunchConfiguration" do
  include Cfer::Provisioning
end

