#! /bin/bash
## Run an out-of-the-box N2000 experiment
##    but with reduced output.

## Experiment basics, modify these for your experiment
TAG=${TAG:-"release-noresm2.0.7"}
COMPSET=${COMPSET:-"N2000"}
RES=${RES:-"f19_tn14"}
SRCROOT=${SRCROOT:-"/cluster/projects/nn1001k/xxUSERxx/NorESM"}
CASEDIR=${CASEDIR:-"/cluster/work/users/xxUSERxx/cases"}
REPO=${REPO:-"https://github.com/NorESMhub/NorESM"}
PROJECT=${PROJECT:-"nn9039k"}
STOP_OPTION=${STOP_OPTION:-"ndays"}
STOP_N=${STOP_N:-"5"}

perror() {
  ## Print an error message and exit if a non-zero error code is passed
  if [ $1 -ne 0 ]; then
    echo "ERROR (${1}): ${2}"
    exit $1
  fi
}

## Decide whether or not to run manage_externals/checkout_externals
## While this is not perfect, it works if used consistently
## NB: If you check out the target tag from outside the script,
## be sure to run checkout_externals yourself, this script might
## miss it.
RUN_CHECKOUT="no"

## (make sure that clone exists, otherwise, clone REPO)
if [ ! -d "${SRCROOT}" ]; then
    git clone -o NorESM ${REPO} ${SRCROOT}
    perror $? "running 'git clone -o NorESM ${REPO} ${SRCROOT}'"
    RUN_CHECKOUT="yes"
fi

## Ensure correct source is checked out
cd ${SRCROOT}
if [ "$( git describe )" != "${TAG}" ]; then
    git checkout ${TAG}
    perror $? "running 'git checkout ${TAG}'"
    RUN_CHECKOUT="yes"
fi
if [ "${RUN_CHECKOUT}" != "no" ]; then
    ./manage_externals/checkout_externals
    perror $? "running './manage_externals/checkout_externals'"
fi

## Create your case
## Because the TAG above is a techical release most compset / res
##    combinations are unsuported.
if [ ! -d "${CASEDIR}" ]; then
    ## Only run create_newcase if the case does not exist
    cn_args=" --case ${CASEDIR} --compset ${COMPSET} --res ${RES} --project ${PROJECT}"
    cn_args="${cn_args} --run-unsupported"
    ./cime/scripts/create_newcase ${cn_args}
    perror $? "running './cime/scripts/create_newcase ${cn_args}'"
fi

## Move to your case directory
cd ${CASEDIR}
perror $? "trying 'cd ${CASEDIR}'"

## Any PE changes must go here

## Set up the case as configured so far
if [ ! -f "CaseStatus" ]; then
    ## Setup the case if it looks like it has not been setup
    ./case.setup
    perror $? "trying './case.setup'"
fi

## Changes that affect the build go here
# Testing a short run first with DEBUG=TRUE is valuable
#    Comment out change for longer runs
#./xmlchange DEBUG=TRUE
#perror $? "trying './xmlchange DEBUG=TRUE'"
./xmlchange STOP_OPTION=${STOP_OPTION},STOP_N=${STOP_N}
perror $? "trying './xmlchange STOP_OPTION=${STOP_OPTION},STOP_N=${STOP_N}'"

## Build the model
./case.build
perror $? "trying './case.build'"

## Last chance to modify run-time settings
cat <<EOF >> user_nl_cam
history_chemistry       = .false.
history_chemspecies_srf = .false.
history_clubb           = .false.
EOF
perror $? "adding variables to user_nl_cam"

## Submit the job
./case.submit
perror $? "trying './case.submit'"
