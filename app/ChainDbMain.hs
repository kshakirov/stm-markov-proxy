{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Proxy.Transport.UnixSocketOutput(connectUnixSocket, sendUnixChunk)
import Proxy.Transport.TcpInput(openTcpListener, acceptTcpConnection)
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
main::IO ()


handleConnection :: Socket -> Socket -> IO ()
handleConnection tcp_conn  file_sock= do
  req <- recv tcp_conn 1024
  sendUnixChunk file_sock req
  putStrLn ""


main = do
  sock <- openTcpListener "127.0.0.1" 9300
  conn <-acceptTcpConnection sock
  f_sock <- connectUnixSocket "" 
  putStrLn ""






