-- | Compatibility layer for network package, including newtype 'PortID'
{-# LANGUAGE CPP, GeneralizedNewtypeDeriving #-}

module Database.MongoDB.Internal.Network (PortID(..), N.HostName, connectTo) where


#if !MIN_VERSION_network(2, 9, 0)

import qualified Network as N
import System.IO (Handle)

#else

import Control.Exception (bracketOnError)
import Network.BSD as BSD
import qualified Network.Socket as N
import System.IO (Handle, IOMode(ReadWriteMode))

#endif


-- | Wraps network's 'PortNumber'
-- Used to ease compatibility between older and newer network versions.
data PortID = PortNumber N.PortNumber
#if !defined(mingw32_HOST_OS) && !defined(cygwin32_HOST_OS) && !defined(_WIN32)
            | UnixSocket String
#endif
            deriving (Eq, Ord, Show)


#if !MIN_VERSION_network(2, 9, 0)

-- Unwrap our newtype and use network's PortID and connectTo
connectTo :: N.HostName         -- Hostname
          -> PortID             -- Port Identifier
          -> IO Handle          -- Connected Socket
connectTo hostname (PortNumber port) = N.connectTo hostname (N.PortNumber port)

#if !defined(mingw32_HOST_OS) && !defined(cygwin32_HOST_OS) && !defined(_WIN32)
connectTo _ (UnixSocket path) = N.connectTo "" (N.UnixSocket path)
#endif

#else

-- Copied implementation from network 2.8's 'connectTo', but using our 'PortID' newtype.
-- https://github.com/haskell/network/blob/e73f0b96c9da924fe83f3c73488f7e69f712755f/Network.hs#L120-L129
connectTo :: N.HostName         -- Hostname
          -> PortID             -- Port Identifier
          -> IO Handle          -- Connected Socket
connectTo hostname (PortNumber port) = do
    proto <- BSD.getProtocolNumber "tcp"
    bracketOnError
        (N.socket N.AF_INET N.Stream proto)
        (N.close)  -- only done if there's an error
        (\sock -> do
          he <- BSD.getHostByName hostname
          N.connect sock (N.SockAddrInet port (hostAddress he))
          N.socketToHandle sock ReadWriteMode
        )

#if !defined(mingw32_HOST_OS) && !defined(cygwin32_HOST_OS) && !defined(_WIN32)
connectTo _ (UnixSocket path) = do
    bracketOnError
        (N.socket N.AF_UNIX N.Stream 0)
        (N.close)
        (\sock -> do
          N.connect sock (N.SockAddrUnix path)
          N.socketToHandle sock ReadWriteMode
        )
#endif

#endif
