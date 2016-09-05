description 'A simple instance to test chef provisioning'
include_template('fragments/vpc.rb')

resource :EC2Instance, 'AWS::EC2::Instance', CreationPolicy: {
    ResourceSignal: {
      Count: 1,
      Timeout: 'PT10M'
    }
  } do


  berksfile = <<-BERKS.strip_heredoc
    source 'https://supermarket.chef.io'

    cookbook 'nginx', '~> 2.7.6'
  BERKS

  chef_solo \
    berksfile: berksfile,
    berkshelf_version: '~> 4.3',
    run_list: [ 'nginx::default' ],
    json: {
      foo: 'bar',
      baz: 5
    }

  cfn_init_setup signal: :EC2Instance,
    cfn_init_config_set: [ :cfn_hup, :run_chef_solo ],
    cfn_hup_config_set: [ :cfn_hup, :run_chef_solo ]

  image_id Fn::ref(:ImageId)
  instance_type Fn::ref(:InstanceType)
  iam_instance_profile VPC[:InstanceProfile]
  key_name (parameters[:SSHKey] || raise("Please specify `SSHKey` in parameters.yml"))
  subnet_id VPC[:Subnet]
  security_group_ids [ VPC[:SecurityGroup] ]

  tag :Name, AWS::stack_name
end

output :IpAddress, Fn::get_att(:EC2Instance, :PublicIp)


