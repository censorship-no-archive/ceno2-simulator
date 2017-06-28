# Simulated testbed

## Description

### Typical setup

  - 1 dedicated server performing routing, traffic shaping etc. between
    containers
  - a few hundred (200 is good) LXC containers representing CENO nodes/user
    devices
  - some LXC containers simulating the censors' infrastructure trying to
    interfere with communications between the censored and uncensored zones,
    such as:
      - a (lying) DNS server
      - a transparent HTTP proxy (optional at the beginning)

### Shared root

To save disk space, VMs share the same base root file system.  We create a
simple *template container* for each VM type (censor, node) and prepare it
with any software and configuration common to the type.  We stop the container
and save its ``rootfs`` directory e.g. to ``/host/path/to/VMTYPE-template``.
Each new container which uses it as a base has empty directories
``/host/path/to/CONTAINER/{rootfs,rootfs-rw}`` and these lines in its LXC
``config`` file:

    lxc.rootfs = overlayfs:/host/path/to/VMTYPE-template:/host/path/to/CONTAINER/rootfs-rw
    lxc.rootfs.backend = overlayfs

``/host/path/to/CONTAINER/rootfs-rw/etc/hostname`` is created before starting
the container to give it a different host name.

If containers are expected to have little local state, all
``/host/path/to/CONTAINER`` directories can be moved to a *tmpfs*.

### Disabling services

The LXC ``config`` option ``lxc.ttys`` of all containers can be set to 0 (do
*not* set ``lxc.console = none``), and in the template container all ``getty``
services and the SSH daemon can be disabled by executing:

    # systemctl -f mask console-getty getty@ ssh

Or creating symbolic links from
``/host/path/to/VMTYPE-template/etc/systemd/system/{getty@,ssh}.service`` to
``/dev/null``.

### Shared data directory

Experiment data can be easily shared with containers and results collected
from them by sharing a writable directory from the host that we will call
``/host/path/to/SHARED``.

Containers have an existing ``/SHARED`` directory where the previous one is
bind-mounted. In the container's LXC ``config`` file:

    lxc.mount.entry = /host/path/to/SHARED /host/path/to/CONTAINER/rootfs/SHARED shared bind,OTHER_OPTIONS 0 0

Containers can store data to be collected at the end of the experiment under a
subdirectory of the shared directory having its own name (see below).

### Signaling

Sending commands from a controlling process in the host to processes to
containers can be done in a very simple and lightweight mode using Linux's
*inotify* infrastructure and the shared directory.

The host manages a ``ctl`` file in ``/host/path/to/SHARED`` (its initial
content is irrelevant). Anytime that the host wants to signal something to
containers, it atomically replaces it with a file with the new content,
e.g. ``mv /host/path/to/ctl.new /host/path/to/SHARED/ctl``.

A process in each container waits for ``moved_to`` events on ``/SHARED``, then
if the event was for the ``ctl`` file, it reads instructions from it.  For
instance, using ``inotify-tools``:

    $ f=$(inotifywait -q -e close_write /SHARED | cut -f3 -d' ')
    $ test "$f" = ctl && do_something

### Naming and addressing

Each LXC container has its own associated bridge interface on the host (no two
containers on the same bridge, to ensure the host acts as a router for all
containers).

The names for the LXC container (``lxc.utsname``), host name
(``/etc/hostname``) and host interface of the VM all have the same value
(``vmCX``, ``vmE0HH``, etc. below).

We separate the CENO nodes in 4 well-separated groups (+ the censors). We should
need only 2 groups ("censored zone" or East and "uncensored zone" or West) but 4
will give a little more flexibility, should it be needed. It does not add
complexity. Their network identifiers are hierarchically grouped like this, to
allow routing and filtering rules to cover certain regions more easily:

PREFIX is an IPv6 /48 ULA prefix as can be retrieved from
<https://www.sixxs.net/tools/grh/ula/> or by running ``subnetcalc ::1
-uniquelocal``.

