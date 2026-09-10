# Sandbox #

Runs [`bubblewrap`][bubblewrap] to contain a process by hiding your `$HOME`,
other processes, and various other stuff. The point is to allow the jailed
process to access whatever is installed on the system.

The contained process is expected to be `claude`.

[bubblewrap]: https://github.com/containers/bubblewrap

## Use ##

Run `claude` to run Claude in a sandbox.

Run `claude --shell` to start a shell instead, and inspect the environment.

Claude sees `~/.claude-home` as `~`.

Copy the example `claude-sandbox-init` to `~/.claude-sandbox-init` and tweak it
to fine-tune what is visible inside the sandbox.

Run `claude-update` to update the agent executable.

### How it works ###

Bubblewrap enters private namespaces, and installs a seccomp syscall filter just
to make sure. This creates a selective container which prevents access to user
data. It is the same technique that everything from [Docker][docker-sbx] to
[Firefox][firefox-sbx] worker processes uses for containment.

Separately, the sandbox creates a persistent network namespace that the process
can enter to hide the loopback device, abstract unix sockets, and the like. A
firewall can further restrict the network.

[firefox-sbx]: https://wiki.mozilla.org/Security/Sandbox#Linux
[docker-sbx]: https://docs.docker.com/get-started/docker-overview/#the-underlying-technology

## Install ##

You need `zsh`.

The `Makefile` has install targets, and they all put things into `/usr/local`.

```
make install
```

...gives you `/usr/local/bin/claude` and a sysctl config which makes sure that
this works as advertised. Undo with `make uninstall`.

Then, get the `claude` executable on your machine and put it into
`/opt/claude/bin`, for instance by running `claude-update`.

The sandbox should now work, but without the network isolation.

### Install the network support ###

Separately, run:

```
make install-network
```

...to install the network configuration. It depends on `systemd-networkd`, and:

- adds a persistent bridge (`br-netns`) for plugging virtual network devices into;
- a service template (`netns@.service`) which creates named network namespaces; and
- a suid executable (`netns-enter`) that allows unprivileged processes to enter
  network namespaces whitelisted in `/usr/local/etc/netns-enter`.

Undo with `make uninstall-network`. After installing, reload networkd:

```
networkctl reload
```

...and enable and start the network sandbox:

```
systemctl enable --now netns@agents.service
```

### Open the firewall ###

At this stage the network sandbox should *almost* work, but there is a chance
that your system has a firewall configured to prevent forwarding. The network
sandbox needs forwarding between the bridge device and the uplink.

This can *probably* be fixed with:

- For [UFW][ufw] machines (e.g. Ubuntu):

      ufw route allow in on br-netns

- For [Firewalld][firewalld] machines (e.g. Fedora):

      firewall-cmd --permanent --zone=trusted --add-interface=br-netns
      firewall-cmd --reload

- Using direct [iptables]:

      iptables -A FORWARD -i br-netns -j ACCEPT
      iptables -A FORWARD -o br-netns -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

[ufw]: https://help.ubuntu.com/community/UFW
[firewalld]: https://firewalld.org/
[iptables]: https://linux.die.net/man/8/iptables

### Tweak the install ###

The `Makefile` has a few variables at the top.
