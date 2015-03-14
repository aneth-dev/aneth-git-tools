#!/bin/bash

#.gitmodules sample with branch and sparse-checkout new parameters:
#[submodule "net.aeten.core"]
#	path = <path>
#	url = <url>
#	branch = <branch-name>
#	sparse-checkout = <path/to/foo>\
#	                \n<path/to/bar>

# Parameters: submodule
function git-submodule-revision() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	git ls-files --error-unmatch --stage -- ${1} | awk '{print $2}'
}

# Parameters: submodule
function git-submodule-check-name() {
	[ 1 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule >&2 ; exit 1; }
	submodule=$(git submodule status "${1}" 2>/dev/null | awk '{print $2}')
	[ -z "${submodule}" ] && { echo No submodule named ${1} >&2 ; exit 1; }
	echo ${submodule}
}

# Parameters: submodule branch revision
function git-submodule-revision-update-shallow() {
	[ 3 -eq ${#} ] || { echo Usage: ${FUNCNAME} submodule branch revision >&2 ; exit 1; }
	submodule=$(git-submodule-check-name ${1})
	[ 0 -eq $? ] || exit $?
	branch=${2}
	revision=${3}
	let depth=1
	url=$(git config --file=.gitmodules --get submodule.${submodule}.url)
	sparse_checkout=$(git config --file=.gitmodules --get submodule.${submodule}.sparse-checkout)
	git_directory=.git/modules/${submodule}
	echo "Shallow update submodule ${submodule} (${revision})"
	rm -rf ${git_directory} ${submodule}
	git clone --no-checkout --depth ${depth} --branch ${branch} --separate-git-dir=${git_directory} ${url} ${submodule}
	if [ ! -z "${sparse_checkout}" ]; then
		git config --file=${git_directory}/config core.sparsecheckout true
		echo "${sparse_checkout}" > ${git_directory}/info/sparse-checkout
	fi
	(
		cd ${submodule}
		while ! git rev-list ${revision} ; do
			git fetch --depth=$((depth+=1)) origin
		done
		git checkout ${revision}
	)

}

# Parameters: [--init] [submodule1 [submodule2 [...]]]
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
		[ 1 -eq $init ] && echo Initialize all submodules && git submodule init && let init=0
		submodules=$(git submodule status|awk '{print $2}')
	else
		submodules=${*}
	fi

	for submodule in ${submodules}; do
		submodule=$(git-submodule-check-name ${submodule})
		[ 1 -eq $init ] && echo Initialize submodule ${submodule} && git submodule init ${submodule}
		branch=$(git config --file=.gitmodules --get submodule.${submodule}.branch)
		revision=$(git-submodule-revision ${submodule})
		git-submodule-revision-update-shallow ${submodule} ${branch} ${revision}
	done
}

function install() {
	install_directory=${1?${FUNCNAME} Must take an installation directory as parameter}
	echo -n Want you really install Git commands into \"${install_directory}'" ? [y|N] '
	read -e
	case $(echo ${REPLY} | tr '[A-Z]' '[a-z]') in
		y|yes) ;;
		*) exit 0;;
	esac

	for command in $(awk '/^function\sgit/ {sub(/\s*\(\)$/, "", $2);print $2}' aeten-submodules.sh); do
		echo Install Git command ${command}
		ln -fs $(readlink -f ${0}) ${install_directory}/${command}
	done
}

if [ -L ${0} ]; then
	$(basename ${0}) ${*}
else
	if [ ${#} -ne 1 ] || [ ! -d "${1}" ]; then
		echo Usage: ${0} install-directory >&2
		exit 1
	fi
	install ${*}
fi
exit 0
