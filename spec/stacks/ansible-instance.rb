description 'A simple instance to test ansible provisioning'

include_template('fragments/vpc.rb')

parameter :FileContents, Default: 'Hello World!!'

resource :EC2Instance, 'AWS::EC2::Instance', CreationPolicy: {
    ResourceSignal: {
      Count: 1,
      Timeout: 'PT10M'
    }
  } do

  ansible_setup play: {
    vars: {
      hello_world: Fn::ref(:FileContents)
    },
    tasks: [
      {
        name: 'write hello world',
        copy: {
          dest: '/home/ubuntu/test.txt',
          content: '{{hello_world}}'
        }
      }
    ]
  }

  cfn_init_setup signal: :EC2Instance,
    cfn_init_config_set: [ :cfn_hup, :run_ansible ],
    cfn_hup_config_set: [ :cfn_hup, :run_ansible ]

  image_id Fn::ref(:ImageId)
  instance_type Fn::ref(:InstanceType)
  iam_instance_profile VPC[:InstanceProfile]
  key_name (parameters[:SSHKey] || raise("Please specify `SSHKey` in parameters.yml"))
  subnet_id VPC[:Subnet]
  security_group_ids [ VPC[:SecurityGroup] ]

  tag :Name, AWS::stack_name
end

output :IpAddress, Fn::get_att(:EC2Instance, :PublicIp)


