require 'cfer/provisioning'

VPC = lookup_outputs('cfer-provisioning-vpc')

# This is the Ubuntu 14.04 LTS HVM AMI provided by Amazon.
parameter :ImageId, default: 'ami-2d39803a'
parameter :InstanceType, default: 't2.nano'


