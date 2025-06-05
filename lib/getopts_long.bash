getopts_long() {

    [[ $# -lt 2  ||  $1 == @(-h|--help) ]] && {

        # print usage docs
        if [[ -n $( command -v docsh ) ]]
        then
            docsh -TD """Re-implemented getopts, with support for --long options.

            Usage

            getopts_long <optspec> <varname> [args ...]

            The usage is very similar to the Bash getopts built-in (refer to
            'help getopts').

            _optspec_ is a string that starts with a series of characters
            representing single-letter options. It may start with ':' to enable silent error
            reporting. This function accepts an extended string after the characters,
            consisting of long option names separated by whitespace. If the long option name
            is followed by ':', an argument is expected.

            _varname_ is the variable that will hold the option flag, while any argument
            will be placed in OPTARG, just as with getopts.

            _args_ is the list of arguments to parse. If omitted, getopts_long will parse
            arguments supplied to the enclosing script, if present, or to the function if
            the extdebug option is enabled.

            Example for a shell function

            local OPT OPTARG OPTIND=1

            while getopts_long 'af: all file:' OPT \"\$@\"
            do
                case \$OPT in
                    ( a | all )
                        echo 'all triggered'
                        ;;
                    ( f | file )
                        echo \"file is \${OPTARG}\"
                        ;;
                    ...
                esac
            done

            shift \$(( OPTIND - 1 ))

            For more details on usage and error reporting, refer to the ReadMe doc:
            https://github.com/AndrewDDavis/getopts_long
            """
        else
            : "${1:?Missing required parameter: long optspec}"
            : "${2:?Missing required parameter: variable name}"
        fi

        return
    }

    # split optspec into short and long parts
    local optspec_short=${1%% *}
    local optspec_long=${1#* }

    # this needs a bit more subtlety to allow opt-strings with spaces, like 'a b foo'
    # - for getopts, this is perfectly valid, but causes <space> to be a valid option flag
    #TODO
    #[[ $1 ==


    # nameref to the OPT variable
    local -n optvar=$2

    shift 2

    # ensure long options will be handled
    optspec_short+="-:"

    # detect silent error reporting
    local _silent_err
    [[ ${optspec_short:0:1} == ':' ]] && _silent_err=1


    if [[ $# == 0  &&  ${BASH_ARGC[1]} -gt 0 ]]
    then
        # if no args were passed, try getting them from BASH_ARGV
        # - NB, this requires extdebug to be set in the calling context, or for the
        #   calling context to be a script.
        # - The loop is necessary b/c BASH_ARGV indexes in the opposite direction
        #   to the way args are passed on the command line.
        # - BASH_ARGC stores the stack of $# for this and enclosing contexts.
        local args=()
        local i a=${BASH_ARGC[0]} b=${BASH_ARGC[1]}

        for (( i = a; i < (a+b); i++ ))
        do
            args+=( "${BASH_ARGV[$i]}" )
        done

        set -- "${args[@]}"
    fi


    ## Short options

    # Use getopts built-in to parse the short options
    builtin getopts -- "$optspec_short" "${!optvar}" "$@" ||
        return

    # This passes when getopts encountered a long option,
    #   since '-:' was added to optspec_short above.
    [[ $optvar == '-' ]] || return 0

    # Handle '--' in edge cases like '-a--'
    # - TODO: maybe better to just show an error message here, it's hard to imagine when this
    #   would happen on purpose
    # [[ $OPTARG != '-' ]] || return 1


    ## Long options

    # Set optvar=key and OPTARG=val from --key=val or --key val,
    # or just set optvar=key and unset OPTARG if no arg expected

    optvar=${OPTARG%%=*}

    if [[ $optspec_long =~ (^|[[:blank:]])${optvar}:([[:blank:]]|$) ]]
    then
        # Argument expected

        # Do an explicit check for 'key=*', to allow null arguments
        # - this is similar to how getopts allows an empty argument
        if [[ $OPTARG == ${optvar}=* ]]
        then
            OPTARG=${OPTARG#${optvar}=}

        else
            # Didn't get key=val style argument
            # Try to get val from the next CLI argument
            [[ $# -ge $OPTIND ]] &&
            {
                OPTARG=${!OPTIND}
                OPTIND=$(( OPTIND + 1 ))
                return 0
            }

            # Otherwise, it's an error
            if [[ -n ${_silent_err:-} ]]
            then
                OPTARG=$optvar
                optvar=':'

            else
                [[ $OPTERR == 0 ]] ||
                    echo >&2 "${0}: option requires an argument -- ${optvar}"

                unset OPTARG
                optvar='?'
            fi
        fi

    elif [[ $optspec_long =~ (^|[[:blank:]])${optvar}([[:blank:]]|$) ]]
    then
        # No argument expected
        if [[ $optvar == $OPTARG ]]
        then
            unset OPTARG

        else
            if [[ -n ${_silent_err:-} ]]
            then
                optvar='?'

            else
                optvar='?'
                [[ $OPTERR == 0 ]] ||
                    echo >&2 "${0}: ${FUNCNAME[0]}: unexpected argument -- ${OPTARG}"
            fi
        fi

        # TODO
        # - check return status of this and getopts when error conditions are triggered

    else
        # Invalid option
        if [[ -n ${_silent_err:-} ]]
        then
            OPTARG=$optvar
            optvar='?'

        else
            [[ $OPTERR == 0 ]] ||
                echo >&2 "${FUNCNAME[0]}: illegal option -- ${optvar}"

            unset OPTARG
            optvar='?'
        fi
    fi
}
