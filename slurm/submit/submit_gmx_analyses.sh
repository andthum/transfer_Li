#!/bin/bash

settings="pr_nvt423_vr"
ana_scripts="1"
flags=(--begin 0)

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Submit Gromacs analysis tools for each transferred lithium ion to"
    echo "the Slurm workload manager using 'HPC Submit Scripts' (hpcss,"
    echo "https://github.com/andthum/hpc_submit_scripts), specifically"
    echo "'submit_gmx_analyses_lintf2_ether.py'"
    echo "(https://hpcss.readthedocs.io/en/latest/doc_pages/_sphinx_autosummary_analysis/submit_gmx_analyses_lintf2_ether.html)."
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
    echo "  -a    The analysis scripts to submit.  See"
    echo "        'submit_gmx_analyses_lintf2_ether.py' for possible options."
    echo "        Default: ${ana_scripts}."
    echo "  -f    Additional options (besides --system, --settings and"
    echo "        --scripts) to parse to"
    echo "        'submit_gmx_analyses_lintf2_ether.py' provided as one long,"
    echo "        enquoted string.  See there for possible options.  Default:"
    echo "        ${flags[*]}"
}

########################################################################
# Argument Parsing                                                     #
########################################################################

while getopts s:a:he:f: option; do
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
        a)
            ana_scripts=${OPTARG}
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

    # ana_dir="ana_${settings}_${system}_${dir}/gmx"
    # if [[ -d ${ana_dir} ]]; then
    #     echo "WARNING: Analysis directory already exists: '${ana_dir}'"
    #     cd ../../ || exit
    #     continue
    # fi

    # shellcheck disable=SC2048,SC2086
    submit_gmx_analyses_lintf2_ether.py \
        --system "${system}_${dir}" \
        --settings "${settings}" \
        --scripts "${ana_scripts}" \
        ${flags[*]} ||
        exit

    cd ../../ || exit
done
