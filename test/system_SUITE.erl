%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is AWeber Communications.
%% Copyright (c) 2015-2016 AWeber Communications
%% Copyright (c) 2016-2020 VMware, Inc. or its affiliates. All rights reserved.
%%

-module(system_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-include("rabbit_peer_discovery_etcd.hrl").

-import(rabbit_data_coercion, [to_binary/1, to_integer/1]).


all() ->
    [
     {group, v3_client}
    ].

groups() ->
    [
     {v3_client, [], [
                    etcd_connection_sanity_check_test,
                    init_opens_a_connection_test,
                    registration_with_locking_test
                ]}
    ].

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    rabbit_ct_helpers:run_setup_steps(Config, [fun init_etcd/1]).

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config, [fun stop_etcd/1]).

init_etcd(Config) ->
    DataDir = ?config(data_dir, Config),
    PrivDir = ?config(priv_dir, Config),
    TcpPort = 25389,
    EtcdDir = filename:join([PrivDir, "etcd"]),
    InitEtcd = filename:join([DataDir, "init-etcd.sh"]),
    Cmd = [InitEtcd, EtcdDir, {"~b", [TcpPort]}],
    case rabbit_ct_helpers:exec(Cmd) of
        {ok, Stdout} ->
            case re:run(Stdout, "^ETCD_PID=([0-9]+)$", [{capture, all_but_first, list}, multiline]) of
                {match, [EtcdPid]} ->
                    ct:pal(?LOW_IMPORTANCE, "etcd PID: ~s~netcd is listening on: ~b", [EtcdPid, TcpPort]),
                    rabbit_ct_helpers:set_config(Config, [{etcd_pid, EtcdPid},
                                                          {etcd_endpoints, [rabbit_misc:format("localhost:~p", [TcpPort])]},
                                                          {etcd_port, TcpPort}]);
                nomatch ->
                    ct:pal(?HI_IMPORTANCE, "init-etcd.sh output did not match what's expected: ~p", [Stdout])
            end;
        _ ->
            _ = rabbit_ct_helpers:exec(["pkill", "-INT", "etcd"]),
            {skip, "Failed to initialize etcd"}
    end.

stop_etcd(Config) ->
    EtcdPid = ?config(etcd_pid, Config),
    Cmd = ["kill", "-INT", EtcdPid],
    _ = rabbit_ct_helpers:exec(Cmd),
    Config.


%%
%% Test cases
%%

etcd_connection_sanity_check_test(Config) ->
    application:ensure_all_started(eetcd),
    Endpoints = ?config(etcd_endpoints, Config),
    ?assertMatch({ok, _Pid}, eetcd:open(test, Endpoints)),

    Condition1 = fun() ->
                    1 =:= length(eetcd_conn_sup:info())
                end,
    rabbit_ct_helpers:await_condition(Condition1, 60000),

    eetcd:close(test),
    Condition2 = fun() ->
                    0 =:= length(eetcd_conn_sup:info())
                end,
    rabbit_ct_helpers:await_condition(Condition2, 60000).

init_opens_a_connection_test(Config) ->
    Endpoints = ?config(etcd_endpoints, Config),
    {ok, Pid} = rabbitmq_peer_discovery_etcd_v3_client:start(#{endpoints => Endpoints}),
    Condition = fun() ->
                    1 =:= length(eetcd_conn_sup:info())
                end,
    rabbit_ct_helpers:await_condition(Condition, 90000),
    gen_statem:stop(Pid),
    ?assertEqual(0, length(eetcd_conn_sup:info())).


registration_with_locking_test(Config) ->
    Endpoints = ?config(etcd_endpoints, Config),
    {ok, Pid} = rabbitmq_peer_discovery_etcd_v3_client:start(#{endpoints => Endpoints}),
    Condition1 = fun() ->
                    1 =:= length(eetcd_conn_sup:info())
                 end,
    rabbit_ct_helpers:await_condition(Condition1, 90000),

    {ok, LockOwnerKey} = rabbitmq_peer_discovery_etcd_v3_client:lock(Pid, node()),
    rabbitmq_peer_discovery_etcd_v3_client:register(Pid),
    ?assertEqual(ok, rabbitmq_peer_discovery_etcd_v3_client:unlock(Pid, LockOwnerKey)),

    Condition2 = fun() ->
                    [node()] =:= rabbitmq_peer_discovery_etcd_v3_client:list_nodes(Pid)
                 end,
    rabbit_ct_helpers:await_condition(Condition2, 45000),

    gen_statem:stop(Pid).
