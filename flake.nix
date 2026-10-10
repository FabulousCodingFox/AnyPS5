{
  description = "AnyPS5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    self.submodules = true;
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      {
        systems = [ "x86_64-linux" ];

        perSystem =
          { pkgs, self', ... }:
          let
            ldflags = "-L${pkgs.glibc}/lib";

            version = "0-unstable-${self.shortRev or self.dirtyShortRev or "unknown"}";

            ffmpegPrebuilt = pkgs.fetchzip {
              url = "https://github.com/KytyPS5/ext-ffmpeg-core/releases/download/9ac4cfd195f1/ffmpeg-linux-x64.zip";
              hash = "sha256-MX8Rifr6CvFFkm0IAmJPNGzLb8FG5HJJUKO/l0zegko=";
              stripRoot = false;
            };

            common = {
              inherit version;
              src = self;

              strictDeps = true;
              __structuredAttrs = true;

              nativeBuildInputs = with pkgs; [
                cmake
                ninja
                python3
                git
              ];
              buildInputs = [ pkgs.glibc.static ];
              env.NIX_LDFLAGS = ldflags;
            };
          in
          {
            packages = {
              default = self'.packages.anyps5;

              relinker = pkgs.stdenv.mkDerivation (
                common
                // {
                  pname = "anyps5-relinker";

                  cmakeFlags = [
                    (pkgs.lib.cmakeBool "ANYPS5_RELINKER_ONLY" true)
                    (pkgs.lib.cmakeBool "BUILD_TESTING" true)
                  ];

                  doCheck = true;
                  checkPhase = ''
                    runHook preCheck
                    ctest --output-on-failure -E '^(linux_entry_argv|linux_program_header_order)$'
                    runHook postCheck
                  '';

                  installPhase = ''
                    runHook preInstall
                    install -Dm755 core/relinker/relinker $out/bin/relinker
                    runHook postInstall
                  '';

                  meta = {
                    description = "AnyPS5 relinker";
                    mainProgram = "relinker";
                    platforms = [ "x86_64-linux" ];
                  };
                }
              );

              anyps5 = pkgs.stdenv.mkDerivation (
                common
                // {
                  pname = "anyps5";

                  buildInputs =
                    common.buildInputs
                    ++ (with pkgs; [
                      libx11
                      libxext
                      libxcb
                      xorgproto
                      vulkan-headers
                    ]);

                  cmakeFlags = [
                    (pkgs.lib.cmakeFeature "FFMPEG_PREBUILT_DIR" "${ffmpegPrebuilt}")
                  ];
                  dontStrip = true;
                  dontPatchELF = true;

                  ninjaFlags = [
                    "all"
                    "libs"
                  ];

                  installPhase = ''
                    runHook preInstall
                    install -Dm755 core/relinker/relinker $out/bin/relinker
                    install -Dm644 -t $out/lib/anyps5/libs core/libs/libs/*.prx
                    runHook postInstall
                  '';

                  meta = {
                    description = "AnyPS5 relinker and system libraries";
                    mainProgram = "relinker";
                    platforms = [ "x86_64-linux" ];
                  };
                }
              );
            };

            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                git
                cmake
                ninja
                gcc
                binutils
                pkg-config
                python3
                ccache
                glibc.static
              ];

              buildInputs = with pkgs; [
                libx11
                libxext
                libxcb
                xorgproto
                vulkan-headers
              ];

              env = {
                CC = "gcc";
                CXX = "g++";
                NIX_LDFLAGS = ldflags;
                LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
                  with pkgs;
                  [
                    vulkan-loader
                    libx11
                    libxext
                  ]
                );
              };
            };

            formatter = pkgs.nixfmt;
          };
      }
    );
}
