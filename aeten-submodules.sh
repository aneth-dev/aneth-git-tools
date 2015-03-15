#!/bin/bash

#.gitmodules sample with branch and sparse-checkout new parameters:
#[submodule "net.aeten.core"]
#	path = <path>
#	url = <url>
#	branch = <branch-name>
#	sparse-checkout = <path/to/foo>\
#	                \n<path/to/bar>

__colorize() {
	local color=$1
	shift
	echo $(tput colors 2>/dev/null | grep -q 8 && echo -e "\033[${color}${*}\033[0;0m" || echo "${*}")
}

__tag() {
	echo -e "\r${OPEN_BRACKET}${1}${CLOSE_BRACKET}${RESTORE_CURSOR_POSITION}"
}

SAVE_CURSOR_POSITION='\033[s'
RESTORE_CURSOR_POSITION='\033[u'
MOVE_CURSOR_UP='\033[1A'
INFO=$(__colorize '1;37m' INFO)
WARN=$(__colorize '1;33m' WARN)
PASS=$(__colorize '1;32m' PASS)
FAIL=$(__colorize '1;31m' FAIL)
ERROR=${FAIL}
OPEN_BRACKET=$(__colorize '0;37m' '[ ')
CLOSE_BRACKET=$(__colorize '0;37m' ' ]')
EMPTY_TAG=$(printf "%4s")

__log() {
	local level=${1}; shift
	while test ${#} -ne 0; do
		case "${1}" in
			-*) args+=" ${1}"; shift;;
			*) shift; break ;;
		esac
	done
	echo -en "\r${OPEN_BRACKET}${level}${CLOSE_BRACKET} "
	echo ${args} "${*}"
}

info() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	__log "${INFO}" "${*}"
}
pass() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	__log "${PASS}" "${*}"
}
warn() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	__log "${WARN}" "${*}"
}
error() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}"
}
fatal() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	__log "${FAIL}" "${*}"
	exit 1
}

query() {
	[ 0 -lt ${#} ] || { echo "Usage: ${FUNCNAME} <message>" >&2 ; exit 1; }
	local out=/proc/${$}/fd/1
	warn -n "${*}" > ${out}
	echo -en "${SAVE_CURSOR_POSITION}"  > ${out}
	read -e
	echo -en ${MOVE_CURSOR_UP} > ${out}
	__tag "${INFO}" > ${out}
	echo -en ${MOVE_CURSOR_UP} > ${out}
	echo ${REPLY}
}

check() {
	[ 2 -lt ${#} ] || { echo "Usage: ${FUNCNAME} (warn|error|fatal) '<message>' <command>" >&2 ; exit 1; }
	local level=$1
	local message=$2
	shift 2
	echo -ne "${OPEN_BRACKET}${EMPTY_TAG}${CLOSE_BRACKET} ${message}${SAVE_CURSOR_POSITION}"
	local output
	output=$( ( ${*} 2>&1 ) )
	local error_code=${?}
	[ 0 -eq ${error_code} ] && __tag "${PASS}" || case ${level} in
		warn) __tag "${WARN}" ;;
		error) __tag "${ERROR}"; echo "${*}"; echo "${output}" ;;
		fatal) __tag "${FAIL}";   echo "${*}"; echo "${output}"; exit ${error_code} ;;
	esac
	return ${error_code}
}



# Parameters: submodule
git-submodule-revision() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	git ls-files --error-unmatch --stage -- ${1} | awk '{print $2}'
}

# Parameters: submodule branch revision
git-submodule-revision-update-shallow() {
	[ 3 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule branch revision >&2 ; exit 1; }
	submodule=$(check-submodule-name ${1})
	[ 0 -eq ${?} ] || exit ${?}
	branch=${2}
	revision=${3}
	let depth=1
	url=$(git config --file=.gitmodules --get submodule.${submodule}.url)
	sparse_checkout=$(git config --file=.gitmodules --get submodule.${submodule}.sparse-checkout)
	git_directory=.git/modules/${submodule}
	rm -rf ${git_directory}
	check warn "Backup ${submodule} to ${submodule}~" mv ${submodule}{,~} || rm -rf ${submodule}
	check fatal "Shallow clone ${url} on branch ${branch} (depth ${depth})" git clone --no-checkout --depth ${depth} --branch ${branch} --separate-git-dir=${git_directory} ${url} ${submodule}
	[ -d ${submodule}~ ] && check warn "Delete bacckup ${submodule}~" rm -rf ${submodule}~
	if [ ! -z "${sparse_checkout}" ]; then
		git config --file=${git_directory}/config core.sparsecheckout true
		echo "${sparse_checkout}" > ${git_directory}/info/sparse-checkout
	fi
	(
		cd ${submodule}
		while ! git rev-list ${revision} ; do
			((depth+=1))
			check fatal "Shallow fetch ${submodule} (depth ${depth})" git fetch --depth=${depth} origin
		done
		check fatal "Checkout ${submodule} (${revision})" git checkout --force ${revision}
	)
}

# Parameters: [--init] [--branch <branch>] -- [submodule1 [submodule2 [...]]]
git-submodule-update-shallow() {
	usage() { echo "${FUNCNAME} [--init] [--branch <branch>] -- [submodule1 [submodule2 [...]]]" >&2 ; exit 1; }
	let init=0
	while test ${#} -ne 0; do
		case "${1}" in
			--init) let init=1 ;;
			--branch) branch=${2} ; shift ;;
			--branch=*) branch=${1/--branch=/} ;;
			--) shift; break ;;
			-*) usage ;;
			*) break ;;
		esac
		shift
	done
	unset -f usage

	# Check all modules before run update
	for submodule in ${*}; do
		check fatal "Check submodule name ${submodule}" check-submodule-name ${submodule}
	done

	if [ -z "${*}" ]; then
		[ 1 -eq $init ] && echo Initialize all submodules && git submodule init && let init=0
		submodules=$(git submodule status|awk '{print $2}')
	else
		submodules=${*}
	fi

	for submodule in ${submodules}; do
		submodule=$(check-submodule-name ${submodule})
		[ 1 -eq $init ] && check fatal "Initialize submodule ${submodule}" git submodule init ${submodule}
		if [ -z "${branch}" ]; then
			branch=$(git config --file=.gitmodules --get submodule.${submodule}.branch)
			revision=$(git-submodule-revision ${submodule})
		else
			revision=HEAD
		fi
		git-submodule-revision-update-shallow ${submodule} ${branch} ${revision}
	done
}

# Parameters: submodule
check-submodule-name() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	submodule=$(git submodule status "${1}" 2>/dev/null | awk '{print $2}')
	[ -z "${submodule}" ] && { echo No submodule named ${1} >&2 ; exit 1; }
	echo ${submodule}
}

install() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} install-directory >&2 ; exit 1; }
	install_directory=${1}
	case $(query Want you really install Git commands into \"${install_directory}'" ? [y|N] ' | tr '[A-Z]' '[a-z]') in
		y|yes) ;;
		*) exit 0;;
	esac

	for command in $(sed --quiet --regexp-extended 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $0); do
		check fatal "Install Git command ${command}" \
			ln -s $(readlink -f ${0}) ${install_directory}/${command}
	done
}

if [ -L ${0} ]; then
	$(basename ${0}) ${*}
else
	if [ ${#} -ne 1 ] && [ ! -d "${1}" ]; then
		echo Usage: ${0} install-directory >&2
		exit 1
	fi
	install ${*}
fi
exit 0
