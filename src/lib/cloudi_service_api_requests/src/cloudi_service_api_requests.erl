%-*-Mode:erlang;coding:utf-8;tab-width:4;c-basic-offset:4;indent-tabs-mode:()-*-
% ex: set ft=erlang fenc=utf-8 sts=4 ts=4 sw=4 et:
%%%
%%%------------------------------------------------------------------------
%%% @doc
%%% ==CloudI Service API Requests==
%%% A service that exposes dynamic configuration of CloudI.
%%% @end
%%%
%%% BSD LICENSE
%%% 
%%% Copyright (c) 2011-2014, Michael Truog <mjtruog at gmail dot com>
%%% All rights reserved.
%%% 
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%% 
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in
%%%       the documentation and/or other materials provided with the
%%%       distribution.
%%%     * All advertising materials mentioning features or use of this
%%%       software must display the following acknowledgment:
%%%         This product includes software developed by Michael Truog
%%%     * The name of the author may not be used to endorse or promote
%%%       products derived from this software without specific prior
%%%       written permission
%%% 
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
%%% CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
%%% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
%%% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
%%% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
%%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
%%% DAMAGE.
%%%
%%% @author Michael Truog <mjtruog [at] gmail (dot) com>
%%% @copyright 2011-2014 Michael Truog
%%% @version 1.4.0 {@date} {@time}
%%%------------------------------------------------------------------------

-module(cloudi_service_api_requests).
-author('mjtruog [at] gmail (dot) com').

-behaviour(cloudi_service).

%% external interface

%% cloudi_service callbacks
-export([cloudi_service_init/4,
         cloudi_service_handle_request/11,
         cloudi_service_handle_info/3,
         cloudi_service_terminate/3]).

-include_lib("cloudi_core/include/cloudi_logger.hrl").

-record(state,
    {
        functions, % method -> function lookup
        formats = cloudi_x_trie:new([
            % new format code paths
            {"rpc",
             fun format_rpc/5},
            {"rpc.json",
             fun format_json_rpc/5},
            % old format code paths
            {"erlang",
             fun format_erlang/5},
            {"json_rpc",
             fun format_json_rpc/5}
        ]),
        prefix_length = undefined
    }).
 
%%%------------------------------------------------------------------------
%%% External interface functions
%%%------------------------------------------------------------------------

%%%------------------------------------------------------------------------
%%% Callback functions from cloudi_service
%%%------------------------------------------------------------------------

cloudi_service_init(_Args, Prefix, _Timeout, Dispatcher) ->
    % newer service names should be preferred to provide a
    % content-type hint as a file extension
    CloudIServiceAPI = lists:foldl(fun({Method, Arity}, Functions) ->
        MethodName = erlang:atom_to_list(Method),
        % new service names are (prefix)rpc/(method)(format-extension)
        FormatMethodNew = "rpc/" ++ MethodName ++ ".erl",
        cloudi_service:subscribe(Dispatcher, FormatMethodNew),
        Fnew = if
            Arity == 1 ->
                cloudi_service:subscribe(Dispatcher,
                                         FormatMethodNew ++ "/get"),
                fun(Arg1) ->
                    cloudi_service_api_call(Method, Arg1)
                end;
            Arity == 2 ->
                cloudi_service:subscribe(Dispatcher,
                                         FormatMethodNew ++ "/post"),
                fun(Arg1, Arg2) ->
                    cloudi_service_api_call(Method, Arg1, Arg2)
                end
        end,
        % old service names are (prefix)(format)/(method)
        FormatMethodOld = "erlang/" ++ MethodName,
        cloudi_service:subscribe(Dispatcher, FormatMethodOld),
        Fold = fun cloudi_service_api:Method/Arity,
        if
            Arity == 1 ->
                cloudi_service:subscribe(Dispatcher,
                                         FormatMethodOld ++ "/get");
            Arity == 2 ->
                cloudi_service:subscribe(Dispatcher,
                                         FormatMethodOld ++ "/post")
        end,
        cloudi_x_trie:store(MethodName ++ ".erl", Fnew,
            cloudi_x_trie:store(MethodName, Fold, Functions))
    end, cloudi_x_trie:new(),
    cloudi_x_reltool_util:module_exports(cloudi_service_api)),
    % new service names for JSON-RPC are:
    cloudi_service:subscribe(Dispatcher, "rpc.json"),
    cloudi_service:subscribe(Dispatcher, "rpc.json/post"),
    % old service names for JSON-RPC are:
    cloudi_service:subscribe(Dispatcher, "json_rpc/"),
    cloudi_service:subscribe(Dispatcher, "json_rpc//post"),
    {ok, #state{functions = CloudIServiceAPI,
                prefix_length = erlang:length(Prefix)}}.

cloudi_service_handle_request(_Type, Name, _Pattern, _RequestInfo, Request,
                              Timeout, _Priority, _TransId, _Pid,
                              #state{prefix_length = PrefixLength,
                                     functions = Functions,
                                     formats = Formats} = State, _Dispatcher) ->
    {Format,
     Suffix} = cloudi_string:splitl($/,
                                    lists:nthtail(PrefixLength, Name), input),
    FormatF = cloudi_x_trie:fetch(Format, Formats),
    MethodName = if
        % new format
        Format == "rpc";
        % old format
        Format == "erlang" ->
            cloudi_string:beforel($/, Suffix, input);
        true ->
            ""
    end,
    F = if
        MethodName == "" ->
            undefined;
        true ->
            cloudi_x_trie:fetch(MethodName, Functions)
    end,
    Response = FormatF(MethodName, F, Request, Timeout, Functions),
    {reply, cloudi_response:new(Request, Response), State}.

