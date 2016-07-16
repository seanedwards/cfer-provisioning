require 'erubis'

module Cfer::Provisioning
  DEFAULT_HUP_INTERVAL_IN_MINUTES = 5

  def cfn_metadata
    self[:Metadata] ||= {}
  end

  def cfn_auth(name, options = {})
    cfn_metadata['AWS::CloudFormation::Authentication'] ||= {}
    cfn_metadata['AWS::CloudFormation::Authentication'][name] = options
  end

  def cfn_init_setup(options = {})
    cfn_metadata['AWS::CloudFormation::Init'] = {}
    cfn_init_set_cloud_init(options)

    if options[:cfn_hup_config_set]
      cfn_hup(options)
    end
  end

  def config_set(name)
    { "ConfigSet" => name }
  end

  def cfn_init_config_set(name, sections)
    cfg_sets = cloudformation_init['configSets'] || { 'default' => [] }
    cfg_set = Set.new(cfg_sets[name] || [])
    cfg_set.merge sections
    cfg_sets[name] = cfg_set.to_a
    cloudformation_init['configSets'] = cfg_sets
  end

  def cfn_init_config(name, options = {}, &block)
    cfg = ConfigSet.new(cloudformation_init[name])
    Docile.dsl_eval(cfg, &block)
    cloudformation_init[name] = cfg.to_h
  end

  private

  class ConfigSet
    def initialize(hash)
      @config_set = hash || {}
    end

    def to_h
      @config_set
    end

    def commands
      @config_set['commands'] ||= {}
    end

    def files
      @config_set['files'] ||= {}
    end

    def packages
      @config_set['packages'] ||= {}
    end

    def command(name, cmd, options = {})
      commands[name] = options.merge('command' => cmd)
    end

    def file(path, options = {})
      files[path] = options
    end

    def package(type, name, versions = [])
      packages[type] ||= {}
      packages[type][name] = versions
    end
  end

  def cloudformation_init(options = {})
    cfn_metadata['AWS::CloudFormation::Init'] ||= {}
  end


  def cfn_hup(options)
    resource_name = @name
    target_config_set = options[:cfn_hup_config_set] ||
      raise('Please specify a `cfn_hup_config_set`')

    cfn_init_config_set :cfn_hup, [ :cfn_hup ]

    cfn_init_config(:cfn_hup) do
      if options[:access_key] && options[:secret_key]
        key_content = <<-FILE.strip_heredoc
          AWSAccessKeyId=#{options[:access_key]}
          AWSSecretKey=#{options[:secret_key]}
        FILE

        file '/etc/cfn/cfn-credentials', content: key_content,
          mode: '000400', owner: 'root', group: 'root'
      end

      hup_conf_content = <<-FILE.strip_heredoc
        [main]
        stack=C{AWS.stack_name}
        region=C{AWS.region}
        interval=#{options[:hup_interval] || DEFAULT_HUP_INTERVAL_IN_MINUTES}
      FILE
      file '/etc/cfn/cfn-hup.conf', content: Cfer.cfize(hup_conf_content),
        mode: '000400', owner: 'root', group: 'root'

      cfn_init_reload_content = <<-FILE.strip_heredoc
        [cfn-auto-reloader-hook]
        triggers=post.update
        path=Resources.#{resource_name}.Metadata
        runas=root
        action=/usr/local/bin/cfn-init -r #{resource_name} --region C{AWS.region} -s C{AWS.stack_name} -c '#{target_config_set.join(",")}'
      FILE

      file '/etc/cfn/hooks.d/cfn-init-reload.conf',
        content: Cfer.cfize(cfn_init_reload_content),
        mode: '000400', owner: 'root', group: 'root'
    end
  end

  def cfn_init_set_cloud_init(options)
    cloud_init_bootcmds << "mkdir -p /usr/local/bin"

    case options[:flavor]
    when :redhat, :centos, :amazon
      cloud_init_bootcmds <<
        'rpm -Uvh https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm'
    when :debian, :ubuntu, nil
      [
        'apt-get update --fix-missing',
        'apt-get install -y python-pip',
        'pip install setuptools',
        'easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz'
      ].each { |line| cloud_init_bootcmds << line }
    end

    cfn_script_eruby = Erubis::Eruby.new(IO.read("#{__dir__}/cfn-bootstrap.bash.erb"))

    cloud_init_write_files << {
      path: '/usr/local/bin/cfn-bootstrap.bash',
      content: cfn_script_eruby.evaluate(resource_name: @name, options: options)
    }

    cloud_init_runcmds << "bash /usr/local/bin/cfn-bootstrap.bash"
  end
end

