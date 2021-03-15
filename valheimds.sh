#!/bin/bash

# The actual program name
declare -r myname="valheimds"
declare -r game="valheimds"

# General rule for the variable-naming-schema:
# Variables in capital letters may be passed through the command line others not.
# Avoid altering any of those later in the code since they may be readonly

# You may use this script for any game server of your choice, just alter the config file
[[ -n "${SERVER_ROOT}" ]]  && declare -r SERVER_ROOT=${SERVER_ROOT}   || SERVER_ROOT="/srv/valheimds"
[[ -n "${SERVER_NAME}" ]]  && declare -r SERVER_NAME=${SERVER_NAME}   || SERVER_NAME="valheimds"

[[ -n "${WORLD_NAME}" ]]  && declare -r WORLD_NAME=${WORLD_NAME}      || WORLD_NAME="valheim_world"
[[ -n "${SERVER_PORT}" ]]  && declare -r SERVER_PORT=${SERVER_PORT}   || SERVER_PORT="2456"
[[ -n "${SERVER_PW}" ]]  && declare -r SERVER_PW=${SERVER_PW}         || SERVER_PW=""

[[ -n "${BACKUP_DEST}" ]]  && declare -r BACKUP_DEST=${BACKUP_DEST}   || BACKUP_DEST="/srv/valheimds/backup"
[[ -n "${BACKUP_PATHS}" ]] && declare -r BACKUP_PATHS=${BACKUP_PATHS} || BACKUP_PATHS="Clusters/${CLUSTER_NAME}"
[[ -n "${BACKUP_FLAGS}" ]] && declare -r BACKUP_FLAGS=${BACKUP_FLAGS} || BACKUP_FLAGS="-z"
[[ -n "${KEEP_BACKUPS}" ]] && declare -r KEEP_BACKUPS=${KEEP_BACKUPS} || KEEP_BACKUPS="10"
[[ -n "${GAME_USER}" ]]    && declare -r GAME_USER=${GAME_USER}       || GAME_USER="valheimds"
[[ -n "${MAIN_EXECUTABLE}" ]] && declare -r MAIN_EXECUTABLE=${MAIN_EXECUTABLE}    || MAIN_EXECUTABLE="valheim-server"
[[ -n "${SERVER_START_CMD}" ]] && declare -r SERVER_START_CMD=${SERVER_START_CMD} || SERVER_START_CMD="'./${MAIN_EXECUTABLE} -nographics -batchmode -name '${SERVER_NAME} -port '${SERVER_PORT} -world '${WORLD_NAME} -password '${SERVER_PW}'"

[[ -n "${SESSION_NAME}" ]] && declare -r SESSION_NAME=${SESSION_NAME} || SESSION_NAME="${game}"

# Additional configuration options which only few may need to alter
[[ -n "${GAME_COMMAND_DUMP}" ]] && declare -r GAME_COMMAND_DUMP=${GAME_COMMAND_DUMP} || GAME_COMMAND_DUMP="/tmp/${myname}_${SESSION_NAME}_command_dump.txt"

# Variables passed over the command line will always override the one from a config file
source /etc/conf.d/"${game}" 2>/dev/null || >&2 echo "Could not source /etc/conf.d/${game}"

# Strictly disallow uninitialized Variables
set -u
# Exit if a single command breaks and its failure is not handled accordingly
set -e

# Check whether sudo is needed at all
if [[ "$(whoami)" == "${GAME_USER}" ]]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo -u ${GAME_USER}"
fi

# Check for sudo rigths
if [[ "$(${SUDO_CMD} whoami)" != "${GAME_USER}" ]]; then
    >&2 echo -e "You have \e[39;1mno permission\e[0m to run commands as $GAME_USER user."
    exit 21
fi

