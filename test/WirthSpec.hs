module WirthSpec (spec) where

import Test.Hspec

spec :: Spec
spec = describe "Wirth streaming parser" $ do
  it "preserves absolute URI offsets across input chunks" $
    pendingWith "Expose a small public feed function or test through the request automaton"

  it "recognizes CRLF CRLF across every chunk boundary" $
    pendingWith "Add a table-driven split-boundary test"

  it "returns an error for malformed request lines" $
    pendingWith "Define the supported malformed-input policy"
