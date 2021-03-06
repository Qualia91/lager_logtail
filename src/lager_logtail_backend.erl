%%%-----------------------------------------------------------------------------
%%% @doc
%%%
%%% @author boc_dev
%%% @copyright MIT
%%% @version 0.0.1
%%% @end
%%%-----------------------------------------------------------------------------

-module(lager_logtail_backend).
-author(boc_dev).
-behaviour(gen_event).

%%%=============================================================================
%%% Exports and Definitions
%%%=============================================================================

-export([
    init/1,
    handle_call/2,
    handle_event/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-type lager_msg_metadata() :: [tuple()].
-type binary_proplist() :: [{binary(), binary()}].

%%% this is only exported for the spawn call
-export([deferred_log/3]).

-record(state, {
                 level          :: integer(),
                 retry_interval :: integer(),
                 retry_times    :: integer(),
                 token          :: string(),
                 url            :: string()
               }).
-type state() :: state.

-include_lib("lager/include/lager.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%%%=============================================================================
%%% Behaviour Impl
%%%=============================================================================

-spec init(list()) -> {ok, state()}.
init([Level, RetryTimes, RetryInterval, Token]) ->
    State = #state{
                    level          = lager_util:level_to_num(Level),
                    retry_interval = RetryInterval,
                    retry_times    = RetryTimes,
                    token          = Token,
                    url            = "https://in.logtail.com"
                  },
    {ok, State}.

-spec handle_call(get_loglevel | set_loglevel, state()) -> {ok, state()}.
handle_call(get_loglevel, #state{ level = Level } = State) ->
    {ok, Level, State};
handle_call({set_loglevel, Level}, State) ->
    {ok, ok, State#state{ level = lager_util:level_to_num(Level) }};
handle_call(_Request, State) ->
    {ok, ok, State}.
   
-spec handle_event({log, any()}, state()) -> {ok, state()}.
handle_event({log, Message}, #state{level=Level} = State) ->

    case lager_util:is_loggable(Message, Level, ?MODULE) of
        true ->
            Payload = jsx:encode(cons_metadata_to_binary_proplist(lager_msg:metadata(Message), [
                                     {<<"level">>, any_to_binary(lager_msg:severity(Message))},
                                     {<<"message">>, any_to_binary(lager_msg:message(Message))}
                                 ])),
            Request = {State#state.url, [{"Authorization", "Bearer " ++ State#state.token}], "application/json", Payload},
            RetryTimes = State#state.retry_times,
            RetryInterval = State#state.retry_interval,

            %% Spawn a background process to handle sending the payload.
            %% It will recurse until the payload has ben successfully sent.
            spawn(?MODULE, deferred_log, [Request, RetryTimes, RetryInterval]),
            {ok, State};
        false ->
            {ok, State}
    end;
handle_event(_Event, State) ->
    {ok, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec deferred_log(any(), integer(), integer()) -> ok.
deferred_log(_Request, 0, _) ->
    io:format("LogTail Request Failed and can't try again"),
    ok;
deferred_log(Request, Retries, Interval) ->
    case httpc:request(post, Request, [], [{body_format, binary}]) of
        {ok, {{_, 202, _}, _Header, _Body}} -> 
            ok;
        Failure ->
            io:format("LogTail Request Failed with ~p retries left: ~p", [Retries, Failure]),
            timer:sleep(Interval * 1000),
            deferred_log(Request, Retries - 1, Interval)
    end.

-spec cons_metadata_to_binary_proplist(Metadata::lager_msg_metadata(), Proplist::binary_proplist()) -> Proplist::binary_proplist().
cons_metadata_to_binary_proplist(Metadata, Proplist) ->
    lists:foldl(fun({Key, Value}, Acc) -> [{any_to_binary(Key), any_to_binary(Value)} | Acc] end, Proplist, Metadata).

-spec any_to_binary(any()) -> binary().
any_to_binary(V) when is_atom(V)    -> any_to_binary(atom_to_list(V));
any_to_binary(V) when is_pid(V)     -> any_to_binary(pid_to_list(V));
any_to_binary(V) when is_list(V)    -> list_to_binary(V);
any_to_binary(V) when is_integer(V) -> integer_to_binary(V);
any_to_binary(V) when is_binary(V)  -> V;
any_to_binary(V)                    -> term_to_binary(V).

%%%===================================================================
%%% Tests
%%%===================================================================

-ifdef(TEST).

any_to_binary_test() ->
    ?assertEqual(<<"hello">>, any_to_binary(hello)),
    ?assertEqual(<<1,2,3>>, any_to_binary([1,2,3])),
    ?assertEqual(<<"1">>, any_to_binary(1)),
    ?assertEqual(<<"1">>, any_to_binary(<<"1">>)),
    ?assertEqual(<<131,104,2,100,0,5,104,101,108,108,111,97,1>>, any_to_binary({hello, 1})).

-endif.