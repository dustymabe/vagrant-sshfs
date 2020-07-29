require 'etc'
require 'spec_helper'
require 'vagrant-sshfs/synced_folder/sshfs_forward_mount'

RSpec.describe 'vagrant-sshfs/synced_folder/sshfs_forward_mount' do

  describe '#get_auth_info' do
    let(:machine) { double('machine') }

    context 'when opts[:ssh_username]=nil and opts[:prompt_for_password]=nil' do
      let(:opts) { Hash.new }

      before :each do
        mount = VagrantPlugins::SyncedFolderSSHFS::SyncedFolder.new

        allow(machine).to receive_message_chain(:ssh_info).and_return(
          {
            :host=>"127.0.0.1",
            :port=>2222,
            :private_key_path=>["/home/vagrant/.vagrant.d/insecure_private_key"],
            :keys_only=>true,
            :verify_host_key=>:never,
            :username=>"vagrant",
            :remote_user=>"vagrant",
            :compression=>true,
            :dsa_authentication=>true,
            :extra_args=>nil,
            :config=>nil,
            :forward_agent=>false,
            :forward_x11=>false,
            :forward_env=>false,
            :connect_timeout=>15
          }
        )

        expect(opts[:ssh_username]).to be_nil
        expect(opts[:prompt_for_password]).to be_nil

        allow(machine).to receive_message_chain(:ui, :ask).with(
          I18n.t("vagrant.sshfs.ask.prompt_for_password", username: opts[:ssh_username]),
          {:echo => false},
        )

        @mount = mount
      end

      it 'should return nil' do
        result = @mount.send(:get_auth_info, machine, opts)
        expect(result).to be_nil
      end

      it "opts[:ssh_username]=#{Etc.getlogin}" do
        @mount.send(:get_auth_info, machine, opts)
        expect(opts[:ssh_username]).to eq Etc.getlogin
      end

      it "opts[:ssh_password]=nil" do
        @mount.send(:get_auth_info, machine, opts)
        expect(opts[:ssh_password]).to be_nil
      end
    end

    context 'when opts[:ssh_username]="foo"' do
      let(:opts) do
        {
          :ssh_username => 'foo',
        }
      end

      before :each do
        mount = VagrantPlugins::SyncedFolderSSHFS::SyncedFolder.new

        allow(machine).to receive_message_chain(:ssh_info).and_return(
          {
            :host=>"127.0.0.1",
            :port=>2222,
            :private_key_path=>["/home/vagrant/.vagrant.d/insecure_private_key"],
            :keys_only=>true,
            :verify_host_key=>:never,
            :username=>"vagrant",
            :remote_user=>"vagrant",
            :compression=>true,
            :dsa_authentication=>true,
            :extra_args=>nil,
            :config=>nil,
            :forward_agent=>false,
            :forward_x11=>false,
            :forward_env=>false,
            :connect_timeout=>15
          }
        )

        expect(opts[:ssh_username]).to eq "foo"
        expect(opts[:prompt_for_password]).to be_nil

        allow(machine).to receive_message_chain(:ui, :ask).with(
          I18n.t("vagrant.sshfs.ask.prompt_for_password", username: opts[:ssh_username]),
          {:echo => false},
        )

        @mount = mount
      end

      it 'should return nil' do
        result = @mount.send(:get_auth_info, machine, opts)

        expect(result).to be_nil
      end

      it 'opts[:ssh_username]="foo"' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:ssh_username]).to eq "foo"
      end

      it 'opts[:ssh_password]=nil' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:ssh_password]).to be_nil
      end

      it 'opts[:prompt_for_password]=nil' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:prompt_for_password]).to be_nil
      end
    end

    context 'when opts[:ssh_username]="foo" and opts[:prompt_for_password]=true' do
      let(:opts) do
        {
          :ssh_username        => 'foo',
          :prompt_for_password => true,
        }
      end

      before :each do
        mount = VagrantPlugins::SyncedFolderSSHFS::SyncedFolder.new

        allow(machine).to receive_message_chain(:ssh_info).and_return(
          {
            :host=>"127.0.0.1",
            :port=>2222,
            :private_key_path=>["/home/vagrant/.vagrant.d/insecure_private_key"],
            :keys_only=>true,
            :verify_host_key=>:never,
            :username=>"vagrant",
            :remote_user=>"vagrant",
            :compression=>true,
            :dsa_authentication=>true,
            :extra_args=>nil,
            :config=>nil,
            :forward_agent=>false,
            :forward_x11=>false,
            :forward_env=>false,
            :connect_timeout=>15
          }
        )

        expect(opts[:ssh_username]).to eq "foo"
        expect(opts[:prompt_for_password]).to eq true

        # here we simulate prompting for a passowrd and returning
        # the word vagrant
        allow(machine).to receive_message_chain(:ui, :ask).with(
          I18n.t("vagrant.sshfs.ask.prompt_for_password", username: opts[:ssh_username]),
          {:echo => false},
        ) { "vagrant" }

        @mount = mount
      end

      it 'should return "vagrant"' do
        result = @mount.send(:get_auth_info, machine, opts)
        expect(result).to eq "vagrant"
      end

      it 'opts[:ssh_username]="foo"' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:ssh_username]).to eq "foo"
      end

      it 'opts[:ssh_password]=vagrant' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:ssh_password]).to eq "vagrant"
      end

      it 'opts[:prompt_for_password]=true' do
        @mount.send(:get_auth_info, machine, opts)

        expect(opts[:prompt_for_password]).to eq true
      end
    end
  end
end
