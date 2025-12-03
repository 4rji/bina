#!/usr/bin/env bash
set -euo pipefail

QUIET=0
INTERACTIVE=1
USE_PAGER=auto # auto|always|never

usage() {
  cat <<EOF
CCDC Defensive Persistence Audit (systemd)
Usage: $0 [options]

Options:
  -q, --quiet           Salida reducida (resúmenes clave)
  -n, --no-interactive  No pausar entre secciones
  -p, --pager[=mode]    Paginado: auto (por defecto), always, never
  -h, --help            Mostrar ayuda
EOF
}

PAGER_CMD=""

setup_pager() {
  # Decide pager based on USE_PAGER and TTY
  local tty=0
  if [ -t 1 ]; then tty=1; fi
  case "$USE_PAGER" in
    always)
      : ;;
    never)
      return ;;
    auto)
      [ "$tty" -eq 1 ] || return ;;
    *) : ;;
  esac
  if command -v less >/dev/null 2>&1; then
    PAGER_CMD="less -RFSX"
  elif command -v more >/dev/null 2>&1; then
    PAGER_CMD="more"
  else
    PAGER_CMD=""
  fi
}

run_with_pager() {
  if [ -n "$PAGER_CMD" ]; then
    eval "$PAGER_CMD"
  else
    cat
  fi
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      -q|--quiet) QUIET=1 ;;
      -n|--no-interactive) INTERACTIVE=0 ;;
      -p|--pager) USE_PAGER=always ;;
      --pager=always) USE_PAGER=always ;;
      --pager=never) USE_PAGER=never ;;
      --pager=auto) USE_PAGER=auto ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Opción no reconocida: $arg" >&2; usage; exit 2 ;;
    esac
  done
}

# CCDC Defensive Persistence Audit
# Focus: systemd services (expandable to more checks later)
# Runs read-only diagnostics and prints concise, greppable sections.

banner() { printf "\n==== %s ====\n" "$1"; }
sub() { printf "\n-- %s --\n" "$1"; }

pause_step() {
  [ "$INTERACTIVE" -eq 1 ] || return
  printf "\n[Enter para continuar, cualquier tecla también. Ctrl-C para salir] "
  if [ -t 0 ]; then
    IFS= read -r -s -n1 _key || true
  else
    sleep 0.2
  fi
  printf "\n"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[WARN] Missing command: $cmd" >&2
    return 1
  fi
}

print_expected() {
  cat <<'EOF'
Expected indicators to review:
- Restart policies: Restart=always, Restart=on-failure, RestartSec>0
- Non-standard service names or odd locations
- WantedBy/Install sections enabling auto-start
- Services not part of base OS profile
EOF
}

list_systemd_services() {
  if ! require_cmd systemctl; then
    echo "systemctl not available; skipping systemd checks."; return
  fi

  banner "Systemd services (all)"
  sub "systemctl list-units --type=service --all"
  if [ "$QUIET" -eq 1 ]; then
    # resumen: unidad, estado, descripción
    systemctl list-units --type=service --all --no-pager 2>/dev/null | awk 'NR==1 || NF{print $1, $3, "|", substr($0, index($0,$5))}' || true
  else
    systemctl list-units --type=service --all --no-pager 2>/dev/null || true
  fi | run_with_pager
  pause_step

  banner "Service unit files in common dirs"
  for d in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system; do
    if [ -d "$d" ]; then
      sub "ls -l $d"
      if [ "$QUIET" -eq 1 ]; then
        ls -1 "$d" 2>/dev/null || true
      else
        ls -l "$d" 2>/dev/null || true
      fi
    fi
  done | run_with_pager
  pause_step

  banner "Services with Restart directives"
  # Search installed unit files for Restart
  # Ignore comments and show filename:line
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading -e '^[^#]*\bRestart\s*=\s*(always|on-failure|on-abort)' \
      /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system 2>/dev/null || true
  else
    grep -RInE '^[^#]*\bRestart\s*=\s*(always|on-failure|on-abort)' \
      /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system 2>/dev/null || true
  fi | run_with_pager
  pause_step

  banner "Enabled services (boot start)"
  sub "systemctl list-unit-files --type=service --state=enabled"
  if [ "$QUIET" -eq 1 ]; then
    systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null | awk 'NR==1 || $2=="enabled"{print $1, $2}'
  else
    systemctl list-unit-files --type=service --state=enabled --no-pager 2>/dev/null || true
  fi | run_with_pager
  pause_step

  banner "Potentially anomalous: services not from base dirs"
  # Show linked/override units and drop-ins
  sub "Overrides and drop-ins"
  if command -v systemctl >/dev/null 2>&1; then
    # Iterate enabled service names and show cat for quick triage
    while IFS= read -r svc; do
      [ -z "$svc" ] && continue
      echo "--- $svc ---"
      if [ "$QUIET" -eq 1 ]; then
        systemctl cat "$svc" --no-pager 2>/dev/null | awk 'BEGIN{show=0} /^[[:space:]]*\[Service\]/{show=1} show && /^[[:space:]]*Restart(=|Sec=)/{print "    "$0} /^\[/{if($0!~"\\[Service\\]") show=0}'
      else
        systemctl cat "$svc" --no-pager 2>/dev/null | sed 's/^/    /' || true
      fi
    done < <(systemctl list-unit-files --type=service --state=enabled --no-pager | awk 'NR>1 && $1 ~ /\.service$/ {print $1}')
  fi | run_with_pager
  pause_step
}

main() {
  parse_args "$@"
  setup_pager
  banner "CCDC Defensive Persistence Audit"
  print_expected
  list_systemd_services
}

main "$@"
