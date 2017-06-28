# Common functions.  Please make sure to define common variables first.

# Iterate over all testbed VM names, first censors then nodes, alphabetically.
iter_vms() {
    lxc-ls -P "$SIM_LXC_DIR" -1 \
           --filter="$SIM_NAME_PREFIX($SIM_CENSOR_KEY|$SIM_NODE_E0_KEY|$SIM_NODE_E1_KEY|$SIM_NODE_W0_KEY|$SIM_NODE_W1_KEY)[0-9a-f]+"
}

# Split "X.Y.0.0" into "X Y 0.0", only works at dot boundaries.
split_ip4_net() {
    echo "$1" | sed -E 's/([0-9.]*)+\.([^0][0-9]*)\.([0.]+)/\1 \2 \3/'
}
