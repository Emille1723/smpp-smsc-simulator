# while this is okay in theory
# I don't like the idea of having to manage 2 places for the carrier names
# variants := "tstt digicel gtt"

# I propose using the ./env directory as the source of truth for the required carriers
# given that the ./env directory is what is used to build the specify the container instances
# and I was copying the names from there
# just derive the variants list from there by default
export variants := `./scripts/get_variants.sh`
export container_name_prefix := "sim-"
export justfile_pwd := justfile_directory()
build:
    #!/usr/bin/env bash
    mkdir -pv build
    g++ -std=c++11 smscsimulator.cpp -o MLSMSCSimulator
build-alt:
    #!/usr/bin/env bash
    mkdir -pv build
    g++ -std=c++11 -static smscsimulator.cpp -o build/app >/dev/null 2>&1
empty:
    podman image exists empty:latest || tar -cf - --files-from /dev/null | podman import - empty:latest
empty-bash:
    #!/usr/bin/env bash
    set -euo pipefail
    if
        ! podman image exists empty:latest > /dev/null 2>&1;
    then
        tar -cf - --files-from /dev/null >/dev/null 2>&1 | podman import - empty:latest >/dev/null 2>&1
    fi
start name:
    -podman rm -f "${container_name_prefix}"{{name}}
    podman create --name "${container_name_prefix}"{{name}} --env-file env/{{name}}.env empty:latest /app
    podman cp build/app "${container_name_prefix}"{{name}}:/app
    podman start "${container_name_prefix}"{{name}}
start-bash name:
    #!/usr/bin/env bash
    set -euo pipefail
    # justfile already knows to target paths relative to its position but I'm using the justfile_pwd as a safety net just incase
    log_file="${justfile_pwd}/logs/"${container_name_prefix}"{{name}}.log"
    # create the log file if missing
    : >> "${log_file}"
    podman stop "${container_name_prefix}"{{name}}
    podman rm -f "${container_name_prefix}"{{name}} >/dev/null 2>&1 || true
    podman create \
        --network=host \
        --pull=never \
        --name "${container_name_prefix}"{{name}} \
        --env-file env/{{name}}.env \
        localhost/empty:latest /app >/dev/null 2>&1
    podman cp build/app "${container_name_prefix}"{{name}}:/app >/dev/null 2>&1
    podman start "${container_name_prefix}"{{name}} >/dev/null 2>&1 && \
    sleep 1 && \ # this fixes a race;  todo: investgate
    podman logs --follow "${container_name_prefix}"{{name}} 2>&1 | tee -a "${log_file}" > /dev/null 2>&1 &
    # podman logs --follow "${container_name_prefix}"{{name}} >> "${log_file}" > /dev/null 2>&1 &
all: build-alt empty-bash
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'echo; exit 0' INT
    while IFS= read -r v; do
        v="${v//.env/}"
        just start-bash "${v}" >/dev/null 2>&1 && \
            printf "%s\n" "Simulator container started for carrier: ${v}" || \
            printf "%s\n" "Failed to start for carrier: ${v}"
    done <<< "${variants[@]}" || exit 1
    printf "\n"
    exec {{just_executable()}} tail
tail:
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'echo; exit 0' INT
    shopt -s nullglob # do nothing when no globs match
    files=(./logs/*.log)
    if
        (("${#files[@]}" == 0));
    then
        printf "%s\n" "No log files to tail"
        exit 1
    fi
    LC_ALL=C stdbuf -oL tail -n 0 -F ---disable-inotify -s 0.1 "${files[@]}"
# claude gave me this but I want to fix my own
# tail-alt:
#     #!/usr/bin/env bash
#     set -euo pipefail
#     trap 'echo; exit 0' INT
#     mapfile -t ctrs < <(podman ps -q --filter name="${container_name_prefix}")
#     (( ${#ctrs[@]} )) || { echo "No simulator containers running" >&2; exit 1; }
#     podman logs --follow --names "${ctrs[@]}"
logs name:
    podman logs "${container_name_prefix}"{{name}}
stop name:
    podman kill simg-{{name}}  >/dev/null 2>&1 # kill instantly
    podman stop "${container_name_prefix}"{{name}} >/dev/null 2>&1 # has a grace period of 10s
    # podman stop -t 0 "${container_name_prefix}"{{name}} # no grace period
stop-all:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r v; do
        v="${v//.env/}"
        # ignore containers that don't exist '--ignore'
        podman stop -t 0 --ignore ""${container_name_prefix}"${v}" >/dev/null 2>&1
    done <<< "${variants[@]}" || exit 1
    printf "%s\n" "All containers stopped"
shell name:
    #!/usr/bin/env bash
    set -euo pipefail
    bb="$(nix build nixpkgs#pkgsStatic.busybox --no-link --print-out-paths)/bin/busybox"
    podman cp "$bb" "${container_name_prefix}"{{name}}:/busybox
    podman exec -it "${container_name_prefix}"{{name}} /busybox sh -c '/busybox mkdir -p /bin && /busybox --install -s /bin && exec /bin/sh'
logsf name:
    #!/usr/bin/env bash
    # follows the app's output live. Stop following with Ctrl-C; the container keeps running.
    podman logs -f "${container_name_prefix}"{{name}}
attach name:
    #!/usr/bin/env bash
    # connects to the app's own input and output.
    # --sig-proxy=false makes Ctrl-C detach you instead of killing the app.
    podman attach --sig-proxy=false "${container_name_prefix}"{{name}}
top name:
    #!/usr/bin/env bash
    # podman stats "${container_name_prefix}"tstt and podman inspect sim-tstt show its
    podman top "${container_name_prefix}"{{name}}
