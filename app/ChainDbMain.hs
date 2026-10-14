{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Proxy.Transport.UnixSocketOutput(connectUnixSocket, sendUnixChunk)
import Proxy.Transport.TcpInput(openTcpListener, acceptTcpConnection)
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
main::IO ()


handleConnection :: Socket -> Socket -> IO ()
handleConnection tcp_conn  unix_conn= do
  req <- recv tcp_conn 1024
  sendUnixChunk unix_conn req
  putStrLn "finished"


main = do
  sock <- openTcpListener "127.0.0.1" 9300
  tcp_conn <-acceptTcpConnection sock
  f_sock <- connectUnixSocket "/tmp/chaindb-proxy-test.sock"
  handleConnection tcp_conn f_sock
  putStrLn ""






