{-# LANGUAGE OverloadedStrings #-}

module Connect.Connect
  ( Connect(..)
  , initConnectSnaplet
  ) where

import           ConfigurationHelpers
import           Connect.Data
import           Connect.Descriptor
import qualified Connect.PageToken       as PT
import qualified Connect.Zone            as CZ
import qualified Control.Monad           as CM
import qualified Control.Monad.IO.Class  as MI
import qualified Crypto.Cipher.AES       as CCA
import qualified Data.ByteString.Char8   as BSC
import qualified Data.Configurator       as DC
import qualified Data.Configurator.Types as DCT
import           Data.ConfiguratorTimeUnits ()
import qualified Data.EnvironmentHelpers as DE
import           Data.Maybe              (fromMaybe)
import           Data.Text
import           Data.Time.Units
import qualified Network.HostName        as HN
import qualified Network.URI             as NU
import qualified Snap.Snaplet            as SS
import qualified System.Exit             as SE

-- This should be the Atlassian Connect Snaplet
-- The primary purpose of this Snaplet should be to load Atlassian Connect specific configuration.
-- We should be able to start a snaplet that actually provides no routes but gives a bunch of
-- required configuration information back to the person that needs it. Actually, it would be really
-- great if we could provide our own Atlassian Connect specific routes in here. That way this
-- connect snaplet could be responsible for providing the Atlassian Connect plugin json descriptor
-- to the rest of the plugin. That would be great!

toConnect :: ConnectConfig -> Connect
toConnect conf = Connect
  { connectAES = CCA.initAES $ ccSecretKey conf
  , connectPluginName = Name $ ccPluginName conf
  , connectPluginKey = PluginKey $ ccPluginKey conf
  , connectBaseUrl = ccBaseUrl conf
  , connectPageTokenTimeout = Timeout $ ccPageTokenTimeout conf
  , connectHostWhitelist = ccHostWhiteList conf
  }

initConnectSnaplet :: IO String -> Maybe CZ.Zone -> SS.SnapletInit b Connect
initConnectSnaplet configDataDir zone = SS.makeSnaplet "Connect" "Atlassian Connect state and operations." (Just configDataDir) $
  MI.liftIO $ CM.liftM toConnect $ SS.loadAppConfig "connect.cfg" "resources" >>= loadConnectConfig zone

data ConnectConfig = ConnectConfig
  { ccSecretKey        :: BSC.ByteString
  , ccPluginName       :: Text
  , ccPluginKey        :: Text
  , ccBaseUrl          :: NU.URI
  , ccPageTokenTimeout :: Second
  , ccHostWhiteList    :: [Text]
  }

validHosts :: IO[Text]
validHosts = fmap hosts HN.getHostName
    where hosts localhost = fmap pack (localhost : ["localhost", "jira-dev.com", "jira.com", "atlassian.net"])

loadConnectConfig :: Maybe CZ.Zone -> DCT.Config -> IO ConnectConfig
loadConnectConfig zone connectConf = do
  name <- require connectConf "plugin_name" "Missing plugin name in connect configuration file."
  key <- require connectConf "plugin_key" "Missing plugin key in connect configuration file."
  rawBaseUrl <- require connectConf "base_url" "Missing base url in connect configuration file."
  secret <- require connectConf "secret_key" "Missing secret key in connect configuration file."
  hostWhiteList <- validHosts
  let keyLength = BSC.length secret
  CM.when (keyLength /= 32) $ do
    putStrLn $ "Expected Atlassian Connect secret_key to be 32 Hex Digits long but was actually: " ++ show keyLength
    SE.exitWith (SE.ExitFailure 1)
  envBaseUrl <- DE.getEnv "CONNECT_BASE_URL"
  envSecretKey <- DE.getEnv "CONNECT_SECRET_KEY"
  let baseUrlToParse = fromMaybe rawBaseUrl envBaseUrl
  case NU.parseURI baseUrlToParse of
    Nothing -> do
      putStrLn $ "Could not parse the baseUrl in the configuration file: " ++ rawBaseUrl
      SE.exitWith (SE.ExitFailure 2)
    Just baseUrl -> do
      pageTokenTimeoutInSeconds <- DC.lookupDefault PT.defaultTimeoutSeconds connectConf "page_token_timeout_seconds"
      return ConnectConfig
        { ccPluginName = name `append` nameKeyAppend zone
        , ccPluginKey = key `append` zoneKeyAppend zone
        , ccBaseUrl = baseUrl
        , ccSecretKey = maybe secret BSC.pack envSecretKey
        , ccPageTokenTimeout = pageTokenTimeoutInSeconds
        , ccHostWhiteList = hostWhiteList
        }

nameKeyAppend :: Maybe CZ.Zone -> Text
nameKeyAppend (Just CZ.Prod) = empty
nameKeyAppend (Just zone) = pack $ " (" ++ show zone ++ ")"
nameKeyAppend Nothing = pack " (Local)"

zoneKeyAppend :: Maybe CZ.Zone -> Text
zoneKeyAppend (Just CZ.Prod) = empty
zoneKeyAppend (Just CZ.Dog) = pack ".dog"
zoneKeyAppend (Just CZ.Dev) = pack ".dev"
zoneKeyAppend Nothing = pack ".local"