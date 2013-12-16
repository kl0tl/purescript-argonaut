{-# LANGUAGE DeriveDataTypeable, OverloadedStrings #-}

module Data.Argonaut
  (
      Json
    , foldJson
    , isNull
    , isTrue
    , isFalse
    , isNumber
    , isString
    , isArray
    , isObject
    , toBool
    , fromBool
    , toText
    , fromText
    , toString
    , fromString
    , toDouble
    , fromDouble
    , toArray
    , fromArray
    , toObject
    , fromObject
    , boolL
    , numberL
    , arrayL
    , objectL
    , stringL
    , nullL
    , fromDoubleToNumberOrNull
    , fromDoubleToNumberOrString
    , jsonTrue
    , jsonFalse
    , jsonZero
    , jsonNull
    , emptyString
    , emptyArray
    , singleItemArray
    , emptyObject
    , singleItemObject
    , objectFromFoldable
    , arrayFromFoldable
    , JField
    , JObject
    , JArray
  ) where

import Control.Lens
import Control.Monad()
import Control.Applicative()
import Data.Foldable
import Data.Maybe
import qualified Data.Char as C
import qualified Data.List as L
import Data.Text(Text,unpack,pack)
import Data.Typeable(Typeable)
import qualified Data.Vector as V
import qualified Data.HashMap.Strict as M
import Text.Printf

type JField = String

type JObject = M.HashMap JField Json

type JArray = V.Vector Json

data Json = JsonObject !JObject
          | JsonArray !JArray
          | JsonString !String
          | JsonNumber !Double
          | JsonBool !Bool
          | JsonNull
          deriving (Eq, Typeable)

instance Show Json where
  show (JsonObject fields)  = ('{' : (L.concat $ L.intersperse "," $ fmap (\(key, value) -> (show key) ++ (':' : (show value))) $ M.toList fields)) ++ "}"
  show (JsonArray entries)  = ('[' : (L.concat $ L.intersperse "," $ fmap show $ toList entries)) ++ "]"
  show (JsonString string)  = '"' : (L.foldr escapeAndPrependChar "\"" string)
  show (JsonNumber number)  = show number
  show (JsonBool bool)      = if bool then "true" else "false"
  show JsonNull             = "null"

escapeAndPrependChar :: Char -> String -> String
escapeAndPrependChar '\r' string  = '\\' : 'r' : string
escapeAndPrependChar '\n' string  = '\\' : 'n' : string
escapeAndPrependChar '\t' string  = '\\' : 't' : string
escapeAndPrependChar '\b' string  = '\\' : 'b' : string
escapeAndPrependChar '\f' string  = '\\' : 'f' : string
escapeAndPrependChar '\\' string  = '\\' : '\\' : string
escapeAndPrependChar '/' string   = '\\' : '/' : string
escapeAndPrependChar '"' string   = '\\' : '"' : string
escapeAndPrependChar char string
    | requiresEscaping  = (printf "\\u04%x" $ fromEnum char) ++ string
    | otherwise         = char : string
  where
    requiresEscaping    = char < '\x20'

collectStringParts ('\\' : 'r' : remainder) workingString   = collectStringParts remainder ('\r' : workingString)
collectStringParts ('\\' : 'n' : remainder) workingString   = collectStringParts remainder ('\n' : workingString)
collectStringParts ('\\' : 't' : remainder) workingString   = collectStringParts remainder ('\t' : workingString)
collectStringParts ('\\' : 'b' : remainder) workingString   = collectStringParts remainder ('\b' : workingString)
collectStringParts ('\\' : 'f' : remainder) workingString   = collectStringParts remainder ('\f' : workingString)
collectStringParts ('\\' : '\\' : remainder) workingString  = collectStringParts remainder ('\\' : workingString)
collectStringParts ('\\' : '/' : remainder) workingString   = collectStringParts remainder ('/' : workingString)
collectStringParts ('\\' : '"' : remainder) workingString   = collectStringParts remainder ('"' : workingString)

foldJson :: a -> (Bool -> a) -> (Double -> a) -> (String -> a) -> (JArray -> a) -> (JObject -> a) -> Json -> a
foldJson _ _ _ _ _ jsonObject (JsonObject value)  = jsonObject value
foldJson _ _ _ _ jsonArray _ (JsonArray value)    = jsonArray value
foldJson _ _ _ jsonString _ _ (JsonString value)  = jsonString value
foldJson _ _ jsonNumber _ _ _ (JsonNumber value)  = jsonNumber value
foldJson _ jsonBool _ _ _ _ (JsonBool value)      = jsonBool value
foldJson jsonNull _ _ _ _ _ (JsonNull)            = jsonNull

isNull :: Json -> Bool
isNull JsonNull = True
isNull _ = False

isTrue :: Json -> Bool
isTrue (JsonBool True) = True
isTrue _ = False

isFalse :: Json -> Bool
isFalse (JsonBool False) = True
isFalse _ = False

isNumber :: Json -> Bool
isNumber (JsonNumber _) = True
isNumber _ = False

isString :: Json -> Bool
isString (JsonString _) = True
isString _ = False

isArray :: Json -> Bool
isArray (JsonArray _) = True
isArray _ = False

isObject :: Json -> Bool
isObject (JsonObject _) = True
isObject _ = False

toBool :: Json -> Maybe Bool
toBool (JsonBool bool) = Just bool
toBool _ = Nothing

fromBool :: Bool -> Json
fromBool = JsonBool

toText :: Json -> Maybe Text
toText (JsonString text) = Just (pack text)
toText _ = Nothing

fromText :: Text -> Json
fromText text = JsonString (unpack text)

toString :: Json -> Maybe String
toString (JsonString text) = Just text
toString _ = Nothing

fromString :: String -> Json
fromString string = JsonString string

toDouble :: Json -> Maybe Double
toDouble (JsonNumber double) = Just double
toDouble _ = Nothing

fromDouble :: Double -> Maybe Json
fromDouble double | isNaN double      = Nothing
                  | isInfinite double = Nothing
                  | otherwise         = Just (JsonNumber double)

toArray :: Json -> Maybe JArray
toArray (JsonArray array) = Just array
toArray _ = Nothing

fromArray :: JArray -> Json
fromArray = JsonArray

toObject :: Json -> Maybe JObject
toObject (JsonObject object) = Just object
toObject _ = Nothing

fromObject :: JObject -> Json
fromObject = JsonObject

toUnit :: Json -> Maybe ()
toUnit JsonNull = Just ()
toUnit _ = Nothing

fromUnit :: () -> Json
fromUnit _ = JsonNull

boolL :: Prism' Json Bool
boolL = prism' fromBool toBool

numberL :: Lens Json (Maybe Json) (Maybe Double) Double
numberL = lens toDouble (const fromDouble)

arrayL :: Prism' Json JArray
arrayL = prism' fromArray toArray

objectL :: Prism' Json JObject
objectL = prism' fromObject toObject

stringL :: Prism' Json Text
stringL = prism' fromText toText

nullL :: Prism' Json ()
nullL = prism' fromUnit toUnit

fromDoubleToNumberOrNull :: Double -> Json
fromDoubleToNumberOrNull = fromMaybe JsonNull . fromDouble

fromDoubleToNumberOrString :: Double -> Json
fromDoubleToNumberOrString double = fromMaybe (fromString $ show double) (fromDouble double)

jsonTrue :: Json
jsonTrue = JsonBool True

jsonFalse :: Json
jsonFalse = JsonBool False

jsonZero :: Json
jsonZero = JsonNumber 0

jsonNull :: Json
jsonNull = JsonNull

emptyString :: Json
emptyString = JsonString ""

emptyArray :: Json
emptyArray = JsonArray V.empty

singleItemArray :: Json -> Json
singleItemArray = JsonArray . V.singleton

emptyObject :: Json
emptyObject = JsonObject (M.empty)

singleItemObject :: JField -> Json -> Json
singleItemObject field json = JsonObject (M.singleton field json)

objectFromFoldable :: Foldable f => f (JField, Json) -> Json
objectFromFoldable = JsonObject . foldMap (uncurry M.singleton)

arrayFromFoldable :: Foldable f => f Json -> Json
arrayFromFoldable = JsonArray . foldMap V.singleton
