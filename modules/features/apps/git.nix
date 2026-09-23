{
  flake.modules.homeManager.git = {
    programs.git = {
      enable = true;
      settings = {
        user.name = "UnfamousThomas";
        user.email = "thompalts@gmail.com";
        init.defaultBranch = "main";
        # Push over SSH, but keep fetching public https URLs anonymously, so
        # clones work before the SSH key/1Password agent is set up.
        url."ssh://git@github.com/".pushInsteadOf = "https://github.com/";
      };
    };
  };
}
