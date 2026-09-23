{-# LANGUAGE OverloadedStrings #-}
module Proxy.Rewrite where

import qualified Data.ByteString as B 
import Data.Word
import Proxy.Types
import Proxy.Markov
import Proxy.Wirth


extractURI ::  B.ByteString  -> ParserState -> Maybe B.ByteString
extractURI s parserState = case (currentState parserState) of
  Success -> 
    let rIndexList = reverse (parsed  parserState)
    in Just (B.drop ((rIndexList !! 1) + 1)  (B.take (rIndexList !! 3) s))
  Error  -> Nothing
  _ -> Nothing



extractAll:: B.ByteString -> ParserState -> Maybe [Int]
extractAll s parserState = case (currentState parserState) of
  Success ->
    let rIndexList = reverse (parsed parserState)
    in Just rIndexList
  _ -> Nothing


requestStreamAutomaton :: B.ByteString -> B.ByteString -> ParserState->  (RequestStreamAutomatonStatus , ParserState, B.ByteString)
requestStreamAutomaton body fragment  ws_in =
    let  n_body = B.concat [body, fragment] 
         ws_out =  runWirth ws_in  fragment
         in
      case (currentState ws_out) of
        Success -> (RSA_Finished, ws_out,n_body)
        Error -> (RSA_Error,ws_out, n_body)
        _-> (RSA_NeedsMoreData, ws_out,n_body)
      
      
    
requestRewrite :: RewriteType ->   B.ByteString -> ParserState -> [(B.ByteString, B.ByteString)] -> B.ByteString
requestRewrite RewriteUrl s parserState rules =
  let ms = extractURI s parserState in 
    case ms of
      Just uri -> runMarkov rules uri
      Nothing -> "no uri"

requestRewrite RewriteMethod s pareserState rules = 
  let rIndexList = reverse (parsed  pareserState)
  in B.take (rIndexList !! 1) s


requestRewrite RewriteHeader s pareserState rules =
  let rIndexList = reverse (parsed  pareserState)
  in B.drop (rIndexList !! 3)   s

testRequestRewrite =
  let state =  ParserState{currentState = Method, currentIndex =0, parsed =[0]} 
      req = "GET /api/v2/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\nn\r\n"
      newState = runWirth state req
      rules  = [("v2","BB")]
  in requestRewrite RewriteUrl

 req newState rules 

