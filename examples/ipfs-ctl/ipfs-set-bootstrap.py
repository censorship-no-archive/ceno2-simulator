#!/usr/bin/env python3
"""Set the given peers as bootstrap in all nodes' IPFS configuration.

Run `show_usage()` for more info.
"""

import json
import os
import re
import subprocess
import sys


IPFS_CONFIG_PATH = '/home/ipfs/.ipfs/config'
IPFS_TCP_PORT = 4001

_vm_addr_re = re.compile(r'^lxc.network.ipv(4|6)\s*=\s*(\S+)/', re.MULTILINE)
_node_name_regexp = (
    '^{SIM_NAME_PREFIX}'
    '({SIM_NODE_E0_KEY}|{SIM_NODE_E1_KEY}|{SIM_NODE_W0_KEY}|{SIM_NODE_W1_KEY})'
    '[0-9a-f]+$')  # to be filled in later


def show_usage():
    print("""\
Usage: {progname} VM_NAME...

Replace IPFS bootstrap peers in ``{ipfscfp}`` of all nodes
with the multiaddresses of each given ``VM_NAME`` peer.

Please remember to first export configuration variables into the environment
using ``export-vars.sh``.
\
""".format(progname=sys.argv[0], ipfscfp=IPFS_CONFIG_PATH), file=sys.stderr)

def get_vm_config_path(vm):
    return os.path.join(os.environ['SIM_LXC_DIR'], vm, 'config')

def get_ipfs_config_path(vm):
    return os.path.join(os.environ['SIM_LXC_DIR'], vm, 'rootfs-rw', IPFS_CONFIG_PATH[1:])

def iter_addrs(vm):
    """Iterate over the IPFS addresses of the given `vm`."""
    with open(get_vm_config_path(vm)) as vmcf, open(get_ipfs_config_path(vm)) as ipfscf:
        id_ = json.loads(ipfscf.read())['Identity']['PeerID']
        for (v, a) in _vm_addr_re.findall(vmcf.read()):
            yield '/ip%s/%s/tcp/%d/ipfs/%s' % (v, a, IPFS_TCP_PORT, id_)

def iter_nodes():
    """Iterate over the names of node VMs."""
    node_name_regexp = _node_name_regexp.format(**os.environ)  # fill in node name regexp
    ret = subprocess.run( ['lxc-ls', '-1P', os.environ['SIM_LXC_DIR'],
                           "--filter=%s" % node_name_regexp],
                          stdout=subprocess.PIPE)
    yield from (n.strip().decode() for n in ret.stdout.split())


if __name__ == '__main__':
    if len(sys.argv) < 2:
        show_usage()
        sys.exit(1)

    if 'SIM_LXC_DIR' not in os.environ:
        raise RuntimeError("please export configuration variables into environment")

    # Get the IPFS addresses of the specified nodes.
    addrs = [a for vm in sys.argv[1:] for a in iter_addrs(vm)]

    # Replace bootstrap peers in all nodes' IPFS config files.
    for node in iter_nodes():
        ipfscfp = get_ipfs_config_path(node)
        with open(ipfscfp) as ipfscf:
            conf = json.loads(ipfscf.read())
            conf['Bootstrap'] = addrs
        with open(ipfscfp, 'w') as ipfscf:
            ipfscf.write(json.dumps(conf, indent=2))
