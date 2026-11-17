# Shared zsh validation helper. Missing/unreadable logs must fail, not pass.
check_log() {
  local scan_status=0
  /usr/bin/grep -E 'SCRIPT ERROR|Parse Error|^ERROR:|CHECK.*false|QA FAIL' "$1" || scan_status=$?
  case "$scan_status" in
    1) return 0 ;; # No failure markers.
    0) print -u2 "Validation errors in $1"; return 1 ;;
    *) print -u2 "Unable to scan validation log: $1"; return 1 ;;
  esac
}
