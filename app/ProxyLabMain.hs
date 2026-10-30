module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead,closeClientResource, closeListeningResource, acceptTcpConnection, openResourceOnly, acceptForeachAndIter,TcpState(..), openResourceExtra,tcpWrite)
import Proxy.Transport.UnixSocketOutput (connectUnixSocket, unixSocekWrite, unixSocketRead)
import Proxy.Transport.NamedPipeOutput(namedPipeWrite)
import Control.Monad
import Control.Exception
import Control.Concurrent
import Control.Concurrent.Async

compose f g state = do
  result <- f state
  case result of
    Left done   -> pure (Left done)
    Right next  -> g next


iter :: (s -> IO (Either l s)) -> s -> IO l
iter step state = do
  result <- step   state
  case result of
    Right r -> iter step r 
    Left l -> pure  l



forkWrapper ::s ->  (s -> IO s ) -> (s -> IO (Either l s)) ->(s -> IO (Either l s))-> (s -> IO()) -> IO (Either  l s)
forkWrapper state stateTrans step1 step2  close = do

  forkIO $ do
    new_state <-  stateTrans state
    void (iter step1 new_state)
    close new_state
    void (iter step2 new_state)
  return (Right state)
  

stateTrans:: TcpState -> IO TcpState
stateTrans s = do
  sock <- connectUnixSocket ""
  return s {unixSocket = sock}


  
  

main :: IO ()
main = do
  -- bracket   (openResource "" 9000) closeResource (iter (compose tcpRead  namedPipeWrite ))
        
  state <- openResourceOnly "" 9000 
  iter  ( compose acceptForeachAndIter (\s -> forkWrapper s stateTrans (compose tcpRead  unixSocekWrite) (compose unixSocketRead tcpWrite)closeClientResource)) state
  closeListeningResource state 

  putStrLn "Hello, world!"
