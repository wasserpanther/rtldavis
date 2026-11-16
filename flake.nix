{
  description = "rtldavis - RTL-SDR receiver for Davis Instruments weather stations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        rtldavis = pkgs.stdenv.mkDerivation rec {
          pname = "rtldavis";
          version = "0.15";

          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              let base = baseNameOf path;
              in !(pkgs.lib.hasPrefix "result" base)
                 && base != ".git";
          };

          nativeBuildInputs = with pkgs; [
            go
            pkg-config
            gcc
          ];

          buildInputs = with pkgs; [
            rtl-sdr
            libusb1
          ];

          configurePhase = ''
            export GOFLAGS=-mod=vendor
            export GOPATH=$TMPDIR/go
            export GOCACHE=$TMPDIR/go-cache
            export CGO_CFLAGS="-I${pkgs.rtl-sdr.dev}/include"
            export CGO_LDFLAGS="-L${pkgs.rtl-sdr}/lib -lrtlsdr"
            export PKG_CONFIG_PATH="${pkgs.rtl-sdr.dev}/lib/pkgconfig"
          '';

          buildPhase = ''
            runHook preBuild
            go build -mod=vendor -ldflags "-s -w" -o rtldavis .
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp rtldavis $out/bin/
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "RTL-SDR receiver for Davis Instruments weather stations";
            homepage = "https://github.com/lheijst/rtldavis";
            license = licenses.gpl3Only;
            maintainers = [ ];
            platforms = platforms.linux;
          };
        };
      in
      {
        packages = {
          default = rtldavis;
          rtldavis = rtldavis;
        };

        devShells.default = pkgs.mkShell {
          name = "rtldavis-dev";

          nativeBuildInputs = with pkgs; [
            go
            pkg-config
            gcc
            cmake
            gnumake
            git
          ];

          buildInputs = with pkgs; [
            rtl-sdr
            rtl-sdr.dev
            libusb1
            libusb1.dev
          ];

          shellHook = ''
            export GOFLAGS=-mod=mod
            export CGO_CFLAGS="-I${pkgs.rtl-sdr.dev}/include"
            export CGO_LDFLAGS="-L${pkgs.rtl-sdr}/lib -lrtlsdr"
            export PKG_CONFIG_PATH="${pkgs.rtl-sdr.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LD_LIBRARY_PATH="${pkgs.rtl-sdr}/lib:${pkgs.libusb1}/lib:$LD_LIBRARY_PATH"

            echo "rtldavis development environment"
            echo "Go: $(go version)"
            echo "rtl-sdr: ${pkgs.rtl-sdr.version}"
            echo ""
            echo "Build:  go build -o rtldavis ."
            echo "Test:   go test ./..."
            echo "Run:    ./rtldavis -h"
          '';
        };
      }
    );
}