# Pipe any given argument to the game server console,
# sleep for $sleep_time and return its output if $return_stdout is set
game_command() {
    if [[ -z "${return_stdout:-}" ]]; then
        ${SUDO_CMD} screen -S "${SESSION_NAME}" -X stuff "$(printf "%s\r" "$*")"
    else
        ${SUDO_CMD} screen -S "${SESSION_NAME}" -X log on
        ${SUDO_CMD} screen -S "${SESSION_NAME}" -X stuff "$(printf "%s\r" "$*")"
        sleep "${sleep_time:-0.3}"
        ${SUDO_CMD} screen -S "${SESSION_NAME}" -X log off
        ${SUDO_CMD} cat "${GAME_COMMAND_DUMP}"
        ${SUDO_CMD} rm "${GAME_COMMAND_DUMP}"
    fi
}

# Check whether there are player on the server through list TODO : adapt for don't starve together
is_player_online() {
    # TODO
    return 0
    }

# is_player_online2() {
#     response="$(sleep_time=0.6 return_stdout=true game_command c_listallplayers())"
#     # Delete leading line and free response string from fancy characters
#     response="$(echo "${response}" | sed -r -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})*)?[JKmsuG]//g')"
#     # The list command prints a line containing the usernames after the last occurrence of ": "
#     # and since playernames may not contain this string the clean player-list can easily be retrieved.
#     # Otherwise check the first digit after the last occurrence of "There are". If it is 0 then there
#     # are no players on the server. Should this test fail as well. Assume that a player is online.
#     if [[ $(echo "${response}" | grep ":" | sed -e 's/.*\: //' | tr -d '\n' | wc -c) -le 1 ]]; then
#         # No player is online
#         return 0
#     elif [[ "x$(echo "${response}" | grep "There are" | sed -r -e 's/.*\: //' -e 's/^([^.]+).*$/\1/; s/^[^0-9]*([0-9]+).*$/\1/' | tr -d '\n')" == "x0" ]]; then
#         # No player is online
#         return 0
#     else
#         # A player is online (or it could not be determined)
#         return 1
#     fi
# }

server_update () {
    if ! command -v "steamcmd" &> /dev/null; then
        >&2 echo "steamcmd binaries needed to update"
        exit 11
    fi
    ${SUDO_CMD} steamcmd +login anonymous +force_install_dir "${SERVER_ROOT}" +app_update 896660 validate +quit
}

# Start the server if it is not already running
server_start() {
    # Start the game server

    if ! command -v -p "${SERVER_ROOT}/${MAIN_EXECUTABLE}" &> /dev/null; then
        >&2 echo "No binaries found use update command to download DST binaries with steamcmd"
        exit 13
    fi


    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        echo "A screen ${SESSION_NAME} session is already running. Please close it first."
    else
        echo -en "Starting server..."
        ${SUDO_CMD} screen -dmS "${SESSION_NAME}" /bin/bash -c "cd ${SERVER_ROOT}; ${SERVER_START_CMD}"
        ${SUDO_CMD} screen -S "${SESSION_NAME}" -X logfile "${GAME_COMMAND_DUMP}"
        echo -e "\e[39;1m done\e[0m"
    fi
}

# Stop the server gracefully by saving everything prior and warning the users
server_stop() {
    # Gracefully exit the game server

    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        # Game server is up and running, gracefully stop the server when there are still active players

        # Check for active player
        if is_player_online; then
            # No player was seen on the server through list
            echo -en "Server is going down..."
            game_command "^C"
        else
            # Player(s) were seen on the server through list (or an error occurred)
            # Warning the users through the server console
            game_command "c_announce(\"Server is going down in 10 seconds! HURRY UP WITH WHATEVER YOU ARE DOING!\")"
            echo -en "Server is going down in..."
            for i in {1..10}; do
                game_command "c_announce(\"down in... $(( 10 - i ))\")"
                echo -n " $(( 10 - i ))"
                sleep 1
            done
            game_command "^C"
        fi

        # Finish as soon as the server has shut down completely
        for i in {1..100}; do
            if ! ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
                echo -e "\e[39;1m done\e[0m"
                break
            fi
            [[ $i -eq 100 ]] && echo -e "\e[39;1m timed out\e[0m"
            sleep 0.1
        done
    else
        echo "The corresponding screen session for ${SESSION_NAME} was already dead."
    fi
}

