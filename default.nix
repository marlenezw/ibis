{ python ? "3.9"
, doCheck ? true
}:
let
  pkgs = import ./nix;
  drv =
    { poetry2nix
    , python
    , lib
    }:

    let
      backends = [
        "dask"
        "datafusion"
        "pandas"
        "sqlite"
      ];

      backendsString = lib.concatStringsSep " " backends;
    in
    poetry2nix.mkPoetryApplication {
      inherit python;

      projectDir = ./.;
      src = pkgs.gitignoreSource ./.;

      overrides = pkgs.poetry2nix.overrides.withDefaults (
        import ./poetry-overrides.nix {
          inherit pkgs;
          inherit (pkgs) lib stdenv;
        }
      );

      preConfigure = ''
        rm setup.py
      '';

      buildInputs = with pkgs; [ graphviz-nox ];
      checkInputs = with pkgs; [ graphviz-nox ];

      checkPhase = ''
        set -euo pipefail

        runHook preCheck

        tempdir="$(mktemp -d)"

        cp -r ${pkgs.ibisTestingData}/* "$tempdir"

        find "$tempdir" -type f -exec chmod u+rw {} +
        find "$tempdir" -type d -exec chmod u+rwx {} +

        ln -s "$tempdir" ci/ibis-testing-data

        for backend in ${backendsString}; do
          python ci/datamgr.py "$backend" &
        done

        wait

        pytest --numprocesses auto -m '${lib.concatStringsSep " or " backends} or core'

        runHook postCheck
      '';

      inherit doCheck;

      pythonImportsCheck = [ "ibis" ] ++ (map (backend: "ibis.backends.${backend}") backends);
    };
in
pkgs.callPackage drv {
  python = pkgs."python${builtins.replaceStrings [ "." ] [ "" ] python}";
}
