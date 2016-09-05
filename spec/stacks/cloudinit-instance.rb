description 'A simple instance to test cfn-init and cfn-hup'

include_template('fragments/vpc.rb')

resource :EC2Instance, 'AWS::EC2::Instance', CreationPolicy: {
    ResourceSignal: {
      Count: 1,
      Timeout: 'PT5M'
    }
  } do
  cfn_init_setup signal: :EC2Instance

  cloud_init_write_files << {
    path: '/home/ubuntu/test.txt',
    content: parameters[:FileContents]
  }

  image_id Fn::ref(:ImageId)
  instance_type Fn::ref(:InstanceType)
  iam_instance_profile VPC[:InstanceProfile]
  key_name (parameters[:SSHKey] || raise("Please specify `SSHKey` in parameters.yml"))
  subnet_id VPC[:Subnet]
  security_group_ids [ VPC[:SecurityGroup] ]

  tag :Name, AWS::stack_name
end

output :IpAddress, Fn::get_att(:EC2Instance, :PublicIp)


