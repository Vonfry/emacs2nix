{-

emacs2nix - Generate Nix expressions for Emacs packages
Copyright (C) 2016 Thomas Tuegel

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

-}

{-# LANGUAGE TemplateHaskell #-}

module Distribution.Nix.Package.Melpa
    ( Package(..)
    , Recipe(..)
    , expression
    , writePackageExpression
    , readPackageExpression
    ) where

import qualified Control.Exception as Exception
import qualified Data.Text as Text
import Data.Version ( Version, showVersion )
import Nix.Expr
import qualified Nix.Parser
import qualified Nix.Pretty
import qualified System.Directory as Directory
import qualified System.FilePath as FilePath
import qualified System.IO.Streams as Streams
import qualified System.IO.Temp as Temp
import qualified Data.Text.Prettyprint.Doc as Pretty

import qualified Distribution.Emacs.Name as Emacs
import Distribution.Nix.Fetch (Fetch, Recipe)
import qualified Distribution.Nix.Fetch as Fetch
import Exceptions
import qualified System.IO.Streams.Pretty as Pretty

data Package =
  Package
    { ename :: !Emacs.Name
    , version :: !Version
    , fetch :: !Fetch
    , deps :: ![Emacs.Name]
    , recipe :: !Recipe
    }

expression :: Package -> NExpr
expression (Package {..}) =
    mkNonRecSet
        [ "ename" $= mkStr (Emacs.fromName ename)
        , "version" $= mkStr (Text.pack $ showVersion version)
        , "src" $= Fetch.fetchExpr fetch
        , "recipe" $= Fetch.fetchExpr (Fetch.fetchRecipe recipe)
        , "deps" $= mkNonRecSet (mkDep <$> deps)
        ]
  where
    mkDep dep = quoted (Emacs.fromName dep) $= mkNull
    quoted str = "\"" <> str <> "\""


writePackageExpression
  :: FilePath
  -> NExpr
  -> IO ()
writePackageExpression output expr =
  do
    let (directory, filename) = FilePath.splitFileName output
    tmp <- Temp.emptyTempFile directory filename
    Streams.withFileAsOutput tmp
      (\out ->
        do
          let
            doc = Nix.Pretty.prettyNix expr
            rendered = Pretty.layoutPretty Pretty.defaultLayoutOptions doc
          Pretty.displayStream rendered =<< Streams.encodeUtf8 out
      )
    Directory.renameFile tmp output


data NixParseFailure = NixParseFailure (Pretty.Doc ())
mkException 'PrettyException ''NixParseFailure


instance Pretty.Pretty NixParseFailure where
  pretty (NixParseFailure failed) =
    "Failed to parse expression:" Pretty.<+> Pretty.unAnnotate failed


readPackageExpression :: FilePath -> IO NExpr
readPackageExpression input =
  do
    result <- Nix.Parser.parseNixFile input
    case result of
      Nix.Parser.Failure failed ->
        Exception.throwIO (NixParseFailure (Pretty.unAnnotate failed))
      Nix.Parser.Success parsed ->
        return parsed
