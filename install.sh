#!/usr/bin/env bash

# Usage
#   $ cat installer.sh | sudo -E bash -s $USER
#
# use sudo to make this script has access, and use '-E' for preserve most env variables;
# use '-s $USER' to pass "real target user" to this install script

COLOR_RED=`tput setaf 9`
COLOR_GREEN=`tput setaf 10`
COLOR_YELLOW=`tput setaf 11`
SGR_RESET=`tput sgr 0`

# bash strict mode (https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425)
set -xo pipefail

log.info() {
    set +x
    echo -e "\n${COLOR_YELLOW} $@ ${SGR_RESET}\n"
    set -x
}

log.success() {
    set +x
    echo -e "\n${COLOR_GREEN} $@ ${SGR_RESET}\n"
    set -x
}

log.error() {
    set +x
    echo -e "\n${COLOR_RED} $@ ${SGR_RESET}\n" >&2
    set -x
}

is-command() { command -v $@ &> /dev/null; }

S_USER="$USER"
S_HOME="$HOME"
GITHUB_PROXY=""

# Parse named arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            S_USER="$2"
            shift 2
            ;;
        --proxy)
            GITHUB_PROXY="$2"
            shift 2
            ;;
        *)
            log.error "[LazyOmz] Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Update home directory if user is specified
if [[ "$S_USER" != "$USER" ]]; then
    S_HOME=`sudo -u "${S_USER}" -i echo '$HOME'`
fi

# Log configuration
if [[ -n "${GITHUB_PROXY}" ]]; then
    log.info "[LazyOmz] Using GitHub proxy: ${GITHUB_PROXY}"
fi
log.info "[LazyOmz] Installing for user: ${S_USER} (home: ${S_HOME})"

# setup oh-my-zsh env variables
if [[ -z "${ZSH}" ]]; then
    # If ZSH is not defined, use the current script's directory.
    ZSH="${S_HOME}/.oh-my-zsh"
fi

# Set ZSH_CUSTOM to the path where your custom config files
ZSH_CUSTOM="${ZSH}/custom"

# it's same as `realpath <file>`, but `realpath` is GNU only and not builtin
prel-realpath() {
  perl -MCwd -e 'print Cwd::realpath($ARGV[0]),qq<\n>' $1
}

# Get GitHub URL with proxy if configured
get-github-url() {
    local original_url="$1"
    if [[ -n "${GITHUB_PROXY}" ]]; then
        # Remove trailing slash from proxy and leading slash from original_url
        local proxy_url="${GITHUB_PROXY%/}"
        local clean_url="${original_url#/}"
        echo "${proxy_url}/${clean_url}"
    else
        echo "${original_url}"
    fi
}

install-via-manager() {
    local package="$1"
    log.info "[LazyOmz] install package: ${package}"

    if is-command brew; then
        sudo -Eu ${S_USER} brew install ${package}

    elif is-command apt; then
        apt install -y ${package}

    elif is-command apt-get; then
        apt-get install -y ${package}

    elif is-command yum; then
        yum install -y ${package}

    elif is-command pacman; then
        pacman -S --noconfirm --needed ${package}
    fi
}

install.packages() {
    local packages=( $@ )
    log.info "[LazyOmz] install packages: ${packages[@]}"

    local package

    for package in ${packages[@]}; do
        install-via-manager ${package}
    done
}

install.zsh() {
    log.info "[LazyOmz] detect whether installed zsh"

    if [[ "${SHELL}" =~ '/zsh$' ]]; then
        log.success "[LazyOmz] default shell is zsh, skip to install"
        return 0
    fi

    if is-command zsh || install.packages zsh; then
        log.info "[LazyOmz] switch default login shell to zsh"
        chsh -s `command -v zsh` ${S_USER}
        return 0
    else
        log.error "[ERROR][LazyOmz] cannot find or install zsh, please install zsh manually"
        return 1
    fi
}

