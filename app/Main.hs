{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}


module Main where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, STM,atomically)
import Control.Monad.Reader
    ( ReaderT(runReaderT), MonadReader(ask), MonadIO(liftIO) )
import qualified Control.Monad.Trans.Reader as RT
import Network.Socket (Socket)
import qualified Network.Socket as S


import Control.Monad (forever)
import Control.Concurrent (forkIO)
import Network.Socket.ByteString (recv, sendAll)
import qualified Data.ByteString as B
import MyLib (runMarkov, requestStreamAutomaton, RequestStreamAutomatonStatus(..), ParserState(..),ParserStatus(..), requestRewrite, RewriteType(..))

data Env = Env
  { proxyConfig :: Config,
    backendConfigs :: [BackendConfig],
    proxyTVarState :: TVar ProxyState
  }

data BackendConfig = BackendConfig
  { appName :: String,
    runningPort :: Int
  }

data Config = Config
  { hostName :: String,
    port :: Int,
    backends ::Int
  }

data ProxyState = ProxyState
  { nextBackendIndex :: Int
  }


-- 1. Тип правила: обычное (Normal) или финальное (Terminal)

-- 2. Структура одного Марковского правила перезаписи строк


type ProxyM a = ReaderT Env IO a

listenAndServe :: ProxyM ()
listenAndServe = do
  --  let c = Config{hostName="proxyHost", port=8989, backends = [1,2]}

  env <- ask
  let name = (hostName . proxyConfig) env
  let port_num = (port . proxyConfig) env
  let requestBuffer = ""
  let ends =( backends  . proxyConfig)env
  let tVarState = proxyTVarState env
  let wirthParserState = ParserState{currentState = Method, currentIndex =0, parsed =[0]}
  liftIO $ putStrLn $ "The host is " ++ name ++ "port is " ++ (show port_num)
  socket <-  liftIO  $ openListeningSocket name port_num
  forever $ do 
    (conn, addr) <- liftIO $ S.accept socket
    sb <- liftIO $ atomically $ nextBackendIdxTx tVarState ends

    liftIO $ forkIO (runReaderT (handleClient conn requestBuffer wirthParserState sb ) env)

    -- здесь будет наш форк ищ 
--    forkIO $ handleClient conn 
  liftIO $ print socket 
  

--  putStrLn ""

main :: IO ()
main = do
  putStrLn "Starting stm-proxy-markov!"
  let initProxyState = ProxyState {nextBackendIndex = 0}
  refProxyTVarState <- newTVarIO initProxyState
  -- for the time bieing hardcoded TODO move to config
  let bs =[ BackendConfig{appName="127.0.0.1", runningPort=8081}]
  let c = Config {hostName = "127.0.0.1", port = 8989, backends=length bs}

  let e = Env {proxyConfig = c, backendConfigs = bs, proxyTVarState = refProxyTVarState}
  
  runReaderT listenAndServe e


-- Нам понадобятся функции readTVar и writeTVar из Control.Concurrent.STM
nextBackendIdxTx :: TVar ProxyState -> Int -> STM Int
nextBackendIdxTx stateRef totalBackends = do
  -- 1. Читаем текущее состояние из транзакционной переменной
  currentState <- readTVar stateRef
  
  -- 2. Достаем текущий индекс
  let currentIdx = nextBackendIndex currentState
  
  -- 3. Вычисляем следующий индекс по формуле Round-Robin
  -- Если бэкендов 0, то индекс всегда 0, чтобы избежать деления на ноль
  let nextIdx = if totalBackends == 0 
                then 0 
                else (currentIdx + 1) `mod` totalBackends
                
  -- 4. Записываем обновленное состояние обратно
  writeTVar stateRef (ProxyState { nextBackendIndex = nextIdx })
  
  -- 5. Возвращаем ТЕКУЩИЙ индекс, по которому прокси должен отправить запрос
  return currentIdx


openListeningSocket ::String -> Int -> IO Socket
openListeningSocket hostName portNum = do
  let hints = S.defaultHints { S.addrFlags = [S.AI_PASSIVE], S.addrSocketType = S.Stream }
  addrInfo <- head <$> S.getAddrInfo (Just hints) (Just hostName) (Just (show portNum))
  sock <- S.socket (S.AF_INET) (S.addrSocketType addrInfo) (S.addrProtocol addrInfo)
  S.setSocketOption sock S.ReuseAddr 1
  S.bind sock (S.addrAddress addrInfo)
  S.listen sock 1024
  return sock

handleClient:: Socket -> B.ByteString ->ParserState -> Int ->  ProxyM ()

handleClient s requestBuffer ws sb= do
  env <- ask

  -- let ends =( backends  . proxyConfig)env
  -- let tVarState = proxyTVarState env
  -- sb <- liftIO $ atomically $ nextBackendIdxTx tVarState ends
  -- liftIO $ putStrLn  (show sb)
  let currentBackend = (backendConfigs  env )  !! sb
  let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 12\r\nConnection: close\r\n\r\nHello, world"
  request <- liftIO $ recv s 1024
  if B.null request then 
    do
      liftIO $ putStrLn "Closed by the client"
      liftIO $ S.close s
  else  do
      let (status, wirthState, acc_requestBuffer) = requestStreamAutomaton requestBuffer request ws 
      liftIO $putStrLn (show status)
      liftIO $putStrLn (show $ parsed wirthState)
      liftIO $putStrLn (show acc_requestBuffer)

      
      case status of
        RSA_Finished -> do
          liftIO $putStrLn "Finished Case"
          let newPrefix = requestRewrite RewriteMethod acc_requestBuffer wirthState [("v1","BB")]
          let newUri = requestRewrite RewriteUrl acc_requestBuffer wirthState [("v1","BB")]
          let newSuffix = requestRewrite RewriteHeader acc_requestBuffer wirthState [("v1","BB")]
          let newBody = B.concat [newPrefix, newUri, newSuffix]
          liftIO $print  newUri
          b_socket <-liftIO $ connectBackend (appName currentBackend) (runningPort currentBackend)
          liftIO $ pipeResponse b_socket s newBody

        RSA_Error -> do
-- here must error response but for the time being 
          liftIO $ sendAll s resp 
          liftIO $ S.close s
        _ -> handleClient s acc_requestBuffer wirthState sb
  return ()


connectBackend::String->Int ->IO Socket
connectBackend hostName portNum = do
  let hints = S.defaultHints { S.addrFlags = [S.AI_PASSIVE], S.addrSocketType = S.Stream }
  addrInfo <- head <$> S.getAddrInfo (Just hints) (Just hostName) (Just (show portNum))
  sock <- S.socket (S.AF_INET) (S.addrSocketType addrInfo) (S.addrProtocol addrInfo)
  S.connect sock (S.addrAddress addrInfo)
  return sock


  
pipeResponse ::Socket -> Socket -> B.ByteString -> IO ()
pipeResponse s_b s_c payload = do
  sendAll s_b payload
  response <- recv s_b 1024 -- for the time being once
  S.close s_b
  sendAll s_c response
  S.close s_c
  return ()
