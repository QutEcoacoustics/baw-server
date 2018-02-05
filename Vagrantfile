# -*- mode: ruby -*-
# vi: set ft=ruby :

# http://matthewcooper.net/2015/01/15/automatically-installing-vagrant-plugin-dependencies/
required_plugins = %w( )
required_plugins.each do |plugin|
  unless Vagrant.has_plugin? plugin || ARGV[0] == 'plugin'
    command_separator = Vagrant::Util::Platform.windows? ? " & " : ";"
    exec "vagrant plugin install #{plugin}#{command_separator}vagrant #{ARGV.join(" ")}"
  end
end

def sshfs_opts
  # Explored using the vagrant-sshfs plugin but found it didn't work well. Might be better in the future.
  # {
  #   type: "sshfs",
  #   mount_options: [],
  #   ssh_opts_append: "-o Compression=no",
  #   sshfs_opts_append: "-o cache=no -o uid=1000 -o gid=1000 -o umask=0011 -o idmap=user -o allow_other"
  # }
  {
      type: "smb",
      mount_options: ["vers=3.0"]
  }
end

def nfs_opts
  {
      type: "nfs",

      # these mount options are not needed unless using nfs on Windows
      #mount_options: [ "dir_mode=0700,file_mode=0600" ],
  }
end

def set_synced_folders(config, type)
  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # Option hashes are modified by reference - can't pass the same hash to multiple synced folder calls.

  config.vm.synced_folder '../baw-server', '/home/vagrant/baw-server', **(type == "sshfs" ? sshfs_opts : nfs_opts)
  config.vm.synced_folder '../baw-workers', '/home/vagrant/baw-workers', **(type == "sshfs" ? sshfs_opts : nfs_opts)
  config.vm.synced_folder '../baw-audio-tools', '/home/vagrant/baw-audio-tools', **(type == "sshfs" ? sshfs_opts : nfs_opts)
  config.vm.synced_folder '.', '/vagrant', disabled: true
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  
  # Every Vagrant development environment requires a box.
  config.vm.box = 'bento/ubuntu-14.04'

  # Enable ssh agent forwarding. Default is false.
  # This magic allows for the SSH key used to connect back to the host for the
  # SSH synced folders to be automatically sent to the guest!
  config.ssh.forward_agent = true

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine.
  config.vm.network 'forwarded_port', guest: 3000, host: 3000 # rails
  config.vm.network 'forwarded_port', guest: 1236, host: 26166 # debugging
  config.vm.network 'forwarded_port', guest: 5432, guest_ip: '127.0.0.1', host: 5432 # postgres

  # Create a private network, which allows host-only access to the machine.
  # A private dhcp network is required for NFS to work (on Windows hosts, at least)
  config.vm.network "private_network", type: "dhcp"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network 'public_network'

  config.vm.provider 'hyperv' do |hyperv, override|
    hyperv.vmname = 'baw-server-dev'
    # Customize the amount of memory on the VM:
    hyperv.memory = 1536
    hyperv.cpus = 2
    set_synced_folders(override, "sshfs")
  end
  
  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider 'virtualbox' do |vb, override|
    # Display the VirtualBox GUI when booting the machine
    vb.gui = false
    vb.name = 'baw-server-dev'
    # Customize the amount of memory on the VM:
    vb.memory = 1536
    vb.cpus = 2
    set_synced_folders(override, "nfs")
  end
  
  config.vm.provision 'ansible_local' do |ansible|
    ansible.install = true
    ansible.version = 'latest'
    ansible.install_mode = :pip

    ansible.verbose = true
    ansible.galaxy_role_file = '/home/vagrant/baw-server/provision/requirements.yml'
    ansible.galaxy_roles_path = '/home/vagrant/.ansible/roles'
    ansible.provisioning_path = '/home/vagrant/baw-server/provision'
    ansible.playbook = '/home/vagrant/baw-server/provision/vagrant.yml'
  end

  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    cd /home/vagrant/baw-server && bin/setup
  SHELL

end
