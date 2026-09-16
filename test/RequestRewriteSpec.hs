{-# LANGUAGE OverloadedStrings #-}

module RequestRewriteSpec (spec) where

import qualified Data.ByteString as B
import MyLib
import Test.Hspec

request :: B.ByteString
request =
  "GET /api/v1/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"

-- Coordinates recorded by the current Wirth parser for the request line.
-- The parser stores them in reverse discovery order.
finishedState :: ParserState
finishedState =
  ParserState
    { currentState = Success,
      currentIndex = B.length request - 1,
      parsed = [22, 21, 4, 3, 0]
    }

rules :: [(B.ByteString, B.ByteString)]
rules = [("v1", "BB")]

spec :: Spec
spec = describe "Request URI reconstruction" $ do
  it "reconstructs the complete request around a rewritten URI" $ do
    let prefix = requestRewrite RewriteMethod request finishedState rules
        newUri = requestRewrite RewriteUrl request finishedState rules
        suffix = requestRewrite RewriteHeader request finishedState rules
    B.concat [prefix, newUri, suffix]
      `shouldBe`
        "GET /api/BB/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"

  it "returns the URI without its separating spaces" $ do
    requestRewrite RewriteUrl request finishedState rules
      `shouldBe` "/api/BB/users/123"
