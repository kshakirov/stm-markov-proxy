{-# LANGUAGE OverloadedStrings #-}

module MyLib (runMarkov) where

import qualified Data.ByteString as B 
import Data.Word

data ParserStatus
  = Method
  | URI
  | Version
  | Error
  |Success
  | Finish
  |ExpectCLRF
  |HeaderName
  |HeaderValue
  |ExpectFinalCLRF
  deriving (Show, Eq)

data ParserState = ParserState
  { currentState :: ParserStatus,
    currentIndex :: Int,
    parsed :: [Int]
  }
  deriving (Show, Eq)

someFunc :: IO ()
someFunc = putStrLn "someFunc"

runMarkovStep :: B.ByteString -> B.ByteString -> B.ByteString -> (B.ByteString, Bool)
runMarkovStep s t r =
  let (before, after) = B.breakSubstring t s
      result = if (B.null after) then (before, False) else (B.concat [before, r, B.drop (B.length t) after], True)
   in result

runMarkov :: [(B.ByteString, B.ByteString)] -> B.ByteString -> B.ByteString
runMarkov allRules s = go allRules s
  where
    go [] ss = ss
    go (r : rs) ss =
      let transformed = uncurry (runMarkovStep ss) r
       in case transformed of
            (ts, True) -> runMarkov allRules ts
            (ts, False) -> go rs ts

runWirth :: ParserState -> B.ByteString -> ParserState
runWirth s b = case currentState s of
  Success -> s
  Error -> s
  _  ->  case B.uncons b of
    Nothing -> s
    Just (w8, rest) ->
      let nextState = runWirthStep s w8
      in runWirth nextState rest

runWirthStep :: ParserState -> Word8 -> ParserState


runWirthStep state 0x0A
  | currentState state == ExpectFinalCLRF =
      state {currentState =Success  , currentIndex = currentIndex state , parsed =  parsed state}


runWirthStep state 0x0D
  | currentState state == HeaderName =
      state {currentState = ExpectFinalCLRF, currentIndex = currentIndex state + 1, parsed = currentIndex state + 1 : parsed state}


runWirthStep state 0x0D 
  | currentState state == HeaderValue =
      state {currentState = ExpectCLRF, currentIndex = currentIndex state + 1, parsed = currentIndex state  : parsed state}

runWirthStep state w8
  | currentState state == HeaderValue  =
      state {currentState =HeaderValue, currentIndex = currentIndex state + 1}



runWirthStep state 0x3A
  | currentState state == HeaderName =
      state {currentState = HeaderValue, currentIndex = currentIndex state + 1, parsed = currentIndex state + 1 : parsed state}

runWirthStep state w8
  | currentState state == HeaderName  =
      state {currentState =HeaderName, currentIndex = currentIndex state + 1}


runWirthStep state 0x0A
  | currentState state == ExpectCLRF =
      state {currentState = HeaderName , currentIndex = currentIndex state + 1, parsed = currentIndex state + 1 : parsed state}


runWirthStep state 0x0D
  | currentState state == Version =
      state {currentState = ExpectCLRF, currentIndex = currentIndex state + 1, parsed = currentIndex state  : parsed state}


runWirthStep state 0x20
  | currentState state == URI =
      state {currentState = Version, currentIndex = currentIndex state + 1, parsed = currentIndex state + 1 : parsed state}

runWirthStep state w8
  | currentState state == URI  =
      state {currentState = URI, currentIndex = currentIndex state + 1}


runWirthStep state 0x20
  | currentState state == Method && currentIndex state < 8 =
      ParserState {currentState = URI, currentIndex = currentIndex state + 1, parsed = currentIndex state + 1  : parsed state}
runWirthStep state w8
  | currentState state == Method && currentIndex state > 8 =
      state {currentState = Error, currentIndex = currentIndex state, parsed = parsed state}
runWirthStep state w8
  | currentState state == Method && currentIndex state < 8 =
      state {currentState = Method, currentIndex = currentIndex state + 1}

runWirthStep s _ = s
