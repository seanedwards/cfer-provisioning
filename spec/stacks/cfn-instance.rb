description 'A simple instance to test cloud-init'

include_template('fragments/vpc.rb')

resource :EC2Instance, 'AWS::EC2::Instance', CreationPolicy: {
    ResourceSignal: {
      Count: 1,
      Timeout: 'PT10M'
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
  key_name (parameters[:SSHKey] || raise("Please specify `SSHKey` in parameters.yml"))
  subnet_id VPC[:Subnet]
  security_group_ids [ VPC[:SecurityGroup] ]

  tag :Name, AWS::stack_name
end

output :IpAddress, Fn::get_att(:EC2Instance, :PublicIp)


