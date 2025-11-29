{pkgs, ...}: {
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    # *.nix files
    alejandra.enable = true;
    # *.{graphqls?,json,md,yaml} files
    prettier = {
      enable = true;
      includes = [
        "*.cjs"
        "*.css"
        "*.html"
        "*.gql"
        "*.graphql"
        "*.graphqls"
        "*.js"
        "*.json"
        "*.json5"
        "*.jsx"
        "*.md"
        "*.mdx"
        "*.mjs"
        "*.scss"
        "*.ts"
        "*.tsx"
        "*.vue"
        "*.yaml"
        "*.yml"
      ];
      settings = {
        printWidth = 100;
        singleQuote = true;
        semi = false;
        overrides = [
          {
            files = "*.md";
            options = {
              tabWidth = 4;
            };
          }
        ];
      };
    };
    # *.rs files
    rustfmt.enable = true;
    rustfmt.package = pkgs.rustToolchain;
  };
}
