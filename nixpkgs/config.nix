{
    packageOverrides = super: let self = super.pkgs; in
    {
        haskellEnv = self.haskell.packages.ghc784.ghcWithPackages
            (haskellPackages: with haskellPackages; [
                # libraries
                async criterion text parsec lens attoparsec bzlib hexpat
                # tools
                cabal-install ghc-mod
            ]);
    };
}
