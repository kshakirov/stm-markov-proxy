module Proxy.Transport.NamedPipeOutput
  ( namedPipeOutput
  ) where

import qualified Data.ByteString as B

namedPipeOutput :: FilePath -> B.ByteString -> IO ()
namedPipeOutput = B.writeFile
