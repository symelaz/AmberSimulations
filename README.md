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

```
Input PDB (protein ± ligand)
          │
          ▼
   utils/run.sh
          │
          ├─ If ligand present → extract ligand → generate ligand parameters (antechamber + frcmod)
          │
          ▼
   tleap (build_protein.leap / build_complex.leap)
          │
          ▼
   Solvation + Ions
          │
          ▼
   step3_input.{parm7,rst7,pdb}
          │
          ▼
   Equilibration
   ┌─────────────────────┐
   │ step4.1_equilibration│
   │ - Minimization       │
   │ - Restrained MD      │
   └─────────────────────┘
          │
          ▼
   step4.2_equilibration
   │ - Unrestrained MD    │
   │ - Pressure coupling  │
          │
          ▼
   Production (step5)
   │ - OpenMM simulations │
   │ - Checkpoints + DCD  │
          ▼
   Analysis & visualization
```
```mermaid
flowchart TD
    A[Input PDB (protein or ligand)] --> B[utils/run.sh]
    B -->|If ligand present| C[Extract ligand & generate ligand parameters<br>(antechamber and frcmod)]
    B -->|Protein-only| D[Skip ligand preparation]
    C --> E[tleap (build_protein.leap or build_complex.leap)]
    D --> E
    E --> F[Solvation and Ions]
    F --> G[step3_input.{parm7, rst7, pdb}]
    G --> H[Equilibration]
    H --> I[step4.1_equilibration<br>- Minimization<br>- Restrained MD]
    I --> J[step4.2_equilibration<br>- Unrestrained MD<br>- Pressure coupling]
    J --> K[Production (step5)<br>- OpenMM simulations<br>- Checkpoints and DCD]
    K --> L[Analysis and visualization]`
```
---

## Installation / Environment Setup (ubelix server)

To run the simulations on **ubelix**:

1. Load CUDA:

```bash
module load CUDA/11.8.0
```

2. Create the OpenMM conda environment:

```bash
conda env create -f utils/environment.yml -n openmm
conda activate openmm
```

> OpenMM v7.7 is required. Using an older version may cause errors.

---

## Preparing and Running Simulations

### 1. System Preparation

Run the main preparation script:

```bash
bash utils/run.sh <input_pdb_file> [<ligand_resname> <ligand_charge>]
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

* Use `utils/batch_submit.sh` to submit multiple dependent jobs.

---

## Pinned / Important Variables

* **PDB input file:** `$1` in `run.sh`
* **Ligand residue name:** `$2` in `run.sh`
* **Ligand charge:** `$3` in `run.sh`
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
