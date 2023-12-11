#!/bin/bash

settings="pr_nvt423_vr"
path_to_hpcss="${HOME}/Promotion/hpc_submit_scripts"
cleanup_script="analysis/lintf2_ether/mdt/.cleanup_mdt_analyses.sh"

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Clean up the directory containing the results of the MDTools"
    echo "analysis scripts for each transferred lithium ion."
}

usage() {
    echo
    echo "Usage:"
    echo
    echo "Required arguments:"
    echo "  -s    The name of the system to clean up, e.g."
    echo "        lintf2_g1_20-1_gra_q1_sc80."
    echo
    echo "Optional arguments:"
    echo "  -h    Show this help message and exit."
    echo "  -e    The simulation settings of the simulation to clean up."
    echo "        Default: ${settings}."
    echo "  -p    Path to your HPC Submit Scripts (hpcss) installation"
    echo "        (https://github.com/andthum/hpc_submit_scripts).  Default:"
    echo "        ${path_to_hpcss}."
}

########################################################################
# Argument Parsing                                                     #
########################################################################

while getopts s:he:p: option; do
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
        e)
            settings=${OPTARG}
            ;;
        p)
            path_to_hpcss=${OPTARG}
            ;;
        # Handling of invalid options or missing arguments.
        *)
            usage
            exit 1
            ;;
    esac
done

########################################################################
# Function Definitions                                                 #
########################################################################

gather() {
    # Gather output of similar analysis scripts.
    local root="${1}"
    if [[ -d ${root} ]]; then
        echo "WARNING: Directory already exists: '${root}'"
        return 0
    fi
    if [[ -n $(find . -maxdepth 1 -type d -name "${root}*_slurm-[0-9]*" -print -quit) ]]; then
        mkdir "${root}/" || exit
        mv "${root}"*_slurm-[0-9]*/ "${root}/" || exit
        cd "${root}/" || exit
        mv "${root}"*_slurm-[0-9]*/* ./ || exit
        rm -r "${root:?}"*_slurm-[0-9]*/ || exit
        cd ../ || exit
    else
        echo "WARNING: No directory matching pattern '${root}*_slurm-[0-9]*'"
    fi
}

########################################################################
# Main Part                                                            #
########################################################################

if [[ ${settings} == "re_nvt423_ld" ]]; then
    prefix="01"
elif [[ ${settings} == "pr_nvt423_vr" ]]; then
    prefix="02"
else
    echo
    echo "Error: Unknown 'settings': '${settings}'"
fi

# Clean up the directory containing the results of the MDTools analysis
# scripts.
for dir in Li[0-9]*_transferred; do
    echo
    echo "${dir}"
    if [[ ! -d ${dir} ]]; then
        echo "WARNING: No such directory: '${dir}'"
        continue
    fi
    cd "${dir}" || exit

    sim_dir="${prefix}_${settings}_${system}_${dir}"
    if [[ ! -d ${sim_dir} ]]; then
        echo "WARNING: No such directory: '${sim_dir}'"
        cd ../ || exit
        continue
    fi
    cd "${sim_dir}" || exit

    ana_dir="ana_${settings}_${system}_${dir}/mdt"
    if [[ ! -d ${ana_dir} ]]; then
        echo "WARNING: No such directory: '${ana_dir}'"
        cd ../../ || exit
        continue
    fi
    cd "${ana_dir}" || exit

    bash "${path_to_hpcss}/${cleanup_script}" || exit
    gather "rmsd_vs_time" || exit

    cd ../../../../ || exit
done

# Remove left-behind slurm output files with CPU/Memory usage
# statitistics.
files=$(
    find . \
        -type f \
        -user root \
        -name "${settings}_${system}_Li[0-9]*_transferred_*_slurm-[0-9]*.out" ||
        exit
)
if [[ ${#files[@]} -gt 0 ]]; then
    echo
    for file in ${files}; do
        rm -fv "${file}" || exit
    done
fi
