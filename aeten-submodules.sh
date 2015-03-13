#!/bin/bash

# Parameters: submodule
function git-submodule-revision() {
	: ${1?${FUNCNAME} Must take a submodule as first argument}
	git submodule status ${1}|awk '{sub(/[-+]/,"",$1);print $1}'
}

# Parameters: submodule
function git-submodule-check-name() {
	: ${1?${FUNCNAME} Must take a submodule as first argument}
	submodule=$(git submodule status "${1}" 2>/dev/null | awk '{print $2}')
	[ -z "${submodule}" ] && { echo No submodule named ${1} >&2 ; exit 1; }
	echo ${submodule}
}

# Parameters: submodule revision
function git-submodule-revision-update-shallow() {
	: ${2?${FUNCNAME} Must take a submodule as first argument and a revision as second.}
	submodule=$(git-submodule-check-name ${1})
	[ 0 -eq $? ] || exit $?
	revision=${2}
	echo "Shallow update submodule ${submodule} (${revision})"
	[ -f .git/modules/${submodule}/config ] || git clone --depth 1 --no-single-branch --separate-git-dir -n .git/modules/${submodule}/ $(git config --file=.gitmodules --get submodule.${submodule}.url) ${submodule}
	(
		cd ${submodule}
		while ! git rev-list ${revision} ; do
			git fetch --depth=$((i+=1))
		done
		git checkout ${revision}
	)
}

# Parameters: [submodule1 [submodule2 [...]]]
function git-submodule-update-shallow() {
	let init=0
	for arg in ${*}; do
		case ${arg} in
			--init) let init=1 ; shift ;;
		esac
	done

	# Check all modules before run update
	for submodule in ${*}; do
		git-submodule-check-name ${submodule} > /dev/null
	done

	if [ -z "$*" ]; then
		[ 1 -eq $init ] && echo Init all submodules && git submodule init && let init=0
		submodules=$(git submodule status|awk '{print $2}')
	else
		submodules=${*}
	fi

	for submodule in ${submodules}; do
		submodule=$(git-submodule-check-name ${submodule})
		[ 1 -eq $init ] && echo Init submodule ${submodule} && git submodule init ${submodule}
		revision=$(git-submodule-revision ${submodule})
		git-submodule-revision-update-shallow ${submodule} ${revision}
	done
}

if [ -L ${0} ]; then
	$(basename ${0}) ${*}
else
	if [ ${#} -ne 1 ] || [ ! -d ${1} ]; then
		echo Usage: ${0} install-directory >&2
		exit 4
	fi
	for command in $(awk '/^function\sgit/ {sub(/\s*\(\)$/, "", $2);print $2}' aeten-submodules.sh); do
		echo Install Git command ${command}
		ln -s $(readlink -f ${0}) ${1}/${command}
	done
fi
