### To reset root password:

`sudo passwd root`  
Enter a new password.

### To add a new sudo user

`sudo adduser mike`  

Now, to give root privileges, either:
`apt-get install sudo -y`  
`adduser mike sudo`  
`chmod 0440 /etc/sudoers`  
`exit` (restart the server)

Or:
`usermod -aG sudo mike`

### To install security updates / do apt updates

`sudo apt update`  
`sudo apt upgrade -y`  
`sudo apt-get update`  

### To run as an ssh server

`sudo apt install openssh-server`  
`sudo systemctl status ssh` (to check the ssh daemon is running. can also be used to check whether anyone's tried to login)  

### To get ssh keys into the server (from local)

`ssh-keygen` to generate a key. Then there are several ways to copy over the key https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-on-ubuntu-1804. The key will ultimately be stored in the server at `~/.ssh/authorized_keys`.

To copy ssh keys from server's root user to a non-root user `mike`:
`su root`  
`rsync --archive --chown=mike:mike ~/.ssh /home/mike` copies the ssh keys and access permissions.  



### To login via ssh

`ssh [-i path/to/.ssh/id_rsa] mike@<ip-addr> -p <port num>`

### To get IP address

`hostname -I`   

### `scp` from local to server

`scp -P 22 -r ./local-dirname mike@ip-addr:/home/mike`

### `scp` from server to local

`scp -P 22 -r mike@ip-addr:/home/mike/dirname ./local-dirname`

### To kill connections to the server

`pgrep -c sshd` shows number of ssh connections  
`pkill --signal HUP sshd`  OR  
`pkill --signal KILL`  OR  
`ps -A | grep ssh` shows all processes relating to search term "ssh". A number will be shown for each process, e.g. 4990.  
`sudo kill 4990`  
`pgrep -c sshd`  

`sudo systemctl status ssh` (can also be used to check whether anyone's tried to login)  

`cat /var/log/auth.log` can also be used to view the hundreds of attempts to access (bombard) the server
`grep "Accepted password" /var/log/auth.log`

### Disabling root login & other access settings

`su root`  
`nano /etc/ssh/sshd_config`  
Can do things like set `PermitRootLoging: no`; `PasswordAuthentication: no`; `Port: <new number>`  

Check configuration of config file:  
`sshd -t` (should be blank output if no errors)  

`service ssh restart` AND MAKE SURE TO TRY LOGGING IN BEFORE CLOSING THE SSH TUNNEL!!! (or maybe `service sshd restart`)


### Install docker

Use ansible. But here's some manual stuff to include in ansible playbook:  

`sudo groupadd docker`  
`sudo usermod -aG docker ${USER}`  
`newgrp docker`


### Firewall

To see existing firewall 'profiles' (created by different apps):  
`sudo apt install ufw`
`ufw app list`  

TO RESET UFE TO DEFAULTS:
`sudo ufw default deny incoming`
`sudo ufw default allow outgoing`

To enable ssh login:
`ufw allow OpenSSH`  
`ufw enable`  
`ufw status`  

`apt install ufw`  
`ufw allow <ssh port number>`  
`ufw allow 80` (http)  
`ufw allow 443` (https)  
`ufw allow 8302` (block producer)  
`ufw enable`  
`ufw status`  

Block communications to private networks:

`ufw deny out from any to 10.0.0.0/8`  
`ufw deny out from any to 172.16.0.0/12`  
`ufw deny out from any to 192.168.0.0/16`  
`ufw deny out from any to 100.64.0.0/10`  
`ufw deny out from any to 198.18.0.0/15`  
`ufw deny out from any to 169.254.0.0/16`    

`ufw status`  

Also check with `iptables-save`  

`sudo iptables -A INPUT -p tcp --dport 8302:8303 -j ACCEPT`  

Test with `ping`:   

`ping 172.16.5.204` should error.


#### To undo firewall steps:

`ufw status numbered` (lists by number)
`ufw delete <rule number>`

### systemd daemon stuff

User-created daemon processes are saved in `/usr/lib/systemd/user/<service-name>.service`.

Make sure to `cat` that file to see what the startup command is!

You might need to remove things / edit the daemon startup command, every time you download new versions.

E.g.:

Remove `-peer-list-file %h/peers.txt \`

### Creating your own daemon:

```
systemctl --user daemon-reload
systemctl --user start <name>
systemctl --user enable <name>
sudo loginctl enable-linger
```
^^^These commands will allow the node to continue running after you logout, and restart automatically when the machine reboots.

`systemctl --user status <name>` This command will let you know if mina had any trouble getting started.

`systemctl --user stop <name>` to stop mina gracefully, and to stop automatically-restarting the service.

`systemctl --user restart <name>` to manually restart it.

`journalctl --user -u <name> -n 1000 -f` to look at logs.

### Installing node and npm and stuff

Install nvm: `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash` (see this link for updated download method: https://github.com/nvm-sh/nvm#install--update-script)

`nvm install --lts`

And now we nave Node.js!

`npm` command will show you where global binaries get stored (so that you can point daemons to them, for example)

E.g. `npm@6.14.11 /home/mike/.nvm/versions/node/v14.16.0/lib/node_modules/npm`

Since nvm stores the `node` binary in a weird place, ubuntu might sometimes get confused and look in the more standard location of `/usr/bin/`.
Your computer should understand the `node` command by now. So let's create a symlink from `node` to `/usr/local/bin`:

`sudo ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/node" "/usr/local/bin/node"`
`sudo ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/npm" "/usr/local/bin/npm"`
