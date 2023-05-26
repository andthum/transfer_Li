#!/bin/bash

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Submit the relaxation run for each transferred lithium ion to the"
    echo "Slurm workload manager."
}

usage() {
    echo
    echo "Usage:"
    echo
    echo "Required arguments:"
    echo "  -h    Show this help message and exit."
    echo "  -s    The name of the system to simulate, e.g."
    echo "        lintf2_g1_20-1_gra_q1_sc80."
}

########################################################################
# Argument Parsing                                                     #
########################################################################

while getopts hs: option; do
    case ${option} in
        # Optional arguments.
        h)
            information
            usage
            exit 0
            ;;
        s)
            system=${OPTARG}
            ;;
        # Handling of invalid options or missing arguments.
        *)
            usage
            exit 1
            ;;
    esac
done

########################################################################
# Main Part                                                            #
########################################################################

snapshot="pr_nvt423_nh"
relaxation="re_nvt423_ld"

for dir in Li[0-9]*_transferred; do
    echo
    echo "${dir}"
    cd "${dir}" || exit
    structure="${snapshot}_out_${system}_${dir}.gro"
    submit_gmx_mdrun.py \
        --system "${system}_${dir}" \
        --settings "${relaxation}" \
        --structure "${structure}" \
        --grompp "-maxwarn 1" \
        --partition express,himsshort,q0heuer,hims,normal \
        --time 0-01:00:00 ||
        exit
    cd ../ || exit
done
