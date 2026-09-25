module Proxy.Wirth where

import qualified Data.ByteString as B 
import Data.Word
import Proxy.Types
import Proxy.Markov



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
      let r = recognizeMethod w8 (method (recognizingData state)) in
        case r of
          Right m  ->       state {currentState = Method, currentIndex = currentIndex state + 1, recognizingData = (recognizingData state){method=m}}
          Left e -> state {currentState = e}

runWirthStep s _ = s


recognizeMethod :: Word8 -> MethodData -> Either ParserStatus  MethodData
recognizeMethod w md =
  case matchingIndex md of
    0 -> case w of
      0x50 ->Right MethodData{guess=PSTAR, matchingIndex=1}
      0x47 -> Right MethodData{guess=GET, matchingIndex=1}
      _ -> Left Error 
    1 -> case w of
      0x55 | guess md == PSTAR -> Right MethodData{guess=PUT, matchingIndex=2} 
      0x4f  | guess md == PSTAR -> Right MethodData{guess=POST, matchingIndex=2}
      0x41 | guess md == PSTAR -> Right MethodData{guess=PATCH, matchingIndex=2} 
      0x45 | guess md == GET -> Right MethodData{guess=GET, matchingIndex=2}
      _ -> Left Error
    2 -> case w of
      0x54 | guess md == PUT -> Right MethodData{guess=PUT, matchingIndex=3} 
      0x53 | guess md == POST -> Right MethodData{guess=POST, matchingIndex=3}
      0x41
          | guess md == PATCH -> Right MethodData{guess=PATCH, matchingIndex=3}
          | guess md == GET -> Right MethodData{guess=GET, matchingIndex=3}
      _ -> Left Error
    3 -> case w of
      0x20 | guess md == PUT -> Right MethodData{guess=PUT, matchingIndex=4}
              | guess md == GET -> Right MethodData{guess=GET, matchingIndex=4}
      0x41 | guess md == POST -> Right MethodData{guess=POST, matchingIndex=4}
      0x43 | guess md == PATCH -> Right MethodData{guess=PATCH, matchingIndex=3}
      _ -> Left Error
    4 -> case w of
      0x20 | guess md == POST -> Right MethodData{guess=POST, matchingIndex=5}
      _ -> Left Error
      -- don't care about Patch and others for the time being 
    _ -> Left Error
      
