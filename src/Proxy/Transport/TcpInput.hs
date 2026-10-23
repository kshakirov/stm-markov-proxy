{-# LANGUAGE OverloadedStrings #-}
module Proxy.Transport.TcpInput
  ( openTcpListener
  , acceptTcpConnection
  ,tcpInput,
   openResource,
   tcpRead,
   TcpState(..),
   closeResource
  ) where

import Control.Exception (onException)
import Network.Socket (Socket)
import qualified Network.Socket as S
import Network.Socket.ByteString (recv)
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
  payload :: B.ByteString
  }

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
  

tcpRead :: TcpState -> IO (Either B.ByteString TcpState)
tcpRead state = do
  chunk <- recv (socket state) 1023
  if (B.length chunk)  > 0 
    then return ( Right state {payload=chunk})
    else return (Left "all read")

closeResource::TcpState -> IO ()
closeResource state =do
  S.close (socket state)
  S.close (listeningSocket state)
  


acceptTcpConnection :: Socket -> IO Socket
acceptTcpConnection listener = fst <$> S.accept listener
