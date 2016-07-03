require 'yaml'

module Cfer::Provisioning
  def cloud_init
    unless self.key?(:CloudInit)
      self[:CloudInit] = {
        bootcmd: [],
        runcmd: [],
        packages: [],
        ssh_authorized_keys: [],
        write_files: [
          {
            path: '/etc/cfn-resource-name',
            permissions: '0444',
            content: @name.to_s
          },
          {
            path: '/etc/cfn-stack-name',
            permissions: '0444',
            content: 'C{AWS.stack_name}'
          },
          {
            path: '/etc/cfn-region',
            permissions: '0444',
            content: 'C{AWS.region}'
          }
        ],
        output: {}
      }
    end

    self[:CloudInit]
  end

  def cloud_init_bootcmds
    cloud_init[:bootcmd]
  end

  def cloud_init_runcmds
    cloud_init[:runcmd]
  end

  def cloud_init_outputs
    cloud_init[:output]
  end

  def cloud_init_packages
    cloud_init[:packages]
  end

  def cloud_init_write_files
    cloud_init[:write_files]
  end

  def cloud_init_ssh_authorized_keys
    cloud_init[:ssh_authorized_keys]
  end

  def cloud_init_finalize!
    cloud_init_outputs[:all] ||= "| tee -a /var/log/cloud-init-output.log"

    user_data Cfer::Core::Fn.base64( cloud_init_to_user_data(self[:CloudInit]) )
    self.delete :CloudInit
  end

  private
  def cloud_init_to_user_data(cloud_init)

    Cfer.cfize([
      '#cloud-config',
      YAML.dump(cloud_init.to_hash_recursive.deep_stringify_keys).gsub(/^---$/, "")
    ].join("\n"))
  end

end
