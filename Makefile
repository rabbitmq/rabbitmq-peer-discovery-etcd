PROJECT = rabbitmq_peer_discovery_etcd
PROJECT_DESCRIPTION = etcd-based RabbitMQ peer discovery backend
PROJECT_MOD = rabbitmq_peer_discovery_etcd_app

DEPS = rabbit_common rabbitmq_peer_discovery_common rabbit eetcd
TEST_DEPS = rabbitmq_ct_helpers rabbitmq_ct_client_helpers ct_helper meck
dep_ct_helper = git https://github.com/extend/ct_helper.git master
dep_eetcd = git https://github.com/zhongwencool/eetcd bbaa8f93

DEP_EARLY_PLUGINS = rabbit_common/mk/rabbitmq-early-plugin.mk
DEP_PLUGINS = rabbit_common/mk/rabbitmq-plugin.mk

# FIXME: Use erlang.mk patched for RabbitMQ, while waiting for PRs to be
# reviewed and merged.

ERLANG_MK_REPO = https://github.com/rabbitmq/erlang.mk.git
ERLANG_MK_COMMIT = rabbitmq-tmp

include rabbitmq-components.mk
include erlang.mk
