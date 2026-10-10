{ pkgs, ... }:
{
  custom.zsh = {
    enable = true;
    suggestionAliases = true;
    darwinAliases = true;
    extraAliases = {
      update = "nh darwin switch";
    };
  };

  programs.zsh.initContent = ''
    # gha <pr>: run nixpkgs-review for a nixpkgs PR on GitHub Actions
    gha() {
      if [ -z "$1" ]; then
        echo "Usage: gha <pr-number>"
        return 1
      fi
      echo "Triggering nixpkgs-review for PR $1..."
      ${pkgs.gh}/bin/gh workflow run review.yml --repo iedame/nixpkgs-review-gha -f pr="$1"
      echo "Workflow started! Check progress here:"
      echo "https://github.com/iedame/nixpkgs-review-gha/actions"
    }
  '';
}
