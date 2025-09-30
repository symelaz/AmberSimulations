# Amber Simulations of Soluble Proteins

This repository automatically receives an input PDB file with or without a ligand, and prepares all the files for running Amber simulations using python's OPENMM library.

To setup the simulations' files you need to run:

```
bash utils/run.sh <input pdb file> <ligand's resname in the input pdb file> <ligand's desired charge for the simulation>
```

This will generate the parameter files for the ligand [if given in the input] and the `step3_input.parm7`, `step3_input.pdb`, `step3_input.rst7` files of the protein alone or the complex.

