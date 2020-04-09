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

-module(unit_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-include("rabbit_peer_discovery_etcd.hrl").

-import(rabbit_data_coercion, [to_binary/1]).


all() ->
    [
     {group, unit}
    ].

groups() ->
    [
     {unit, [], [
                    registration_value_test,
                    extract_nodes_case1_test,
                    filter_nodes_test,
                    node_key_base_test,
                    node_key_test,
                    lock_key_base_test
                ]}
    ].


%%
%% Test cases
%%

registration_value_test(_Config) ->
    LeaseID = 8488283859587364900,
    TTL     = 61,
    Input   = #statem_data{
        node_key_lease_id = LeaseID,
        node_key_ttl_in_seconds = TTL
    },
    Expected = registration_value_of(LeaseID, TTL),
    ?assertEqual(Expected, rabbitmq_peer_discovery_etcd_v3_client:registration_value(Input)).


extract_nodes_case1_test(_Config) ->
    Input    = registration_value_of(8488283859587364900, 61),
    Expected = node(),

    ?assertEqual(Expected, rabbitmq_peer_discovery_etcd_v3_client:extract_node(Input)),

    ?assertEqual(undefined, rabbitmq_peer_discovery_etcd_v3_client:extract_node(<<"{}">>)).

filter_nodes_test(_Config) ->
    Input    = [node(), undefined, undefined, {error, reason1}, {error, {another, reason}}],
    Expected = [node()],

    ?assertEqual(Expected, lists:filter(fun rabbitmq_peer_discovery_etcd_v3_client:filter_node/1, Input)).

node_key_base_test(_Config) ->
    Expected = <<"/rabbitmq/discovery/prefffix/clusters/cluster-a/nodes">>,
    Input = #statem_data{
        cluster_name = "cluster-a",
        key_prefix = "prefffix"
    },
    ?assertEqual(Expected, rabbitmq_peer_discovery_etcd_v3_client:node_key_base(Input)).

node_key_test(_Config) ->
    Expected = to_binary(rabbit_misc:format("/rabbitmq/discovery/prefffix/clusters/cluster-a/nodes/~s", [node()])),
    Input = #statem_data{
        cluster_name = "cluster-a",
        key_prefix = "prefffix"
    },
    ?assertEqual(Expected, rabbitmq_peer_discovery_etcd_v3_client:node_key(Input)).

lock_key_base_test(_Config) ->
    Expected = <<"/rabbitmq/locks/prefffix/clusters/cluster-b/registration">>,
    Input = #statem_data{
        cluster_name = "cluster-b",
        key_prefix = "prefffix"
    },
    ?assertEqual(Expected, rabbitmq_peer_discovery_etcd_v3_client:lock_key_base(Input)).

%%
%% Helpers
%%

registration_value_of(LeaseID, TTL) ->
    to_binary(rabbit_json:encode(#{
        <<"node">> => to_binary(node()),
        <<"lease_id">> => LeaseID,
        <<"ttl">> => TTL
    })).
