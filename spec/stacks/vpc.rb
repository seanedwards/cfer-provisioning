description 'Stack providing a VPC for cfer-provisioning tests'

resource :vpc, 'AWS::EC2::VPC' do
  cidr_block '172.42.0.0/16'
  enable_dns_support true
  enable_dns_hostnames true
  instance_tenancy 'default'
  tag :Name, 'cfer-provisioning test vpc'
end

resource :defaultigw, 'AWS::EC2::InternetGateway'

resource :vpcigw, 'AWS::EC2::VPCGatewayAttachment' do
  vpc_id Fn::ref(:vpc)
  internet_gateway_id Fn::ref(:defaultigw)
end

resource :routetable, 'AWS::EC2::RouteTable' do
  vpc_id Fn::ref(:vpc)
end

resource :subnet, 'AWS::EC2::Subnet' do
  availability_zone Fn::select(0, Fn::get_azs(AWS::region))
  cidr_block "172.42.0.0/24"
  vpc_id Fn::ref(:vpc)
  map_public_ip_on_launch true
end

resource :SRTA, 'AWS::EC2::SubnetRouteTableAssociation' do
  subnet_id Fn::ref(:subnet)
  route_table_id Fn::ref(:routetable)
end

resource :DefaultRoute, 'AWS::EC2::Route', DependsOn: [:vpcigw] do
  route_table_id Fn::ref(:routetable)
  gateway_id Fn::ref(:defaultigw)
  destination_cidr_block '0.0.0.0/0'
end

resource :InstanceRole, "AWS::IAM::Role" do
  assume_role_policy_document Version: "2012-10-17",
    Statement: [ {
      Effect: "Allow",
      Principal: {
        Service: [ "ec2.amazonaws.com" ]
      },
      Action: [ "sts:AssumeRole" ]
    } ]

  policy :describe_cfn do
    allow {
      action [
        'cloudformation:DescribeStacks',
        'cloudformation:DescribeStackEvents',
        'cloudformation:DescribeStackResource',
        'cloudformation:DescribeStackResources'
      ]
      resource '*'
    }
  end

  path '/'
end

resource :InstanceProfile, "AWS::IAM::InstanceProfile" do
  path '/'
  roles [ Fn::ref(:InstanceRole) ]
end

resource :SSHSecurityGroup, 'AWS::EC2::SecurityGroup' do
  group_description 'Allows SSH access for tests'
  vpc_id Fn::ref(:vpc)
  security_group_ingress [22].map { |p|
    {
      CidrIp: '0.0.0.0/0',
      FromPort: p,
      ToPort: p,
      IpProtocol: 'tcp'
    }
  } + [{
    CidrIp: '0.0.0.0/0',
    FromPort: -1,
    ToPort: -1,
    IpProtocol: 'icmp'
  }]
end

output :SecurityGroup, Fn::ref(:SSHSecurityGroup)
output :InstanceProfile, Fn::ref(:InstanceProfile)
output :InstanceRole, Fn::ref(:InstanceRole)
output :Subnet, Fn::ref(:subnet)
output :VpcId, Fn::ref(:vpc)


