module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead,closeClientResource, closeListeningResource, acceptTcpConnection, openResourceOnly, acceptForeachAndIter,TcpState)
import Proxy.Transport.NamedPipeOutput(namedPipeWrite)
import Control.Monad
import Control.Exception
import Control.Concurrent

compose f g state = do
  result <- f state
  case result of
    Left done   -> pure (Left done)
    Right next  -> g next


iter :: (s -> IO (Either l s)) -> s -> IO l
iter step state = do
  result <- step state
  case result of
    Right r -> iter step r 
    Left l -> pure  l



forkWrapper :: s -> (s -> IO (Either l s))-> (s -> IO()) -> IO (Either  l s)
forkWrapper state step  close = do
  forkIO $ do
    void (iter step state)
    close state
  return (Right state)
  





  
  

main :: IO ()
main = do
  -- bracket   (openResource "" 9000) closeResource (iter (compose tcpRead  namedPipeWrite ))
  
  state <- openResourceOnly "" 9000
  iter  ( compose acceptForeachAndIter (\s -> forkWrapper s (compose tcpRead  namedPipeWrite ) closeClientResource)) state
  closeListeningResource state 

  putStrLn "Hello, world!"
