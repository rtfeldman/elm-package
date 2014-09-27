module Install.Fetch where

import Control.Monad.Error (ErrorT, liftIO, throwError)
import qualified Codec.Archive.Zip as Zip
import qualified Data.List as List
import qualified Network.HTTP.Client as Client
import System.Directory (doesDirectoryExist, getDirectoryContents, renameDirectory)

import qualified Elm.Package.Name as N
import qualified Elm.Package.Version as V
import qualified Utils.Commands as Cmd
import qualified Utils.Http as Http


package :: N.Name -> V.Version -> ErrorT String IO ()
package name version =
  ifNotExists directory $ do
      Http.send zipball extract
      files <- liftIO $ getDirectoryContents "."
      case List.find (List.isPrefixOf (N.toFilePath name)) files of
        Nothing ->
            throwError "Could not download source code successfully."
        Just dir ->
            liftIO $ renameDirectory dir (V.toString version)
  where
    directory = N.toFilePath name
    zipball =
        "http://github.com/" ++ N.toUrl name ++ "/zipball/" ++ V.toString version ++ "/"


ifNotExists :: FilePath -> ErrorT String IO () -> ErrorT String IO ()
ifNotExists directory command =
    do exists <- liftIO $ doesDirectoryExist directory
       if exists
          then return ()
          else Cmd.inDir directory command


extract :: Client.Request -> Client.Manager -> IO ()
extract request manager =
    do  response <- Client.httpLbs request manager
        let archive = Zip.toArchive (Client.responseBody response)
        Zip.extractFilesFromArchive [] archive