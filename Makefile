# ---- config ----
SHELL := /bin/bash
DOCKER_DIR := docker
SERVICE    ?= django
APPDIR     := /app
LOCALES    := fr en sw
LOCALE_DIR := $(APPDIR)/locale
LOCALE_FLAGS := $(foreach L,$(LOCALES),-l $(L))

# Determine which compose files to use
# If .env.dev exists locally, we assume dev mode. Otherwise, use base only (prod).
COMPOSE_FILES := -f compose.yml
ifneq ("$(wildcard .env.dev)","")
    COMPOSE_FILES += -f compose.dev.yml
endif

DC := cd $(DOCKER_DIR) && docker compose -p chota $(COMPOSE_FILES)
EX := $(DC) exec -T $(SERVICE) bash -lc

.PHONY: dev prod i18n i18n-clean fix-line-endings quick-nl-pass fix-po \
        validate-po-detailed debug-one i18n-missing i18n-compile i18n-js i18n-reset-en \
        run migrate makemigrations shell test docker-up docker-down restart pull

# ----------------------------
# Environments
# ----------------------------
dev:
	cd $(DOCKER_DIR) && ln -sf ../.env.dev .env
	cd $(DOCKER_DIR) && docker compose -f compose.yml -f compose.dev.yml down
	cd $(DOCKER_DIR) && docker compose -f compose.yml -f compose.dev.yml up -d --build

dev-reset:
	cd $(DOCKER_DIR) && ln -sf ../.env.dev .env
	cd $(DOCKER_DIR) && docker compose -f compose.yml -f compose.dev.yml down
	cd $(DOCKER_DIR) && docker compose -f compose.yml -f compose.dev.yml build --no-cache
	cd $(DOCKER_DIR) && docker compose -f compose.yml -f compose.dev.yml up -d

prod:
	cd $(DOCKER_DIR) && ln -sf ../.env.prod .env
	cd $(DOCKER_DIR) && docker compose -f compose.yml down
	cd $(DOCKER_DIR) && docker compose -f compose.yml up -d --build

# ----------------------------
# Local Development (Non-Docker)
# ----------------------------
run:
	cd backend && python manage.py runserver

migrate:
	cd backend && python manage.py migrate

makemigrations:
	cd backend && python manage.py makemigrations

shell:
	cd backend && python manage.py shell

test:
	pytest

# ----------------------------
# Line endings
# ----------------------------
fix-line-endings:
	$(EX) "set -e; for L in $(LOCALES); do \
	  for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/*.po; do [ -f \"$$F\" ] || continue; \
	    sed -i 's/\r$$//' \"$$F\"; dos2unix \"$$F\" 2>/dev/null || true; \
	  done; done"

# ----------------------------
# Pre-clean existing PO files
# ----------------------------
i18n-clean: fix-line-endings
	$(EX) "set -e; for L in $(LOCALES); do \
	  for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/*.po; do [ -f \"$$F\" ] || continue; \
	    msguniq --use-first -o \"$$F\" \"$$F\"; \
	    msgattrib --clear-fuzzy -o \"$$F\" \"$$F\"; \
	    msgattrib --no-obsolete -o \"$$F\" \"$$F\"; \
	  done; done"

# ----------------------------
# Extract + Fix + Validate + Compile
# ----------------------------
i18n: i18n-clean
	# Extract Python/HTML/TXT
	$(EX) "set -euo pipefail; cd $(APPDIR) && PYTHONPATH=$(APPDIR)/backend DJANGO_SETTINGS_MODULE=chota_config.settings \
	  python -m django makemessages $(LOCALE_FLAGS) \
	  -e py,html,txt -i 'node_modules/*' -i '*migrations*' --no-location --no-wrap"

	# Extract JS
	$(EX) "set -euo pipefail; cd $(APPDIR) && PYTHONPATH=$(APPDIR)/backend DJANGO_SETTINGS_MODULE=chota_config.settings \
	  python -m django makemessages -d djangojs $(LOCALE_FLAGS) \
	  -e js -i 'node_modules/*' -i '*migrations*' -i '*.min.js' --no-location --no-wrap"

	# Normalize endings + pre-clean
	$(MAKE) fix-line-endings
	$(EX) "set -e; for L in $(LOCALES); do \
	  for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/*.po; do [ -f \"$$F\" ] || continue; \
	    msguniq --use-first -o \"$$F\" \"$$F\"; \
	    msgattrib --clear-fuzzy -o \"$$F\" \"$$F\"; \
	    msgattrib --no-obsolete -o \"$$F\" \"$$F\"; \
	  done; done"

	# enforce '\n' symmetry (Requires scripts/quick_nl_pass.py)
	# $(EX) "python $(APPDIR)/backend/scripts/quick_nl_pass.py --root $(LOCALE_DIR) --locales '$(LOCALES)'"

	# placeholders + header normalization (Requires scripts/fix_po.py)
	# $(EX) "python $(APPDIR)/backend/scripts/fix_po.py --root $(LOCALE_DIR) --locales '$(LOCALES)' --strip-stray"

	# final dedupe + strict symmetry pass
	$(EX) "set -e; for L in $(LOCALES); do \
	  for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/*.po; do [ -f \"$$F\" ] || continue; \
	    msguniq --use-first -o \"$$F\" \"$$F\"; \
	  done; done"
	# $(EX) "python $(APPDIR)/backend/scripts/force_nl_symmetry.py --root $(LOCALE_DIR) --locales '$(LOCALES)'"

	# validate per-file (auto-fix if needed)
	$(MAKE) validate-po-detailed

	# check coverage from templates
	$(MAKE) i18n-missing

	# compile + restart app so catalogs reload
	$(MAKE) i18n-compile

