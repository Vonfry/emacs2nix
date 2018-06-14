{-

emacs2nix - Generate Nix expressions for Emacs packages
Copyright (C) 2018 Thomas Tuegel

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


{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE StandaloneDeriving #-}

module Exceptions
    ( module Control.Exception
    , showExceptions, showExceptions_, mapExceptionIO
    , NoRevision (..)
    , Died (..)
    , ProcessFailed (..)
    , ProcessingFailed (..)
    , ParseFilesError (..)
    , ManyExceptions (..), manyExceptions
    ) where

import Control.Exception
import Data.Text ( Text )
import qualified Data.Text as Text
import Data.Typeable
import qualified System.IO.Streams as Stream


data NoRevision = NoRevision
  deriving (Show, Typeable)

instance Exception NoRevision


data Died = Died Int Text
  deriving (Show, Typeable)

instance Exception Died


data ProcessFailed = ProcessFailed String [String] SomeException
  deriving (Show, Typeable)

instance Exception ProcessFailed


data ProcessingFailed = ProcessingFailed Text Text SomeException
  deriving (Show, Typeable)

instance Exception ProcessingFailed


data ParseFilesError = ParseFilesError String
  deriving (Show, Typeable)

instance Exception ParseFilesError


showExceptions :: IO b -> IO (Maybe b)
showExceptions go = catch (Just <$> go) handler
  where
    handler (SomeException e) = do
      Stream.write (Just (Text.pack (show e))) =<< Stream.encodeUtf8 =<< Stream.unlines Stream.stdout
      pure Nothing

showExceptions_ :: IO b -> IO ()
showExceptions_ go = showExceptions go >> pure ()

mapExceptionIO :: (Exception e, Exception f) => (e -> f) -> IO a -> IO a
mapExceptionIO f go = catch go handler where
  handler e = throwIO (f e)

data ManyExceptions = forall e. Exception e => ManyExceptions [e]
  deriving (Typeable)

deriving instance Show ManyExceptions

instance Exception ManyExceptions

manyExceptions :: Exception e => [e] -> ManyExceptions
manyExceptions = ManyExceptions