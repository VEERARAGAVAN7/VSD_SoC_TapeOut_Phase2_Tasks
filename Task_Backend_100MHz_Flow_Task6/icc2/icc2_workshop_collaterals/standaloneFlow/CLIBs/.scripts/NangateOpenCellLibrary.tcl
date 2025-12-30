set NDM_LIBS {}
set FRAME_LIBS {}
set LEF_FILES {/home/veeram/PD_task6/run1/icc2_workshop_collaterals/nangate_stdcell.lef}
set DB_FILES {/home/veeram/PD_task6/run1/icc2_workshop_collaterals/nangate_typical.db}
set TECH_FILE "/home/veeram/PD_task6/run1/icc2_workshop_collaterals/nangate.tf"

set_app_options -name lib.workspace.create_cached_lib -value true
#suppress_messages

set_app_options -name lib.workspace.allow_read_aggregate_lib -value true
create_workspace NangateOpenCellLibrary -technology $TECH_FILE -scale_factor 10000
read_lef $LEF_FILES
read_db $DB_FILES
process_workspaces -check_options {-allow_missing} -force -directory CLIBs -output NangateOpenCellLibrary.ndm
