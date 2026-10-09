{-# LANGUAGE OverloadedStrings #-}
module Proxy.Rewrite where

import qualified Data.ByteString as B 
import Data.Word
import Proxy.Types
import Proxy.Markov
import Proxy.Wirth


extractURI ::   ParserState -> Maybe B.ByteString
extractURI  parserState = case currentState parserState of
  Success -> 
    Just  (buffer (uriData (recognizingData parserState)))
  Error  -> Nothing
  _ -> Nothing



-- extractAll:: B.ByteString -> ParserState -> Maybe [Int]
-- extractAll s parserState = case (currentState parserState) of
--   Success ->
--     let rIndexList = reverse (parsed parserState)
--     in Just rIndexList
--   _ -> Nothing


requestStreamAutomaton :: B.ByteString -> B.ByteString -> ParserState->  (RequestStreamAutomatonStatus , ParserState, B.ByteString)
requestStreamAutomaton body fragment  ws_in =
    let  n_body = B.concat [body, fragment] 
         ws_out =  runWirth ws_in  fragment
         in
      case (currentState ws_out) of
        Success -> (RSA_Finished, ws_out,n_body)
        Error -> (RSA_Error,ws_out, n_body)
        _-> (RSA_NeedsMoreData, ws_out,n_body)
      
      
    
requestRewrite :: RewriteType ->    ParserState -> [(B.ByteString, B.ByteString)] -> B.ByteString
requestRewrite RewriteUrl  parserState rules =
  let ms = extractURI parserState in 
    case ms of
      Just uri -> runMarkov rules uri
      Nothing -> "no uri"

requestRewrite RewriteMethod  pareserState rules = 
  case   guess (method (recognizingData pareserState)) of
  GET -> "GET"
  POST -> "POST"
  PUT -> "PUT"
  _ -> ""


requestRewrite RewriteHeader  pareserState rules =
  " Via: 1.1 stm-markov-proxy\r\n\r\n"


