{
  # Plain-markdown notes in ~/notes, two shortcuts (desktop/niri.nix):
  #   Mod+N        new note in a small floating terminal
  #   Mod+Shift+N  find and view notes (search over titles *and* text, with a
  #                preview); Enter opens the note in the editor
  # No daily notes, no index, no database: a note is a file, so anything can
  # read, sync or grep them. Notes are found anywhere under ~/notes.
  flake.modules.homeManager.notes =
    { pkgs, ... }:
    let
      note = pkgs.writeShellApplication {
        name = "note";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gnused
          fzf
          bat
          nano
        ];
        text = ''
          notes_dir="''${NOTES_DIR:-$HOME/notes}"
          editor="''${EDITOR:-nano}"
          self="$(readlink -f "$0")"

          slug() {
            tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-50
          }

          # First non-empty line, without markdown heading marks.
          title_of() {
            sed -n -E '/[^[:space:]]/{s/^[#[:space:]]+//; p; q}' "$1"
          }

          # Tab-separated, newest first: "date  title", path, the rest of the
          # text (flattened; searched, and shown as a snippet after the title).
          list_notes() {
            [ -d "$notes_dir" ] || return 0
            find "$notes_dir" -type f -name '*.md' -printf '%T@\t%p\n' | sort -rn | cut -f2- |
              while IFS= read -r file; do
                title="$(title_of "$file")"
                printf '%s  %s\t%s\t%s\n' \
                  "$(date -r "$file" +%Y-%m-%d)" "''${title:-(empty)}" "$file" \
                  "$(sed -n -E '/[^[:space:]]/,$p' "$file" | tail -n +2 | head -c 4000 | tr '\n\t' '  ')"
              done
          }

          new_note() {
            mkdir -p "$notes_dir"
            title="$*"
            stamp="$(date +%Y-%m-%d-%H%M%S)"
            file="$notes_dir/$stamp-note.md"
            initial=""
            if [ -n "$title" ]; then
              initial="$(printf '# %s\n\n' "$title")"
              printf '%s\n' "$initial" > "$file"
            fi

            "$editor" "$file"

            # Nothing written (or only the title we put there): no note.
            if [ ! -e "$file" ] || [ "$(cat "$file")" = "$initial" ] || ! grep -q '[^[:space:]]' "$file"; then
              rm -f "$file"
              return 0
            fi
            # Name it after what it says.
            name="$(title_of "$file" | slug)"
            target="$notes_dir/$stamp-''${name:-note}.md"
            if [ "$target" != "$file" ] && [ ! -e "$target" ]; then
              mv "$file" "$target"
            fi
          }

          find_notes() {
            selection="$(list_notes | fzf \
              --delimiter=$'\t' --with-nth=1,3 --exact --no-sort --prompt='note> ' \
              --header='enter: open   ctrl-n: new   type to search titles and text' \
              --preview="bat --color=always --style=plain --language=markdown {2}" \
              --preview-window='right,60%,wrap' \
              --bind "ctrl-n:execute($self new)+reload($self list)" || true)"
            [ -n "$selection" ] || return 0
            file="$(printf '%s' "$selection" | cut -f2)"
            exec "$editor" "$file"
          }

          case "''${1:-find}" in
            new) shift; new_note "$@" ;;
            find) find_notes ;;
            list) list_notes ;;
            *) echo "usage: note [new [title...] | find | list]" >&2; exit 2 ;;
          esac
        '';
      };
    in
    {
      home.packages = [ note ];
    };
}
