-module(gleeth_ffi).
-export([generate_secure_bytes/1]).

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
