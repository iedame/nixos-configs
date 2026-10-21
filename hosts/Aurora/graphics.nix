{ config, pkgs, ... }:

{
  # Enable OpenGL and 32Bit support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    #
    # TEMPORARY, until nixpkgs fixes https://github.com/NixOS/nixpkgs/issues/576412:
    # patchelf 0.18 and 0.19 lay out the driver's programs (nvidia-smi and
    # a few helpers) so that their dynamic section lands in a read-only
    # page, and the loader crashes before they start; Beszel's GPU
    # collector runs nvidia-smi every few seconds. Patch them with 0.15.2,
    # the version nixpkgs used before. The kernel module and the libraries
    # are unchanged. Drop this once nixpkgs has the fix.
    package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (old: {
      builder = pkgs.runCommand "nvidia-builder.sh" { } ''
        substitute ${old.builder} $out --replace-fail \
          'patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \' \
          '${
            pkgs.patchelf.overrideAttrs {
              version = "0.15.2";
              src = pkgs.fetchurl {
                url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
                hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
              };
              doCheck = false;
            }
          }/bin/patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \'
      '';
    });
  };
}
