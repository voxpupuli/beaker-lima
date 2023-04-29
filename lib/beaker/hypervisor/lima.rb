# frozen_string_literal: true

module Beaker
  # beaker extenstion to manage Lima VMs: https://github.com/lima-vm/lima
  class Lima < Beaker::Hypervisor
    # @param [Host, Array<Host>, String, Symbol] hosts One or more hosts to act
    # upon, or a role (String or Symbol) that identifies one or more hosts.
    # @param [Hash{Symbol=>String}] options Options to pass on to the hypervisor
    def initialize(hosts, options)
      require 'beaker/hypervisor/lima_helper'

      super
      @logger = options[:logger] || Beaker::Logger.new
      @limahelper = options[:lima_helper] || LimaHelper.new(options)
    end

    def provision
      @logger.notify 'Provisioning Lima'
      @hosts.each do |host|
        @logger.notify "provisioning #{host.name}"
        @limahelper.start(host.name, host[:lima])
        vm_opts = @limahelper.list([host.name]).first
        @logger.info "vm_opts: #{vm_opts}\n"
        setup_ssh(host)
        @logger.debug "node available at #{host[:ip]}:#{host[:port]}"
      end
      hack_etc_hosts @hosts, @options
    end

    def cleanup
      @logger.notify 'Cleaning up Lima'
      @hosts.each do |host|
        @logger.debug "stopping #{host.name}"
        @limahelper.stop(host.name)
        @limahelper.delete(host.name)
      end
    end

    def connection_preference(_host)
      [:ip]
    end

    private

    def setup_ssh(host)
      @logger.debug 'configure lima VMs (set ssh-config, switch to root user, hack etc/hosts)'

      default_user = host[:user] # root

      ssh_config = convert_ssh_opts(host)
      host[:ip] = '127.0.0.1'
      host[:port] = ssh_config[:port]
      host[:ssh] = host[:ssh].merge(ssh_config)
      host[:user] = ssh_config[:user]

      # copy user's keys to roots home dir, to allow for login as root
      copy_ssh_to_root host, @options
      # ensure that root login is enabled for this host
      enable_root_login host, @options
      # shut down connection, will reconnect on next exec
      host.close

      host[:user] = default_user
      host[:ssh][:user] = default_user
    end

    # Convert lima ssh opts to beaker (Net::SSH) ssh opts
    def convert_ssh_opts(host)
      cfg = @limahelper.ssh_info(host.name)
      forward_ssh_agent = @options[:forward_ssh_agent] || false
      keys_only = if @options[:forward_ssh_agent] == true
                    false
                  else
                    (cfg['IdentitiesOnly'] || 'yes') == 'yes'
                  end

      {
        forward_agent: forward_ssh_agent,
        host_name: cfg['Hostname'],
        keys: cfg['IdentityFile'],
        keys_only: keys_only,
        port: cfg['Port'],
        use_agent: forward_ssh_agent,
        user: cfg['User'],
      }
    end
  end
end
