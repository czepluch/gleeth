-module(gleeth_ffi).
-export([generate_secure_bytes/1, get_env/1]).

%% Get an environment variable, returning {ok, Value} or {error, nil}
get_env(Name) when is_binary(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, unicode:characters_to_binary(Value)}
    end.

%% Generate cryptographically secure random bytes using Erlang's crypto module
%% Returns {ok, Bytes} or {error, Reason}
generate_secure_bytes(Length) when is_integer(Length), Length > 0 ->
    try
        Bytes = crypto:strong_rand_bytes(Length),
        {ok, Bytes}
    catch
        error:low_entropy ->
            {error, <<"Insufficient entropy available">>};
        error:not_supported ->
            {error, <<"Strong random bytes not supported">>};
        Error:Reason ->
            ErrorMsg = io_lib:format("Crypto error: ~p:~p", [Error, Reason]),
            {error, list_to_binary(ErrorMsg)}
    end;
generate_secure_bytes(Length) ->
    ErrorMsg = io_lib:format("Invalid length: ~p (must be positive integer)", [Length]),
    {error, list_to_binary(ErrorMsg)}.
