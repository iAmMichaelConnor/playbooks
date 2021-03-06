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

Docker access to local machine:
`sudo ufw allow in on docker0 from 172.17.0.0/16 to 172.17.0.0/16`


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

### Managing journalctl log size

`sudo nano /etc/systemd/journald.conf`  
Set `SystemMaxUse=500M`

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

# MINA

### daemon:
- Gets automatically installed (upon apk install) at `/usr/lib/systemd/user/mina.service`
- Needs a bit of tweaking after EVERY download: `sudo nano /usr/lib/systemd/user/mina.service`
- ```
  [Unit]
  Description=Mina Daemon Service
  After=network.target
  StartLimitIntervalSec=60
  StartLimitBurst=3

  [Service]
  EnvironmentFile=%h/.mina-env
  Type=simple
  Restart=always
  RestartSec=15
  ExecStart=/usr/local/bin/mina daemon \
    -block-producer-key %h/keys/my-wallet \
    -generate-genesis-proof true \
    -log-level Info \
    $EXTRA_FLAGS
  ExecStop=/usr/local/bin/mina client stop-daemon

  [Install]
  WantedBy=multi-user.target
  ```

*You might need to remove some lines from `ExecStart` above (e.g. the PEER LIST, which will instead be fed-in via the EXTRA_FLAGS specified in ~/.mina-env*

Put these flags in the `~/.mina-env` file (*PEER LIST URL MIGHT BE DIFFERENT*):
`EXTRA_FLAGS=" --limited-graphql-port 3095 --file-log-level Info --peer-list-url https://storage.googleapis.com/seed-lists/devnet_seeds.txt --coinbase-receiver B62qpA8s9wbazMmXGFENyR952kKgCofTGG6QX584Je55A5QrpqPaahW --snark-worker-fee 10 --snark-worker-parallelism 16 --work-selection seq"`

Note: the snark work address will be set by the wrkr (and the address will be that of the supercharged address (except at the very start when it'll be the hot wallet address))


### wrkr
- Created a `wrkr` daemon in `/usr/lib/systemd/user/wrkr.service`
- (See commands above for how to start a daemon and enable it to restart)
- ```
  [Unit]
  Description=Mina Snark Worker
  After=network.target
  StartLimitIntervalSec=60
  StartLimitBurst=3

  [Service]
  Type=simple
  Restart=always
  RestartSec=15
  ExecStart=/home/mike/.nvm/versions/node/v14.16.0/bin/wrkr --pk <insert pk here>

  [Install]
  WantedBy=multi-user.target
  ```

### sidecar

IGNORE BELOW - see better sidecar instructions here: https://minaprotocol.com/docs/advanced/node-status

- Created a `mina-sidecar` daemon in `/usr/lib/systemd/user/mina-sidecar.service`
- (See commands above for how to start a daemon and enable it to restart)
- ```
  [Unit]
  Description=Mina Sidecar
  After=network.target
  StartLimitIntervalSec=60
  StartLimitBurst=3

  [Service]
  Type=simple
  Restart=always
  RestartSec=15
  ExecStart=/usr/bin/python3 /home/mike/git/mina-bp-stats-sidecar/sidecar.py

  [Install]
  WantedBy=multi-user.target
  ```

Alternatively, you can use the Docker package to run the sidecar: https://github.com/Fitblip/mina/blob/ryan/mina-bp-stats/automation/services/mina-bp-stats/sidecar/README.md <--- you can get the python script from here, in order to run as a daemon.

Package at dockerhub: `minaprotocol/mina-bp-stats-sidecar:latest`

MINA_BP_UPLOAD_URL: https://us-central1-mina-mainnet-303900.cloudfunctions.net/block-producer-stats-ingest/?token=72941420a9595e1f4006e2f3565881b5


##### Docker sidecar

If you're running a mina node locally (using the mina daemon), but want to run the mina-sidecar as a docker container, you can do:

`docker run --name mina-sidecar -d --network host -v /etc/mina-sidecar.json:/etc/mina-sidecar.json minaprotocol/mina-bp-stats-sidecar:latest`

(the host network being the key thing)

With `.json` at :`/etc/mina-sidecar.json`
```
{
  "uploadURL": "https://us-central1-mina-mainnet-303900.cloudfunctions.net/block-producer-stats-ingest/?token=72941420a9595e1f4006e2f3565881b5",
  "nodeURL": "http://localhost:3085"
}
```

# Mina Block Producer Metrics Sidecar

This is a simple sidecar that communicates with Mina nodes to ship off uptime data for analysis.

Unless you're a founding block producer, you shouldn't need to run this sidecar.

## Configuration

The sidecar takes 2 approaches to configuration, a pair of envars, or a configuration file.

**Note**: Environment variables always take precedence, even if the config file is available and valid.

#### Envars
- `MINA_BP_UPLOAD_URL` - The URL to upload block producer statistics to
- `MINA_NODE_URL` - The URL that the sidecar will reach out to to get statistics from

#### Config File
The mina metrics sidecar will also look at `/etc/mina-sidecar.json` for its configuration variables, and the file should look like this:

```
{
  "uploadURL": "https://your.upload.url.here?token=someToken",
  "nodeURL": "https://your.mina.node.here:4321"
}
```

The `uploadURL` parameter should be given to you by the Mina engineers

## Running with Docker
Running in docker should be as straight forward as anything else. The examples below assume you've checked out this repo and run `docker build -t mina-sidecar .` in this folder.

We will likely also be cutting a release to docker hub soon which will likely live at `codaprotocol/mina-sidecar` (subject to change).

#### Running with envars
```bash
$ docker run --rm -it -e MINA_BP_UPLOAD_URL=https://some-url-here -e MINA_NODE_URL=https://localhost:4321 mina-sidecar
```

#### Running with a config file
```bash
$ docker run --rm -it -v $(pwd)/mina-sidecar.json:/etc/mina-sidecar.json mina-sidecar
```
#### You can even bake your own docker image with the config file already in it
```bash
# Custom Docker Image
$ echo '{"uploadURL": "https://some-url-here", "nodeURL": "https://localhost:4321"}' > your_custom_config.conf
$ cat <<EOF > Dockerfile.custom
FROM codaprotocol/mina-sidecar
COPY your_custom_config.conf /etc/mina-sidecar.json
EOF
$ docker build -t your-custom-sidecar .
$ docker run --rm -it your-custom-sidecar
```


# Running a 2nd docker container & sidecar

Do all this in a new folder, and run commands from that folder.

`mkdir docker-mina`

`cp -R keys/ docker-mina/`

`cd docker-mina`

`chmod...` (copy permissions of keys from internet guide)

We run everything on a different set of ports (incrementing the first digit by one from the defaults). Note, you'll need to do `sudo ufw allow 9302` to open that port to the outside world.

`docker network create mina-network`

`docker run --name mina -d -p 9302:9302 -p 4085:4085 -p 4095:4095 --network mina-network --restart=always --mount "type=bind,source=`pwd`/keys,dst=/keys,readonly" --mount "type=bind,source=`pwd`/.mina-config,dst=/root/.mina-config" -e CODA_PRIVKEY_PASS="YOUR_PASSWORD_HERE" minaprotocol/mina-daemon-baked:1.1.5-a42bdee daemon --block-producer-key /keys/my-wallet --insecure-rest-server --file-log-level Info --log-level Info --peer-list-url https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt --coinbase-receiver B62qpA8s9wbazMmXGFENyR952kKgCofTGG6QX584Je55A5QrpqPaahW --open-limited-graphql-port --limited-graphql-port 4095 --external-port 9302 --rest-port 4085`

`docker pull minaprotocol/mina-bp-stats-sidecar:latest`

`nano mina-sidecar-config.json`

```
{
  "uploadURL": "https://us-central1-mina-mainnet-303900.cloudfunctions.net/block-producer-stats-ingest/?token=72941420a9595e1f4006e2f3565881b5",
  "nodeURL": "http://mina:4095"
}
```
(Note the port number is incremented here to match the new mina container)

`docker network create mina-network`

```
docker run \
--name mina-sidecar \
--network mina-network \
--restart=always -d \
-v $(pwd)/mina-sidecar-config.json:/etc/mina-sidecar.json \
minaprotocol/mina-bp-stats-sidecar:latest
```

`docker logs -f mina`
or
`docker logs -f mina-sidecar`
