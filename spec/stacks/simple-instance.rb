description 'A simple instance to test cfn-init and cfn-hup'

VPC = lookup_outputs(VPC_STACK_NAME)

# This is the Ubuntu 14.04 LTS HVM AMI provided by Amazon.
parameter :ImageId, default: 'ami-fce3c696'
parameter :InstanceType, default: 't2.nano'


resource :EC2Instance, 'AWS::EC2::Instance', CreationPolicy: {
    ResourceSignal: {
      Count: 1,
      Timeout: 'PT5M'
    }
  } do

  cfn_init_setup signal: :EC2Instance,
    cfn_init_config_set: [ :cfn_hup, :provision ],
    cfn_hup_config_set: [ :cfn_hup, :provision ]

  cfn_init_config_set :provision, [ :provision_file ]

  cfn_init_config :provision_file do
    file '/home/ubuntu/test.txt', content: parameters[:FileContents]
  end

  image_id Fn::ref(:ImageId)
  instance_type Fn::ref(:InstanceType)
  iam_instance_profile VPC[:InstanceProfile]
  key_name 'SeniorlinkMBP'
  subnet_id VPC[:Subnet]
  security_group_ids [ VPC[:SecurityGroup] ]
end

output :IpAddress, Fn::get_att(:EC2Instance, :PublicIp)


