# dCDN tests

Basic tests for [dCDN](https://github.com/clostra/dcdn/).

## Common host preparation

Install the binaries to ``SHARED/dcdn/bin``.

## Canonical operation test

### Node template

Install the ``dcdn-exp`` script and the ``dcdn-exp.service`` file:

    # install 1-canonical/dcdn-exp /var/lib/lxc/node/rootfs/usr/local/sbin
    # install -m 0644 1-canonical/dcdn-exp /var/lib/lxc/node/rootfs/etc/systemd/system

Start the template, attach a shell to it and install Debian packages:

    # apt install inotify-tools libblocksruntime0 llvm curl

Enable the ``dcdn-exp`` service:

    # systemctl enable dcdn-exp

Stop the template.

### Execution

Example commands:

    INJECTOR_START
    (wait until "INJECTOR_START -> <RESULT>" appears in "vmW001.log")
    CLIENT_START
    CLIENT_FETCH http://www.bbc.com/
    (check "vmE001.log")
    NODE_STOP

How:

    echo "COMMAND" > SHARED/dcdn/1-canonical/ctl.new \
        && mv SHARED/dcdn/1-canonical/ctl.new SHARED/dcdn/1-canonical/ctl
