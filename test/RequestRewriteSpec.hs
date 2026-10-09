{-# LANGUAGE OverloadedStrings #-}

module RequestRewriteSpec (spec) where

import qualified Data.ByteString as B
import Proxy
import Test.Hspec

request :: B.ByteString
request =
  "GET /api/v1/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"

-- Coordinates recorded by the current Wirth parser for the request line.
-- The parser stores them in reverse discovery order.
uriState::UriData
uriState = UriData{buffer="/api/v1/users/123",bufferLength=17,maxLength=2048}
recognizingState:: RecognizingData
recognizingState = RecognizingData{uriData=uriState, method = MethodData{guess=GET, matchingIndex=3}}
finishedState :: ParserState
finishedState =
  ParserState
    { currentState = Success,
      currentIndex = B.length request - 1,
      parsed = [22, 21, 4, 3, 0],
      recognizingData = recognizingState }
    

rules :: [(B.ByteString, B.ByteString)]
rules = [("v1", "BB")]

spec :: Spec
spec = describe "Request URI reconstruction" $ do
  it "reconstructs the complete request around a rewritten URI" $ do
    let prefix = requestRewrite RewriteMethod  finishedState rules
        newUri = requestRewrite RewriteUrl finishedState rules
        suffix = requestRewrite RewriteHeader  finishedState rules
    B.concat [prefix, " ", newUri, suffix]
      `shouldBe`
        "GET /api/BB/users/123 Via: 1.1 stm-markov-proxy\r\n\r\n"

  it "returns the URI without its separating spaces" $ do
    requestRewrite RewriteUrl  finishedState rules
      `shouldBe` "/api/BB/users/123"
