module Proxy.Transport.UnixSocketOutput
  ( connectUnixSocket
  , sendUnixChunk
  ,unixSocketOutput,

   unixSocekWrite
  ) where

import Control.Exception (onException)
import qualified Data.ByteString as B
import Network.Socket (Socket)
import qualified Network.Socket as S
import qualified Network.Socket.ByteString as SB
import Proxy.Transport.TcpInput (TcpState(..))







connectUnixSocket :: FilePath -> IO Socket
connectUnixSocket socketPath = do
  output <- S.socket S.AF_UNIX S.Stream S.defaultProtocol
  S.connect output (S.SockAddrUnix socketPath) `onException` S.close output
  pure output

sendUnixChunk :: Socket -> B.ByteString -> IO ()
sendUnixChunk = SB.sendAll


unixSocekWrite:: TcpState -> IO (Either B.ByteString TcpState)
unixSocekWrite state  = do
  SB.sendAll (unixSocket state) (payload state)
  return (Right state )
  

unixSocketOutput :: FilePath -> B.ByteString -> IO()
unixSocketOutput filePath chunk = do
  f_sock <- connectUnixSocket filePath
  sendUnixChunk f_sock chunk
