#!/bin/bash

#SBATCH --time=0-06:00:00
#SBATCH --partition=himsshsort,q0heuer,hims,normal
#SBATCH --job-name="rmsd_vs_time"
#SBATCH --output="rmsd_vs_time_slurm-%j.out"
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=a_thum01@uni-muenster.de
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
# #SBATCH --mem=2G
# The above options are only default values that can be overwritten by
# command-line arguments

# MIT License

analysis="rmsd_vs_time"
thisfile=$(basename "${BASH_SOURCE[0]}")
echo "${thisfile}"
start_time=$(date --rfc-3339=seconds || exit)
echo "Start time = ${start_time}"

########################################################################
# Argument Parsing                                                     #
########################################################################

bash_dir="${HOME}/Promotion/hpc_submit_scripts/bash" # Directory containing bash scripts used by this script
py_lmod="${HOME}/Promotion/hpc_submit_scripts/lmod/palma/2020b/python3-8-6.sh" # File containing the modules to load Python
py_exe="${HOME}/Promotion/mdtools/.venv/bin/python3" # Name of the Python executable
mdt_path="${HOME}/Promotion/mdtools" # Path to the MDTools installation
system=${1} # The name of the system to analyze
settings=${2} # The used simulation settings
begin=0 # First frame to read.  Frame numbering starts at 0
end=-1  # Last frame to read (exclusive)
every=1 # Read every n-th frame
resid=${3} # Residue ID of the replaced lithium ion
removal_point=${4} # Point from which the lithium ion was removed in Angstrom
insertion_point=${5} # Point where the lithium ion was inserted in Angstrom
solvation_shell_1=3.00 # End of the 1st Li solvation shell in Angstrom
solvation_shell_2=7.50 # End of the 2nd Li solvation shell in Angstrom
solvation_shell_3=12.00 # End of the 2nd Li solvation shell in Angstrom

echo -e "\n"
echo "Parsed arguments:"
echo "bash_dir          = ${bash_dir}"
echo "py_lmod           = ${py_lmod}"
echo "py_exe            = ${py_exe}"
echo "mdt_path          = ${mdt_path}"
echo "system            = ${system}"
echo "settings          = ${settings}"
echo "begin             = ${begin}"
echo "end               = ${end}"
echo "every             = ${every}"
echo "resid             = ${resid}"
echo "removal_point     = ${removal_point}"
echo "insertion_point   = ${insertion_point}"
echo "solvation_shell_1 = ${solvation_shell_1}"
echo "solvation_shell_2 = ${solvation_shell_2}"
echo "solvation_shell_3 = ${solvation_shell_3}"

if [[ ! -d ${bash_dir} ]]; then
    echo
    echo "ERROR: No such directory: '${bash_dir}'"
    exit 1
fi

echo -e "\n"
bash "${bash_dir}/echo_slurm_output_environment_variables.sh"

########################################################################
# Load required executable(s)                                          #
########################################################################

# shellcheck source=/dev/null
source "${bash_dir}/load_python.sh" "${py_lmod}" "${py_exe}" || exit

########################################################################
# Start the Analysis                                                   #
########################################################################

electrodes="resname gra*"

removal_shell_1="not ${electrodes} and not resid ${resid} and point ${removal_point} ${solvation_shell_1}"
removal_shell_2="not ${electrodes} and not resid ${resid} and not point ${removal_point} ${solvation_shell_1} and point ${removal_point} ${solvation_shell_2}"
removal_shell_3="not ${electrodes} and not resid ${resid} and not point ${removal_point} ${solvation_shell_2} and point ${removal_point} ${solvation_shell_3}"
not_removal_area="not point ${removal_point} ${solvation_shell_3}"

insertion_shell_1="not ${electrodes} and not resid ${resid} and point ${insertion_point} ${solvation_shell_1}"
insertion_shell_2="not ${electrodes} and not resid ${resid} and not point ${insertion_point} ${solvation_shell_1} and point ${insertion_point} ${solvation_shell_2}"
insertion_shell_3="not ${electrodes} and not resid ${resid} and not point ${insertion_point} ${solvation_shell_2} and point ${insertion_point} ${solvation_shell_3}"
not_insertion_area="not point ${insertion_point} ${solvation_shell_3}"

resid_shell_1="not ${electrodes} and around ${solvation_shell_1} resid ${resid}"
resid_shell_2="not ${electrodes} and sphlayer ${solvation_shell_1} ${solvation_shell_2} resid ${resid}"
resid_shell_3="not ${electrodes} and sphlayer ${solvation_shell_2} ${solvation_shell_3} resid ${resid}"
resid_itself="resid ${resid}"

remaining="not ${electrodes} and not resid ${resid} and ${not_removal_area} and ${not_insertion_area}"


echo -e "\n"
echo "1st Solvation Shell of Removal Point"
echo "0.00-${solvation_shell_1} Angstrom"
echo "Selection: ${removal_shell_1}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_removal_point_0.00-${solvation_shell_1}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${removal_shell_1}" \
    --cmp "atoms" \
    --weights "mass"
    # For 1st solvation shell, dont't exit on failure, because there
    # might be no atoms within the 1st solvation shell (although this is
    # quite unlikely).
echo "================================================================="

