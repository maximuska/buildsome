module Buildsome.Opts
  ( OverwriteUnregisteredOutputs(..)
  , UpdateGitIgnore(..)
  , KeepGoing(..)
  , Color(..)
  , Opt(..), Opts(..), get
  , PrintCommands(..)
  , PrintOutputs(..)
  , Verbosity(..)
  ) where

import Control.Monad (liftM)
import Data.ByteString (ByteString)
import Data.List (intercalate)
import Lib.FilePath (FilePath)
import Options.Applicative
import Prelude hiding (FilePath)
import qualified Data.ByteString.Char8 as BS8

data OverwriteUnregisteredOutputs = OverwriteUnregisteredOutputs | DontOverwriteUnregisteredOutputs
  deriving (Show)
data UpdateGitIgnore = UpdateGitIgnore | DontUpdateGitIgnore
  deriving (Show)
data KeepGoing = KeepGoing | DieQuickly
  deriving (Show)
data Color = ColorDisable | ColorEnable | ColorDefault
  deriving (Show)

data PrintCommands
  = PrintCommandsNever
  | PrintCommandsForExecution {-default-}
  | PrintCommandsForAll
  deriving (Show)

data PrintOutputs
  = PrintOutputsAnyway
  | PrintOutputsNonEmpty
  | PrintOutputsIfStderr {-default-}
  deriving (Show)

data Verbosity = Verbosity
  { verbosityCommands :: PrintCommands
  , verbosityOutputs :: PrintOutputs
  , verbosityGeneral :: Bool
  }
  deriving (Show)

verbosityAll :: Verbosity
verbosityAll = Verbosity
  { verbosityCommands = PrintCommandsForAll
  , verbosityOutputs = PrintOutputsAnyway
  , verbosityGeneral = True
  }

parseVerbosity :: Parser Verbosity
parseVerbosity =
  flag' verbosityAll
    (short 'v' <>
     long "verbose" <>
     help "Run in verbose mode")
  <|>
  ( Verbosity
    <$> flag PrintCommandsNever PrintCommandsForAll
        (long "verbose-cmds" <>
         help "Show commands (executed and replayed)")
    <*> flag PrintOutputsIfStderr PrintOutputsNonEmpty
        (long "verbose-stdouts" <>
         help "Replay stdouts and not just stderrs")
    <*> switch
        (long "verbose-general" <>
         help "Show buildsome's own execution details")
  )

data Opt = Opt { optRequestedTargets :: [FilePath]
               , optMakefilePath :: Maybe FilePath
               , optParallelism :: Maybe Int
               , optUpdateGitIgnore :: UpdateGitIgnore
               , optColor :: Color
               , optOverwriteUnregisteredOutputs :: OverwriteUnregisteredOutputs
               , optKeepGoing :: KeepGoing
               , optChartsPath :: Maybe FilePath
               , optFsOverrideLdPreloadPath :: Maybe FilePath
               , optWiths :: [ByteString]
               , optWithouts :: [ByteString]

               , optVerbosity :: Verbosity
                 -- In theory, --help-flags could be mutually
                 -- exclusive with many other flags, but this would
                 -- just make life more difficult for users, so it is
                 -- allowed in conjunction
               , optHelpFlags :: Bool
               }
  deriving (Show)

data Opts = GetVersion | Opts Opt
  deriving (Show)

opt :: Read a => Mod OptionFields a -> Parser (Maybe a)
opt = optional . option

strOptional :: Mod OptionFields String -> Parser (Maybe ByteString)
strOptional = (fmap . fmap) BS8.pack . optional . strOption

strOpt :: Mod OptionFields String -> Parser ByteString
strOpt = fmap BS8.pack . strOption

desc :: String
desc = intercalate "\n"
  [ "Build a buildsome project."
  , ""
  , "Unless -f is given, scans upwards to find a Makefile and "
  , "builds the target named 'default' in the invocation directory."
  , "If 'clean' is used as the sole target name, cleans all "
  , "outputs previously generated by buildsome."
  ]

bytestr :: Monad m => String -> m ByteString
bytestr = liftM BS8.pack . str

get :: IO Opts
get =
  execParser $
  info (helper <*> parser)
  (fullDesc <> progDesc desc <> header "buildsome - build an awesome project")
  where
    parser = versionParser <|> (Opts <$> optsParser)
    versionParser = flag' GetVersion $ long "version" <> help "Get buildsome's version"
    optsParser =
      Opt <$> many (argument bytestr (metavar "targets"))
          <*> strOptional (short 'f' <>
                           long "file" <>
                           metavar "file" <>
                           help "Use file as a makefile.")
          <*> opt (short 'j' <>
                   long "parallelism" <>
                   help "How many commands to execute in parallel" <>
                   metavar "jobs")
          <*> ( flag' UpdateGitIgnore
                (short 'g' <>
                 long "gitignore" <>
                 help "Update (or create) .gitignore file in the same directory as the Makefile (default)")
                <|>
                flag' DontUpdateGitIgnore
                (short 'G' <>
                 long "no-gitignore" <>
                 help "Do not touch the .gitignore file in the same directory as the Makefile")
                <|>
                pure UpdateGitIgnore
              )
          <*> ( flag' ColorDisable
                (long "disable-color" <>
                 help "Do not use color coded outputs")
                <|>
                flag' ColorEnable
                (long "enable-color" <>
                 help "Use color coded outputs")
                <|>
                pure ColorDefault
              )
          <*> flag DontOverwriteUnregisteredOutputs OverwriteUnregisteredOutputs
              (long "overwrite" <>
               help "Overwrite outputs not created by buildsome")
          <*> flag DieQuickly KeepGoing
              (short 'k' <>
               long "keep-going" <>
               help "Continue as much as possible after an error.")
          <*> strOptional (long "charts" <>
                           metavar "charts-file" <>
                           help "File to write charts to")
          <*> strOptional (long "fs-override" <>
                           metavar "path" <>
                           help "Path for fs_override.so")
          <*> many (strOpt (metavar "flag" <> long "with" <>
                            help "Enable flags that are disabled by default"))
          <*> many (strOpt (metavar "flag" <> long "without" <>
                            help "Disable flags that are enabled by default"))
          <*> parseVerbosity
          <*> switch (long "help-flags" <> help "Get all flag variables assigned with ?=")
