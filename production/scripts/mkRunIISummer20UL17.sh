#!/bin/bash
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})
source $SCRIPT_DIR/utils.sh

CAMPAIGN=RunIISummer20UL17
FRAGMENT=$1
GRIDPACK=$2
EVENTS=$3

# == GEN,LHE =====================================
# Prepid: SMP-RunIISummer20UL17wmLHEGEN-00001
setup_cmssw CMSSW_10_6_17_patch1 slc7_amd64_gcc700 --no_scramb

# Copy fragment to the appropriate area
FRAGMENT_PATH=Configuration/GenProduction/python/$FRAGMENT
cp fragments/wmLHEGS_${CAMPAIGN}.py $FRAGMENT_PATH
# Insert gridpack path info fragment
GRIDPACK_ESC=$(echo $GRIDPACK | sed 's_/_\\/_g') # escape slashes in gridpack path
sed -i "s/GRIDPACK_SED_PLACEHOLDER/$GRIDPACK/g" $CMSSW_VERSION/src/$FRAGMENT_PATH
sed -i "s/NEVENTS_SED_PLACEHOLDER/$EVENTS/g" $CMSSW_VERSION/src/$FRAGMENT_PATH

scram b -j8
cd ../..

cmsDriver.py $FRAGMENT_PATH \
    --python_filename LHEGS_${CAMPAIGN}_cfg.py \
    --eventcontent RAWSIM,LHE \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN,LHE \
    --fileout file:LHEGS_${CAMPAIGN}.root \
    --conditions 106X_mc2017_realistic_v6 \
    --beamspot Realistic25ns13TeVEarly2017Collision \
    --customise_commands process.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" \
    --step LHE,GEN \
    --geometry DB:Extended \
    --era Run2_2017 \
    --no_exec \
    --mc \
    -n $EVENTS

# == GEN,LHE =====================================

# == SIM =========================================
# Prepid: SMP-RunIISummer20UL17SIM-00014
setup_cmssw CMSSW_10_6_17_patch1 slc7_amd64_gcc700
cmsDriver.py \
    --python_filename SIM_${CAMPAIGN}_cfg.py \
    --eventcontent RAWSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN-SIM \
    --fileout file:SIM_${CAMPAIGN}.root \
    --conditions 106X_mc2017_realistic_v6 \
    --beamspot Realistic25ns13TeVEarly2017Collision \
    --step SIM \
    --geometry DB:Extended \
    --filein file:LHEGS_${CAMPAIGN}.root \
    --era Run2_2017 \
    --runUnscheduled \
    --no_exec \
    --mc \
    -n $EVENTS

# == SIM =========================================

# == DIGIPREMIX ==================================
# Prepid: SMP-RunIISummer20UL17DIGIPremix-00014
# Pileup: /Neutrino_E-10_gun/RunIISummer20ULPrePremix-UL17_106X_mc2017_realistic_v6-v3/PREMIX
RANDOM_PILEUPFILES=$(shuf -n 5 $SCRIPT_DIR/pileup_files_RunIISummer20UL17.txt | tr '\n' ',') 
RANDOM_PILEUPFILES=${RANDOM_PILEUPFILES::-1} # trim last comma

setup_cmssw CMSSW_10_6_17_patch1 slc7_amd64_gcc700
cmsDriver.py \
    --python_filename DIGIPremix_${CAMPAIGN}_cfg.py \
    --eventcontent PREMIXRAW \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN-SIM-DIGI \
    --fileout file:DIGIPremix_${CAMPAIGN}.root \
    --pileup_input $RANDOM_PILEUPFILES \
    --conditions 106X_mc2017_realistic_v6 \
    --step DIGI,DATAMIX,L1,DIGI2RAW \
    --procModifiers premix_stage2 \
    --geometry DB:Extended \
    --filein file:SIM_${CAMPAIGN}.root \
    --datamix PreMix \
    --era Run2_2017 \
    --runUnscheduled \
    --no_exec \
    --mc \
    -n $EVENTS

# == DIGIPREMIX ==================================

# == HLT =========================================
# Prepid: SMP-RunIISummer20UL17HLT-00013
setup_cmssw CMSSW_9_4_14_UL_patch1 slc7_amd64_gcc630
cmsDriver.py \
    --python_filename HLT_${CAMPAIGN}_cfg.py \
    --eventcontent RAWSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier GEN-SIM-RAW \
    --fileout file:HLT_${CAMPAIGN}.root \
    --conditions 94X_mc2017_realistic_v15 \
    --customise_commands 'process.source.bypassVersionCheck = cms.untracked.bool(True)' \
    --step HLT:2e34v40 \
    --geometry DB:Extended \
    --filein file:DIGIPremix_${CAMPAIGN}.root \
    --era Run2_2017 \
    --no_exec \
    --mc \
    -n $EVENTS

# == HLT =========================================

# == RECO ========================================
# Prepid: SMP-RunIISummer20UL17RECO-00013
setup_cmssw CMSSW_10_6_17_patch1 slc7_amd64_gcc700
cmsDriver.py \
    --python_filename RECO_${CAMPAIGN}_cfg.py \
    --eventcontent AODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier AODSIM \
    --fileout file:RECO_${CAMPAIGN}.root \
    --conditions 106X_mc2017_realistic_v6 \
    --step RAW2DIGI,L1Reco,RECO,RECOSIM \
    --geometry DB:Extended \
    --filein file:DIGIPremix_${CAMPAIGN}.root \
    --era Run2_2017 \
    --runUnscheduled \
    --no_exec \
    --mc \
    -n $EVENTS

# == RECO ========================================

# == MiniAODv2 ===================================
# Prepid: SMP-RunIISummer20UL17MiniAODv2-00013
setup_cmssw CMSSW_10_6_20 slc7_amd64_gcc700
cmsDriver.py \
    --python_filename MiniAODv2_${CAMPAIGN}_cfg.py \
    --eventcontent MINIAODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier MINIAODSIM \
    --fileout file:MiniAODv2_${CAMPAIGN}.root \
    --conditions 106X_mc2017_realistic_v9 \
    --step PAT \
    --procModifiers run2_miniAOD_UL \
    --geometry DB:Extended \
    --filein file:RECO_${CAMPAIGN}.root \
    --era Run2_2017 \
    --runUnscheduled \
    --no_exec \
    --mc \
    -n $EVENTS

# == MiniAODv2 ===================================


# == NanoAODv9 ===================================
# Prepid: SMP-RunIISummer20UL17NanoAODv9-00018
setup_cmssw CMSSW_10_6_26 slc7_amd64_gcc700
cmsDriver.py \
    --python_filename NanoAODv9_${CAMPAIGN}_cfg.py \
    --eventcontent NANOEDMAODSIM \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --datatier NANOAODSIM \
    --fileout file:NanoAODv9_${CAMPAIGN}.root \
    --conditions 106X_mc2017_realistic_v9 \
    --step NANO \
    --filein file:MiniAODv2_${CAMPAIGN}.root \
    --era Run2_2017,run2_nanoAOD_106Xv2 \
    --no_exec \
    --mc \
    -n $EVENTS

# == NanoAODv9 ===================================