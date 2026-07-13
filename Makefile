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

# Codex : le validateur skill-creator n'accepte que name, description, allowed-tools,
# license, metadata dans le frontmatter. La clé Claude-only `argument-hint` (aide
# d'autocomplétion) est donc strippée de la copie installée — le runtime Codex tolère
# la clé, mais l'installation reste conforme à leur validateur.
install-codex: check-skill
	@mkdir -p "$(CODEX_SKILLS_DEST)"
	@for s in $(SKILLS); do \
		rsync -a --delete "$(SKILLS_SRC)/$$s/" "$(CODEX_SKILLS_DEST)/$$s/"; \
		file="$(CODEX_SKILLS_DEST)/$$s/SKILL.md"; \
		grep -v '^argument-hint:' "$$file" > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
		echo "Codex installé : $$s (frontmatter sans argument-hint)"; \
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
		echo "=== $$s : skill (repo → ~/.agents, argument-hint strippé à l'install) ==="; \
		if [ -d "$(CODEX_SKILLS_DEST)/$$s" ]; then \
			diff -ru -x SKILL.md "$(SKILLS_SRC)/$$s" "$(CODEX_SKILLS_DEST)/$$s" || true; \
			grep -v '^argument-hint:' "$(SKILLS_SRC)/$$s/SKILL.md" \
				| diff -u - "$(CODEX_SKILLS_DEST)/$$s/SKILL.md" || true; \
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

# Clés de frontmatter autorisées dans la source canonique : intersection Claude/Codex
# plus `argument-hint` (Claude-only, strippée par install-codex — cf. commentaire de
# la target). Toute autre clé casserait l'un des deux écosystèmes.
FRONTMATTER_KEYS := name description argument-hint allowed-tools license metadata

validate: check-skill
	@for s in $(ALL_SKILLS); do \
		file="$(SKILLS_SRC)/$$s/SKILL.md"; \
		test -f "$$file" || { echo "SKILL.md manquant : $$s"; exit 1; }; \
		test "$$(sed -n '1p' "$$file")" = "---" || { echo "Frontmatter invalide : $$s"; exit 1; }; \
		grep -Fqx "name: $$s" "$$file" || { echo "Nom invalide : $$s"; exit 1; }; \
		grep -Eq '^description: .+' "$$file" || { echo "Description manquante : $$s"; exit 1; }; \
		for k in $$(awk '/^---$$/{n++; next} n==1 && /^[A-Za-z][A-Za-z-]*:/{sub(/:.*/,""); print}' "$$file"); do \
			case " $(FRONTMATTER_KEYS) " in \
				*" $$k "*) ;; \
				*) echo "Clé frontmatter non portable dans $$s/SKILL.md : $$k (autorisées : $(FRONTMATTER_KEYS))"; exit 1 ;; \
			esac; \
		done; \
		test -f "$(SKILLS_SRC)/$$s/agents/openai.yaml" || { echo "agents/openai.yaml manquant : $$s"; exit 1; }; \
		for src in "$$file" $$(ls "$(SKILLS_SRC)/$$s/references/"*.md 2>/dev/null); do \
			for ref in $$(grep -Eo 'references/[a-z0-9-]+\.md' "$$src" | sort -u); do \
				test -f "$(SKILLS_SRC)/$$s/$$ref" || { echo "Référence manquante : $$s/$$ref (citée par $$src)"; exit 1; }; \
			done; \
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
	@if command -v claude >/dev/null 2>&1; then \
		claude plugin validate . >/dev/null && echo "claude plugin validate : OK"; \
	else \
		echo "claude CLI absent : 'claude plugin validate .' ignoré."; \
	fi
	@echo "Validation locale OK : $(words $(ALL_SKILLS)) skills, vues Claude/Codex et manifests JSON."
