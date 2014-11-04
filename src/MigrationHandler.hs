module MigrationHandler 
   (migrationRequest
   ) where

import           Application
import           Control.Applicative ((<$>))
import           Control.Monad.IO.Class (liftIO)
import           Data.ByteString.Char8 as BSC
import qualified Data.EnvironmentHelpers as DE
import qualified Database.PostgreSQL.Simple as P
import qualified RemindMeConfiguration as RC
import qualified Snap.Core                as SC
import qualified SnapHelpers as SH
import           System.Environment (getExecutablePath)
import           System.FilePath (dropFileName, (</>))
import           System.Process (callProcess)

migrationRequest :: AppHandler ()
migrationRequest = SH.handleMethods
   [ (SC.PUT, handleMigrationRun)
   ]

-- This should be an idempotent operation, this means that we should require that the user pass in
-- the ID of the migration that they wish to run up to.
handleMigrationRun :: AppHandler ()
handleMigrationRun = SH.getKeyAndConfirm RC.rmMigrationKey handleFlywayMigrate

handleFlywayMigrate :: AppHandler ()
handleFlywayMigrate = either (SH.respondWithError SH.badRequest) (liftIO . flywayMigrate) =<< getFlywayOptions

flywayMigrate :: FlywayOptions -> IO ()
flywayMigrate options = do
   flywayPath <- flywayExecutablePath
   callProcess flywayPath migrationArguments
   where
      migrationArguments = "migrate" : flywayOptionsToArguments options
   
getFlywayOptions :: AppHandler (Either String FlywayOptions)
getFlywayOptions = do
   potentialTarget <- fmap (read . BSC.unpack) <$> SC.getParam (BSC.pack "target")
   case potentialTarget of
      Nothing -> return . Left $ "You need to provide a 'target' schema version param to the migration endpoint."
      Just target -> do
         pHost     <- siGetEnv  $ pgRemindMePre "HOST"
         pPort     <- fmap read <$> (siGetEnv $ pgRemindMePre "PORT")
         pSchema   <- siGetEnv  $ pgRemindMePre "SCHEMA"
         pRole     <- siGetEnv  $ pgRemindMePre "ROLE"
         pPassword <- siGetEnv  $ pgRemindMePre "PASSWORD"
         case (pHost, pPort, pSchema, pRole, pPassword) of
            (Just host, Just port, Just schema, Just role, Just password) -> do
               let connectionInfo = P.ConnectInfo 
                                       { P.connectHost = host
                                       , P.connectPort = port
                                       , P.connectDatabase = schema 
                                       , P.connectUser = ""
                                       , P.connectPassword = ""
                                       }
               let connectionString = P.postgreSQLConnectionString connectionInfo
               return . Right $ FlywayOptions
                  { flywayUrl = BSC.unpack connectionString
                  , flywayUser = role
                  , flywayPassword = password
                  , flywayTarget = target
                  }
            _ -> return . Left $ "Could not load the database details from the environment variables."
   where
      siGetEnv :: String -> AppHandler (Maybe String)
      siGetEnv = liftIO . DE.getEnv
   
      pgRemindMePre :: String -> String
      pgRemindMePre = (++) "PG_REMIND_ME_"

getExecutableDirectory :: IO FilePath
getExecutableDirectory = fmap dropFileName getExecutablePath

flywayExecutablePath :: IO FilePath
flywayExecutablePath = fmap addFlywayPath getExecutableDirectory

addFlywayPath :: FilePath -> FilePath
addFlywayPath f = f </> "migrations" </> "flyway"

data FlywayOptions = FlywayOptions
   { flywayUrl :: String
   , flywayUser :: String
   , flywayPassword :: String
   , flywayTarget :: Integer
   } deriving (Eq)

flywayOptionsToArguments :: FlywayOptions -> [String]
flywayOptionsToArguments fo = 
   [ "-url=" ++ flywayUrl fo
   , "-user=" ++ flywayUser fo
   , "-password=" ++ flywayPassword fo
   , "-target=" ++ (show . flywayTarget $ fo)
   ]
