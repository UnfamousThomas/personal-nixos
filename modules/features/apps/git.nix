{
  flake.modules.homeManager.git = {
    programs.git = {
      enable = true;
      settings = {
        user.name = "UnfamousThomas";
        user.email = "thompalts@gmail.com";
        init.defaultBranch = "main";
        url."ssh://git@github.com/".insteadOf = "https://github.com/";
      };
    };
  };
}
