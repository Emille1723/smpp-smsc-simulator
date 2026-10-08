{
    description = "Build melrose & run instances where the SMPP port differs";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        flake-utils.url = "github:numtide/flake-utils";

        devshell = {
            url = "github:numtide/devshell";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    nixConfig = {
        extra-substituters = [ "https://cache.nixos.org" "https://nix-community.cachix.org" ];
        extra-trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    };

    outputs = { self, nixpkgs, ... }@inputs:
        let
            system = "x86_64-linux";
            pkgs = nixpkgs.legacyPackages.${system};

            commonPackages = with pkgs; [
                # latest stable is 16.2
                # also gcc is included by default
                gcc16
                just
                podman
                clang
            ];

            # function to setup podman within the devShell
            # nix functions are 'argument: body'
            # pass named arguments with defaults via an attribute set
            # using cgroupfs as a fallback
            podmanEnv = { driver ? "overlay", cgroupManager ? "cgroupfs" }: {
                CONTAINERS_STORAGE_CONF = pkgs.writeText "storage.conf" ''
                    [storage]
                    driver = "${driver}"
                '';
                CONTAINERS_CONF = pkgs.writeText "containers.conf" ''
                    [containers]
                    log_driver = "k8s-file"

                    [engine]
                    cgroup_manager = "${cgroupManager}"
                    events_logger = "file"
                '';
            };

            baseShell = {
                packages = commonPackages;
                buildInputs = [ pkgs.glibc.static ];
            };

            # funtion to create devShells
            # allows me to merge attribute sets into one argument attribute set where the last one wins on duplicate keys
            # mkShell normally takes one argument attribute set set
            # merge many here
            makeDevShell = { name, shellHook ? "", podman ? false }:
            pkgs.mkShellNoCC (
                baseShell
                # set the podman environment variables when podman is true
                # use systemd
                // pkgs.lib.optionalAttrs podman (podmanEnv{ cgroupManager = "systemd"; })
                // {
                    inherit name;
                    shellHook = ''
                        export PS1="(${name}) $PS1"
                        printf "%s\n" "Entered devShell: ${name}"
                        ${shellHook}
                    '';
                }
            );

            # this is what the merge looks like
            # {
            #     packages = [ pkgs.just ]; # from baseShell
            #     buildInputs = [ pkgs.glibc.static ]; # from baseShell
            #     CONTAINERS_STORAGE_CONF = /nix/store/...-storage.conf; # from optionalAttrs
            #     CONTAINERS_CONF = /nix/store/...-containers.conf; # from optionalAttrs
            #     name = "smsc-sim"; # from the last set
            #     shellHook = "..."; # from the last set
            # }
        in
        {
            devShells.${system} = {
                # ref of how I used to write them
                # default = pkgs.mkShellNoCC {
                #     name = "default";
                #     packages = commonPackages ++ [ ];
                #     buildInputs = [ pkgs.glibc.static ];
                #     hardeningDisable = ["all"];
                #     strictDeps = false;
                #     shellHook = ''
                #     '';
                # };
                default = makeDevShell {
                    name = "default";
                    podman = true;
                    shellHook = ''
                    '';
                };
            };
        };
}
