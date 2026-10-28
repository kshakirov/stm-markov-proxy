module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead,closeResource)
import Proxy.Transport.NamedPipeOutput(namedPipeWrite)
import Control.Monad
import Control.Exception

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
    


main :: IO ()
main = do
  bracket   (openResource "" 9000) closeResource (iter (compose tcpRead  namedPipeWrite ))
  putStrLn "Hello, world!"
