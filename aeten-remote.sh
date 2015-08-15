#!/bin/bash

#.gitmodules sample with branch and sparse-checkout new parameters:
#[submodule "net.aeten.core"]
#	path = <path>
#	url = <url>
#	branch = <branch-name>
#	sparse-checkout = <path/to/foo>\n \
#							<path/to/bar>

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

__download_object() {
	local tmp_dir
	local repo
	local sha
	local object_dir
	local object_file

	repo="$1"
	sha=$2
	tmp_dir="$3"
	object_dir="objects/$(echo $sha|sed 's/\([0-9a-z]\{2\}\).*/\1/')"
	object_file="${object_dir}/$(echo $sha|sed 's/[0-9a-z]\{2\}\(.*\)/\1/')"
	[ -f "${tmp_dir}/${object_file}" ] && return 0
	[ -f "${tmp_dir}/config" ] || check --quiet --message "Init temporary git repository '$tmp_dir'" git --git-dir "$tmp_dir" init --bare
	[ -d "${tmp_dir}/${object_dir}" ] || mkdir "${tmp_dir}/${object_dir}"
	check --quiet --message "Downloading $sha from '$(__hostname_from_url $repo)'" wget -O "${tmp_dir}/${object_file}" "${repo}/${object_file}"
}

git-remote-ls() {
	local repo
	local ref
	local usage
	local tmp_dir
	local sha
	local tree
	usage="${FUNCNAME} <repository-url> [<commit>|<tree>]"
	[ ${#} -gt 2 ] || [ ${#} -eq 0 ] && __usage 1 "Usage: ${usage}"
	repo="$1"
	ref="$2"
	: ${ref:=HEAD}
	while [ ${#} -ne 0 ]; do
		case "${1}" in
      	-h|--help) __usage 0 "Usage: ${usage}" ;;
		esac
		shift
	done

	tmp_dir="/tmp/cache/$(basename $(readlink -f "$0"))/$(__repo_from_url $repo)"
	[ -d "$tmp_dir" ] || mkdir --parent "$tmp_dir"
	if echo "$ref"|grep --quiet '^[0-9a-z]\{40\}$'; then
		sha="$ref"
	else
		sha=$(git ls-remote "$repo" "$ref"|awk '{print $1}')
	fi
	__download_object "$repo" $sha "$tmp_dir"
	if [ "commit" = $(git --git-dir "$tmp_dir" cat-file -t $sha) ]; then
		sha=$(git --git-dir "$tmp_dir" cat-file -p $sha|awk '/^tree / {print $2}')
		__download_object "$repo" $sha "$tmp_dir"
	fi
	git --git-dir "$tmp_dir" cat-file -p $sha
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
