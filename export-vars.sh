# Export simulator configuration variables into the environment.
# To use, run ``. ./export-vars.sh``.
. ./vars.sh
for v in $(set | sed -En 's/^(SIM_[^=]+)=.*/\1/p'); do export $v; done
unset v
