require 'inifile'

module Cfer::Provisioning

  def install_ansible(options = {})
    cfn_init_config :install_ansible do
      command :install_ansible, "pip install ansible"
    end

    cfn_init_config_set :install_ansible, [ :install_ansible ]
  end

  def set_ansible_playbook(yml = {})
    self[:Metadata]['CferExt::Provisioning::Ansible'] = [ (yml || {}).merge(hosts: 'localhost') ]
  end

  def build_write_playbook_cmd(ansible_playbook_path)
    Cfer::Core::Fn.join('', [
      "mkdir -p #{File.dirname(ansible_playbook_path)} && cfn-get-metadata --region ",
        Cfer::Cfn::AWS.region,
        ' -s ', Cfer::Cfn::AWS.stack_name, ' -r ', @name,
        " | python -c 'import sys; import yaml; print " \
          "yaml.dump(yaml.load(sys.stdin.read()).get(" \
          '"CferExt::Provisioning::Ansible",  {}))',
        "' > #{ansible_playbook_path}"
    ])
  end

  def ansible_playbook(options = {})
    raise "Ansible already configured on this resource" if @ansible
    @ansible = true

    ansible_config_dir = options[:ansible_config_dir] || '/etc/ansible'
    chef_log_path = options[:log_path] || "/var/log/ansible.log"

    set_ansible_playbook(options[:playbook])
    write_playbook_cmd = build_write_playbook_cmd("#{ansible_config_dir}/playbook.yml")

    cfn_init_config :write_ansible_config do
      file "#{ansible_config_dir}/hosts", content: <<-EOF.strip_heredoc
        [targets]
        localhost ansible_connection=local
      EOF

      file "#{ansible_config_dir}/ansible.cfg", content: <<-EOF.strip_heredoc
      EOF

      command :write_ansible_playbook, write_playbook_cmd
    end

    ansible_cmd = "ansible-playbook #{ansible_playbook_path}"
    cfn_init_config :run_ansible, ansible_cmd

    run_set = [ :write_ansible_config, :run_ansible ]
    cfn_init_config_set :run_ansible, run_set
  end

end

