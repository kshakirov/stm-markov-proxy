module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead)
import Proxy.Transport.NamedPipeOutput(namedPipeWrite)
import Control.Monad


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
  state <- openResource "" 9000
  iter (compose tcpRead  namedPipeWrite ) state 
  putStrLn "Hello, world!"