Group        | Identifier      | IPv4 network  | IPv6 network
-------------|-----------------|---------------|-------------------
All          | ``0b0001_0xxx`` | 172.16.0.0/13 | PREFIX::/48
Censors      | ``0b0001_00xx`` | 172.16.0.0/14 | PREFIX::f0e0:0/108
Normal nodes | ``0b0001_01xx`` | 172.20.0.0/14 | PREFIX::0000:0/102
- East       | ``0b0001_010x`` | 172.20.0.0/15 | PREFIX::0000:0/103
- West       | ``0b0001_011x`` | 172.22.0.0/15 | PREFIX::0200:0/103

Group Censors (`0b0001_00_01=16+0+1=17`):

  - host IPv4 (vmCX): 172.17.X.0/31
  - container IPv4 (eth0): 172.17.X.1/31
  - host IPv6 (vmCX): PREFIX::f0eX:0/127
  - container IPv6 (eth0): PREFIX::f0eX:1/127

Group Nodes 1 (`0b0001_010_0=16+4+0=20`, East):

  - host IPv4 (vmE0HH): 172.20.[1-125].0/31
  - container IPv4 (eth0): 172.20.[1-125].1/31
  - host IPv6 (vmE0HH): PREFIX::[0001-007d]:0/127
  - container IPv6: PREFIX::[0001-007d]:1/127

Group Nodes 2 (`0b0001_010_1=16+4+1=21`, East):

  - host IPv4 (vmE1HH): 172.21.[1-125].0/31
  - container IPv4 (eth0): 172.21.[1-125].1/31
  - host IPv6 (vmE1HH): PREFIX::[0101-017d]:0/127
  - container IPv6 (eth0): PREFIX::[0101-017d]:1/127

Group Nodes 3 (`0b0001_011_0=16+4+2=22`, West):

  - host IPv4 (vmW0HH): 172.22.[1-125].0/31
  - container IPv4 (eth0): 172.22.[1-125].1/31
  - host IPv6 (vmW0HH): PREFIX::[0201-027d]:0/127
  - container IPv6 (eth0): PREFIX::[0201-027d]:1/127

Group Nodes 4 (`0b0001_011_1=16+4+3=23`, West):

  - host IPv4 (vmW1HH): 172.23.[1-125].0/31
  - container IPv4 (eth0): 172.23.[1-125].1/31
  - host IPv6 (vmW1HH): PREFIX::[0301-037d]:0/127
  - container IPv6 (eth0): PREFIX::[0301-037d]:1/127

Example ``LXC`` configuration for Censor 2 with ``PREFIX = fddb:bd8c:1e4f::/48``:

    lxc.network.type = veth
    lxc.network.name = eth0
    lxc.network.veth.pair = vmC2
    lxc.network.link =
    lxc.network.flags = up
    lxc.network.ipv4 = 172.17.2.1/31
    lxc.network.ipv4.gateway = 172.17.2.0
    lxc.network.ipv6 = fddb:bd8c:1e4f::f0e2:1/127
    lxc.network.ipv6.gateway = fddb:bd8c:1e4f::f0e2:0

The interface must not be configured inside of the container:

    $ sed -i 's/dhcp/manual/' /host/path/to/ROOT-BASE/etc/network/interfaces

After starting the container, the host adds its own addresses to the host-side
interface of the container's veth pair:

    # ip addr add 172.17.2.0 peer 172.17.2.1/31 dev vmC2
    # ip addr add fddb:bd8c:1e4f::f0e2:0 peer fddb:bd8c:1e4f::f0e2:1/127 dev vmC2

## Host configuration

The simulator needs LXC 2 (Debian package ``lxc``) and a kernel supporting
OverlayFS (module ``overlay``) or AuFS (module ``aufs`` and Debian package
``aufs-tools``).

