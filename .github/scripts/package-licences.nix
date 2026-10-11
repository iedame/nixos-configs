# Best-effort licence lookup for the cache report in workflows/ci.yml.
#
# Takes a list of { drv, pname } (derivation file name and package name) and
# a system configuration, and returns { <drv> = "<licences>"; }. A package is
# looked up among the ones the configuration installs, by its exact
# derivation, and failing that by name in nixpkgs, so the licence of a
# rebuilt variant is the one of the package it is based on.
packages: system:
let
  inherit (system) config pkgs;
  inherit (pkgs) lib;

  installed =
    config.environment.systemPackages
    ++ lib.concatMap (user: user.home.packages) (lib.attrValues config.home-manager.users);
  byDrv = lib.listToAttrs (
    map (
      package:
      lib.nameValuePair (baseNameOf (builtins.unsafeDiscardStringContext package.drvPath)) package
    ) (lib.filter (package: package ? drvPath) installed)
  );

  find = { drv, pname }: byDrv.${drv} or pkgs.${pname} or pkgs.python3Packages.${pname} or null;

  describe =
    package:
    let
      licences = lib.toList (package.meta.license or [ ]);
      name = licence: if lib.isString licence then licence else licence.spdxId or licence.shortName;
    in
    if package == null || licences == [ ] then
      "unknown"
    else
      let
        names = lib.concatMapStringsSep ", " name licences;
        unfree = lib.any (licence: !(licence.free or true)) licences;
      in
      # nixpkgs' own unfree licences already say so in their name
      if unfree && !lib.hasInfix "unfree" names then "${names} (unfree)" else names;

  # Some names in nixpkgs are aliases that throw when evaluated
  tryDescribe =
    package:
    let
      result = builtins.tryEval (describe (find package));
    in
    if result.success then result.value else "unknown";
in
lib.listToAttrs (map (package: lib.nameValuePair package.drv (tryDescribe package)) packages)
