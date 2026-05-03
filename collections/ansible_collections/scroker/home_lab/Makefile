.PHONY: lint test test-dante test-nut test-nginx test-container-runtime test-wireguard

ROLES_DIR := roles
MOLECULE := molecule

lint:
	ansible-lint roles/

test-dante:
	cd $(ROLES_DIR)/dante && $(MOLECULE) test

test-nut:
	cd $(ROLES_DIR)/nut && $(MOLECULE) test

test-nginx:
	cd $(ROLES_DIR)/nginx && $(MOLECULE) test

test-container-runtime:
	cd $(ROLES_DIR)/container_runtime && $(MOLECULE) test

test-wireguard:
	cd $(ROLES_DIR)/wireguard && $(MOLECULE) test

test: lint test-dante test-nut test-nginx test-container-runtime test-wireguard