i18n-compile:
	$(EX) "set -euo pipefail; cd $(APPDIR) && PYTHONPATH=$(APPDIR)/backend DJANGO_SETTINGS_MODULE=chota_config.settings python -m django compilemessages -f"
	cd $(DOCKER_DIR) && docker compose restart $(SERVICE)

# ----------------------------
# Missing strings check
# ----------------------------
i18n-missing:
	$(EX) "set -euo pipefail; \
	  : > /tmp/_wanted.txt; \
	  { \
	    grep -Rho --include='*.html' \"{% *trans *\\\"[^\\\"]\\+\\\" *%}\" $(APPDIR)/frontend/templates $(APPDIR)/backend/*/templates \
	      | sed -E \"s/.*trans *\\\"(.*)\\\".*/\\1/\"; \
	    grep -Rho --include='*.html' \"{% *trans *'[^']\\+' *%}\" $(APPDIR)/frontend/templates $(APPDIR)/backend/*/templates \
	      | sed -E \"s/.*trans *'(.*)'.*/\\1/\"; \
	  } | sort -u > /tmp/_wanted.txt || true; \
	  : > /tmp/_found.txt; \
	  for L in $(LOCALES); do \
	    for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/django.po $(LOCALE_DIR)/$$L/LC_MESSAGES/djangojs.po; do \
	      [ -f \"$$F\" ] || continue; \
	      awk -F\\\" '/^msgid /{print $$2}' \"$$F\" >> /tmp/_found.txt; \
	    done; \
	  done; \
	  sort -u -o /tmp/_found.txt /tmp/_found.txt; \
	  echo '--- Missing msgids (wanted → not in any PO) ---'; \
	  missing=$$(comm -23 /tmp/_wanted.txt /tmp/_found.txt | tee /tmp/_missing.txt); \
	  if [ -n \"$$missing\" ]; then \
	    echo \"\nERROR: missing template strings in PO (see list above)\"; exit 1; \
	  else echo '(none)'; fi"

# ----------------------------
# Per-file validation with auto-fix
# ----------------------------
validate-po-detailed:
	$(EX) "set -e; for L in $(LOCALES); do \
	  for F in $(LOCALE_DIR)/$$L/LC_MESSAGES/*.po; do [ -f \"$$F\" ] || continue; \
	    echo '=== Validating' \"$$F\" '==='; \
	    if ! msgfmt --check \"$$F\" 2>/tmp/msgfmt_error_$$L.log; then \
	      echo 'Auto-fix attempts...'; \
	      msguniq --use-first -o \"$$F\" \"$$F\"; \
	      msgattrib --clear-fuzzy -o \"$$F\" \"$$F\"; \
	      msgattrib --no-obsolete -o \"$$F\" \"$$F\"; \
	      msgfmt --check \"$$F\" || (echo 'FATAL:' \"$$F\" && cat /tmp/msgfmt_error_$$L.log && exit 1); \
	    fi; \
	    echo '✓' \"$$F\" 'is valid'; \
	  done; done"

# Helpers
i18n-js:
	$(EX) "set -euo pipefail; cd $(APPDIR) && PYTHONPATH=$(APPDIR)/backend DJANGO_SETTINGS_MODULE=chota_config.settings \
	  python -m django makemessages -d djangojs $(LOCALE_FLAGS) -e js -i 'node_modules/*' -i '*migrations*' -i '*.min.js' --no-location --no-wrap"

i18n-reset-en:
	$(EX) "rm -rf $(LOCALE_DIR)/en && echo 'Removed EN locale'; true"

#--------------------------------------------
# Restart is the service without re-building
#--------------------------------------------
restart:
	$(DC) restart $(SERVICE)

# --------------------------------------------
# GIT PULL (Safe on VPS)
# Pull latest code from main branch while ignoring local images in root
# --------------------------------------------
pull:
	@echo "⚙️  Pulling latest changes from main (ignoring local root images)..."
	# Temporarily stash only tracked changes
	git stash push -m "temp-stash" || true
	# Remove large image files from root before pulling
	find . -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \) -exec rm -f {} \;
	# Pull latest changes
	git pull origin main
	# Restore stashed files (if any)
	git stash pop || true
	@echo "✅ Pull completed successfully."

logs:
	$(DC) logs -f --tail=200 $(SERVICE)

# ----------------------------
# Docker commands
# ----------------------------
docker-up:
	$(DC) up -d

docker-down:
	$(DC) down
