# Amber Simulations of Soluble Proteins

This repository provides an **automated pipeline** to prepare and run **Amber molecular dynamics simulations** of soluble proteins, with or without a ligand, using **Python’s OpenMM library**. The workflow prepares all necessary input files, solvation, ligand parameters, and simulation configurations for equilibration and production runs.

---

## Repository Structure

* `utils/` – Utility scripts for system preparation, equilibration, production runs, and server submission.

  * `run.sh` – Main script to prepare the system and run equilibration/production simulations.
  * `openmm_run.py` – OpenMM execution script.
  * `batch_submit.sh` – Helper script for submitting multiple jobs on a SLURM server.
  * `job.sh` – Example SLURM submission script for running a simulation.
  * `environment.yml` – Conda environment configuration for OpenMM.
  * `build_complex.leap` – tleap file to prepare **protein-ligand complexes**.
  * `build_protein.leap` – tleap file to prepare **protein-only systems**.
* `step4.1_equilibration.inp` – Input file for initial equilibration (minimization + restrained MD).
* `step4.2_equilibration.inp` – Input file for subsequent equilibration (unrestrained MD).
* `step5_production.inp` – Input file for production MD simulations (30 ns, unrestrained, NPT ensemble).

---

## Workflow Diagram
<img src="figures/workflow.png" alt="Amber Workflow" width="600">

---

## Usage Example

**Protein-ligand system:**

```bash
conda activate ambertools23
bash utils/build.sh <input_pdb_file> <ligand_resname> <ligand_charge>
bash utils/run.sh
```

**Protein-only system:**

```bash
conda activate ambertools23
bash utils/build.sh <input_pdb_file> 
bash utils/run.sh myprotein.pdb
```

* `<input_pdb_file>` – Path to the PDB file (protein or protein-ligand complex).
* `<ligand_resname>` – Three-letter residue name of the ligand in the PDB file.
* `<ligand_charge>` – Total charge of the ligand (integer or decimal).

---

## Notes / Best Practices

* Ensure the **PDB file is pre-optimized** (missing hydrogens may be added automatically).
* Simulations require the **same GPU and CUDA version** if using checkpoint files.
* OpenMM v7.7 is required.
* Step5 production runs are controlled by the `.inp` file parameters (`dt`, `nstout`, `Target_ns`).
