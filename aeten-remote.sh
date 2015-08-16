#!/bin/bash

__api() {
	sed --quiet --regexp-extended 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' "${*}" 2>/dev/null
}

__usage() {
	local errno
	errno=${1}
	shift
	$([ ${errno} -eq 0 ] && echo inform || echo fatal --errno ${errno}) "${@}"
	exit ${errno}
}

__repo_from_url() {
	echo "$@"|sed 's@.*://@@g'
}

__hostname_from_url() {
	echo "$@"|awk -F/ '{print $3}'
}

__wget() {
	local msg
	local src
	local dst
	local errcode
	msg="$1"
	[ $# -eq 3 ] && shift
	src="$1"
	dst="$2"
	wget -O "$dst" "$src" &>/dev/null
	errcode=$?
	case $errcode in
		0) ;; # No problems occurred
		1) \rm -f "$dst"; error --errno $errcode "${msg}: wget generic error";;
		2) \rm -f "$dst"; error --errno $errcode "${msg}: wget parsing error";;
		3) \rm -f "$dst"; error --errno $errcode "${msg}: wget file I/O error";;
		4) \rm -f "$dst"; error --errno $errcode "${msg}: wget network failure";;
		5) \rm -f "$dst"; error --errno $errcode "${msg}: wget SSL verification failure";;
		6) \rm -f "$dst"; error --errno $errcode "${msg}: wget authentication failure";;
		7) \rm -f "$dst"; error --errno $errcode "${msg}: wget protocol error";;
		8) \rm -f "$dst"; error --errno $errcode "${msg}: wget server issued an error response";;
		*) \rm -f "$dst"; error --errno $errcode "${msg}: wget unknown error ($errcode)";;
	esac
	return $errcode
}

__mkdir() {
	[ -d "$1" ] || check --quiet mkdir --parent "$1"
}

__download_object() {
	local tmp_dir
	local repo
	local ref
	local sha
	local object_dir
	local object_file
	local msg
	local errcode
	local idx_name
	local idx_offset
	repo="$1"
	ref="$2"
	tmp_dir="$3"
	idx_offset=$((8*8 + 256*8))

	[ -f "${tmp_dir}/config" ] || {
		__mkdir "$tmp_dir"
		check --quiet --message "Init temporary git repository '$tmp_dir'" git --git-dir "$tmp_dir" init --bare
		__mkdir "${tmp_dir}/info"
	}
	if echo "$ref"|grep --quiet '^[0-9a-z]\{40\}$'; then
		sha="$ref"
	else
		if [ "$ref" = HEAD ]; then
			__wget "${repo}/HEAD" "${tmp_dir}/HEAD"
		else
			__wget "${repo}/info/refs" "${tmp_dir}/info/refs"
		fi

		for record in "$(< "${tmp_dir}/info/refs")"; do
			sha=$(echo $record|awk '{print $1}')
			reference=$(echo $record|awk '{print $2}')
			if [ "$ref" = "$(basename $reference)" ]; then
				__mkdir $(dirname "${tmp_dir}/$reference")
				( __wget "${repo}/$reference" "${tmp_dir}/$reference" && __download_object $repo $sha $tmp_dir > /dev/null)
				sha=$(git --git-dir "$tmp_dir" rev-parse $ref)
				break
			fi
		done
		[ -n "$sha" ] || fatal "Unable to get $ref on $repo"
	fi
	git --git-dir "$tmp_dir" cat-file -e $sha && { echo $sha; return 0; }
	object_dir="objects/$(echo $sha|sed 's/\([0-9a-z]\{2\}\).*/\1/')"
	object_file="${object_dir}/$(echo $sha|sed 's/[0-9a-z]\{2\}\(.*\)/\1/')"
	[ -f "${tmp_dir}/${object_file}" ] && [ $ref = $sha ] && { echo $sha; return 0; }
	[ -d "${tmp_dir}/${object_dir}" ] || mkdir "${tmp_dir}/${object_dir}"
	__wget "Downloading $sha from '$(__hostname_from_url $repo)'" "${repo}/${object_file}" "${tmp_dir}/${object_file}" &>/dev/null
	errcode=$?
	case $errcode in
		0) ;; # No problems occurred
		8) # Maybe packed?
			__wget "Downloading pack info from '$(__hostname_from_url $repo)'" "${repo}/packed-refs" "${tmp_dir}/packed-refs" || return $errcode
			wget -r --directory-prefix=${tmp_dir}/objects/pack --no-directories --accept '*.idx' --include-directories=$(echo $repo|sed "s@.*://$(__hostname_from_url $repo)/@@")/objects/pack/ ${repo}/objects/pack/ &>/dev/null
			for idx in $(find ${tmp_dir}/objects/pack/ -name '*.idx'); do
				if hexdump -s $idx_offset -e '20/1 "%02x" "\n"' $idx | grep --quiet "^$sha\$"; then
					idx_name=$(basename $idx .idx)
					__wget "${repo}/objects/pack/${idx_name}.pack" "${tmp_dir}/objects/pack/${idx_name}.pack"
					break
				fi
			done
		;;
		*) return $errcode;;
	esac
	echo $sha
	return 0
}

git-remote-ls() {
	local repo
	local ref
	local usage
	local tmp_dir
	local sha
	local tree
	local errcode
	local recurse
	usage="${FUNCNAME} <repository-url> [<commit>|<tree>]"
	while [ ${#} -ne 0 ]; do
		case "${1}" in
      	-h|--help) __usage 0 "Usage: ${usage}" ;;
#TODO			-r|--recurse) ;;
			--) ;;
			*) break;;
		esac
		shift
	done

	[ ${#} -gt 2 ] || [ ${#} -eq 0 ] && __usage 1 "Usage: ${usage}"
	repo="$1"
	ref="$2"
	: ${ref:=HEAD}

	tmp_dir="/tmp/cache/$(basename $(readlink -f $0))/$(__repo_from_url $repo)"
	sha=$(__download_object "$repo" "$ref" "$tmp_dir")
	errcode=$?
	[ $errcode = 0 ] || exit $errcode
	if [ "commit" = "$(git --git-dir="$tmp_dir" cat-file -t $sha)" ]; then
		sha=$(git --git-dir "$tmp_dir" cat-file -p $sha|awk '/^tree / {print $2}')
	fi
	git --git-dir "$tmp_dir" cat-file -p $sha || {
		__download_object "$repo" $sha "$tmp_dir"
		git --git-dir "$tmp_dir" cat-file -p $sha
	}
}

#@@AETEN-CLI-INCLUDE@@

if [ -L "${0}" ] && [ 1 -eq $(__api "${0}"|grep "^$(basename ${0})$"|wc -l) ]; then
	$(basename ${0}) "${@}"
elif [ ! -L "${0}" ]; then
	cmd=${1}
	case "$cmd" in
		-h|--help) __api "${0}";;
		__api) __api "${0}";;
		*) if [ 1 -eq $(__api "${0}"|grep "^${cmd}$"|wc -l) ]; then
			shift
			${cmd} "${@}"
		else
			__usage 1 "Invalid command"
		fi ;;
	esac
fi
