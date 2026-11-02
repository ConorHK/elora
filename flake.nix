{
  description = "Elora Halcyon QMK userspace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          qmk-flash = pkgs.writeShellApplication {
            name = "qmk-flash";
            runtimeInputs = [
              pkgs.qmk
              pkgs.git
              pkgs.util-linux
              pkgs.coreutils
            ];
            text = ''
              cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

              if [ ! -f qmk.json ]; then
                echo "Run from the elora repo."
                exit 1
              fi

              qmk userspace-compile

              device=/dev/disk/by-label/RPI-RP2
              mountpoint=$(mktemp -d)
              trap 'rmdir "$mountpoint"' EXIT

              flash() {
                echo "Enter boot mode on the $1 half..."
                for _ in $(seq 60); do
                  [ -e "$device" ] && break
                  sleep 1
                done
                if [ ! -e "$device" ]; then
                  echo "No RPI-RP2 drive found, exiting."
                  exit 1
                fi

                sudo mount "$device" "$mountpoint"
                if [ ! -f "$mountpoint/INFO_UF2.txt" ]; then
                  echo "INFO_UF2.txt not found, exiting."
                  sudo umount "$mountpoint"
                  exit 1
                fi
                sudo cp "$1.uf2" "$mountpoint"
                sudo umount "$mountpoint"

                # The half reboots after the copy, so wait for its drive to vanish.
                for _ in $(seq 30); do
                  [ -e "$device" ] || break
                  sleep 1
                done
                echo "Flashed $1 half."
              }

              flash left
              flash right
              echo "Complete!"
            '';
          };
        in
        {
          inherit qmk-flash;
          default = qmk-flash;
        }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ nixpkgs.legacyPackages.${system}.qmk ];
        };
      });
    };
}
