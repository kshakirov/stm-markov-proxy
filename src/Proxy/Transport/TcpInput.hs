module Proxy.Transport.TcpInput
  ( openTcpListener
  , acceptTcpConnection
  ) where

import Control.Exception (onException)
import Network.Socket (Socket)
import qualified Network.Socket as S

openTcpListener :: String -> Int -> IO Socket
openTcpListener hostName portNumber = do
  let hints =
        S.defaultHints
          { S.addrFlags = [S.AI_PASSIVE]
          , S.addrSocketType = S.Stream
          }
  address <- head <$> S.getAddrInfo (Just hints) (Just hostName) (Just (show portNumber))
  listener <- S.socket (S.addrFamily address) (S.addrSocketType address) (S.addrProtocol address)
  let openListener = do
        S.setSocketOption listener S.ReuseAddr 1
        S.bind listener (S.addrAddress address)
        S.listen listener 1024
        pure listener
  openListener `onException` S.close listener

acceptTcpConnection :: Socket -> IO Socket
acceptTcpConnection listener = fst <$> S.accept listener
