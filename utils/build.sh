#!/bin/bash

############################## INPUTS ##############################
# $1 --> input PDB file
# $2 --> ligand resname
# $3 --> ligand charge
# $4 --> ph for ligand protonation (normally 7.4)

PDBFILE="$1"
RESNAME="$2"
LIGCHARGE="$3"
LIGPH="$4"

# Check if at least the PDB file is provided
if [ -z "$PDBFILE" ]; then
    echo "Usage: $0 <pdb_file> [ligand_resname ligand_charge]"
    exit 1
fi

# Create main directory to save the preparation steps
FOLDER=build
mkdir -p $FOLDER

# Flag to indicate if ligand is present
LIGAND_PRESENT=false

# If all three inputs are provided, process the ligand
if [ -n "$RESNAME" ] && [ -n "$LIGCHARGE" ]; then
    LIGAND_PRESENT=true
    echo "Ligand detected: $RESNAME with charge $LIGCHARGE"

    # Extract the ligand only from the PDB
    grep -w "$RESNAME" "$PDBFILE" | sed "s/$RESNAME/out/g" > "$FOLDER/out_noh.pdb"

    # Protonate the ligand
    python utils/protonate_pdb.py "$FOLDER"/out_noh.pdb "$FOLDER"/out_ph.pdb $LIGPH
    sed -i 's/UNL/out/g' "$FOLDER"/out_ph.pdb

    # Run antechamber to generate ligand parameters
    antechamber -i "$FOLDER"/out_ph.pdb -fi pdb -o "$FOLDER"/out.mol2 -fo mol2 -c bcc -rn out -at gaff2 -nc "$LIGCHARGE"
    rm -f ANTECHAMBER_* ATOMTYPE.INF
    mv sqm* "$FOLDER"

    # Generate PREPI file
    antechamber -i "$FOLDER"/out_ph.pdb -fi pdb -o "$FOLDER"/out.prepin -fo prepi -c bcc -at gaff2 -nc "$LIGCHARGE"
    rm -f ANTECHAMBER_* ATOMTYPE.INF
    mv sqm* "$FOLDER"

    # Generate FRCMOD file
    parmchk2 -i "$FOLDER"/out.mol2 -f mol2 -o "$FOLDER"/out.frcmod -s gaff2
    rm -f PREP.INF NEWPDB.PDB

    # Convert the mol2 file back to PDB
    # to ensure compatibility between antechamber atom names and the PDB file 
    # before running tleap
    antechamber -i "$FOLDER"/out.mol2 -fi mol2 -o "$FOLDER"/out.pdb -fo pdb

else
    echo "No ligand detected. Only protein will be processed."
fi

# Extract protein without hydrogens
vmd -dispdev text -e utils/extract_protein.tcl -args "$PDBFILE" "$FOLDER/protein_noh.pdb"

# System preparation using tleap
if [ "$LIGAND_PRESENT" = true ]; then
    echo "Running tleap for protein-ligand complex"
    tleap -s -f utils/build_complex.leap
else
    echo "Running tleap for protein only"
    tleap -s -f utils/build_protein.leap
fi

mv leap.log "$FOLDER"

# Final step: create restraints and move box to 0.0.0
mkdir -p restraints
vmd -dispdev text -e utils/create_omm.tcl

echo "System preparation complete."
exit 0
