%% -*- erlang -*-
%%
%% Cuneiform: A Functional Language for Large Scale Scientific Data Analysis
%%
%% Copyright 2016 Jörgen Brandt, Marc Bux, and Ulf Leser
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%    http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

%% @author Jörgen Brandt <brandjoe@hu-berlin.de>


-module( effi_interact ).
-author( "Jorgen Brandt <brandjoe@hu-berlin.de>" ).
-vsn( "0.1.1-snapshot" ).

-behaviour( effi ).

%% ------------------------------------------------------------
%% Includes
%% ------------------------------------------------------------

-include( "effi.hrl" ).

%% ------------------------------------------------------------
%% Callback definitions
%% ------------------------------------------------------------

-callback ffi_type() -> atom().
-callback interpreter() -> string().
-callback prefix() -> string().
-callback suffix() -> string().
-callback assignment( ParamName::string(), IsList::boolean(), Value::string() | [string()] ) -> iodata().
-callback dismissal( OutName::string(), IsList::boolean() ) -> iodata().
-callback preprocess( Script::iodata() ) -> iodata().
-callback libpath( Path::string() ) -> string().


%% ------------------------------------------------------------
%% Callback function exports
%% ------------------------------------------------------------

-export( [create_port/4] ).


%% ------------------------------------------------------------
%% Callback functions
%% ------------------------------------------------------------

%% create_port/4
%
create_port( Mod, Script, Dir, Prof )

when is_atom( Mod ),
     is_list( Script ),
     is_list( Dir ),
     is_tuple( Prof ) ->

  % get interpreter
  Interpreter = apply( Mod, interpreter, [] ),

  % get instrumentation wrapper
  ProfiledInterpreter = case effi_profiling:do_profiling( Prof ) of true -> 
    % generate a name for the invocation profile file by hashing the contents of the script
    % OutfileName = string:concat(integer_to_list(erlang:phash2(Script)), "_profile.xml"),
    % set the output file of kickstart to be in Dir 
    {profiling, _, ProfileFileName} = Prof,
    OutfileArgument = string:concat( "-l ", filename:join(Dir, ProfileFileName) ),
    % profiler call which to which the actual application is passed
    % connect the profiled process' stdin, stdout, and stderr to the default file descriptors 
    Profiler = string:concat( "pegasus-kickstart -o - -i - -e - ", OutfileArgument ),
    string:join( [Profiler, Interpreter], " " );
    false -> ""
  end,

  % get prefix
  Prefix = apply( Mod, prefix, [] ),

  % get suffix
  Suffix = apply( Mod, suffix, [] ),

  % complement script
  ActScript = string:join( [Prefix, Script, Suffix, ""], "\n" ),

  % run ticket
  Port = open_port( {spawn, case effi_profiling:do_profiling(Prof) of true -> ProfiledInterpreter; false -> Interpreter end},
                    [exit_status,
                     stderr_to_stdout,
                     binary,
                     {cd, Dir},
                     {line, ?BUF_SIZE}] ),

  true = port_command( Port, ActScript ),

  {Port, ActScript}.
