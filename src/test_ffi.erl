-module(test_ffi).
-export([run_command/1]).

%% Run a shell command and return the output as a binary string.
%% Strips trailing newline.
run_command(Command) when is_binary(Command) ->
    Output = os:cmd(binary_to_list(Command)),
    Bin = unicode:characters_to_binary(Output),
    string:trim(Bin, trailing, "\n").
