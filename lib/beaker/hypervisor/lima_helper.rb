# frozen_string_literal: true

module Beaker
  # Beaker helper module to interact with Lima CLI
  class LimaHelper
    class LimaError < StandardError
    end

    def initialize(options)
      require 'json'
      require 'open3'
      require 'shellwords'

      @options = options
      @logger = options[:logger]

      @limactl = @options[:limactl] || 'limactl'
      @lima_info = nil
      @ssh_info = {}
      @timeout = @options[:timeout] || 600 # 10m
    end

    def info
      return @lima_info if @lima_info

      lima_cmd = [@limactl, 'info']
      stdout_str, stderr_str, status = Open3.capture3(*lima_cmd)
      unless status.success?
        raise LimaError, "`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}"
      end

      @lima_info = JSON.parse(stdout_str)
    end

    def list(vm_names = [])
      lima_cmd = [@limactl, 'list', '--json']
      vm_names.each { |vm_name| lima_cmd << vm_name }
      stdout_str, stderr_str, status = Open3.capture3(*lima_cmd)
      unless status.success?
        raise LimaError, "`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}"
      end

      stdout_str.split("\n").map { |vm| JSON.parse(vm) }
    end

    # A bit faster `list` variant to check the VM status
    def status(vm_name)
      lima_cmd = [@limactl, 'list', '--format', '{{ .Status }}', vm_name]
      stdout_str, stderr_str, status = Open3.capture3(*lima_cmd)
      unless status.success?
        raise LimaError, "`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}"
      end

      stdout_str.chomp
    end

    def start(vm_name, cfg = {})
      case status(vm_name)
      when ''
        return create(vm_name, cfg)
      when 'Running'
        @logger.debug("'#{vm_name}' is running already, skipping...")
        return true
      end

      lima_cmd = [@limactl, 'start', "--timeout=#{@timeout}s", vm_name]
      _, stderr_str, status = Open3.capture3(*lima_cmd)
      unless status.success?
        raise LimaError, "`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}"
      end

      true
    end

    def create(vm_name, cfg = {})
      @logger.debug("Options: #{cfg}")
      raise LimaError, 'Only one of url/template/config parameters must be specified' if cfg[:url] && cfg[:config]

      if cfg[:url]
        cfg_url = cfg[:url]
      elsif cfg[:config]
        # Write config to a temporary YAML file and pass it to limactl later
        safe_name = Shellwords.escape(vm_name)
        tmpfile = Tempfile.new(["lima_#{safe_name}", '.yaml'])
        # config has symbolized keys by default. So .to_yaml will write keys as :symbols.
        # Keys should be stringified to avoid this so Lima can parse the YAML properly.
        tmpfile.write(stringify_keys_recursively(cfg[:config]).to_yaml)
        tmpfile.close

        # Validate the config
        _, stderr_str, status = Open3.capture3(@limactl, 'validate', tmpfile.path)
        raise LimaError, "Config validation fails with error: #{stderr_str}" unless status.success?

        cfg_url = tmpfile.path
      else
        raise LimaError, 'At least one of url/template/config parameters must be specified'
      end

      lima_cmd = [@limactl, 'start', "--name=#{vm_name}", "--timeout=#{@timeout}s", cfg_url]
      _, stderr_str, status = Open3.capture3(*lima_cmd)
      tmpfile&.unlink # Delete tmpfile if any

      unless status.success?
        raise LimaError, "`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}"
      end

      true
    end

    def stop(vm_name)
      lima_cmd = [@limactl, 'stop', vm_name]
      _, stderr_str, status = Open3.capture3(*lima_cmd)

      # `limactl stop` might fail sometimes though VM is stopped actually
      # Performing additional check
      return true if status(vm_name) == 'Stopped'

      @logger.warn("`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}")
      false
    end

    def delete(vm_name)
      lima_cmd = [@limactl, 'delete', vm_name]
      _, stderr_str, status = Open3.capture3(*lima_cmd)

      # `limactl delete` might fail sometimes though VM is deleted actually
      # Performing additional check
      return true if status(vm_name).empty?

      @logger.warn("`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}")
      false
    end

    def ssh_info(vm_name)
      return @ssh_info[vm_name] if @ssh_info.key? vm_name

      lima_cmd = [@limactl, 'show-ssh', '--format', 'options', vm_name]
      stdout_str, stderr_str, status = Open3.capture3(*lima_cmd)

      if stdout_str.empty?
        @logger.warn("`#{lima_cmd.join(' ')}` failed with status #{status.exitstatus}: #{stderr_str}")
        return {}
      end

      # Convert key=value to [key],[value] pairs array
      vm_opts_pairs = Shellwords.shellwords(stdout_str).map { |x| x.split('=', 2) }

      # Collect all IdentityFile values
      identity_files = vm_opts_pairs.filter { |x| x[0] == 'IdentityFile' }.map { |x| x[1] }

      # Convert pairs array to a hash
      vm_opts = Hash[*vm_opts_pairs.flatten]
      vm_opts['IdentityFile'] = identity_files
      vm_opts['Port'] = vm_opts['Port'].to_i

      @ssh_info[vm_name] = vm_opts
    end

    # Stringify Hash keys recursively
    def stringify_keys_recursively(hash)
      stringified_hash = {}
      hash.each do |k, v|
        stringified_hash[k.to_s] = if v.is_a?(Hash)
                                     stringify_keys_recursively(v)
                                   elsif v.is_a?(Array)
                                     v.map { |x| x.is_a?(Hash) ? stringify_keys_recursively(x) : x }
                                   else
                                     v
                                   end
      end
      stringified_hash
    end
  end
end
