# -*- mode: ruby -*-
# vi: set ft=ruby :

ansible_files = '/home/vagrant/baw-deploy'


# http://matthewcooper.net/2015/01/15/automatically-installing-vagrant-plugin-dependencies/
required_plugins = %w( vagrant-winnfsd )
required_plugins.each do |plugin|
  unless Vagrant.has_plugin? plugin || ARGV[0] == 'plugin'
    command_separator = Vagrant::Util::Platform.windows? ? " & " : ";"
    exec "vagrant plugin install #{plugin}#{command_separator}vagrant #{ARGV.join(" ")}"
  end
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = 'ubuntu/trusty64'

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

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.winnfsd.uid = 1000 # vagrant
  config.winnfsd.gid = 1000 # vagrant
  config.vm.synced_folder './', '/home/vagrant/baw-server', type: "nfs"
  config.vm.synced_folder '../baw-workers', '/home/vagrant/baw-workers', type: "nfs"
  config.vm.synced_folder '../baw-audio-tools', '/home/vagrant/baw-audio-tools', type: "nfs"
  config.vm.synced_folder '../baw-private/Ansible', ansible_files

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider 'virtualbox' do |vb|
    # Display the VirtualBox GUI when booting the machine
    vb.gui = false
    vb.name = 'baw-server-dev'
    # Customize the amount of memory on the VM:
    vb.memory = 1536
    vb.cpus = 2
  end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision 'shell', inline: <<-SHELL
    sudo apt-get update
    # temporary workaround for https://github.com/mitchellh/vagrant/issues/6793
    echo "Installing build tools..."
    sudo apt-get install -y build-essential libffi-dev libssl-dev python-dev
    echo "Installing git, pip, and ansible..."
    sudo apt-get install -y git python-pip && sudo pip install ansible==1.9.3 && sudo cp /usr/local/bin/ansible /usr/bin/ansible
  SHELL
  
  config.vm.provision 'ansible_local' do |ansible|
    # currently defaults to ansible 2.0 which we haven't tested
    # the shell provisioner bootstraps us with v1.9.3 instead
    #ansible.install = true
    ansible.version = '1.9.3'

    ansible.verbose = true

    ansible.galaxy_role_file = "#{ansible_files}/requirements.yml"
    ansible.galaxy_roles_path = "#{ansible_files}/external"
    # temporary workaround due to https://github.com/mitchellh/vagrant/issues/6740
    ansible.galaxy_command = "ansible-galaxy install --role-file=#{ansible_files}/requirements.yml --roles-path=#{ansible_files}/external --force"

    ansible.inventory_path = "#{ansible_files}/vagrant_ansible_local_inventory"

    ansible.playbook = '/home/vagrant/baw-server/provision/vagrant.yml'
    ansible.provisioning_path = ansible_files
  end

  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    cd /home/vagrant/baw-server && bin/setup
  SHELL

end
