{ inputs, ... }:
{
  # JetBrains Toolbox plus IntelliJ IDEA, WebStorm and GoLand.
  #
  # The IDEs come from nixpkgs, not Toolbox: IDEs downloaded by Toolbox are
  # generic Linux binaries that mostly don't start on NixOS, and these are
  # patched, cached and updated with `nix flake update`. Toolbox stays for
  # anything else (other IDEs, Gateway, its update notifications).
  #
  # Plugins are Marketplace builds pinned by nix-jetbrains-plugins. Bundled
  # plugins that aren't wanted are switched off in `disabled_plugins.txt`, which
  # is rewritten on every switch (the IDE's own list is not the source of
  # truth). Theme, colour scheme and font are only seeded when the IDE has no
  # such setting yet, so changing them in the IDE sticks.
  #
  # Toolchains (JDK, Go, Node) are deliberately absent: they come from each
  # project's devenv shell, which the direnv plugin picks up for run configs.
  flake.modules.homeManager.jetbrains =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.nix-jetbrains-plugins.lib) buildIdeWithPlugins;

      # Every IDE.
      commonPlugins = [
        "com.github.catppuccin.jetbrains" # theme, matches Stylix's Catppuccin Mocha
        "com.github.catppuccin.jetbrains_icons" # file icons
        "nix-idea" # Nix syntax
        "co.anbora.labs.direnv" # devenv/direnv environment for run configs
        "zielu.gittoolbox" # inline blame, status of branches
        "mobi.hsz.idea.gitignore" # .gitignore and friends
        "ru.adelf.idea.dotenv" # .env files
        "izhangzhihao.rainbow.brackets" # bracket colouring
        "com.github.lppedd.idea-conventional-commit" # conventional commits in the commit dialog
        "String Manipulation" # case conversion, sorting, encoding
      ];

      # Plugin IDs (see plugin.xml, not the folder names). A bundled plugin
      # that a kept one needs must stay; the lists below were checked for that
      # against each IDE's plugin.xml files, so re-check when adding to them.
      # An ID an IDE doesn't ship is ignored, so a shared list is harmless.
      keymaps = {
        eclipse = "com.intellij.plugins.eclipsekeymap";
        netbeans = "com.intellij.plugins.netbeanskeymap";
        visualStudio = "com.intellij.plugins.visualstudiokeymap";
        vscode = "com.intellij.plugins.vscodekeymap";
      };
      commonDisabled = [
        # Language packs.
        "com.intellij.ja"
        "com.intellij.ko"
        "com.intellij.zh"
        # Remote development, Code With Me, Gateway, dev containers.
        "com.jetbrains.remoteDevelopment"
        "com.jetbrains.gateway"
        "com.jetbrains.remoteDevServer"
        "org.jetbrains.plugins.docker.gateway"
        "com.jetbrains.station"
        "org.jetbrains.plugins.remote-run"
        "com.jetbrains.plugins.webDeployment" # FTP/SFTP deployment
        # Telemetry-ish and machine-learning extras, onboarding, plugin dev.
        "training"
        "com.jetbrains.performancePlugin"
        "com.intellij.searcheverywhere.ml"
        "com.intellij.completion.ml.ranking"
        "org.jetbrains.completion.full.line"
        "com.intellij.dev"
        "com.intellij.settingsSync"
        # Built-in AI tooling; agents run from the terminal.
        "com.intellij.mcpServer"
        "intellij.debuggerMcp"
        # Qodana.
        "org.intellij.qodana"
        "com.intellij.code.provenance"
      ];

      ides = {
        idea = {
          package = "idea";
          dataDir = "IntelliJIdea";
          disabled = [
            keymaps.eclipse
            keymaps.netbeans
            keymaps.visualStudio
            "org.jetbrains.idea.eclipse" # Eclipse project interop
            "org.jetbrains.plugins.javaFX"
            "com.intellij.compose" # Compose Multiplatform
            # Old-school Java EE servers and template engines.
            "JBoss"
            "Tomcat"
            "com.intellij.freemarker"
            "com.intellij.velocity"
            "XPathView"
            # Other JVM frameworks.
            "com.intellij.micronaut"
            "com.intellij.quarkus"
            # Web frameworks and legacy JS tooling: WebStorm's job.
            "AngularJS"
            "org.jetbrains.plugins.vue"
            "intellij.nextjs"
            "com.intellij.react"
            "com.deadlock.scsyntax"
            "com.intellij.plugins.webcomponents"
            "Karma"
            "tslint"
            "jshint"
            "org.jetbrains.plugins.node-remote-interpreter"
            "intellij.webpack"
            "intellij.vitejs"
            "com.intellij.stylelint"
            "com.intellij.tailwindcss"
            "org.intellij.plugins.postcss"
          ];
        };
        webstorm = {
          package = "webstorm";
          dataDir = "WebStorm";
          disabled = [
            keymaps.eclipse
            keymaps.netbeans
            keymaps.visualStudio
            keymaps.vscode
            # Bundled colour schemes; Catppuccin replaces them.
            "com.intellij.plugins.all_hallows_eve.colorscheme"
            "com.intellij.plugins.blackboard.colorscheme"
            "com.intellij.plugins.cobalt.colorscheme"
            "com.intellij.plugins.github.colorscheme"
            "com.intellij.plugins.monokai.colorscheme"
            "com.intellij.plugins.rails_casts.colorscheme"
            "com.intellij.plugins.twilight.colorscheme"
            "com.intellij.plugins.vibrantink.colorscheme"
            "com.intellij.plugins.warmneon.colorscheme"
            # Legacy or niche web tooling.
            "tslint"
            "jshint"
            "Karma"
            "gherkin"
            "cucumber-javascript"
            "com.jetbrains.lang.ejs"
            "com.dmarcotte.handlebars"
            "com.jetbrains.plugins.jade"
            "com.intellij.plugins.html.instantEditing" # Live Edit
            "com.intellij.plugins.webcomponents"
            "org.jetbrains.plugins.node-remote-interpreter"
            "com.intellij.figma"
            "org.jetbrains.plugins.vagrant"
            "com.intellij.tasks.timeTracking"
            "com.intellij.diagram"
          ];
        };
        goland = {
          package = "goland";
          dataDir = "GoLand";
          disabled = [
            keymaps.vscode
            "com.intellij.plugins.colorful.darcula.colorscheme"
            "com.intellij.plugins.monokai.colorscheme"
            "com.intellij.plugins.goland.solarized.colorscheme"
            "com.intellij.diagram"
            "intellij.webpack"
            "com.intellij.stylelint"
          ];
        };
      };

      # The theme picks its own editor colour scheme when chosen in the IDE,
      # not when set in laf.xml, hence colors.scheme.xml as well.
      seedFiles = {
        "options/laf.xml" = ''
          <application>
            <component name="LafManager" autodetect="false">
              <laf themeId="com.github.catppuccin.mocha.islands.jetbrains" />
            </component>
          </application>
        '';
        "options/colors.scheme.xml" = ''
          <application>
            <component name="EditorColorsManagerImpl">
              <global_color_scheme name="Catppuccin Mocha" />
            </component>
          </application>
        '';
        "options/editor-font.xml" = ''
          <application>
            <component name="DefaultFont">
              <option name="FONT_FAMILY" value="JetBrains Mono" />
              <option name="FONT_SIZE" value="15" />
              <option name="FONT_SIZE_2D" value="15.0" />
              <option name="LINE_SPACING" value="1.3" />
              <option name="USE_LIGATURES" value="true" />
            </component>
          </application>
        '';
      };

      # Config lives in <dataDir><major.minor> and moves with each release.
      configDir =
        ide:
        "${config.xdg.configHome}/JetBrains/${ide.dataDir}${
          lib.versions.majorMinor pkgs.jetbrains.${ide.package}.version
        }";

      configScript =
        name: ide:
        let
          dir = configDir ide;
          disabled = pkgs.writeText "${name}-disabled_plugins.txt" (
            lib.concatStringsSep "\n" (lib.unique (commonDisabled ++ ide.disabled)) + "\n"
          );
          seed = lib.mapAttrsToList (file: content: ''
            if [ ! -e "${dir}/${file}" ]; then
              run install -Dm644 ${pkgs.writeText (baseNameOf file) content} "${dir}/${file}"
            fi
          '') seedFiles;
        in
        ''
          run install -Dm644 ${disabled} "${dir}/disabled_plugins.txt"
          ${lib.concatStrings seed}
        '';
    in
    {
      home.packages = [
        pkgs.jetbrains-toolbox
      ]
      ++ lib.mapAttrsToList (_: ide: buildIdeWithPlugins pkgs ide.package commonPlugins) ides;

      home.activation.jetbrainsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStrings (lib.mapAttrsToList configScript ides)
      );
    };
}
