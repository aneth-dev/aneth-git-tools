#!/bin/bash

#.gitmodules sample with branch and sparse-checkout new parameters:
#[submodule "net.aeten.core"]
#	path = <path>
#	url = <url>
#	branch = <branch-name>
#	sparse-checkout = <path/to/foo>\n \
#							<path/to/bar>

#@@AETEN-CLI-INCLUDE@@

__api() {
	sed --quiet --regexp-extended 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' "${*}" 2>/dev/null
}

__usage() {
	local errno
	errno=${1}
	shift
	fatal --errno ${errno} "${@}"
	exit ${errno}
}

# Parameters: submodule
__check-submodule-name() {
	[ 1 -eq ${#} ] || { __usage 1 "Usage: ${FUNCNAME} submodule"; }
	submodule=$(git submodule status "${1}" 2>/dev/null | awk '{print $2}')
	[ -z "${submodule}" ] && { echo No submodule named ${1} >&2 ; exit 1; }
	echo ${submodule}
}

# Parameters: submodule
git-submodule-check() {
	local submodules
	local submodule
	local error
	if [ -z "${*}" ]; then
		submodules=$(git submodule status|awk '{print $2}')
	else
		submodules=${*}
	fi

	let error=0
	for submodule in ${submodules}; do
		check -m "Check submodule ${1}" test "$(git-submodule-checked-out ${1})" = "$(git-submodule-show-rev ${1})" || let error+=1
	done
	[ ${error} -eq 0 ] || fatal One or more submodule out of sync
}

# Parameters: submodule
git-submodule-checked-out() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	git --git-dir=.git/modules/${1} rev-parse HEAD
}

# Parameters: submodule
git-submodule-show-rev() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	git ls-files --error-unmatch --stage -- ${1} | awk '{print $2}'
}

# Parameters: --name <submodule> --branch <branch> --revision <revision>
__submodule-reset-shallow() {
	local usage
	local branch
	local revision
	local name
	local submodule
	local arg
	local depth
	local sparse_checkout
	local git_directory
	local url
	usage="${FUNCNAME} --name <module> --branch <branch> --revision <revision>"
	while test ${#} -ne 0; do
		case "${1}" in
			--branch) branch=${2} ; shift ;;
			--branch=*) branch=${1/--branch=/};;
			--revision) revision=${2} ; shift ;;
			--revision=*) revision=${1/--revision=/};;
			--name) name=${2}; shift; ;;
			--name=*) name=${1/--name=/};;
			*) __usage 1 Usage: ${usage};;
		esac
		shift
	done
	for arg in name branch revision; do
		[ -z "${!arg}" ] && __usage 1 ${usage}
	done
	submodule=$(__check-submodule-name ${name})
	[ 0 -eq ${?} ] || fatal --errno ${?} "invalid module name ${name}"

	let depth=1
	url=$(git config --file=.gitmodules --get submodule.${submodule}.url)
	sparse_checkout=$(git config --file=.gitmodules --get submodule.${submodule}.sparse-checkout | sed --regexp-extended 's/(^\s+)|(\s$)//')
	git_directory=.git/modules/${submodule}
	rm -rf ${git_directory}
	check -l warn -m "Backup ${submodule} to ${submodule}~" mv ${submodule}{,~} || rm -rf ${submodule}
	mkdir --parent $(dirname ${git_directory})
	check -m "Shallow clone ${url} on branch ${branch} (depth ${depth})" git clone --no-checkout --depth ${depth} --branch ${branch} --separate-git-dir=${git_directory} ${url} ${submodule}
	[ -d ${submodule}~ ] && check -l warn -m "Delete backup ${submodule}~" rm -rf ${submodule}~
	if [ ! -z "${sparse_checkout}" ]; then
		git config --file=${git_directory}/config core.sparsecheckout true
		echo "${sparse_checkout}" > ${git_directory}/info/sparse-checkout
	fi
	(
		cd ${submodule}
		while ! git rev-list ${revision} &>/dev/null; do
			((depth+=1))
			check -m "Shallow fetch ${submodule} (depth ${depth})" git fetch --depth=${depth} origin
		done
		check -m "Checkout ${submodule} (${revision})" git checkout --force ${revision}
	)
}

# Parameters: [--help] [--init] [--branch <branch>] -- [submodule1 [submodule2 [...]]]
git-submodule-reset-shallow() {
	local usage
	local init
	local branch
	local revision
	usage="\t${FUNCNAME} [--help]
\t${FUNCNAME} [--init] [--branch <branch>] -- [<submodule1> [<submodule2> [...]]]
\t${FUNCNAME} --branch <branch> --revision <revision> [--] <submodule>"
	let init=0
	while test ${#} -ne 0; do
		case "${1}" in
			--init|-i) let init=1;;
			--branch|-b) branch=${2} ; shift;;
			--branch=*) branch=${1/--branch=/};;
			--revision|r) revision=${2} ; shift;;
			--revision=*) revision=${1/--revision=/};;
			--help) __usage 0 ${usage};;
			--) shift; break;;
			-*) __usage 1 "Usage:\n${usage}";;
			*) break;;
		esac
		shift
	done
	unset -f usage

	if [ ! -z "${revision}" ] && [ 1 -ne ${#} ]; then
		__usage 1 "Usage:\n${usage}"
	fi

	# Check all modules before run update
	for submodule in ${*}; do
		__check-submodule-name "${submodule}" >/dev/null || fatal "Check submodule name ${submodule}"
	done

	if [ -z "${*}" ]; then
		[ 1 -eq $init ] && echo Initialize all submodules && git submodule init && let init=0
		submodules=$(git submodule status|awk '{print $2}')
	else
		submodules=${*}
	fi

	for submodule in ${submodules}; do
		submodule=$(__check-submodule-name ${submodule})
		[ 1 -eq $init ] && check -m "Initialize submodule ${submodule}" git submodule init ${submodule}
		if [ -z "${branch}" ]; then
			branch=$(git config --file=.gitmodules --get submodule.${submodule}.branch)
			[ -z "${revision}" ] && revision=$(git-submodule-show-rev ${submodule})
		else
			[ -z "${revision}" ] && revision=HEAD
		fi
		__submodule-reset-shallow --name ${submodule} --branch ${branch} --revision ${revision}
	done
}

if [ -L "${0}" ] && [ 1 -eq $(__api "${0}"|grep "^$(basename ${0})$"|wc -l) ]; then
	$(basename ${0}) "${@}"
elif [ ! -L "${0}" ]; then
	cmd=${1}
	if [ 1 -eq $(__api "${0}"|grep "^${cmd}$"|wc -l) ]; then
		shift
		${cmd} "${@}"
	fi
fi