# Print whether the server is running and if so give some information about memory usage and threads
server_status() {
    # Print status information for the game server
    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        echo -e "Status:\e[39;1m running\e[0m"

        # Calculating memory usage
        for p in $(${SUDO_CMD} pgrep -f "${MAIN_EXECUTABLE}"); do
            ps -p"${p}" -O rss | tail -n 1;
        done | gawk '{ count ++; sum += $2 }; END {count --; print "Number of processes =", count, "(screen, bash,", count-2, "x server)"; print "Total memory usage =", sum/1024, "MB" ;};'
    else
        echo -e "Status:\e[39;1m stopped\e[0m"
    fi
}

# Restart the complete server by shutting it down and starting it again
server_restart() {
    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        server_stop
        server_start
    else
        server_start
    fi
}

# Backup the directories specified in BACKUP_PATHS
backup_files() {
    # Check for the availability of the tar binaries
    if ! command -v tar &> /dev/null; then
        >&2 echo "The tar binaries are needed for a backup."
        exit 11
    fi

    echo "Starting backup..."
    fname="$(date +%Y_%m_%d_%H.%M.%S).tar.gz"
    ${SUDO_CMD} mkdir -p "${BACKUP_DEST}"
    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        game_command "save"
        sync && wait
        ${SUDO_CMD} tar -C "${SERVER_ROOT}" -cf "${BACKUP_DEST}/${fname}" ${BACKUP_PATHS} --totals ${BACKUP_FLAGS} 2>&1 | grep -v "tar: Removing leading "
    else
        ${SUDO_CMD} tar -C "${SERVER_ROOT}" -cf "${BACKUP_DEST}/${fname}" ${BACKUP_PATHS} --totals ${BACKUP_FLAGS} 2>&1 | grep -v "tar: Removing leading "
    fi
    echo -e "\e[39;1mbackup completed\e[0m\n"

    echo -n "Only keeping the last ${KEEP_BACKUPS} backups and removing the other ones..."
    backup_count=$(for f in "${BACKUP_DEST}"/[0-9_.]*; do echo "${f}"; done | wc -l)
    if [[ $(( backup_count - KEEP_BACKUPS )) -gt 0 ]]; then
        for old_backup in $(for f in "${BACKUP_DEST}"/[0-9_.]*; do echo "${f}"; done | head -n"$(( backup_count - KEEP_BACKUPS ))"); do
            ${SUDO_CMD} rm "${old_backup}";
        done
        echo -e "\e[39;1m done\e[0m ($(( backup_count - KEEP_BACKUPS)) backup(s) pruned)"
    else
        echo -e "\e[39;1m done\e[0m (no backups pruned)"
    fi
}

