#!/bin/bash

settings="pr_nvt423_vr"
analysis="rmsd_vs_time"
flags=()

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Submit the Slurm job script 'mdt_rmsd_vs_time.sh' for each"
    echo "transferred lithium ion to the Slurm workload manager."
}

usage() {
    echo
    echo "Usage:"
    echo
    echo "Required arguments:"
    echo "  -s    The name of the system to analyze, e.g."
    echo "        lintf2_g1_20-1_gra_q1_sc80."
    echo
    echo "Optional arguments:"
    echo "  -h    Show this help message and exit."
    echo "  -e    The simulation settings of the simulation to analyze."
    echo "        Default: ${settings}."
    echo "  -f    Additional options (besides --job-name and --output)"
    echo "        to parse to 'sbatch' provided as one long, enquoted"
    echo "        string.  Default: '${flags[*]}'."
}

########################################################################
# Argument Parsing                                                     #
########################################################################

while getopts s:he:f: option; do
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
        f)
            # See https://github.com/koalaman/shellcheck/wiki/SC2086#exceptions
            # and https://github.com/koalaman/shellcheck/wiki/SC2206
            # shellcheck disable=SC2206
            flags=(${OPTARG})
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

get_resid() {
    resid=$(
        grep "^ *[0-9].*[0-9]$" "${transfer_file}" |
        head -n "${n}" |
        tail -n 1 |
        gawk 'BEGIN {FIELDWIDTHS="5 5 5 5 8 8 8 8 8 8"} {print $1}' ||
        exit
    )
    # Trim leading and trailing spaces (echo without double quotes).
    # shellcheck disable=SC2086
    resid=$(echo ${resid} || exit)
}

get_removal_point() {  # in Angstrom (-> *10)
    removal_point=$(
        grep "^ *[0-9].*[0-9]$" "${transfer_file}" |
        head -n "${n}" |
        tail -n 1 |
        gawk 'BEGIN {FIELDWIDTHS="5 5 5 5 8 8 8 8 8 8"} {printf "%s %s %s", $5*10, $6*10, $7*10}' ||
        exit
    )
    # Trim leading and trailing spaces (echo without double quotes).
    # shellcheck disable=SC2086
    removal_point=$(echo ${removal_point} || exit)
}

get_insertion_point() {  # in Angstrom (-> *10)
    insertion_point=$(
        grep "^ *[0-9].*  # Insertion point.*$" "${transfer_file}" |
        gawk '{printf "%s %s %s", $1*10, $2*10, $3*10}' ||
        exit
    )
    # Trim leading and trailing spaces (echo without double quotes).
    # shellcheck disable=SC2086
    insertion_point=$(echo ${insertion_point} || exit)
}

########################################################################
# Main Part                                                            #
########################################################################

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
slurm_job_script_dir=$(readlink -e "${script_dir}/../job" || exit)
slurm_job_script="${slurm_job_script_dir}/mdt_rmsd_vs_time.sh"
if [[ ! -d ${script_dir} ]]; then
    echo "ERROR: No such directory '${script_dir}'"
    exit 1
fi
if [[ ! -d ${slurm_job_script_dir} ]]; then
    echo "ERROR: No such directory '${slurm_job_script_dir}'"
    exit 1
fi
if [[ ! -f ${slurm_job_script} ]]; then
    echo "ERROR: No such file '${slurm_job_script}'"
    exit 1
fi

transfer_file_gz="pr_nvt423_nh_${system}_transfer_Li.txt.gz"
transfer_file="${transfer_file_gz::-3}"
if [[ ! -f ${transfer_file_gz} ]]; then
    echo "ERROR: No such file '${transfer_file_gz}'"
    exit 1
fi
echo
gzip --decompress --verbose "${transfer_file_gz}"
if [[ ! -f ${transfer_file} ]]; then
    echo "ERROR: No such file '${transfer_file}'"
    exit 1
fi

if [[ ${settings} == "re_nvt423_ld" ]]; then
    prefix="01"
elif [[ ${settings} == "pr_nvt423_vr" ]]; then
    prefix="02"
else
    echo
    echo "Error: Unknown 'settings': '${settings}'"
fi

n_directories=0
for dir in Li[0-9]*_transferred; do
    n_directories=$(( n_directories + 1 ))
done
for (( n=1; n<=n_directories; n++ )); do
    get_resid || exit
    dir="Li${resid}_transferred"
    echo
    echo "${dir}"
    if [[ ! -d ${dir} ]]; then
        echo "WARNING: No such directory: '${dir}'"
        continue
    fi
    get_removal_point || exit
    get_insertion_point || exit
    cd "${dir}/" || exit

    sim_dir="${prefix}_${settings}_${system}_${dir}"
    if [[ ! -d ${sim_dir} ]]; then
        echo "WARNING: No such directory: '${sim_dir}'"
        cd ../ || exit
        continue
    fi
    cd "${sim_dir}" || exit

    # shellcheck disable=SC2048,SC2086
    sbatch \
        --job-name "${settings}_${system}_${dir}_${analysis}" \
        --output "${settings}_${system}_${dir}_${analysis}_slurm-%j.out" \
        ${flags[*]} \
        "${slurm_job_script}" \
            "${system}_${dir}" \
            "${settings}" \
            "${resid}" \
            "${removal_point}" \
            "${insertion_point}" ||
        exit

    cd ../../ || exit
done

echo
gzip --best --verbose "${transfer_file}"
