module Cfer::Provisioning
  def install_chef_with_cloud_init(options = {})
    # we can't use the cloud-init `chef` module because it expects a server/validator.

    cloud_init_bootcmds <<
      "command -v chef-client || " \
        "curl https://www.opscode.com/chef/install.sh | " \
          "bash -s -- -v #{options[:version] || 'latest'}"
    cloud_init_bootcmds << "mkdir -p /etc/chef/ohai/hints"
    cloud_init_bootcmds << "touch /etc/chef/ohai/hints/ec2.json"
    cloud_init_bootcmds << "mkdir -p '#{options[:cookbook_path]}'"
    cloud_init_bootcmds << "mkdir -p '#{options[:data_bag_path]}'"
  end

  def install_berkshelf(options)
    cloud_init_packages << 'git'

    cloud_init_bootcmds << '/opt/chef/embedded/bin/gem install berkshelf --no-ri --no-rdoc'

    berks_content = <<-EOF.strip_heredoc
        # may be run before HOME is established (fixes RbReadLine bug)
        export HOME=/root
        export BERKSHELF_PATH=/var/chef/berkshelf

        # Some cookbooks have UTF-8, and cfn-init uses US-ASCII because of reasons
        export LANG=en_US.UTF-8
        export RUBYOPTS="-E utf-8"

        set -e
        [ -f /opt/chef/embedded/bin/berks ] || /opt/chef/embedded/bin/gem install berkshelf
        set +e

        # Berkshelf seems a bit unreliable, so retry these commands a couple times.
        if [ -e Berksfile.lock ]
        then
          for i in {1..3}; do
            /opt/chef/embedded/bin/berks update && break || sleep 15
          done
        fi
        for i in {1..3}; do
          /opt/chef/embedded/bin/berks vendor '#{options[:cookbook_path]}' \
            -b /var/chef/Berksfile && break || sleep 15
        done
      EOF

    cloud_init_write_files << {
      path: '/var/chef/berkshelf.sh',
      content: berks_content,
      permissions: '0500'
    }
  end

  def emit_berksfile(options)
    cfn_init_config :emit_berksfile do
      file '/var/chef/Berksfile', content: Cfer.cfize(options[:berksfile].strip_heredoc),
        mode: '000500', owner: 'root', group: 'root'
    end
  end

  def run_berkshelf(options)
    cfn_init_config :run_berkshelf do
      command :run_berkshelf, '/var/chef/berkshelf.sh', cwd: '/var/chef'
    end
  end

  def build_write_json_cmd(chef_solo_json_path)
    python_json_dump = [
      'import sys; import json;',
      'print json.dumps(json.loads(sys.stdin.read())',
      '.get("CferExt::Provisioning::Chef", {}), sort_keys=True, indent=2)'
    ].join('')

    cmd = <<-BASH.strip_heredoc
      mkdir -p '#{File.dirname(chef_solo_json_path)}' &&
        cfn-get-metadata --region 'C{AWS.region}' \
                         -s 'C{AWS.stack_name}' \
                         -r #{@name} |
        python -c '#{python_json_dump}' > #{chef_solo_json_path}
    BASH

    Cfer.cfize(cmd)
  end

  def chef_client(options = {})
    raise "Chef already configured on this resource" if @chef
    @chef = true

    raise "must specify chef_server_url" if options[:chef_server_url].nil?
    raise "must specify validation_client_name" if options[:validation_client_name].nil?

    options[:config_path] ||= '/etc/chef/client.rb'
    options[:json_path] ||= '/etc/chef/node.json'
    options[:cookbook_path] ||= '/var/chef/cookbooks'
    options[:data_bag_path] ||= '/var/chef/data_bags'
    options[:log_path] ||= '/var/log/chef-client.log'

    options[:service_type] ||= :upstart

    run_set = []

    install_chef_with_cloud_init(options) unless options[:no_install]

    add_write_chef_json(options)
    run_set << :write_chef_json

    cfn_init_config :run_chef_client do
      client_rb = Erubis::Eruby.new(IO.read("#{__dir__}/client.rb.erb")).result(options: options)

      file options[:config_path], content: Cfer.cfize(options[:client_rb] || client_rb),
        mode: '000400', owner: 'root', group: 'root'

      command :'00_run_chef_once', 'chef-client --once'
    end
    run_set << :run_chef_client

    cfn_init_config_set :run_chef_client, run_set
  end

  def chef_solo(options = {})
    raise "Chef already configured on this resource" if @chef
    @chef = true

    must_install_berkshelf = !options[:berksfile].nil? || options[:force_berkshelf_install]

    options[:config_path] ||= '/etc/chef/solo.rb'
    options[:json_path] ||= '/etc/chef/node.json'
    options[:cookbook_path] ||= '/var/chef/cookbooks'
    options[:data_bag_path] ||= '/var/chef/data_bags'
    options[:log_path] ||= '/var/log/chef-solo.log'

    install_chef_with_cloud_init(options) unless options[:no_install]

    if must_install_berkshelf
      install_berkshelf(options) if must_install_berkshelf # places cloud-init runners
    end

    run_set = []

    unless options[:berksfile].nil?
      emit_berksfile(options)
      run_set << :emit_berksfile
    end

    unless options[:berksfile].nil? || options[:no_run_berkshelf]
      run_berkshelf(options)
      run_set << :run_berkshelf
    end

    add_write_chef_json(options)
    run_set << :write_chef_json

    cfn_init_config :run_chef_solo do
      solo_rb = <<-RB.strip_heredoc
        cookbook_path '#{options[:cookbook_path]}'
        log_location '#{options[:log_path]}'

        json_attribs '#{options[:json_path]}'
      RB

      file options[:config_path], content: options[:solo_rb] || solo_rb,
        mode: '000400', owner: 'root', group: 'root'

      command :run_chef, 'chef-solo'
    end
    run_set << :run_chef_solo

    cfn_init_config_set :run_chef_solo, run_set
  end

  private
  def add_write_chef_json(options)
    options[:run_list] ||= []
    options[:json] ||= {}

    cfn_metadata['CferExt::Provisioning::Chef'] = options[:json].merge(run_list: options[:run_list])
    cfn_init_config :write_chef_json do
      command :write_chef_json, build_write_json_cmd(options[:json_path])
    end
  end
end