cloudi_service_handle_info(Request, State, _) ->
    ?LOG_WARN("Unknown info \"~p\"", [Request]),
    {noreply, State}.

cloudi_service_terminate(_Reason, _Timeout, #state{}) ->
    ok.

%%%------------------------------------------------------------------------
%%% Private functions
%%%------------------------------------------------------------------------

format_rpc(MethodName, F, Input, Timeout, _)
    when is_function(F) ->
    {arity, Arity} = erlang:fun_info(F, arity),
    case filename:extension(MethodName) of
        ".erl" ->
            format_erlang_f(F, Arity, Input, Timeout);
        _ ->
            <<>>
    end.

format_erlang(_, F, Input, Timeout, _)
    when is_function(F) ->
    {arity, Arity} = erlang:fun_info(F, arity),
    format_erlang_f(F, Arity, Input, Timeout).

format_erlang_f(F, 1, Input, Timeout) ->
    if
        is_binary(Input) ->
            case F(Timeout) of
                {ok, Result} when is_binary(Result) ->
                    Result;
                {ok, Result} ->
                    cloudi_string:term_to_binary(Result);
                Result ->
                    cloudi_string:term_to_binary(Result)
            end;
        is_list(Input) ->
            case F(Timeout) of
                {ok, Result} when is_binary(Result) ->
                    erlang:binary_to_list(Result);
                {ok, Result} ->
                    cloudi_string:term_to_list(Result);
                Result ->
                    cloudi_string:term_to_list(Result)
            end
    end;
format_erlang_f(F, 2, Input, Timeout) ->
    if
        is_binary(Input) ->
            case F(cloudi_string:binary_to_term(Input), Timeout) of
                {ok, Result} when is_binary(Result) ->
                    Result;
                {ok, Result} ->
                    cloudi_string:term_to_binary(Result);
                Result ->
                    cloudi_string:term_to_binary(Result)
            end;
        is_list(Input) ->
            case F(cloudi_string:list_to_term(Input), Timeout) of
                {ok, Result} when is_binary(Result) ->
                    erlang:binary_to_list(Result);
                {ok, Result} ->
                    cloudi_string:term_to_list(Result);
                Result ->
                    cloudi_string:term_to_list(Result)
            end
    end.

-spec format_json_rpc(string(),
                      'undefined',
                      Input :: binary() | string(),
                      Timeout :: integer(),
                      Functions :: any()) -> binary().

format_json_rpc(_, undefined, Input, Timeout, Functions) ->
    {Method, Params, Id} = cloudi_json_rpc:request_to_term(Input),
    try (case cloudi_x_trie:fetch(erlang:binary_to_list(Method), Functions) of
        F when Params == [], is_function(F, 1) ->
            F(Timeout);
        F when length(Params) == 1, is_function(F, 2) ->
            F(cloudi_string:binary_to_term(erlang:hd(Params)), Timeout)
         end) of
        {ok, Result} when is_binary(Result) ->
            cloudi_json_rpc:response_to_json(
                Result, Id
            );
        {ok, Result} ->
            cloudi_json_rpc:response_to_json(
                cloudi_string:term_to_binary(Result), Id
            );
        Result ->
            cloudi_json_rpc:response_to_json(
                cloudi_string:term_to_binary(Result), Id
            )
    catch
        Type:Error ->
            ?LOG_ERROR("JSON RPC error ~p ~p~n~p",
                       [Type, Error, erlang:get_stacktrace()]),
            cloudi_json_rpc:response_to_json(
                null, 0, cloudi_string:term_to_binary(Error), Id
            )
    end.

cloudi_service_api_call(services = Method, Timeout) ->
    case cloudi_service_api:Method(Timeout) of
        {ok, L} ->
            {ok, [{cloudi_x_uuid:uuid_to_string(UUID), Data} ||
                  {UUID, Data} <- L]};
        {error, _} = Error ->
            Error
    end;
cloudi_service_api_call(Method, Timeout) ->
    cloudi_service_api:Method(Timeout).

cloudi_service_api_call(services_search = Method, Input, Timeout) ->
    case cloudi_service_api:Method(Input, Timeout) of
        {ok, L} ->
            {ok, [{cloudi_x_uuid:uuid_to_string(UUID), Data} ||
                  {UUID, Data} <- L]};
        {error, _} = Error ->
            Error
    end;
cloudi_service_api_call(services_add = Method, Input, Timeout) ->
    case cloudi_service_api:Method(Input, Timeout) of
        {ok, L} ->
            {ok, [cloudi_x_uuid:uuid_to_string(UUID) || UUID <- L]};
        {error, _} = Error ->
            Error
    end;
cloudi_service_api_call(Method, Input, Timeout) ->
    cloudi_service_api:Method(Input, Timeout).

