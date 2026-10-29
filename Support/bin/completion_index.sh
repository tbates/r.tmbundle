# Shared helpers for the daemon-less completion index.
# Sourced, never executed:
#   . "$TM_BUNDLE_SUPPORT/bin/completion_index.sh"
#
# Layout: $TM_R_COMPLETION_CACHE/completion.tsv  (alias<TAB>package, sorted)
#         $TM_R_COMPLETION_CACHE/completion.meta (libpath<TAB>mtime per lib)

: "${TM_R_COMPLETION_CACHE:=$HOME/Library/Caches/com.macromates.TextMate/R.tmbundle}"
TM_R_COMPLETION_INDEX="$TM_R_COMPLETION_CACHE/completion.tsv"
TM_R_COMPLETION_META="$TM_R_COMPLETION_CACHE/completion.meta"

tm_rscript() {
	# stdout: path to a working Rscript, else return 1
	[ -n "${TM_RSCRIPT:-}" ] && [ -x "$TM_RSCRIPT" ] && { echo "$TM_RSCRIPT"; return 0; }
	if [ -n "${TM_REXEC:-}" ]; then
		case "$TM_REXEC" in
			*/*) cand="$(dirname "$TM_REXEC")/Rscript"
				[ -x "$cand" ] && { echo "$cand"; return 0; } ;;
			*) r=$(command -v "$TM_REXEC" 2>/dev/null) && [ -n "$r" ] \
				&& [ -x "${r%/*}/Rscript" ] && { echo "${r%/*}/Rscript"; return 0; } ;;
		esac
	fi
	r=$(command -v Rscript 2>/dev/null) && [ -x "$r" ] && { echo "$r"; return 0; }
	for d in /usr/local/bin /opt/homebrew/bin /opt/R/bin \
		/Library/Frameworks/R.framework/Resources/bin; do
		[ -x "$d/Rscript" ] && { echo "$d/Rscript"; return 0; }
	done
	return 1
}

tm_index_stale() {
	# return 0 when the index must be (re)built
	[ -s "$TM_R_COMPLETION_INDEX" ] && [ -f "$TM_R_COMPLETION_META" ] || return 0
	while IFS='	' read -r lib mt; do
		[ -n "$lib" ] || continue
		cur=$(stat -f "%m" "$lib" 2>/dev/null) || return 0
		[ "$cur" = "$mt" ] || return 0
	done < "$TM_R_COMPLETION_META"
	return 1
}

tm_refresh_completion_index() {
	# rebuild unconditionally; prints "<n> completion entries" on success
	rs=$(tm_rscript) || { echo "No Rscript found (set TM_REXEC to your R binary)"; return 1; }
	[ -n "$TM_BUNDLE_SUPPORT" ] || { echo "TM_BUNDLE_SUPPORT is not set"; return 1; }
	mkdir -p "$TM_R_COMPLETION_CACHE" || return 1
	LC_ALL=C "$rs" --vanilla "$TM_BUNDLE_SUPPORT/bin/buildCompletionIndex.R" \
		"$TM_R_COMPLETION_INDEX" "$TM_R_COMPLETION_META"
}

tm_ensure_completion_index() {
	if tm_index_stale; then
		tm_refresh_completion_index
	else
		return 0
	fi
}

tm_complete_from_index() {
	# $1 = regex-escaped completion prefix; prints alias<TAB>package lines
	tm_ensure_completion_index || return 1
	LC_ALL=C grep -i "^$1" "$TM_R_COMPLETION_INDEX" 2>/dev/null
	return 0
}
