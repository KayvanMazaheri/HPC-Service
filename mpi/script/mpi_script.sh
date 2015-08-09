#! /bin/bash
# set -x

function init
{
    LOG_FILE="process.log"
    COMPILE_LOG_FILE="compile.log"

    SAFE_PATH="hpcsafe"
    if [[ ! -e $SAFE_PATH ]]; then
        mkdir $SAFE_PATH
        if [[ $? -ne 0 ]]; then
            log "Safe Path error."
            exit 3
        fi
        log "Safe Path created successfully!"
    fi

    rm -f ./$SAFE_PATH/*
    if [[ $? -ne 0 ]]; then
        log "Error during cleaning og the safe path."
        exit 3
    fi
    log "Safe Path cleared successfully!"

    default
    
    return 0
}

function default
{
    SOURCE_FILE="code.cpp"
    EXEC_FILE="code.exec"
    OUTPUT_FILE="output.out"
    STDERR_FILE="stderr.out"
    EXEC_PATH=$SAFE_PATH/$EXEC_FILE
    return 0;
}

function read_arguments
{
    while [[ $# > 0 ]]
    do
        key="$1"

        case $key in
            # Zip file
            -z|--zip-file )
                ZIP_FILE="$2"
                shift
                ;;

            -s|--source-file )
                SOURCE_FILE="$2"
                shift
                ;;

            -i|--std-input-file )
                INPUT_FILE="$2"
                STD_INPUT=YES
                shift
                ;;

            -o|--output-file )
                OUTPUT_FILE="$2"
                shift
                ;;

            -f|--hosts-file )
                HOSTS_FILE="$2"
                shift
                ;;

            -h|--help )
                help
                ;;

            --default)
                DEFAULT_SETTINGS=YES
                ;;
            * )
                help
                ;;
        esac
        shift
    done

    return 0;
}

function help
{
    echo "HELP is HERE"
    exit 0
}

function system_info
{
    mpichversion >&2
    mpichversion >> $LOG_FILE 
    return 0;
}

function run
{
    EXEC_CMD="mpirun"
    if [[ ! -z ${HOSTS_FILE+x} ]];then
        EXEC_CMD+=" -f $HOSTS_FILE"
    fi
    EXEC_CMD+=" $EXEC_PATH"
    EXEC_CMD+=" > ./$SAFE_PATH/$OUTPUT_FILE"
    EXEC_CMD+=" 2> ./$SAFE_PATH/$STDERR_FILE"


    log "Executing $EXEC_CMD"


    # DATE_OUTPUT="$(date +%s:N)"
    EXEC_TIME_B="$(echo "$(date +%N) + $(date +%s) * 1000000000" | bc)";
    
    #
    eval $EXEC_CMD

    if [[ $? -ne 0 ]]; then
        log "Program exited with non zero code"
        return 3
    fi

    EXEC_TIME_A="$(echo "$(date +%N) + $(date +%s) * 1000000000" | bc)";
    
    EXEC_TIME="$( echo "$EXEC_TIME_A - $EXEC_TIME_B" | bc)";

    # EXEC_TIME="$(echo \"\$ $EXEC_TIME - (date +%N) + $(date +%s) * 1000000000\" | bc)";
    # EXEC_TIME="$(($(date +%N)-EXEC_TIME))"
    log "Executed in $EXEC_TIME nanoseconds"
    # eval  $EXEC_CMD
    # EXEC_TIME=$(time $EXEC_CMD)
    # echo $EXEC_TIME
    return 0
}


function compile
{
    mpicxx $SOURCE_FILE -o ./$EXEC_PATH 2> ./$SAFE_PATH/$COMPILE_LOG_FILE

    if [[ $? -ne 0 ]]; then
        log "Compilation error: "
        cat ./$SAFE_PATH/$COMPILE_LOG_FILE >&2
        cat ./$SAFE_PATH/$COMPILE_LOG_FILE >> $LOG_FILE
        return 3
    fi

    return 0
}

# function handle_stdin
# {

# }

function handle_input
{
    if [[ ! -z ${STD_INPUT+x} ]];then 
        handle_stdin
        if [[ $? -ne 0 ]]; then
            log "Standard input handling failed"
            return 3
        fi
    fi

    if [[ -z ${ZIP_FILE+x} ]]; then
        return 0
    fi

    unzip -o $ZIP_FILE -d ./$SAFE_PATH/

    if [[ $? -ne 0 ]]; then
        log "Unzip failed"
        return 3
    fi

    return 0
}

function validate
{
    if [[ ! -z ${ZIP_FILE+x} ]] && [[ ! -f $ZIP_FILE ]]; then
        log  "Zip file doesn't exist!"
        return 3
    elif [[ ! -z ${ZIP_FILE+x} ]] && [[ ${ZIP_FILE: -4} != ".zip" ]]; then
        log "Compressed file must have .zip extension"
        return 3
    fi

    if [[ ! -z ${INPUT_FILE+x} ]] && [[ ! -f $INPUT_FILE ]]; then
        log  "Input file doesn't exist!"
        return 3
    fi

    if [[ -z ${SOURCE_FILE+x} ]] || [[ ! -f $SOURCE_FILE ]]; then
        log  "Source code must be provided."
        return 3
    fi

    if [[ ! -z ${HOSTS_FILE+x} ]] && [[ ! -f $HOSTS_FILE ]]; then
        log  "Hosts file doesn't exist!"
        return 3
    fi


    return 0
}



function log
{ 
    if [[ $# == 0 ]]; then
        touch LOG_FILE
        
        echo "
 ==========================================================
|   Welcome to *** HPC Service. You are running your MPI   |
|  program on our server. This server is configured with   |
|         hosts and runs with c++ codes only. The defult   |
|  compiler used in this service is mpicc (MPICH) the      |
|  details of the compiler are wriiten in following log    |
|  file.                                                   |
 ==========================================================
"       > $LOG_FILE
        cat $LOG_FILE >&2
        return 0
    fi

    echo $1 >> $LOG_FILE
    echo $1 >&2
    return 0

}

function main
{
    if [[ $# == 0 ]]; then
        help
    fi

    init
    log
    system_info
    read_arguments $@
    validate

    if [[ $? -ne 0 ]]; then
        log "Validation failed"
        exit 3
    fi

    handle_input

    if [[ $? -ne 0 ]]; then
        log "Input handling failed"
        exit 3
    fi

    compile

    if [[ $? -ne 0 ]]; then
        log "Compilation failed"
        exit 3
    fi

    run
    return $?

}

main $@
exit $? 
