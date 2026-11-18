module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead,closeClientResource, closeListeningResource, acceptTcpConnection, openResourceOnly, acceptForeachAndIter,TcpState(..), openResourceExtra,tcpWrite,closeAccetpResource)
import Proxy.Transport.UnixSocketOutput (connectUnixSocket, unixSocekWrite, unixSocketRead, closeUnixSocket)
import Proxy.Transport.NamedPipeOutput(namedPipeWrite)
import Control.Monad
import Control.Exception
import Control.Concurrent
import Control.Concurrent.Async
import Network.Socket (Socket)
import GHC.Conc (atomically, readTVar, readTVarIO, writeTVar)
import qualified Network.Socket as S

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


useResource ::  (s -> IO (Either l s)) ->(s -> IO (Either l s))  ->s -> IO ()
useResource step1 step2 state  = do
    withAsync (void (iter step1 state)) $ \task -> do
      link task
      void (iter step2 state)
  

forkWrapper ::s ->  (s -> IO s ) -> (s -> IO (Either l s)) ->(s -> IO (Either l s))-> (s -> IO()) -> IO (Either  l s)
forkWrapper state stateTrans step1 step2  close = do

  forkIO $ do
   bracket (stateTrans state ) close (useResource step1 step2)
  return (Right state)



connectUnixBackend:: TcpState -> IO TcpState
connectUnixBackend s = do
  sock <- connectUnixSocket  "/tmp/.jbc_socket"

  return s {unixSocket = sock}

tcpSockFromState :: TcpState -> IO Socket 
tcpSockFromState s =  return (socket s )

forkWrapper2 ::TcpState ->  (TcpState -> IO (Either l TcpState)) ->(TcpState -> IO (Either l TcpState))-> (TcpState -> IO()) -> (TcpState -> IO()) -> IO (Either  l TcpState)
forkWrapper2 state  step1 step2  close1 close2 = do
  limitReached  <-  atomically  $ do
    counter <- readTVar (connectionCounter state)
    case counter >= (connectionLimit state) of
      True -> pure True
      False -> do
        writeTVar (connectionCounter state) (counter + 1)
        pure False
    
  case limitReached  of 
    True -> S.close (socket state)
    False ->  void (forkIO $ do
              bracket (return state) close1 (\tcp -> bracket (connectUnixBackend state  ) close2 (useResource step1 step2)))
  return (Right state)

 
  

main :: IO ()
main = do
  -- bracket   (openResource "" 9000) closeResource (iter (compose tcpRead  namedPipeWrite ))
        
  state <- openResourceOnly "" 9000 
  iter  ( compose acceptForeachAndIter (\s -> forkWrapper2 s (compose tcpRead  unixSocekWrite) (compose unixSocketRead tcpWrite) closeAccetpResource closeUnixSocket)) state 
  closeListeningResource state 

  putStrLn "Hello, world!"