install.ohmyzsh() {
    log.info "[LazyOmz] detect whether installed oh-my-zsh"

    if [[ -d ${ZSH} && -d ${ZSH_CUSTOM} ]]; then
        log.success "[LazyOmz] oh-my-zsh detected, skip to install"
        return 0
    fi

    log.info "[LazyOmz] this theme base on oh-my-zsh, now will install it"

    if ! is-command git; then
        install.packages git
    fi

    if ! is-command curl; then
        install.packages curl
    fi

    # https://ohmyz.sh/#install
    local install_url=$(get-github-url "https://github.com/ohmyzsh/ohmyzsh/raw/master/tools/install.sh")
    # curl -sSL -H 'Cache-Control: no-cache' "${install_url}" | sudo -Eu ${S_USER} sh
    if [[ -n "${GITHUB_PROXY}" ]]; then
        curl -sSL -H 'Cache-Control: no-cache' "${install_url}" | sudo -Eu ${S_USER} REMOTE="${GITHUB_PROXY}/https://github.com/ohmyzsh/ohmyzsh.git" sh
    else
        curl -sSL -H 'Cache-Control: no-cache' "${install_url}" | sudo -Eu ${S_USER} sh
    fi
}


install.zsh-plugins() {
    log.info "[LazyOmz] install zsh plugins"

    local plugin_dir="${ZSH_CUSTOM}/plugins"

    if ! is-command git; then
        install.packages git
    fi

    if [[ ! -d ${plugin_dir}/zsh-syntax-highlighting ]]; then
        log.info "[LazyOmz] install plugin zsh-syntax-highlighting"
        local plugin_url=$(get-github-url "https://github.com/zsh-users/zsh-syntax-highlighting.git")
        sudo -Eu ${S_USER} git clone --depth=1 "${plugin_url}" "${plugin_dir}/zsh-syntax-highlighting"
    fi

    log.info "[LazyOmz] setup oh-my-zsh plugins in ~/.zshrc"
    local plugins=(
        git
        zsh-syntax-highlighting
    )

    local plugin_str="${plugins[@]}"
    plugin_str="\n  ${plugin_str// /\\n  }\n"
    perl -0i -pe "s/^plugins=\(.*?\) *$/plugins=(${plugin_str})/gms" $(prel-realpath "${S_HOME}/.zshrc")
}

preference-zsh() {
    log.info "[LazyOmz] preference zsh in ~/.zshrc"

    if is-command brew; then
        perl -i -pe "s/.*HOMEBREW_NO_AUTO_UPDATE.*//gms" $(prel-realpath "${S_HOME}/.zshrc")
        echo "export HOMEBREW_NO_AUTO_UPDATE=true" >> "${S_HOME}/.zshrc"
    fi

    install.zsh-plugins
}

install.theme() {
    log.info "[LazyOmz] install theme 'LazyOmz'"

    local theme_name="lazyomz"
    local git_prefix=$(get-github-url "https://github.com/xxxbrian/lazyomz/raw/main")
    local theme_remote="${git_prefix}/${theme_name}.zsh-theme"
    local custom_dir="${ZSH_CUSTOM:-"${S_HOME}/.oh-my-zsh/custom"}"

    sudo -Eu ${S_USER} mkdir -p "${custom_dir}/themes" "${custom_dir}/plugins/${theme_name}"
    local theme_local="${custom_dir}/themes/${theme_name}.zsh-theme"

    sudo -Eu ${S_USER} curl -sSL -H 'Cache-Control: no-cache' "${theme_remote}" -o "${theme_local}"

    perl -i -pe "s/^ZSH_THEME=.*/ZSH_THEME=\"${theme_name}\"/g" $(prel-realpath "${S_HOME}/.zshrc")
}


(install.zsh && install.ohmyzsh) || exit 1

install.theme
preference-zsh


log.success "[LazyOmz] installed"
