{-# LANGUAGE OverloadedStrings #-}
module Proxy.Transport.TcpInput
  ( openTcpListener
  , acceptTcpConnection
  ,tcpInput,
   openResource,
   tcpRead,
   tcpWrite,
   TcpState(..),
   closeClientResource,
   closeListeningResource,
   openResourceOnly,
   openResourceExtra,
   acceptForeachAndIter
  ) where

import Control.Exception (onException)
import Network.Socket (Socket)
import qualified Network.Socket as S
import Network.Socket.ByteString (recv,sendAll)
import qualified Data.ByteString as B

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

data TcpState = TcpState{
  socket :: Socket,
  listeningSocket :: Socket,
  unixSocket::Socket,
  payload :: B.ByteString
  }


openResourceOnly::String -> Int -> IO TcpState
openResourceOnly hostName port = do
  sock <- openTcpListener  hostName port
  return TcpState{socket = undefined, payload="", listeningSocket=sock}

openResourceExtra::String -> Int ->(FilePath -> IO Socket)-> FilePath ->  IO TcpState
openResourceExtra hostName port openAnotherSocekt  filePath= do
  sock <- openTcpListener  hostName port 
  anotherSock <- openAnotherSocekt filePath
  return TcpState{socket = undefined, payload="", listeningSocket=sock, unixSocket = anotherSock}




openResource::String -> Int -> IO TcpState
openResource hostName port = do
  sock <- openTcpListener  hostName port
  conn <-acceptTcpConnection sock
  return TcpState{socket = conn, payload="", listeningSocket=sock}

tcpInput :: String -> Int -> IO B.ByteString
tcpInput hostName port   = do 
  sock <- openTcpListener  hostName port
  conn <- acceptTcpConnection sock
  recv conn 1024


tcpWrite :: TcpState -> IO (Either B.ByteString TcpState)
tcpWrite state = do
   sendAll (socket state) (payload state)
   return ( Right state)
   



tcpRead :: TcpState -> IO (Either B.ByteString TcpState)
tcpRead state = do
  chunk <- recv (socket state) 1023
  if (B.length chunk)  > 0 
    then return ( Right state {payload=chunk})
    else return (Left "all read")

closeClientResource::TcpState -> IO ()
closeClientResource state =do
  S.close (socket state)


closeListeningResource::TcpState -> IO ()
closeListeningResource state =do
  S.close (listeningSocket state)




acceptTcpConnection :: Socket -> IO Socket
acceptTcpConnection listener = fst <$> S.accept listener


acceptForeachAndIter  :: TcpState -> IO (Either B.ByteString TcpState)
acceptForeachAndIter tcpState = do
     conn <- acceptTcpConnection (listeningSocket tcpState)
     return ( Right tcpState {socket=conn})
