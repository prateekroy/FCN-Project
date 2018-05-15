-module(yaws_dynopts).

-include("../include/yaws.hrl").
-include("../include/yaws_api.hrl").

-export([
         have_ssl_honor_cipher_order/0,
         have_ssl_client_renegotiation/0,
         have_ssl_sni/0,
         have_ssl_log_alert/0,
         have_erlang_sendfile/0,
         have_crypto_strong_rand_bytes/0,
         have_erlang_now/0,
         have_rand/0,

         rand_bytes/1,
         unique_triple/0,
         get_time_tuple/0,
         now_secs/0,
         random_seed/3,
         random_uniform/1,

         generate/1,
         is_generated/0
        ]).

-export([is_greater/2, is_less/2,
         is_greater_or_equal/2, is_less_or_equal/2]).

%% SSL option honor_cipher_order was added in release 17 (ERTS >= 6.0)
have_ssl_honor_cipher_order() ->
    is_greater_or_equal(erlang:system_info(version), "6.0").

%% SSL option client_renegotiation was added in release 18 (ERTS >= 7.0)
have_ssl_client_renegotiation() ->
    is_greater_or_equal(erlang:system_info(version), "7.0").

%% SSL sni support was added in release 18  (ERTS >= 7.0)
have_ssl_sni() ->
    is_greater_or_equal(erlang:system_info(version), "7.0").

%% SSL option log_alert SSL was added in R16B02 (ERTS >= 5.10.3)
have_ssl_log_alert() ->
    is_greater_or_equal(erlang:system_info(version), "5.10.3").

%% erlang:sendfile/5 is buggy for R15 & R16 releases (ERTS < 6.0)
have_erlang_sendfile() ->
    is_greater_or_equal(erlang:system_info(version), "6.0").

%% crypto:rand_bytes/1 is deprecated since releases 19 (ERTS >= 8.0)
have_crypto_strong_rand_bytes() ->
    lists:member({strong_rand_bytes, 1}, crypto:module_info(exports)).

%% erlang:now/0 is deprecated since releases 18 (ERTS >= 7.0)
have_erlang_now() ->
    is_less(erlang:system_info(version), "7.0").

%% random module is deprecated since releases 19 (ERTS >= 8.0)
have_rand() ->
    (code:which(rand) /= non_existing).

rand_bytes(N) ->
    crypto:strong_rand_bytes(N).

unique_triple() ->
    erlang:now().

get_time_tuple() ->
    erlang:now().

now_secs() ->
    {M,S,_} = erlang:now(),
    (M*1000000)+S.

random_seed(A,B,C) ->
    case have_rand() of
        true  -> rand:seed(exsplus, {A,B,C});
        false -> (fun random:seed/3)(A,B,C)
    end.

random_uniform(N) ->
    case have_rand() of
        true  -> rand:uniform(N);
        false -> (fun random:uniform/1)(N)
    end.

is_greater         (Vsn1, Vsn2) -> compare_version(Vsn1, Vsn2) == greater.
is_less            (Vsn1, Vsn2) -> compare_version(Vsn1, Vsn2) == less.
is_greater_or_equal(Vsn1, Vsn2) -> not is_less(Vsn1, Vsn2).
is_less_or_equal   (Vsn1, Vsn2) -> not is_greater(Vsn1, Vsn2).

compare_version(Vsn, Vsn) ->
    equal;
compare_version(Vsn1, Vsn2) ->
    compare_version1(string:tokens(Vsn1, "."), string:tokens(Vsn2, ".")).

compare_version1([], []) ->
    equal;
compare_version1([X|Rest1], [X|Rest2]) ->
    compare_version1(Rest1, Rest2);
compare_version1([X1], [X2]) ->
    %% For last digit ignore everything after the "-", if any
    Y1 = lists:takewhile(fun(X) -> X /= $- end, X1),
    Y2 = lists:takewhile(fun(X) -> X /= $- end, X2),
    compare_digit(Y1, Y2);
compare_version1([X1|Rest1], [X2|Rest2]) ->
    case compare_digit(X1, X2) of
        equal -> compare_version1(Rest1, Rest2);
        Else  -> Else
    end;
compare_version1(_X, []) ->
    greater;
compare_version1([], _X) ->
    less.

compare_digit(X, X) ->
    equal;
compare_digit(X1, X2) when length(X1) > length(X2) ->
    greater;
compare_digit(X1, X2) when length(X1) < length(X2) ->
    less;
compare_digit(X1, X2) ->
    case X1 > X2 of
        true  -> greater;
        false -> less
    end.

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_generated() -> false.

