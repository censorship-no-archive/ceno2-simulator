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

    $ ./create 0 1
    $ ./start
    $ alias ctl="/path/to/examples/ctl SHARED/dcdn/1-canonical/ctl"
    $ ctl INJECTOR_START
    (wait until "INJECTOR_START -> <RESULT>" appears in "vmW001.log")
    $ ctl CLIENT_START
    $ ctl "CLIENT_FETCH http://www.bbc.com/"
    (check "vmE001.log")
    $ ctl NODE_STOP
    $ ./stop
    $ ./destroy
