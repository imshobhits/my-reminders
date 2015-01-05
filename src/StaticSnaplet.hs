{-# LANGUAGE OverloadedStrings #-}
module StaticSnaplet
    ( initStaticSnaplet
    , StaticConf
    ) where

import           Control.Applicative
import           Control.Lens              ((&), (.~))
import qualified Control.Monad.IO.Class    as MI
import           Control.Monad.State.Class (get)
import           Data.ByteString           (ByteString, append)
import qualified Data.ByteString.Char8     as BC
import qualified Data.CaseInsensitive      as CI
import           Data.Maybe                (isNothing)
import           Data.Monoid               (mempty)
import qualified Data.Text                 as T
import qualified Data.UUID.V4              as UUID
import           Data.Version              (showVersion)
import qualified Heist                     as H
import qualified Heist.Internal.Types      as HIT
import qualified Heist.Interpreted         as HI
import           MicrosZone                (Zone(..), fromEnv)
import qualified Snap.Core                 as SC
import qualified Snap.Snaplet              as SS
import qualified Snap.Snaplet.Heist        as SSH
import           Snap.Util.FileServe
import qualified SnapHelpers               as SH
import qualified Text.XmlHtml              as X

import qualified Paths_my_reminders        as PMR

initStaticSnaplet :: SS.Snaplet (SSH.Heist b) -> SS.SnapletInit b StaticConf
initStaticSnaplet appHeist = SS.makeSnaplet "Static Content" "Static content per version" Nothing $ do
    conf <- MI.liftIO generateStaticConf
    SS.addRoutes versionRoutes
    SSH.addConfig appHeist (spliceConfig conf)
    return conf

data StaticConf = StaticConf
    { scResourcesVersion :: String
    , scCacheForever     :: Bool
    } deriving (Show)

spliceConfig :: StaticConf -> H.SpliceConfig (SS.Handler a a)
spliceConfig sc = mempty
   & HIT.scInterpretedSplices .~ customSplices sc

customSplices :: StaticConf -> HIT.Splices (HI.Splice (SS.Handler a a))
customSplices sc = "resourcesVersion" H.## resourcesVersion sc

resourcesVersion :: StaticConf -> SSH.SnapletISplice a
resourcesVersion = return . text . scResourcesVersion

text :: String -> [X.Node]
text x = [X.TextNode (T.pack x)]

generateStaticConf :: IO StaticConf
generateStaticConf = do
   zone <- fromEnv
   versionString <- generateResourcesVersion zone
   return StaticConf
      { scResourcesVersion = versionString
      , scCacheForever = not . isLocal $ zone
      }
   where
      isLocal = isNothing

generateResourcesVersion :: Maybe Zone -> IO String
generateResourcesVersion (Just _) = return baseVersionString
generateResourcesVersion Nothing  = do
    hash <- UUID.nextRandom
    return $ baseVersionString ++ "-" ++ show hash

baseVersionString :: String
baseVersionString = showVersion PMR.version

-- We should first try and directly match and extract the resources version, and it it does match then
-- pass the route onwards without the resources version present. Otherwise, if no matching route could
-- be found then we should redirect the to the same URL but with the resources version injected.
versionRoutes :: [(ByteString, SS.Handler a StaticConf ())]
versionRoutes =
    [ (":rv/"   , handlePotentialResourcesVersion (SC.route staticRoutes))
    , (""       , redirectStatic)
    ]

handlePotentialResourcesVersion :: SS.Handler a StaticConf () -> SS.Handler a StaticConf ()
handlePotentialResourcesVersion handle = do
    potentialResourcesVersion <- SC.getParam "rv"
    case potentialResourcesVersion of
        Nothing -> SC.pass -- Don't handle this request
        Just passedResourcesVersion -> do
            actualResourcesVersion <- BC.pack . scResourcesVersion <$> get
            if passedResourcesVersion == actualResourcesVersion then handle else SC.pass

-- Add the resources version between the context path and the path information and redirect to that
redirectStatic :: SS.Handler a StaticConf ()
redirectStatic = do
    sc <- get
    r <- SC.getRequest
    let cp = SC.rqContextPath r
    let pathInfo = SC.rqPathInfo r
    SC.redirect $ cp `append` addResourcesVersion sc pathInfo

addResourcesVersion :: StaticConf -> BC.ByteString -> BC.ByteString
addResourcesVersion (StaticConf rv _) original = BC.pack rv `append` BC.pack "/" `append` original

-- These are the real routes to our resources. If you could not find any resources that match then you should
-- return a HTTP 404.
staticRoutes :: [(ByteString, SS.Handler a StaticConf ())]
staticRoutes =
  [ ("css"    , staticServeDirectory "static/css")
  , ("images" , staticServeDirectory "static/images")
  , ("js"     , staticServeDirectory "static-js")
  , (""       , SH.respondNotFound) -- If nothing else was matched then stop immediately.
  ]

staticServeDirectory :: FilePath -> SS.Handler a StaticConf ()
staticServeDirectory path = rawStaticServeDirectory path <|> SH.respondNotFound

rawStaticServeDirectory :: FilePath -> SS.Handler a StaticConf ()
rawStaticServeDirectory path = do
    serveDirectory path
    shouldCacheForever <- scCacheForever <$> get
    if shouldCacheForever then cacheForever else noCache

cacheForever :: SS.Handler a b ()
cacheForever = cache "max-age=31536000"

noCache :: SS.Handler a b ()
noCache = cache "no-cache"

cache :: BC.ByteString -> SS.Handler a b ()
cache v = SC.modifyResponse (SC.setHeader (CI.mk "Cache-Control") v)