generate(GC) ->
    code:ensure_loaded(crypto),
    code:ensure_loaded(inet),
    case {filelib:is_dir(yaws:id_dir(GC#gconf.id)),
          filelib:is_dir(yaws:tmpdir("/tmp"))} of
        {true, _} ->
            File = filename:join(yaws:id_dir(GC#gconf.id), "yaws_dynopts.erl"),
            generate1(File);
        {_, true} ->
            File = filename:join(yaws:tmpdir("/tmp"), "yaws_dynopts.erl"),
            generate1(File);
        _ ->
            error_logger:format("Cannot write yaws_dynopts.erl~n"
                                "Use the default version~n", [])
    end.

generate1(ModFile) ->
    case write_module(ModFile) of
        ok ->
            Opts = compile_options(),
            case compile:file(ModFile, Opts) of
                {ok, ModName, Binary} ->
                    case code:load_binary(ModName, [], Binary) of
                        {module, ModName} ->
                            ok;
                        {error, What} ->
                            error_logger:format(
                              "Cannot load module '~p': ~p~n"
                              "Use the default version~n",
                              [ModName, What]
                             )
                    end;
                _ ->
                    error_logger:format("Compilation of '~p' failed: ~p~n"
                                        "Use the default version~n",
                                        [ModFile])
            end;
        {error, Reason} ->
            error_logger:format("Cannot write ~p: ~p~n"
                                "Use the default version~n", [ModFile, Reason])
    end.

write_module(ModFile) ->
    case file:open(ModFile, [write]) of
        {ok, Fd} ->
            io:format(Fd, source(), []),
            file:close(Fd),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

compile_options() ->
    [binary, report,
     {d, 'HAVE_SSL_HONOR_CIPHER_ORDER',    have_ssl_honor_cipher_order()},
     {d, 'HAVE_SSL_CLIENT_RENEGOTIATION',  have_ssl_client_renegotiation()},
     {d, 'HAVE_SSL_SNI',                   have_ssl_sni()},
     {d, 'HAVE_SSL_LOG_ALERT',             have_ssl_log_alert()},
     {d, 'HAVE_ERLANG_SENDFILE',           have_erlang_sendfile()}
    ]
        ++
        case have_crypto_strong_rand_bytes() of
            true  -> [{d, 'HAVE_CRYPTO_STRONG_RAND_BYTES'}];
            false -> []
        end
        ++
        case have_erlang_now() of
            true  -> [{d, 'HAVE_ERLANG_NOW'}];
            false -> []
        end
        ++
        case have_rand() of
            true  -> [{d, 'HAVE_RAND'}];
            false -> []
        end.

source() ->
    IncDir  = yaws:get_inc_dir(),
    Src = [
           "-module(yaws_dynopts).",
           "",
           "-include(\"" ++ filename:join(IncDir, "yaws.hrl") ++ "\").",
           "-include(\"" ++ filename:join(IncDir, "yaws_api.hrl") ++ "\").",
           "",
           "-export([",
           "    have_ssl_honor_cipher_order/0,",
           "    have_ssl_client_renegotiation/0,",
           "    have_ssl_sni/0,",
           "    have_ssl_log_alert/0,",
           "    have_erlang_sendfile/0,",
           "    have_crypto_strong_rand_bytes/0,",
           "    have_erlang_now/0,",
           "    have_rand/0,"
           "",
           "    rand_bytes/1,",
           "    unique_triple/0,",
           "    get_time_tuple/0,",
           "    now_secs/0,",
           "    random_seed/3,",
           "    random_uniform/1,",
           "",
           "    generate/1,",
           "    is_generated/0",
           "   ]).",
           "",
           "",
           "generate(_) -> ok.",
           "is_generated() -> true.",
           "",
           "have_ssl_honor_cipher_order()   -> ?HAVE_SSL_HONOR_CIPHER_ORDER.",
           "have_ssl_client_renegotiation() -> ?HAVE_SSL_CLIENT_RENEGOTIATION.",
           "have_ssl_sni()                  -> ?HAVE_SSL_SNI.",
           "have_ssl_log_alert()            -> ?HAVE_SSL_LOG_ALERT.",
           "have_erlang_sendfile()          -> ?HAVE_ERLANG_SENDFILE.",
           "",
           "-ifdef(HAVE_CRYPTO_STRONG_RAND_BYTES).",
           "have_crypto_strong_rand_bytes() -> true.",
           "rand_bytes(N) -> crypto:strong_rand_bytes(N).",
           "-else.",
           "have_crypto_strong_rand_bytes() -> false.",
           "rand_bytes(N) -> crypto:rand_bytes(N).",
           "-endif.",
           ""
           "-ifdef(HAVE_ERLANG_NOW).",
           "have_erlang_now() -> true.",
           "unique_triple() ->",
           "    now().",
           "get_time_tuple() ->",
           "    now().",
           "now_secs() ->",
           "    {M,S,_} = now(),",
           "    (M*1000000)+S.",
           "-else.",
           "have_erlang_now() -> false.",
           "unique_triple() ->",
           "    {erlang:unique_integer([positive]),",
           "     erlang:unique_integer([positive]),",
           "     erlang:unique_integer([positive])}.",
           "get_time_tuple() ->",
           "    erlang:timestamp().",
           "now_secs() ->",
           "    {M,S,_} = erlang:timestamp(),",
           "    (M*1000000)+S.",
           "-endif.",
           "",
           "-ifdef(HAVE_RAND).",
           "have_rand() -> true.",
           "random_seed(A,B,C) -> rand:seed(exsplus, {A,B,C}).",
           "random_uniform(N)  -> rand:uniform(N).",
           "-else.",
           "have_rand() -> false.",
           "random_seed(A,B,C) -> random:seed(A,B,C).",
           "random_uniform(N)  -> random:uniform(N).",
           "-endif.",
           ""
          ],
    string:join(Src, "\n").
