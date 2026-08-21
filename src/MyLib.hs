{-# LANGUAGE OverloadedStrings #-}

module MyLib (runMarkov) where

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

data ParserState = ParserState
  { currentState :: ParserStatus,
    currentIndex :: Int,
    parsed :: [Int]
  }
  deriving (Show, Eq)

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
      state {currentState = HeaderValue, parsed = currentIndex state + 1 : (currentIndex state  : parsed state), currentIndex = currentIndex state + 1}

runWirthStep state 0x0D
  | currentState state == HeaderName  =
      state {currentState =Success, currentIndex = currentIndex state + 1}

runWirthStep state w8
  | currentState state == HeaderName  =
      state {currentState =HeaderName, currentIndex = currentIndex state + 1}




runWirthStep state 0x0A
  | currentState state == ExpectCLRF =
      state {currentState = HeaderName , currentIndex = currentIndex state + 1, parsed = currentIndex state + 1 : parsed state}


runWirthStep state 0x0D
  | currentState state == Version =
      state {currentState = ExpectCLRF,  parsed = currentIndex state  : parsed state, currentIndex = currentIndex state + 1}

runWirthStep state w8
  | currentState state == Version =
      state {currentState = Version,  currentIndex = currentIndex state + 1}


runWirthStep state 0x20
  | currentState state == URI =
      state {currentState = Version,  parsed = currentIndex state + 1 : (currentIndex state  : parsed state), currentIndex = currentIndex state + 1}

runWirthStep state w8
  | currentState state == URI  =
      state {currentState = URI, currentIndex = currentIndex state + 1}


runWirthStep state 0x20
  | currentState state == Method && currentIndex state < 8 =
      ParserState {currentState = URI,  parsed =currentIndex  state + 1 : ( currentIndex state   : parsed state), currentIndex = currentIndex state + 1}
runWirthStep state w8
  | currentState state == Method && currentIndex state > 8 =
      state {currentState = Error, currentIndex = currentIndex state, parsed = parsed state}
runWirthStep state w8
  | currentState state == Method && currentIndex state < 8 =
      state {currentState = Method, currentIndex = currentIndex state + 1}

runWirthStep s _ = s



extractURI ::  B.ByteString  -> ParserState -> Maybe B.ByteString
extractURI s parserState = case (currentState parserState) of
  HeaderName -> 
    let rIndexList = reverse (parsed  parserState)
    in Just (B.drop (rIndexList !! 1)  (B.take (rIndexList !! 2) s))
  Error  -> Nothing
  _ -> Nothing



extractAll:: B.ByteString -> ParserState -> Maybe [Int]
extractAll s parserState = case (currentState parserState) of
  Success ->
    let rIndexList = reverse (parsed parserState)
    in Just rIndexList
  _ -> Nothing

testExtractURI =
  let s =  ParserState{currentState = Method, currentIndex =0, parsed =[0]} 
      --bs = "GET /api/v1/users/123/orders?format=json HTTP/1.1\r\n"
      bs = "GET /api/v1/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"
      ps = runWirth s bs
      in extractURI bs ps 

testExtractAll =
    let s =  ParserState{currentState = Method, currentIndex =0, parsed =[0]} 
        --bs = "GET /api/v1/users/123/orders?format=json HTTP/1.1\r\n"
        bs = "GET /api/v1/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"
        ps = runWirth s bs
    in extractAll bs ps 
