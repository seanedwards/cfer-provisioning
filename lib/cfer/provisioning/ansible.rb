module Cfer::Provisioning

  def ansible_setup(options = {})

    options[:ansible_path] ||= '/etc/ansible'
    options[:ansible_log] ||= '/var/log/ansible.log'

    cloud_init_packages << 'ansible'

    cloud_init_bootcmds << "mkdir -p '#{options[:ansible_path]}'"

    run_set = []

    add_write_ansible_playbook(options)
    run_set << :write_ansible_playbook

    cfn_init_config :run_ansible_playbook do
      command :run_ansible, "ansible-playbook '#{options[:ansible_path]}/playbook.yml' | tee '#{options[:ansible_log]}'"
    end
    run_set << :run_ansible_playbook

    cfn_init_config_set :run_ansible, run_set
  end

  private
  def add_write_ansible_playbook(options)
    resource_name = @name
    play = options[:play] || Hash.new
    cfn_metadata['Cfer::Ansible::Init'] = [{
      hosts: 'all'
    }.merge(play)]

    cfn_init_config :write_ansible_playbook do
      file "#{options[:ansible_path]}/hosts", content: "localhost ansible_connection=local"

      command :download_ansible_playbook, Cfer::Core::Functions::Fn::join('', [
        "cfn-get-metadata ",
        "--region '", Cfer::Core::Functions::AWS::region, "' ",
        "--stack '", Cfer::Core::Functions::AWS::stack_name, "' ",
        "--resource '#{resource_name}' ",
        "--key 'Cfer::Ansible::Init'",
        " | tee '#{options[:ansible_path]}/playbook.yml'"
      ])
    end
  end

end