# Restore backup
backup_restore() {
    # Check for the availability of the tar binaries
    if ! command -v tar &> /dev/null; then
        >&2 echo "The tar binaries are needed for a backup."
        exit 11
    fi

    # Only allow the user to restore a backup if the server is down
    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        >&2 echo -e "The \e[39;1mserver should be down\e[0m in order to restore the world data."
        exit 3
    fi

    # Either let the user choose a backup or expect one as an argument
    if [[ $# -lt 1 ]]; then
        echo "Please enter the corresponding number for the backup to be restored: "
        i=1
        for f in "${BACKUP_DEST}"/[0-9_.]*; do
            echo -e "    \e[39;1m$i)\e[0m\t$f"
            i=$(( i + 1 ))
        done
        echo -en "Restore backup number: "

        # Read in user input
        read -r user_choice

        # Interpeting the input
        if [[ $user_choice =~ ^-?[0-9]+$ ]]; then
            n=1
            for f in "${BACKUP_DEST}"/[0-9_.]*; do
                [[ ${n} -eq $user_choice ]] && fname="$f"
                n=$(( n + 1 ))
            done
            if [[ -z $fname ]]; then
                >&2 echo -e "\e[39;1mFailed\e[0m to interpret your input. Please enter the digit of the presented options."
                exit 5
            fi
        else
            >&2 echo -e "\e[39;1mFailed\e[0m to interpret your input. Please enter a valid digit for one of the presented options."
            exit 6
        fi
    elif [[ $# -eq 1 ]]; then
        # Check for the existance of the specified file
        if [[ -f "$1" ]]; then
            fname="$1"
        else
            if [[ -f "${BACKUP_DEST}"/"$1" ]]; then
                fname="${BACKUP_DEST}"/"$1"
            else
                >&2 echo -e "Sorry, but '$1', is \e[39;1mnot a valid file\e[0m, neither in your current directory nor in the backup folder."
                exit 4
            fi
        fi
    elif [[ $# -gt 1 ]]; then
        >&2 echo -e "\e[39;1mToo many arguments.\e[0m Please pass only the filename for the world data as an argument."
        >&2 echo "Or alternatively, no arguments at all to choose from a list of available backups."
        exit 7
    fi

    echo "Restoring backup..."
    if ${SUDO_CMD} tar -xf "${fname}" -C "${SERVER_ROOT}" 2>&1; then
        echo -e "\e[39;1mRestoration completed\e[0m"
    else
        echo -e "\e[39;1mFailed to restore backup.\e[0m"
    fi
}

# Run the given command at the game server console
server_command() {
    if [[ $# -lt 1 ]]; then
        >&2 echo "No server command specified. Try 'help' for a list of commands."
        exit 1
    fi

    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        return_stdout=true game_command "$@"
    else
        echo "There is no ${SESSION_NAME} session to connect to."
    fi
}

# Enter the screen game session
server_console() {
    if ${SUDO_CMD} screen -S "${SESSION_NAME}" -Q select . > /dev/null; then
        # Circumvent a permission bug related to running GNU screen as a different user,
        # see e.g. https://serverfault.com/questions/116775/sudo-as-different-user-and-running-screen
        ${SUDO_CMD} script -q -c "screen -S \"${SESSION_NAME}\" -rx" /dev/null
    else
        echo "There is no ${SESSION_NAME} session to connect to."
    fi
}

# Help function, no arguments required
help() {
    cat <<-EOF
    This script was designed to easily control any ${game} server. Almost any parameter for a given
    ${game} server derivative can be changed by editing the variables in the configuration file.

        Usage: ${myname} {start|stop|restart|status|update|backup|restore|command <command>|console}
            start                Start the ${game} server
            stop                 Stop the ${game} server
            restart              Restart the ${game} server
            status               Print some status information
            update               update server binaries via steamcmd
            backup               Backup the world data
            restore [filename]   Restore the world data from a backup
            command <command>    Run the given command at the ${game} server console
            console              Enter the server console through a screen session

    Copyright (c) Gordian Edenhofer <gordian.edenhofer@gmail.com> for the core of the script
                  And Samuel Dawant <samueld@mailo.com> for the transcription into DST dedicated server
EOF
}

case "${1:-}" in
    update)
        server_update
        ;;

    start)
        server_start
        ;;

    stop)
        server_stop
        ;;

    status)
        server_status
        ;;

    restart)
        server_restart
        ;;

    console)
        server_console
        ;;

    command)
        server_command "${@:2}"
        ;;

    backup)
        backup_files
        ;;

    restore)
        backup_restore "${@:2}"
        ;;

    -h|--help)
        help
        exit 0
        ;;

    *)
        help
        exit 1
        ;;
esac

exit 0
