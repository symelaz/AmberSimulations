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

## Installation / Environment Setup (ubelix server)

To run the simulations on **ubelix**:

### 1. Load CUDA:

```bash
module load CUDA/11.8.0
```

### 2. Create the OpenMM conda environment:

```bash
conda env create -f utils/environment.yml -n openmm
conda activate openmm
```
Ensure that the openmm is activated properly by submitting the `utils/test.sh` job
```bash
sbatch utils/test.sh
```
The output should look like this:
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

### 3. Create AmberTools 23 environment (needed for ligand preparation in `build.sh`)

```bash
conda create -n ambertools23 -c conda-forge python=3.9 ambertools=23
conda activate ambertools23
```
Ensure the correct installation of `AmberTools23` by running:
```bash
tleap -v
antechamber -h
```

### 4. VMD 1.9.4a57 Installation on Ubelix
This guide explains how to install VMD 1.9.4a57 on the Ubelix server (Linux RHEL 7+, 64-bit Intel/AMD) without CUDA or SIMD packages.

 1. Download VMD from https://www.ks.uiuc.edu/Research/vmd/
 2. Choose Linux version and copy to a folder on the server, e.g.:
 `LINUX_64 (RHEL 7+) OpenGL, CUDA, OptiX RTX, OSPRay (Linux (RHEL 7+) 64-bit Intel/AMD x86_64 SSE/AVX+ with CUDA 10, OptiX6.5 RTX, OSPRay185.opengl)`
 3. Transfer this file to the ubelix server in the location where you want VMD installed.
 4. Extract the package:
 ```bash
 gunzip vmd-1.9.4a57.bin.LINUXAMD64-CUDA102-OptiX650-OSPRay185.opengl.tar.gz
 tar -xvf vmd-1.9.4a57.bin.LINUXAMD64-CUDA102-OptiX650-OSPRay185.opengl.tar
 cd vmd-1.9.4a57
 ```
 5. Go inside the folder end extract its full path:
 ```bash
 cd vmd-1.9.4a57
 pwd
 ```
 6. Copy this path and add it inside the `configure` file of the folder as shown below:
 
 ``` bash
 # Name of shell script used to start program; this is the name used by users
 $install_name = "vmd";

 # Directory where VMD startup script is installed, should be in users' paths.
 $install_bin_dir="YOUR/PATH/HERE";
 
 # Directory where VMD files and executables are installed
 $install_library_dir="YOUR/PATH/HERE";
 ```
 
  7. Run the configure script without CUDA or SIMD:
  ```bash
  ./configure LINUXAMD64 TCL IMD COLVARS SILENT
  ```

  8. Build VMD: go to the `src` folder and finalize installation
  ```bash
  cd src
  make
  make install
  cd ../
  ```

  9. Add vmd to path, by adding this line `export PATH=“YOUR/PATH/HERE/vmd:$PATH”`（e.g. export PATH="/storage/homefs/username/vmd-1.9.4a57/bin:$PATH"）at the end of the `~/.bashrc` file. Then source ~/.bashrc.
  10. Check again the installation by typing just `vmd` from any folder. This should output something like:
  ```
  Info) VMD for LINUXAMD64, version 1.9.4a57 (April 27, 2022)
  Info) http://www.ks.uiuc.edu/Research/vmd/                         
  Info) Email questions and bug reports to vmd@ks.uiuc.edu           
  Info) Please include this reference in published work using VMD:   
  Info)    Humphrey, W., Dalke, A. and Schulten, K., `VMD - Visual   
  Info)    Molecular Dynamics', J. Molec. Graphics 1996, 14.1, 33-38.
  Info) -------------------------------------------------------------
  Info) Multithreading available, 128 CPUs.
  Info)   CPU features: SSE2 SSE4.1 AVX AVX2 FMA F16 HT 
  Info) Free system memory: 48GB (38%)
  Info) No CUDA accelerator devices available.
  Info) Dynamically loaded 3 plugins in directory:
  Info) /storage/homefs/cr22r967/vmd-1.9.4a57/plugins/LINUXAMD64/molfile
  vmd > 
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
  * Runs `antechamber` to generate ligand `.mol2`, `.prepin`, and `.frcmod` files.
  * Uses `build_complex.leap` to combine protein and ligand, solvate, add ions, and generate `step3_input.{parm7,rst7,pdb}`.

* **Protein-only:**

  * Extracts protein without hydrogens.
  * Uses `build_protein.leap` to solvate and add ions.
  * Generates `step3_input.{parm7,rst7,pdb}`.

---

### 2. Equilibration

Two-step equilibration is implemented:

1. **step4.1_equilibration.inp** – Minimization + restrained MD

   * Steps: 5000 minimization + 125000 restrained MD
   * Time-step: 1 fs
   * Positional restraints: backbone (400 kJ/mol/nm²), side-chain (40 kJ/mol/nm²)
   * Temperature: 303.15 K, no pressure coupling

2. **step4.2_equilibration.inp** – Unrestrained MD

   * Steps: 1,000,000
   * Timestep: 2 fs
   * Backbone restraint: 40 kJ/mol/nm², side-chain: 0
   * Pressure coupling enabled (1 bar, isotropic Monte Carlo barostat)

> The equilibration runs are automatically managed in `utils/run.sh`.

---

### 3. Production Simulation

- **step5_production.inp**
   
   * Steps: 15,000,000 (30 ns)
   * Timestep: 2 fs
   * Backbone/side-chain restraints: none
   * NPT ensemble: temperature 303.15 K, pressure 1 bar, isotropic
   * Output frequency: nstout = 25000, nstdcd = 250000

- **How it works**
   
   * Managed through `utils/run.sh`.
   * Generates both **checkpoint (`.chk`)** and **restart (`.rst`)** files:
       - `.chk` files store full OpenMM internal state, including GPU-specific randomization, and allow a **true continuation** of the simulation on the same hardware.
     - `.rst` files contain coordinates and velocities only; they can be used to **start simulations on different GPUs** but do not fully preserve the GPU-specific state like `.chk`.

### 3. Sever Submission
* Pinned variables in `utils/job.sh` for server submission:

  * GPU devices: `--gres=gpu:rtx4090:2`
  * Job name: `test`
  * Partition: `gpu`
  * Conda environment: `openmm`
  * Memory: `--mem-per-cpu=8G`
  * Excluded nodes: `--exclude=gnode23`

* Use `utils/batch_submit.sh job.sh 10 [dependency id]` to submit multiple dependent jobs.

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

---

## Usage Example

**Protein-ligand system:**

```bash
bash utils/run.sh myprotein_ligand.pdb LIG 0
```

**Protein-only system:**

```bash
bash utils/run.sh myprotein.pdb
```

---

## Notes / Best Practices

* Ensure the **PDB file is pre-optimized** (missing hydrogens may be added automatically).
* Simulations require the **same GPU and CUDA version** if using checkpoint files.
* OpenMM v7.7 is required.
* Step5 production runs are controlled by the `.inp` file parameters (`dt`, `nstout`, `Target_ns`).
