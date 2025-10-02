# Amber Simulations of Soluble Proteins

This repository provides an **automated pipeline** to prepare and run **[Amber](https://ambermd.org/) molecular dynamics simulations** of soluble proteins, with or without a ligand, using **Python’s [OpenMM](https://openmm.org/) library**. The workflow prepares all necessary input files, solvation, ligand parameters, and simulation configurations for equilibration and production runs.

---

## Repository Structure

* `utils/` – Utility scripts for system preparation, equilibration, production runs, and server submission.
  * `build.sh` – Main script to build system before running it.
  * `run.sh` – Main script to prepare the system and run equilibration/production simulations.
  * `openmm_run.py` – OpenMM execution script.
  * `batch_submit.sh` – Helper script for submitting multiple jobs on a [SLURM](https://slurm.schedmd.com/) server.
  * `job.slurm` – Example SLURM submission script for running a simulation.
  * `environment.yml` – Conda environment configuration for OpenMM.
  * `build_complex.leap` – tleap file to prepare **protein-ligand complexes**.
  * `build_protein.leap` – tleap file to prepare **protein-only systems**.
* `step1_equilibration.inp` – Input file for initial equilibration (minimization + restrained MD).
* `step2_equilibration.inp` – Input file for subsequent equilibration (unrestrained MD).
* `step3_production.inp` – Input file for production MD simulations (30 ns, unrestrained, NPT ensemble).

---

## Workflow Diagram
<img src="figures/workflow.png" alt="Amber Workflow" width="600">

---

## Installation / Environment Setup (UBELIX server)

To run the simulations on **[UBELIX](https://hpc-unibe-ch.github.io/)** or another server with [SLURM](https://slurm.schedmd.com/) installed:

1. Load the [CUDA](https://en.wikipedia.org/wiki/CUDA) module:

```bash
module load CUDA/11.8.0
```

2. Create the OpenMM [conda](https://docs.conda.io/en/latest/) environment:

```bash
conda env create -f utils/environment.yml -n openmm
conda activate openmm
```
Ensure that the openmm is activated properly by submitting the `utils/test.sh` job
```bash
sbatch utils/test.slurm
```
The output should look something like this:
```
OpenMM Version: 7.7
Git Revision: 130124a3f9277b054ec40927360a6ad20c8f5fa6

There are 4 Platforms available:

1 Reference - Successfully computed forces
2 CPU - Successfully computed forces
3 CUDA - Successfully computed forces
4 OpenCL - Successfully computed forces

Median difference in forces between platforms:

Reference vs. CPU: 6.31347e-06
Reference vs. CUDA: 6.72976e-06
CPU vs. CUDA: 7.17819e-07
Reference vs. OpenCL: 6.74399e-06
CPU vs. OpenCL: 7.50779e-07
CUDA vs. OpenCL: 2.16192e-07

All differences are within tolerance.
```

3. Create AmberTools 23 environment (needed for ligand preparation in `build.sh`)

```bash
conda create -n ambertools23 -c conda-forge python=3.9 ambertools=23
conda activate ambertools23
```
Ensure the correct installation of `AmberTools23` by running:
```bash
tleap -v
antechamber -h
```

4. Install VMD (for tcl scripts in `build.sh`, not visualization):
 - Download VMD from https://www.ks.uiuc.edu/Research/vmd/
 - Choose Linux version and copy to a folder on the server, e.g.:

```bash
tar -xvf vmd-1.9.4a51.bin.LINUXAMD64.opengl.tar.gz -C $HOME/tools
export PATH=$HOME/tools/VMD-1.9.4/bin:$PATH
```

Ensure VMD executable is in the `$PATH`, so `build.sh` can call TCL scripts. To test VMD installation execute:
```bash
vmd -dispdev text -e /dev/null -args
```

> OpenMM v7.7 and AmberTools 23 are required. Using older versions may cause errors.

---

## Preparing and Running Simulations

### 1. System Preparation

Run the main preparation script:

```bash
conda activate ambertools23
bash utils/build.sh <input_pdb_file> [<ligand_resname> <ligand_charge>]
```

* `<input_pdb_file>` – Path to the PDB file (protein or protein-ligand complex).
* `<ligand_resname>` – Three-letter residue name of the ligand in the PDB file.
* `<ligand_charge>` – Total charge of the ligand (integer or decimal).

**Behavior:**

* **With ligand:**

  * Extracts ligand from the PDB file.
  * Runs [`antechamber`](https://ambermd.org/antechamber/ac.html) to generate ligand `.mol2`, `.prepin`, and `.frcmod` files.
  * Uses `build_complex.leap` to combine protein and ligand, solvate, add ions, and generate `step3_input.{parm7,rst7,pdb}`.

* **Protein-only:**

  * Extracts protein without hydrogens.
  * Uses `build_protein.leap` to solvate and add ions.
  * Generates `step3_input.{parm7,rst7,pdb}`.

---

### 2. Equilibration

Two-step equilibration is implemented:

1. **step1_equilibration.inp** – Minimization + restrained MD

   * Steps: 5000 minimization + 125000 restrained MD
   * Time-step: 1 fs
   * Positional restraints: backbone (400 kJ/mol/nm²), side-chain (40 kJ/mol/nm²)
   * Temperature: 303.15 K, no pressure coupling

2. **step2_equilibration.inp** – Unrestrained MD

   * Steps: 1,000,000
   * Timestep: 2 fs
   * Backbone restraint: 40 kJ/mol/nm², side-chain: 0
   * Pressure coupling enabled (1 bar, isotropic Monte Carlo barostat)

> The equilibration runs are automatically managed in `utils/run.sh`.

---

### 3. Production Simulation

- **step3_production.inp**
   
   * Steps: 15,000,000 (30 ns)
   * Timestep: 2 fs
   * Backbone/side-chain restraints: none
   * NPT ensemble: temperature 303.15 K, pressure 1 bar, isotropic
   * Output frequency: nstout = 25000, nstdcd = 250000

- **How it works**
   
   * Managed through `utils/run.slurm`.
   * Generates both **checkpoint (`.chk`)** and **restart (`.rst`)** files:
       - `.chk` files store full OpenMM internal state, including GPU-specific randomization, and allow a **true continuation** of the simulation on the same hardware.
     - `.rst` files contain coordinates and velocities only; they can be used to **start simulations on different GPUs** but do not fully preserve the GPU-specific state like `.chk`.

### 4. Server Submission
* Pinned variables in `utils/job.slurm` for server submission:

  * GPU devices: `--gres=gpu:rtx4090:2`
  * Job name: `Amber_simulation`
  * Partition: `gpu`
  * Conda environment: `openmm`
  * Memory: `--mem-per-cpu=8G`
  * Excluded nodes: `--exclude=gnode23`

* Use `utils/batch_submit.sh job.slurm 10 [dependency id]` to submit multiple dependent jobs.

---

## Pinned / Important Variables

* **PDB input file:** `$1` in `build.sh`
* **Ligand residue name:** `$2` in `build.sh`
* **Ligand charge:** `$3` in `build.sh`
* **tleap files:**

  * Protein only → `build_protein.leap`
  * Protein-ligand → `build_complex.leap`
* **GPU devices for production:** `0,1` in `job.sh`
* **Amber/GAFF parameters:** `frcmod.ionsjc_tip3p`, `out.prepin`, `out.frcmod`

## Notes / Best Practices

* Ensure the **PDB file is pre-optimized** (missing hydrogens may be added automatically).
    * @Symela what does that mean? What tools can I use?
* Simulations require the **same GPU and CUDA version** if using checkpoint files.
* OpenMM v7.7 is required.
* Step3 production runs are controlled by the `.inp` file parameters (`dt`, `nstout`, `Target_ns`).


## Citation
Reference for CHARMM-GUI (used for openmm scripts)

> S. Jo, T. Kim, V.G. Iyer, and W. Im (2008)  CHARMM-GUI: A Web-based Graphical User Interface for CHARMM. J. Comput. Chem. 29:1859-1865 

## License
This project is licensed under the MIT License. See the LICENSE file for details.

## Authors
Symela Lazaridi, Univeristy of Bern, Switzerland, `symela.lazaridi@unibe.ch`

Thomas Lemmin, Univeristy of Bern, Switzerland, `thomas.lemmin@unibe.ch`