echo -e "\n"
echo "2nd Solvation Shell of Removal Point"
echo "${solvation_shell_1}-${solvation_shell_2} Angstrom"
echo "Selection: ${removal_shell_2}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_removal_point_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${removal_shell_2}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="

echo -e "\n"
echo "3rd Solvation Shell of Removal Point"
echo "${solvation_shell_2}-${solvation_shell_3} Angstrom"
echo "Selection: ${removal_shell_3}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_removal_point_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${removal_shell_3}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="


echo -e "\n"
echo "1st Solvation Shell of Insertion Point"
echo "0.00-${solvation_shell_1} Angstrom"
echo "Selection: ${insertion_shell_1}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_insertion_point_0.00-${solvation_shell_1}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${insertion_shell_1}" \
    --cmp "atoms" \
    --weights "mass"
    # For 1st solvation shell, dont't exit on failure, because there
    # might be no atoms within the 1st solvation shell (although this is
    # quite unlikely).
echo "================================================================="

echo -e "\n"
echo "2nd Solvation Shell of Insertion Point"
echo "${solvation_shell_1}-${solvation_shell_2} Angstrom"
echo "Selection: ${insertion_shell_2}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_insertion_point_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${insertion_shell_2}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="

echo -e "\n"
echo "3rd Solvation Shell of Insertion Point"
echo "${solvation_shell_2}-${solvation_shell_3} Angstrom"
echo "Selection: ${insertion_shell_3}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_insertion_point_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${insertion_shell_3}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="


echo -e "\n"
echo "1st Solvation Shell of Transferred Li"
echo "0.00-${solvation_shell_1} Angstrom"
echo "Selection: ${resid_shell_1}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_resid${resid}_0.00-${solvation_shell_1}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${resid_shell_1}" \
    --cmp "atoms" \
    --weights "mass"
    # For 1st solvation shell, dont't exit on failure, because there
    # might be no atoms within the 1st solvation shell (although this is
    # quite unlikely).
echo "================================================================="

echo -e "\n"
echo "2nd Solvation Shell of Transferred Li"
echo "${solvation_shell_1}-${solvation_shell_2} Angstrom"
echo "Selection: ${resid_shell_2}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_resid${resid}_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${resid_shell_2}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="

echo -e "\n"
echo "3rd Solvation Shell of Transferred Li"
echo "${solvation_shell_2}-${solvation_shell_3} Angstrom"
echo "Selection: ${resid_shell_3}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_resid${resid}_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${resid_shell_3}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="


echo -e "\n"
echo "The Transferred Li Itself"
echo "Selection: ${resid_itself}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_resid${resid}.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${resid_itself}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="


echo -e "\n"
echo "Remaining (Neither Removal nor Insertion Area nor the Replaced Li Itself)"
echo "Selection: ${remaining}"
echo "================================================================="
${py_exe} -u \
    "${mdt_path}/scripts/structure/rmsd_vs_time.py" \
    -f "${settings}_out_${system}_pbc_whole_mol_nojump.xtc" \
    -s "${settings}_${system}.tpr" \
    -o "${settings}_${system}_${analysis}_remaining.txt.gz" \
    -b "${begin}" \
    -e "${end}" \
    --every "${every}" \
    --sel "${remaining}" \
    --cmp "atoms" \
    --weights "mass" ||
    exit
echo "================================================================="

########################################################################
# Cleanup                                                              #
########################################################################

save_dir="${analysis}_slurm-${SLURM_JOB_ID}"
if [[ ! -d ${save_dir} ]]; then
    echo -e "\n"
    mkdir -v "${save_dir}" || exit
    mv -v \
        "${settings}_${system}_${analysis}_removal_point_0.00-${solvation_shell_1}A.txt.gz" \
        "${settings}_${system}_${analysis}_removal_point_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
        "${settings}_${system}_${analysis}_removal_point_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
        "${settings}_${system}_${analysis}_insertion_point_0.00-${solvation_shell_1}A.txt.gz" \
        "${settings}_${system}_${analysis}_insertion_point_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
        "${settings}_${system}_${analysis}_insertion_point_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
        "${settings}_${system}_${analysis}_resid${resid}_0.00-${solvation_shell_1}A.txt.gz" \
        "${settings}_${system}_${analysis}_resid${resid}_${solvation_shell_1}-${solvation_shell_2}A.txt.gz" \
        "${settings}_${system}_${analysis}_resid${resid}_${solvation_shell_2}-${solvation_shell_3}A.txt.gz" \
        "${settings}_${system}_${analysis}_resid${resid}.txt.gz" \
        "${settings}_${system}_${analysis}_remaining.txt.gz" \
        "${settings}_${system}_${analysis}_slurm-${SLURM_JOB_ID}.out" \
        "${save_dir}"
    bash "${bash_dir}/cleanup_analysis.sh" \
        "${system}" \
        "${settings}" \
        "${save_dir}" \
        "mdt"
fi

end_time=$(date --rfc-3339=seconds)
elapsed_time=$(bash \
    "${bash_dir}/date_time_diff.sh" \
    -s "${start_time}" \
    -e "${end_time}")
echo -e "\n"
echo "End time     = ${end_time}"
echo "Elapsed time = ${elapsed_time}"
echo "${thisfile} done"
