#!/bin/bash

########################################################################
# Information and Usage Functions                                      #
########################################################################

information() {
    echo "Submit the production run for each transferred lithium ion to the"
    echo "Slurm workload manager."
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

relaxation="re_nvt423_ld"
production="pr_nvt423_vr"

for dir in Li[0-9]*_transferred; do
    echo
    echo "${dir}"
    if [[ ! -d ${dir} ]]; then
        echo "WARNING: No such directory: '${dir}'"
        continue
    fi
    cd "${dir}" || exit

    # Clean up relaxation run.
    mv -v "${relaxation}_${system}_${dir}" "01_${relaxation}_${system}_${dir}" || exit

    # Prepare production run.
    cp -v "01_${relaxation}_${system}_${dir}/${system}_${dir}.top" ./ || exit
    cp -v "01_${relaxation}_${system}_${dir}/${system}_${dir}.ndx" ./ || exit
    cp -v "01_${relaxation}_${system}_${dir}/${relaxation}_out_${system}_${dir}.gro" ./ || exit

    # Submit production run.
    submit_gmx_mdrun.py \
        --system "${system}_${dir}" \
        --settings "${production}" \
        --structure "${relaxation}_out_${system}_${dir}.gro" \
        --grompp-flags "-maxwarn 1" \
        --mdrun-flags "-cpt 60 -ntmpi 36 -npme 12" ||
        exit

    cd ../ || exit
done

# Remove left-behind slurm output files with CPU/Memory usage
# statitistics.
files=$(
    find . \
        -type f \
        -user root \
        -name "${relaxation}_out_${system}_Li[0-9]*_transferred_slurm-[0-9]*.out" ||
        exit
)
if [[ ${#files[@]} -gt 0 ]]; then
    echo
    for file in ${files}; do
        rm -fv "${file}" || exit
    done
fi
