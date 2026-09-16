module Main (main) where

import qualified MarkovSpec
import qualified RequestRewriteSpec
import Test.Hspec (hspec)
import qualified WirthSpec

main :: IO ()
main = hspec $ do
  MarkovSpec.spec
  WirthSpec.spec
  RequestRewriteSpec.spec
