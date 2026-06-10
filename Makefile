# CLI d'installation des skills de ce repo vers ~/.claude.
#
# Les skills sont découverts dynamiquement dans .claude/skills/*.
# Chaque skill <name> possède :
#   - .claude/skills/<name>/      (SKILL.md + references/…)
#   - .claude/commands/<name>/    (ses slash commands ; le sous-dossier est un
#     namespace d'organisation, le nom des commandes reste celui des fichiers)
#
# Usage :
#   make list                  # skills disponibles dans le repo
#   make install               # installe tous les skills
#   make install SKILL=foo     # installe un seul skill
#   make diff                  # diff repo ↔ ~/.claude (tous les skills)
#   make diff SKILL=foo        # diff pour un seul skill
#   make uninstall SKILL=foo   # retire un skill de ~/.claude (confirmation)
#   make uninstall             # retire tous les skills (confirmation)

CLAUDE_DIR    := $(HOME)/.claude
SKILLS_SRC    := .claude/skills
COMMANDS_SRC  := .claude/commands
SKILLS_DEST   := $(CLAUDE_DIR)/skills
COMMANDS_DEST := $(CLAUDE_DIR)/commands

ALL_SKILLS := $(notdir $(wildcard $(SKILLS_SRC)/*))
SKILLS     := $(if $(SKILL),$(SKILL),$(ALL_SKILLS))

.PHONY: help list install sync diff uninstall check-skill

help:
	@echo "Targets :"
	@echo "  make list                 Liste les skills du repo"
	@echo "  make install [SKILL=x]    Sync skill(s) + commands vers ~/.claude"
	@echo "  make diff [SKILL=x]       Diff entre le repo et ~/.claude"
	@echo "  make uninstall [SKILL=x]  Retire skill(s) de ~/.claude (confirmation)"

list:
	@for s in $(ALL_SKILLS); do \
		if [ -d $(SKILLS_DEST)/$$s ]; then state="installé"; else state="non installé"; fi; \
		echo "  $$s ($$state)"; \
	done

check-skill:
	@for s in $(SKILLS); do \
		if [ ! -d $(SKILLS_SRC)/$$s ]; then \
			echo "Skill inconnu : $$s (voir 'make list')"; exit 1; \
		fi; \
	done

install: sync

sync: check-skill
	@mkdir -p $(SKILLS_DEST) $(COMMANDS_DEST)
	@for s in $(SKILLS); do \
		rsync -a --delete $(SKILLS_SRC)/$$s/ $(SKILLS_DEST)/$$s/; \
		if [ -d $(COMMANDS_SRC)/$$s ]; then \
			rsync -a --delete $(COMMANDS_SRC)/$$s/ $(COMMANDS_DEST)/$$s/; \
		fi; \
		echo "Installé : $$s"; \
	done

diff: check-skill
	@for s in $(SKILLS); do \
		echo "=== $$s : skill (repo → ~/.claude) ==="; \
		if [ -d $(SKILLS_DEST)/$$s ]; then \
			diff -ru $(SKILLS_SRC)/$$s $(SKILLS_DEST)/$$s || true; \
		else \
			echo "  non installé — lance 'make install SKILL=$$s'."; \
		fi; \
		echo ""; \
		if [ -d $(COMMANDS_SRC)/$$s ]; then \
			echo "=== $$s : commands (repo → ~/.claude) ==="; \
			if [ -d $(COMMANDS_DEST)/$$s ]; then \
				diff -ru $(COMMANDS_SRC)/$$s $(COMMANDS_DEST)/$$s || true; \
			else \
				echo "  non installées — lance 'make install SKILL=$$s'."; \
			fi; \
			echo ""; \
		fi; \
	done

uninstall: check-skill
	@printf "Retirer de ~/.claude : $(SKILLS) ? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf $(SKILLS_DEST)/$$s $(COMMANDS_DEST)/$$s; \
			echo "Désinstallé : $$s"; \
		done; \
	else \
		echo "Annulé."; \
	fi
