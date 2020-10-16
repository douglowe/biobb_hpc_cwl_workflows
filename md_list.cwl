#!/usr/bin/env cwl-runner

cwlVersion: v1.2.0-dev3
class: Workflow
label: Example of setting up a simulation system
doc: |
  CWL version of the md_list.cwl workflow for HPC.

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}


inputs:
  step1_pdb_file: File
  step2_editconf_config: string
  step4_grompp_genion_config: string
  step5_genion_config: string
  step6_grompp_min_config: string
  step8_make_ndx_config: string
  
  step9_grompp_nvt_config: string
  step11_grompp_npt_config: string
  step13_grompp_md_config: string
  step14_mdrun_md_config: string

outputs:
  dir:
    label: whole workflow output
    doc: |
      outputs from the whole workflow, containing these optional files:
      step14_mdrun_md/output_trr_file:   Raw trajectory from the free simulation step
      step14_mdrun_md/output_gro_file:   Raw structure from the free simulation step.
      step14_mdrun_md/output_cpt_file:   GROMACS portable checkpoint file, allowing to restore (continue) the
                                         simulation from the last step of the setup process.
      step13_grompp_md/output_tpr_file:  GROMACS portable binary run input file, containing the starting structure
                                         of the simulation, the molecular topology and all the simulation parameters.
      step5_genion/output_top_zip_file:  GROMACS topology file, containing the molecular topology in an ASCII
                                         readable format.
    type: Directory
    outputSource: step15_gather_outputs/step15_work_dir

