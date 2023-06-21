#!/bin/bash

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Prepare the simulation directory for each transferred lithium ion by"
    echo "copying the parameter and topology files to the corresponding"
    echo "directories."
}

usage() {
    echo
    echo "Usage:"
    echo
    echo "Required arguments:"
    echo "  -s    The name of the system to simulate, e.g."
    echo "        lintf2_g1_20-1_gra_q1_sc80."
    echo
    echo "Optional arguments:"
    echo "  -h    Show this help message and exit."
}

########################################################################
# Argument Parsing                                                     #
########################################################################

while getopts s:h option; do
    case ${option} in
        # Required arguments.
        s)
            system=${OPTARG}
            ;;
        # Optional arguments.
        h)
            information
            usage
            exit 0
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

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
project_root=$(readlink -e "${script_dir}/.." || exit)
mdp_dir="${project_root}/gmx"
top_dir="../topology"

relaxation="re_nvt423_ld"
production="pr_nvt423_vr"

for dir in Li[0-9]*_transferred; do
    echo
    echo "${dir}"
    cp -v "${mdp_dir}/01_${relaxation}_walls_freeze.mdp" "${dir}/${relaxation}_${system}_${dir}.mdp" || exit
    cp -v "${mdp_dir}/02_${production}_walls_freeze.mdp" "${dir}/${production}_${system}_${dir}.mdp" || exit
    cp -v "${top_dir}/${system}.top" "${dir}/${system}_${dir}.top" || exit
    cp -v "${top_dir}/${system}.ndx" "${dir}/${system}_${dir}.ndx" || exit
done
