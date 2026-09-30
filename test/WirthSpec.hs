{-# LANGUAGE OverloadedStrings #-}

module WirthSpec (spec) where

import Test.Hspec
import Proxy.Wirth
import Proxy.Types
import qualified Data.ByteString as B
request :: B.ByteString
request =
  "GET /api/v1/users/123 HTTP/1.1\r\nHost: example.com\r\nAccept: application/json\r\n\r\n"


spec :: Spec
spec = describe "Wirth streaming parser" $ do
  it "gets the method while streaing right" $do
    let state = runWirth ParserState{currentState=Method, currentIndex=0,parsed=[], recognizingData=RecognizingData{method=MethodData {guess=PSTAR, matchingIndex=0}, uriData=UriData{buffer= "", maxLength=1024},httpVersion=0}} request 
    guess (method (recognizingData state))
         `shouldBe` GET

  it "recognizes CRLF CRLF across every chunk boundary" $
    pendingWith "Add a table-driven split-boundary test"

  it "returns an error for malformed request lines" $
    pendingWith "Define the supported malformed-input policy"
