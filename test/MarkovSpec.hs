{-# LANGUAGE OverloadedStrings #-}

module MarkovSpec (spec) where

import MyLib (runMarkov)
import Test.Hspec

spec :: Spec
spec = describe "Markov rewriter" $ do
  it "applies one URI rule" $ do
    runMarkov [("v1", "BB")] "/api/v1/users/123"
      `shouldBe` "/api/BB/users/123"

  it "returns input unchanged when no rule matches" $ do
    runMarkov [("v2", "BB")] "/api/v1/users/123"
      `shouldBe` "/api/v1/users/123"

  it "restarts from the first rule after a successful rewrite" $ do
    runMarkov [("ab", "ba"), ("ba", "X")] "ab"
      `shouldBe` "X"
