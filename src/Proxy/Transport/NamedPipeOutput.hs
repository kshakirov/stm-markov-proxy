module Proxy.Transport.NamedPipeOutput
  ( namedPipeOutput,
    namedPipeWrite
  ) where

import qualified Data.ByteString as B
import Proxy.Transport.TcpInput (TcpState(..))

namedPipeOutput :: FilePath -> B.ByteString -> IO ()
namedPipeOutput = B.writeFile


namedPipeWrite :: TcpState -> IO (Either B.ByteString TcpState)
namedPipeWrite state =do 
  B.writeFile  "" (payload state)
  return (Right  state)
