# frozen_string_literal: true

require 'spec_helper'

# Beaker::Lima unit tests
module Beaker
  describe Lima do
    let(:hosts) do
      the_hosts = make_hosts
      the_hosts[0][:lima] = { url: 'template://ubuntu-lts' }
      the_hosts[1][:lima] = { config: { images: [] } }
      the_hosts
    end

    let(:logger) do
      logger = instance_double(Logger)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
      allow(logger).to receive(:warn)
      allow(logger).to receive(:error)
      allow(logger).to receive(:notify)
      logger
    end

    let(:options) do
      {
        logger: logger,
        lima_helper: lima_helper,
        forward_ssh_agent: true,
        provision: true,
      }
    end

    let(:ssh_info_hash) do
      {
        hosts[0].name => {
          'IdentityFile' => [
            '/home/test/.lima/_config/user',
            '/home/test/.ssh/id_rsa',
          ],
          'PreferredAuthentications' => 'publickey',
          'User' => 'test',
          'Hostname' => '127.0.0.1',
          'Port' => 54_321,
        },
        hosts[1].name => {
          'IdentityFile' => [
            '/home/test/.lima/_config/user',
            '/home/test/.ssh/id_rsa',
          ],
          'PreferredAuthentications' => 'publickey',
          'User' => 'test',
          'Hostname' => '127.0.0.1',
          'Port' => 54_322,
        },
        hosts[2].name => {
          'IdentityFile' => [
            '/home/test/.lima/_config/user',
            '/home/test/.ssh/id_rsa',
          ],
          'PreferredAuthentications' => 'publickey',
          'User' => 'test',
          'Hostname' => '127.0.0.1',
          'Port' => 54_323,
        },
      }
    end

    let(:lima) { described_class.new(hosts, options) }

    let(:lima_helper) do
      lh = instance_double(LimaHelper)
      allow(lh).to receive(:info).and_return({ 'version' => '1.2.3' })
      hosts.each do |host|
        # [list, status] are missing here because they depedns on a test case
        allow(lh).to receive(:start).with(host.name, host[:lima]).and_return(host.name)
        allow(lh).to receive(:stop).with(host.name).and_return(true)
        allow(lh).to receive(:ssh_info).with(host.name).and_return(ssh_info_hash[host.name])
        allow(lh).to receive(:delete).with(host.name).and_return(true)
      end
      lh
    end

    describe '#provision' do
      it 'provisions the VMs' do
        hosts.each do |host|
          allow(lima_helper).to receive(:list).with([host.name])
                                              .and_return([{ 'name' => host.name, 'status' => 'Running' }])
        end

        lima.provision

        hosts.each do |host|
          expect(lima_helper).to have_received(:start).with(host.name, host[:lima]).once
          expect(lima_helper).to have_received(:ssh_info).with(host.name).once
        end
      end
    end

    describe '#cleanup' do
      it 'cleanups the VMs' do
        lima.cleanup

        hosts.each do |host|
          allow(lima_helper).to receive(:list).with([host.name]).and_return([])

          expect(lima_helper).to have_received(:stop).with(host.name).once
          expect(lima_helper).to have_received(:delete).with(host.name).once
        end
      end
    end
  end
end