You need to enable IPv4 and IPv6 forwarding to allow the host to route traffic
between VMs.  You also need to allow more entries in the ARP and NDP tables,
and more inotify instances are probably needed (the values below are ok for
some 500 containers):

    # cat > /etc/sysctl.d/local-ceno2sim.conf << EOF
    net.ipv4.conf.all.forwarding = 1
    net.ipv6.conf.all.forwarding = 1

    net.ipv4.neigh.default.gc_thresh1 = 2048
    net.ipv4.neigh.default.gc_thresh2 = 4096
    net.ipv4.neigh.default.gc_thresh3 = 8192

    net.ipv6.neigh.default.gc_thresh1 = 2048
    net.ipv6.neigh.default.gc_thresh2 = 4096
    net.ipv6.neigh.default.gc_thresh3 = 8192

    fs.inotify.max_user_instances = 8192
    EOF
    # sysctl -p /etc/sysctl.d/local-ceno2sim.conf

If you want your containers to have access to the Internet, you may enable
source NAT or masquerading at the host.  Assuming that ``eth0`` is the main
host interface:

    # iptables -t nat -A POSTROUTING -s 172.16.0.0/13 -o eth0 -j MASQUERADE
    # ip6tables -t nat -A POSTROUTING -s fddb:bd8c:1e4f::/48 -o eth0 -j MASQUERADE

Also, if you want to restrict container memory usage, please note that Debian
Jessie does not support this by default.  You need to add
``cgroup_enable=memory swapaccount=1`` to ``GRUB_CMDLINE_LINUX`` in
``/etc/default/grub``, run ``update-grub`` and reboot.

## Quick start

Before starting, rename ``vars.sh.example`` to ``vars.sh`` and edit it, if
needed, to suit it to your needs.

You may run the following commands (as ``root``) to load the testbed
configuration, create a sample testbed with 2 censors and 4\*10 nodes, start
it, check connectivity between nodes, stop the testbed and destroy it:

    # . ./vars.sh
    # ./template-create "$SIM_CENSOR_TEMPLATE_NAME"
    # ./template-create "$SIM_NODE_TEMPLATE_NAME"

    # chroot "$SIM_NODE_TEMPLATE_ROOT" apt update
    # chroot "$SIM_NODE_TEMPLATE_ROOT" apt install --no-install-recommends \
        iputils-ping  # netcat-openbsd host curl (also useful for testing)
    # chroot "$SIM_NODE_TEMPLATE_ROOT" apt-get clean

    # mkdir -p "$SIM_SHARED_HOST_DIR"
    # echo "shared file" > "$SIM_SHARED_HOST_DIR/shared.txt"

    # ./create 2 10
    # ./start
    # lxc-attach -P "$SIM_LXC_DIR" -n vmE104 -- \
        ping6 -c4 fddb:bd8c:1e4f::0308:1  # to vmW108
    # ./stop
    # ./destroy

## Interference examples

### Transparent HTTP proxy

To redirect all HTTP traffic to ``example.com`` (by its IP addresses) from the
East group towards the first censor, configure the following rules in the
host:

    # iptables -t nat -I PREROUTING -s 172.20.0.0/15 \
      -d 93.184.216.34 -p tcp --dport 80 \
      -j DNAT --to 172.17.1.1
    # ip6tables -t nat -I PREROUTING -s fddb:bd8c:1e4f::0000:0/103 \
      -d 2606:2800:220:1:248:1893:25c8:1946 -p tcp --dport 80 \
      -j DNAT --to fddb:bd8c:1e4f::f0e1:1

Running e.g. ``curl http://example.com/`` from a Western node will show up a
page with original content, while from an Eastern node it will show content
served by the censor (e.g. the server welcome page from a default installation
of ``nginx-light`` in Debian).

### DNS hijacking

To have DNS queries from the East group intercepted and served by the first
censor, configure the following rules in the host:

    # iptables -t nat -I PREROUTING -s 172.20.0.0/15 \
      -p udp --dport 53 \
      -j DNAT --to 172.17.1.1
    # ip6tables -t nat -I PREROUTING -s fddb:bd8c:1e4f::0000:0/103 \
      -p udp --dport 53 \
      -j DNAT --to fddb:bd8c:1e4f::f0e1:1

