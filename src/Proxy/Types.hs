module Proxy.Types where

import qualified Data.ByteString as B 
import Data.Word

data ParserStatus
  = Method
  |URI
  |Version
  |Error
  |Success
  |Finish
  |ExpectCLRF
  |HeaderName
  |HeaderValue
  |ExpectFinalCLRF
  deriving (Show, Eq)


data RewriteType
  = RewriteMethod
  |RewriteUrl
  |RewriteHeader

data HttpMethod =PUT
  |GET
  |POST
  |PATCH
  |HEAD
  |DELETE
  |PSTAR
  deriving (Show, Eq)

data MethodData = MethodData
  {  guess ::  HttpMethod,
     matchingIndex :: Int
  }
  deriving (Show, Eq)

data UriData = UriData
  {buffer :: B.ByteString,
   maxLength :: Int}

data RecognizingData = RecognizingData
  {method:: MethodData,
   uriData :: UriData,
   httpVersion :: Int}
   

data ParserState = ParserState
  { currentState :: ParserStatus,
    currentIndex :: Int,
    parsed :: [Int]
  }
  deriving (Show, Eq)

data RuleType = Normal | Terminal 
  deriving (Show, Eq)

data MarkovRule = MarkovRule
  { pattern     :: B.ByteString
  , replacement :: B.ByteString
  , ruleType    :: RuleType
  } deriving (Show, Eq)

-- 3. Система НАМ — это упорядоченный список правил
type MarkovSystem = [MarkovRule]




data RequestStreamAutomatonStatus =
  RSA_Finished
  |RSA_NeedsMoreData
  |RSA_Error
  deriving (Show,Eq)

