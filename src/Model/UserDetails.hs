{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Model.UserDetails
   ( getUserDetails
   , UserWithDetails(..)
   ) where

import           AppConfig
import           Application
import           Data.Aeson
import qualified Data.ByteString                   as B
import qualified Data.Map                          as M
import           Data.Text.Encoding                (encodeUtf8)
import           GHC.Generics
import           NetworkHelpers
import qualified Snap.AtlassianConnect             as AC
import qualified Snap.AtlassianConnect.HostRequest as AC
import qualified Snap.Snaplet                      as SS

data UserWithDetails = UserWithDetails
   { name         :: AC.UserKey
   , emailAddress :: String
   , avatarUrls   :: M.Map String String
   , displayName  :: String
   , active       :: Bool
   , timeZone     :: String
   } deriving (Show, Generic)
--TODO: parse url here

instance FromJSON UserWithDetails
instance ToJSON UserWithDetails

getUserDetails :: AC.Tenant -> AC.UserKey -> AppHandler (Either AC.ProductErrorResponse UserWithDetails)
getUserDetails tenant userKey = do
    rmConf <- getAppConf
    SS.with connect $ AC.hostGetRequest tenant usernameUrl queryParams (proxyUpdate rmConf)
  where
    proxyUpdate rmConf = setPotentialProxy (getProxyFromConf productBaseUrlString rmConf)
    productBaseUrlString = show . AC.getURI . AC.baseUrl $ tenant

    usernameUrl :: B.ByteString
    usernameUrl = "/rest/api/2/user"

    queryParams :: [(B.ByteString, Maybe B.ByteString)]
    queryParams = [("username", Just . encodeUtf8 $ userKey)]