steps:
  step1_pdb2gmx:
    label: Create Protein System Topology
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/pdb2gmx.cwl
    in:
      input_pdb_path: step1_pdb_file
    out: [output_gro_file, output_top_zip_file]

  step2_editconf:
    label: Create Solvent Box
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/editconf.cwl
    in:
      input_gro_path: step1_pdb2gmx/output_gro_file
    out: [output_gro_file]

  step3_solvate:
    label: Fill the Box with Water Molecules
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/solvate.cwl
    in:
      input_solute_gro_path: step2_editconf/output_gro_file
      input_top_zip_path: step1_pdb2gmx/output_top_zip_file
    out: [output_gro_file, output_top_zip_file]

  step4_grompp_genion:
    label: Add Ions - part 1
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/grompp.cwl
    in:
      config: step4_grompp_genion_config
      input_gro_path: step3_solvate/output_gro_file
      input_top_zip_path: step3_solvate/output_top_zip_file
    out: [output_tpr_file]

  step5_genion:
    label: Add Ions - part 2
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/genion.cwl
    in:
      config: step5_genion_config
      input_tpr_path: step4_grompp_genion/output_tpr_file
      input_top_zip_path: step3_solvate/output_top_zip_file
    out: [output_gro_file, output_top_zip_file]

  step6_grompp_min:
    label: Energetically Minimize the System - part 1
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/grompp.cwl
    in:
      config: step6_grompp_min_config
      input_gro_path: step5_genion/output_gro_file
      input_top_zip_path: step5_genion/output_top_zip_file
    out: [output_tpr_file]

  step7_mdrun_min:
    label: Energetically Minimize the System - part 2
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/mdrun.cwl
    in:
      input_tpr_path: step6_grompp_min/output_tpr_file
    out: [output_trr_file, output_gro_file, output_edr_file, output_log_file]

  step8_make_ndx:
    label: Generate GROMACS index file
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/make_ndx.cwl
    in:
      config: step8_make_ndx_config
      input_structure_path: step7_mdrun_min/output_gro_file
    out: [output_ndx_file]

  step9_grompp_nvt:
    label: Equilibrate the System (NVT) - part 1
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/grompp.cwl
    in:
      config: step9_grompp_nvt_config
      input_gro_path: step7_mdrun_min/output_gro_file
      input_top_zip_path: step5_genion/output_top_zip_file
      input_ndx_path: step8_make_ndx/output_ndx_file
    out: [output_tpr_file]

  step10_mdrun_nvt:
    label: Equilibrate the System (NVT) - part 2
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/mdrun.cwl
    in:
      input_tpr_path: step9_grompp_nvt/output_tpr_file
    out: [output_trr_file, output_gro_file, output_edr_file, output_log_file, output_cpt_file]

  step11_grompp_npt:
    label: Equilibrate the System (NPT) - part 1
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/grompp.cwl
    in:
      config: step11_grompp_npt_config
      input_gro_path: step10_mdrun_nvt/output_gro_file
      input_top_zip_path: step5_genion/output_top_zip_file
      input_ndx_path: step8_make_ndx/output_ndx_file
      input_cpt_path:  step10_mdrun_nvt/output_cpt_file
    out: [output_tpr_file]

  step12_mdrun_npt:
    label: Equilibrate the System (NPT) - part 2
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/mdrun.cwl
    in:
      input_tpr_path: step11_grompp_npt/output_tpr_file
    out: [output_trr_file, output_gro_file, output_edr_file, output_log_file, output_cpt_file]

  step13_grompp_md:
    label: Free Molecular Dynamics Simulation - part 1
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/grompp.cwl
    in:
      config: step13_grompp_md_config
      input_gro_path: step12_mdrun_npt/output_gro_file
      input_top_zip_path: step5_genion/output_top_zip_file
      input_ndx_path: step8_make_ndx/output_ndx_file
      input_cpt_path:  step12_mdrun_npt/output_cpt_file
    out: [output_tpr_file]

  step14_mdrun_md:
    label: Free Molecular Dynamics Simulation - part 2
    run: biobb/biobb_adapters/cwl/biobb_md/gromacs/mdrun.cwl
    in:
      config: step14_mdrun_md_config
      input_tpr_path: step13_grompp_md/output_tpr_file
    out: [output_trr_file, output_gro_file, output_edr_file, output_log_file, output_cpt_file]

  step15_gather_outputs:
    label: Archiving outputs to be returned to user
    in:
      step15_project_file: step1_pdb_file
      step15_files: 
        source:
          - step14_mdrun_md/output_trr_file
          - step14_mdrun_md/output_gro_file
          - step14_mdrun_md/output_cpt_file  # we have to run with v1.2.0, or this null value breaks the workflow!
          - step13_grompp_md/output_tpr_file 
          - step5_genion/output_top_zip_file
        linkMerge: merge_flattened
        pickValue: all_non_null # this is needed to avoid null values causing problems, but is only available from v1.2.0 onwards
    out: [step15_work_dir]
    run:
      class: Workflow
      inputs:
        step15_project_file: File
        step15_files: File[]
      outputs:
        step15_work_dir: 
          label: Output archive directory
          doc: |
            workflow output directory, containing required output files
          type: Directory
          outputSource: stepb_move_files/output_dir
      steps:
        
        stepa_create_dir:
          in:
            stepa_project_file: step15_project_file
          out: [output_dir]
          run: 
            class: CommandLineTool
            baseCommand: mkdir
            arguments: [ $(inputs.stepa_project_file.basename) ]
            inputs:
              stepa_project_file: File
            outputs:
              output_dir:
                type: Directory
                outputBinding:
                  glob: "$(inputs.stepa_project_file.basename)"
        
        stepb_move_files:
          in:
            stepb_project_dir: stepa_create_dir/output_dir
            stepb_files: step15_files
          out: [output_dir]
          run:
            class: CommandLineTool 
            baseCommand: mv
            requirements:
              InitialWorkDirRequirement:
                listing:
                  - $(inputs.stepb_project_dir)
            arguments: [ $(inputs.stepb_files), $(inputs.stepb_project_dir.basename) ]
            inputs:
              stepb_project_dir: Directory 
              stepb_files: File[]
            outputs:
              output_dir:
                type: Directory
                outputBinding:
                  glob: "$(inputs.stepb_project_dir.basename)"











