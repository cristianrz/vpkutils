#!/bin/sh -u
#
# Copyright (c) 2019, Cristian Ariza
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Installs packages and updates the git repo

###########
# Functions
###########

try() { "$@" || exit "$?"; }

quiet() {
	case "$verbose" in
		true) "$@" ;;
		*) "$@" > /dev/null ;;
	esac
}

vpkinit() {
	mkdir -p "$WORKDIR" || return "$?"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" init || return "$?"
}

vpkupdate() {
	dpkg-query -Wf '${Package}=${Version}\n' | sort > "$WORKDIR"/packages || return "$?"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" add packages -f || return "$?"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" commit -m "Sync"
	quiet apt-get update || return "$?"
}

vpkinstall() { apt-get install "$@"; }

vpkupgrade() { apt-get upgrade -y; }

vpkcommit() {
	dpkg-query -Wf '${Package}=${Version}\n' | sort > "$WORKDIR"/packages || return "$?"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" add packages -f || return "$?"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" commit -m "$1" || return "$?"
}

vpkcheckout() {
	TMP="$(mktemp)"
	quiet git --git-dir="$WORKDIR"/.git --work-tree="$WORKDIR" show \
		"$2":packages > "$TMP" || return "$?"

	eval "set -- $(comm -13 "$WORKDIR"/packages "$TMP")"
	apt-get install "$@" || return "$?"
	eval "set -- $(comm -23 "$WORKDIR"packages "$TMP")"
	apt-get --autoremove purge "$@" || return "$?"

	rm "$TMP" || return "$?"
	unset "$TMP"
}

usage() {
	printf 'pkutils v0.7.0 (C) Cristian Ariza

Usage: %s [-duv] [--help] [-c COMMITID] [PACKAGE]...\n' "$(basename "$0")" >&2
	exit "$1"
}

######
# Main
######

verbose=false
WORKDIR="/var/cache/vpk"

while test "$#" -gt 0; do
	arg="$1" && shift
	case "$arg" in
		"-v") verbose=true ;;
		"-d") set -x ;;
		"--help") usage 0 ;;
		"-c")
			action="checkout"
			break
			;;
		"-u")
			action="upgrade"
			break
			;;
		"-"*) usage 1 ;;
		*)
			action="install"
			set -- "$arg" "$@"
			break
			;;
	esac
done

if test ! -d "$WORKDIR"/.git; then
	try vpkinit
fi

try vpkupdate

if test -n "$action"; then
	try "vpk$action" "$@"
	try vpkcommit "$action $*"
fi

exit 0
