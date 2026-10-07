variants := "tstt digicel gtt"

build:
    mkdir -p build
    # g++ -std=c++11 -static smscsimulator.cpp -o build/MLSMSCSimulator
    g++ -std=c++11 -static smscsimulator.cpp -o build/app

# one image; build/ is the context so only the binary goes in
image: build
    podman build -f Containerfile -t mlsmsc:latest build/

start name:
    -podman rm -f smsc-{{name}}
    podman run -d --name smsc-{{name}} --env-file env/{{name}}.env mlsmsc:latest

all: image
    for v in {{variants}}; do just start $v; done

logs name:
    podman logs smsc-{{name}}
