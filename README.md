# Sample webapp with database using OpenShift Pipelines


## Results

After the pipeline completes, use the following command to connect to the database instance:

        oc rsh $(  oc get pod |grep jdbcquery-data |awk '{print $1}' ) psql -Upostgres -djdbcquery -h127.0.0.1

### Minshift Configuration

### Linux

When Minishift is configured to use Virtualbox on Linux, the directory `/home` is shared to the VM as `/hosthome`.

By default, Minishift on Linux uses libvirt/KVM instead of Virtualbox and the user must configure shares using Samba.

### Configuring Share

These steps assuming the Samba share arleady exists, if not configure Samba and come back to this section.

1. Create the share

        minishift hostfolder add minidata

        UNC path: //192.168.0.11/minidata
        Mountpoint [/mnt/sda1/minidata]:  
        Username: docker
        Password: [HIDDEN]
        Domain: 
        Added: minidata

2. Mount the share

        minishift hostfolder mount minidata


### Installing Samba

Reference: https://help.ubuntu.com/community/How%20to%20Create%20a%20Network%20Share%20Via%20Samba%20Via%20CLI%20%28Command-line%20interface/Linux%20Terminal%29%20-%20Uncomplicated,%20Simple%20and%20Brief%20Way!

1. If docker user does not exist, add it:

        sudo useradd docker -g 133 -M -u 133
        
2. Install Samba

        sudo apt-get update
        sudo apt-get install samba
        
3. Create docker user in samba:

        sudo smbpasswd -a docker
        # choose a password you'll remember, it's used only when accessing samba shares.
        
4. Create the directory to share:

        mkdir /home/username/minidata
        sudo chgrp /home/username/minidata
        chmod g+rx /home/username/minidata
        
5. Add following block to end of /etc/samba/smb.conf

        [minidata]
        path = /home/bmoriarty/minidata
        valid users = docker
        read only = no

6. Restart service

        sudo service smbd restart
        
7. Install smbclient (used to verify it share works)

        sudo apt-get install smbclient

8. Verify share

       smbclient -L //192.168.0.11/minidata -U docker

       smbclient //192.168.0.1/minidata -U docker
