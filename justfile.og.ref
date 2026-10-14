variants := "tstt digicel gtt"
build:
    #!/usr/bin/env bash
    mkdir -pv build
    g++ -std=c++11 smscsimulator.cpp -o MLSMSCSimulator
build-alt:
    #!/usr/bin/env bash
    mkdir -pv build
    # g++ -std=c++11 -static smscsimulator.cpp -o build/MLSMSCSimulator
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
    -podman rm -f sim-{{name}}
    podman create --name sim-{{name}} --env-file env/{{name}}.env empty:latest /app
    podman cp build/app sim-{{name}}:/app
    podman start sim-{{name}}
start-bash name:
    #!/usr/bin/env bash
    set -euo pipefail
    podman rm -f sim-{{name}} >/dev/null 2>&1 || true
    podman create \
        --network=host \
        --pull=never \
        --name sim-{{name}} \
        --env-file env/{{name}}.env \
        localhost/empty:latest /app >/dev/null 2>&1
    podman cp build/app sim-{{name}}:/app >/dev/null 2>&1
    podman start sim-{{name}} >/dev/null 2>&1
    # podman logs --follow sim-{{name}} >> ./logs/sim-{{name}}.log 2>&1 &
    podman logs --follow sim-{{name}} 2>&1 | tee -a ./logs/sim-{{name}}.log > /dev/null 2>&1 &
all: build-alt empty-bash
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'echo; exit 0' INT
    for v in {{variants}}; do
        just start-bash "${v}" >/dev/null 2>&1 && \
            printf "%s\n" "Container started: ${v}" || \
                printf "%s\n" "Failed to start: ${v}"
    done
    just tail
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
logs name:
    podman logs sim-{{name}}
stop name:
    podman kill simg-{{name}}  >/dev/null 2>&1 # kill instantly
    podman stop sim-{{name}} >/dev/null 2>&1 # has a grace period of 10s
    # podman stop -t 0 sim-{{name}} # no grace period
stop-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for v in {{variants}}; do
        # ignore containers that don't exist '--ignore'
        podman stop -t 0 --ignore "sim-${v}" >/dev/null 2>&1
    done
shell name:
    #!/usr/bin/env bash
    set -euo pipefail
    bb="$(nix build nixpkgs#pkgsStatic.busybox --no-link --print-out-paths)/bin/busybox"
    podman cp "$bb" sim-{{name}}:/busybox
    podman exec -it sim-{{name}} /busybox sh -c '/busybox mkdir -p /bin && /busybox --install -s /bin && exec /bin/sh'
logsf name:
    #!/usr/bin/env bash
    # follows the app's output live. Stop following with Ctrl-C; the container keeps running.
    podman logs -f sim-{{name}}
attach name:
    #!/usr/bin/env bash
    # connects to the app's own input and output.
    # --sig-proxy=false makes Ctrl-C detach you instead of killing the app.
    podman attach --sig-proxy=false sim-{{name}}
top name:
    #!/usr/bin/env bash
    # podman stats sim-tstt and podman inspect sim-tstt show its
    podman top sim-{{name}}
