# CLI locale pour installer les skills canoniques vers Claude Code et Codex.
#
# Usage :
#   make list
#   make install-claude [SKILL=foo]
#   make install-codex  [SKILL=foo]
#   make install-all    [SKILL=foo]
#   make install AGENT=claude|codex|all [SKILL=foo]
#   make diff-claude|diff-codex|diff-all [SKILL=foo]
#   make uninstall-claude|uninstall-codex|uninstall-all [SKILL=foo]
#   make validate

CLAUDE_DIR         := $(HOME)/.claude
CODEX_DIR          := $(HOME)/.agents
SKILLS_SRC         := skills
CLAUDE_SKILLS_DEST := $(CLAUDE_DIR)/skills
CODEX_SKILLS_DEST  := $(CODEX_DIR)/skills

ALL_SKILLS := $(notdir $(wildcard $(SKILLS_SRC)/*))
SKILLS     := $(if $(SKILL),$(SKILL),$(ALL_SKILLS))
AGENT      ?= claude

.PHONY: help list check-skill sync \
	install install-all install-claude install-codex \
	diff diff-all diff-claude diff-codex \
	uninstall uninstall-all uninstall-claude uninstall-codex \
	validate

help:
	@echo "Targets :"
	@echo "  make list                              État d'installation par agent"
	@echo "  make install-claude [SKILL=x]          Installe vers ~/.claude"
	@echo "  make install-codex  [SKILL=x]          Installe vers ~/.agents"
	@echo "  make install-all    [SKILL=x]          Installe vers les deux agents"
	@echo "  make install AGENT=claude|codex|all    Variante générique"
	@echo "  make diff-<agent> [SKILL=x]             Compare repo et installation"
	@echo "  make uninstall-<agent> [SKILL=x]        Désinstalle avec confirmation"
	@echo "  make validate                           Valide structure et manifests"

list:
	@for s in $(ALL_SKILLS); do \
		if [ -d "$(CLAUDE_SKILLS_DEST)/$$s" ]; then claude="installé"; else claude="absent"; fi; \
		if [ -d "$(CODEX_SKILLS_DEST)/$$s" ]; then codex="installé"; else codex="absent"; fi; \
		printf "  %-20s claude: %-9s codex: %s\n" "$$s" "$$claude" "$$codex"; \
	done

check-skill:
	@for s in $(SKILLS); do \
		if [ ! -d "$(SKILLS_SRC)/$$s" ]; then \
			echo "Skill inconnu : $$s (voir 'make list')"; exit 1; \
		fi; \
	done

install: install-$(AGENT)

install-all: install-claude install-codex

# Compatibilité avec l'ancien Makefile : `make sync` reste Claude-only.
sync: install-claude

install-claude: check-skill
	@mkdir -p "$(CLAUDE_SKILLS_DEST)"
	@for s in $(SKILLS); do \
		rsync -a --delete "$(SKILLS_SRC)/$$s/" "$(CLAUDE_SKILLS_DEST)/$$s/"; \
		echo "Claude installé : $$s"; \
	done

install-codex: check-skill
	@mkdir -p "$(CODEX_SKILLS_DEST)"
	@for s in $(SKILLS); do \
		rsync -a --delete "$(SKILLS_SRC)/$$s/" "$(CODEX_SKILLS_DEST)/$$s/"; \
		echo "Codex installé : $$s"; \
	done

diff: diff-$(AGENT)

diff-all: diff-claude diff-codex

diff-claude: check-skill
	@for s in $(SKILLS); do \
		echo "=== $$s : skill (repo → ~/.claude) ==="; \
		if [ -d "$(CLAUDE_SKILLS_DEST)/$$s" ]; then \
			diff -ru "$(SKILLS_SRC)/$$s" "$(CLAUDE_SKILLS_DEST)/$$s" || true; \
		else \
			echo "  non installé — lance 'make install-claude SKILL=$$s'."; \
		fi; \
	done

diff-codex: check-skill
	@for s in $(SKILLS); do \
		echo "=== $$s : skill (repo → ~/.agents) ==="; \
		if [ -d "$(CODEX_SKILLS_DEST)/$$s" ]; then \
			diff -ru "$(SKILLS_SRC)/$$s" "$(CODEX_SKILLS_DEST)/$$s" || true; \
		else \
			echo "  non installé — lance 'make install-codex SKILL=$$s'."; \
		fi; \
	done

uninstall: uninstall-$(AGENT)

uninstall-all: check-skill
	@printf "Retirer de ~/.claude et ~/.agents : $(SKILLS) ? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CLAUDE_SKILLS_DEST)/$$s" "$(CODEX_SKILLS_DEST)/$$s"; \
			echo "Désinstallé des deux agents : $$s"; \
		done; \
	else \
		echo "Annulé."; \
	fi

uninstall-claude: check-skill
	@printf "Retirer de ~/.claude : $(SKILLS) ? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CLAUDE_SKILLS_DEST)/$$s"; \
			echo "Claude désinstallé : $$s"; \
		done; \
	else \
		echo "Annulé."; \
	fi

uninstall-codex: check-skill
	@printf "Retirer de ~/.agents : $(SKILLS) ? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CODEX_SKILLS_DEST)/$$s"; \
			echo "Codex désinstallé : $$s"; \
		done; \
	else \
		echo "Annulé."; \
	fi

validate: check-skill
	@for s in $(ALL_SKILLS); do \
		file="$(SKILLS_SRC)/$$s/SKILL.md"; \
		test -f "$$file" || { echo "SKILL.md manquant : $$s"; exit 1; }; \
		test "$$(sed -n '1p' "$$file")" = "---" || { echo "Frontmatter invalide : $$s"; exit 1; }; \
		grep -Fqx "name: $$s" "$$file" || { echo "Nom invalide : $$s"; exit 1; }; \
		grep -Eq '^description: .+' "$$file" || { echo "Description manquante : $$s"; exit 1; }; \
		test -f "$(SKILLS_SRC)/$$s/agents/openai.yaml" || { echo "agents/openai.yaml manquant : $$s"; exit 1; }; \
		for ref in $$(grep -Eo 'references/[a-z0-9-]+\.md' "$$file" | sort -u); do \
			test -f "$(SKILLS_SRC)/$$s/$$ref" || { echo "Référence manquante : $$s/$$ref"; exit 1; }; \
		done; \
		for agent_dir in .claude .agents; do \
			link="$$agent_dir/skills/$$s"; \
			test -L "$$link" || { echo "Symlink manquant : $$link"; exit 1; }; \
			test -f "$$link/SKILL.md" || { echo "Symlink cassé : $$link"; exit 1; }; \
			test "$$(readlink "$$link")" = "../../skills/$$s" || { echo "Cible inattendue : $$link"; exit 1; }; \
		done; \
	done
	@python3 -m json.tool .claude-plugin/plugin.json >/dev/null
	@python3 -m json.tool .codex-plugin/plugin.json >/dev/null
	@if command -v ruby >/dev/null 2>&1; then \
		ruby -ryaml -e 'ARGV.each { |f| text = File.read(f); if f.end_with?("/SKILL.md"); match = text.match(/\A---\n(.*?)\n---/m); raise "frontmatter missing: #{f}" unless match; text = match[1]; end; YAML.parse_stream(text) }' \
			$(addsuffix /SKILL.md,$(addprefix $(SKILLS_SRC)/,$(ALL_SKILLS))) \
			$(addsuffix /agents/openai.yaml,$(addprefix $(SKILLS_SRC)/,$(ALL_SKILLS))); \
	else \
		echo "Ruby absent : parsing YAML complet ignoré (contrôles structurels effectués)."; \
	fi
	@echo "Validation locale OK : $(words $(ALL_SKILLS)) skills, vues Claude/Codex et manifests JSON."
