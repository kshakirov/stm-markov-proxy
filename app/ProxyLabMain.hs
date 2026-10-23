module Main where


import Proxy.Transport.TcpInput(openResource,tcpRead)

iter :: (s -> IO (Either r s)) -> s -> IO r
iter step state = do
  result <- step state
  case result of
    Right r -> iter step r
    Left err -> pure err
    


main :: IO ()
main = putStrLn "Hello, world!"
