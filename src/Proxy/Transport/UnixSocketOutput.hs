module Proxy.Transport.UnixSocketOutput
  ( connectUnixSocket
  , sendUnixChunk
  ) where

import Control.Exception (onException)
import qualified Data.ByteString as B
import Network.Socket (Socket)
import qualified Network.Socket as S
import qualified Network.Socket.ByteString as SB

connectUnixSocket :: FilePath -> IO Socket
connectUnixSocket socketPath = do
  output <- S.socket S.AF_UNIX S.Stream S.defaultProtocol
  S.connect output (S.SockAddrUnix socketPath) `onException` S.close output
  pure output

sendUnixChunk :: Socket -> B.ByteString -> IO ()
sendUnixChunk = SB.sendAll
