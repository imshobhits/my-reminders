module TenantJWT ( withTenant ) where

import           Control.Applicative
import           Control.Monad (join, guard)
import qualified Data.ByteString.Char8          as B
import qualified Data.CaseInsensitive           as DC
import           Data.Maybe                     (isJust)
import qualified Data.Text                      as T
import qualified Snap.Core                      as SC
import qualified Web.JWT                        as J

import           Application
import qualified Persistence.PostgreSQL         as PP
import qualified Persistence.Tenant             as PT
import qualified SnapHelpers                    as SH
import qualified Connect.Tenant                 as CT

type UnverifiedJWT = J.JWT J.UnverifiedJWT

withTenant :: (CT.ConnectTenant -> AppHandler ()) -> AppHandler ()
withTenant tennantApply = do
  parsed <- sequence [getJWTTokenFromParam, getJWTTokenFromAuthHeader]
  let jwtParamOrErrors = firstRightOrLefts parsed
  case jwtParamOrErrors of
    Left errors -> SH.respondWithErrors SH.badRequest errors
    Right unverifiedJwt -> do
      possibleTenant <- getTenant unverifiedJwt
      case possibleTenant of
        Left result -> SH.respondPlainWithError SH.badRequest result
        Right tenant -> tennantApply tenant

decodeByteString :: B.ByteString -> Maybe UnverifiedJWT
decodeByteString = J.decode . SH.byteStringToText

-- Standard GET requests (and maybe even POSTs) from Atlassian Connect will put the jwt header in a
-- param in either the query params or in form params. This method will extract it from either.
getJWTTokenFromParam :: AppHandler (Either String UnverifiedJWT)
getJWTTokenFromParam = do
   potentialParam <- fmap decodeByteString <$> SC.getParam (B.pack "jwt")
   case join potentialParam of
      Nothing -> return . Left $ "There was no JWT param in the request"
      Just unverifiedJwt -> return . Right $ unverifiedJwt

-- Sometimes Atlassian Connect will pass the JWT token in an Authorization header in your requests
-- in this format:
-- Authorization: JWT <token>
-- This method will extract the JWT token from the Auth header if it is present.
getJWTTokenFromAuthHeader :: AppHandler (Either String UnverifiedJWT)
getJWTTokenFromAuthHeader = do
   authHeader <- fmap (SC.getHeaders authorizationHeaderName) SC.getRequest
   case authHeader of
      Just (firstHeader : _) -> if B.isPrefixOf jwtPrefix firstHeader
         then return $ maybe (Left "The JWT Auth header could not be parsed.") Right (decodeByteString . dropJwtPrefix $ firstHeader)
         else return . Left $ "The Authorization header did not contain a JWT token: " ++ show firstHeader
      _ -> return . Left $ "There was no Authorization header in the request."
   where
      jwtPrefix = B.pack "JWT "
      dropJwtPrefix = B.drop (B.length jwtPrefix)

authorizationHeaderName :: DC.CI B.ByteString
authorizationHeaderName = DC.mk . B.pack $ "Authorization"

firstRightOrLefts :: [Either b a] -> Either [b] a
firstRightOrLefts = go []
   where
      go :: [b] -> [Either b a] -> Either [b] a
      go accum [] = Left accum
      go accum (Left x : xs) = go (x : accum) xs
      go _ (Right x : _) = Right x

getTenant :: UnverifiedJWT -> AppHandler (Either String CT.ConnectTenant)
getTenant unverifiedJwt = do
  let potentialKey = getClientKey unverifiedJwt
  -- TODO collapse these cases
  case potentialKey of
    Nothing -> retError "Could not parse the JWT message."
    Just key ->
      PP.withConnection $ \conn -> do
        potentialTenant <- PT.lookupTenant conn normalisedClientKey
        case potentialTenant of
          Nothing -> retError $ "Could not find a tenant with that id: " ++ sClientKey
          Just unverifiedTenant ->
            case verifyTenant unverifiedTenant unverifiedJwt of
              Nothing -> retError "Invalid signature for request. Danger! Request ignored."
              Just verifiedTenant -> ret (verifiedTenant, getUserKey unverifiedJwt)
      where
        sClientKey          = show key
        normalisedClientKey = T.pack sClientKey

  where
    retError :: Monad m => x -> m (Either x y)
    retError = return . Left

    ret :: Monad m => y -> m (Either x y)
    ret = return . Right

verifyTenant :: PT.Tenant -> UnverifiedJWT -> Maybe PT.Tenant
verifyTenant tenant unverifiedJwt = do
  guard (isJust $ J.verify tenantSecret unverifiedJwt)
  pure tenant
  where
    tenantSecret = J.secret . PT.sharedSecret $ tenant

getClientKey :: J.JWT a -> Maybe J.StringOrURI
getClientKey jwt = J.iss . J.claims $ jwt

getUserKey :: J.JWT a -> Maybe String
getUserKey jwt = fmap show (getSub jwt)
   where
      getSub = J.sub . J.claims