In that censor node you may install the Debian package ``dnsmasq``, make it
listen on ``eth0`` and have all IPv4 and IPv6 DNS queries of ``*.example.com``
resolved to the censor itself.  Just place this in the censor's
``/etc/dnsmasq.d/local-censor.conf``:

    interface=eth0
    address=/example.com/172.17.1.1
    address=/example.com/fddb:bd8c:1e4f::f0e1:1

Then restart ``dnsmasq`` with ``systemctl restart dnsmasq``.  Now, running
``host example.com`` from a Western node will yield the original addresses,
while from an Eastern node it will yield the censor addresses.

### Port throttling

To restrict the speed of traffic coming from certain ports of Western hosts
into Eastern hosts, you may use the ``port-throttle`` script.  You need to
have the [tcconfig](https://pypi.python.org/pypi/tcconfig/) Python package
installed.

To limit e.g. traffic coming from HTTP and HTTPS ports to 1 Mbps, after
starting the testbed run the following commands at the host:

    # ./port-throttle 80 1M
    # ./port-throttle 443 1M

Currently the speed provided in the first command applies to all ports used in
subsequent invocations, until the testbed is restarted.

### Internet blocking

To fully cut access to the Internet to Eastern nodes (which inside of the
testbed is equivalent to cut access to Western nodes), you may insert rules
like these in the firewall:

    # iptables -t filter -I FORWARD -s 172.20.0.0/15 -d 172.22.0.0/15 \
      -j REJECT --reject-with=icmp6-adm-prohibited
    # ip6tables -t filter -I FORWARD \
      -s fddb:bd8c:1e4f::0000:0/103 -d fddb:bd8c:1e4f::0200:0/103 \
      -j REJECT --reject-with=icmp6-adm-prohibited

Instead of the explicit rejection errors you may also just silently drop
packets with ``-j DROP``.

Please not that this does not cut access to the real Internet (you should turn
NAT off or use ``! -d SOURCE_NET`` above for that).

## Example experiment

The [ctl-logger directory](examples/ctl-logger) contains files for a simple
example experiment where all nodes monitor changes of the ``/shared/ctl`` file
and log its content after a change to ``/shared/HOSTNAME/ctl.log``.

To configure nodes with a service that implements this experiment, first
install the ``ctl-logger`` script to the template's ``/usr/local/bin``:

    # . ./vars.sh
    # TEMPLATE_ROOT="$SIM_NODE_TEMPLATE_ROOT"
    # install examples/ctl-logger/ctl-logger \
      "$TEMPLATE_ROOT/usr/local/bin"

Then copy and enable the service unit file:

    # install -m 0644 examples/ctl-logger/ctl-logger.service \
      "$TEMPLATE_ROOT/etc/systemd/system"
    # chroot "$TEMPLATE_ROOT" systemctl enable ctl-logger

You will need the ``inotify-tools`` package in the template:

    # chroot "$TEMPLATE_ROOT" apt install inotify-tools

(For the quick start setup, repeat the previous steps for the censor template
with ``TEMPLATE_ROOT="$SIM_CENSOR_TEMPLATE_ROOT"``.)

After creating and starting the testbed, you may change the ``ctl`` file
atomically from the host or any other node by doing:

    # echo foo > /path/to/shared/ctl.new
    # mv /path/to/shared/ctl.new /path/to/shared/ctl

All containers should report the change to their log file.

## IPFS experiment

TBD

To isolate the experiment from the Internet by having some nodes acting as
IPFS bootstrap peers for all nodes, you may use ``ipfs-set-bootstrap.py``,
which needs the configuration variables to be exported in the environment.
For instance:

    # . ./export-vars.sh
    # examples/ipfs-ctl/ipfs-set-bootstrap.py vmE001 vmW001 vmW002
