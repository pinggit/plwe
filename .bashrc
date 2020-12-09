# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# determine platform {{{1
platform='unknown'
unamestr=`uname -a`
if [[ "$unamestr" =~ 'Microsoft' ]]; then
    platform='wsl'
elif [[ "$unamestr" =~ 'Linux' ]]; then
    platform='linux'
elif [[ "$unamestr" =~ 'FreeBSD' ]]; then
    platform='freebsd'
elif [[ "$unamestr" =~ 'CYGWIN' ]]; then
    platform='cygwin'
fi

# common unix {{{1
# If not running interactively, don't do anything
[ -z "$PS1" ] && return

#ping: (2018-02-23) I think I need both
## don't put duplicate lines in the history. See bash(1) for more options
## don't overwrite GNU Midnight Commander's setting of `ignorespace'.
#HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
## ... or force ignoredups and ignorespace
#HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# shell terminal looking {{{1
# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# ping: 2018-01-13 use cygwin orignal 2 line PS1
# if [ "$color_prompt" = yes ]; then
#     PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
# else
#     PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
# fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    # ping: 2018-01-13 use cygwin orignal 2 line PS1
    # PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

#ping:(Thu, Feb 22, 2018 12:44:22 AM) 
#https://gist.github.com/mkottman/1936195
#=================================
# A two-line colored Bash prompt (PS1) with Git branch and a line decoration
# which adjusts automatically to the width of the terminal.
# Recognizes and shows Git, SVN and Fossil branch/revision.
# Screenshot: http://img194.imageshack.us/img194/2154/twolineprompt.png
# Michal Kottman, 2012

RESET="\[\033[0m\]"
RED="\[\033[0;31m\]"
GREEN="\[\033[01;32m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\033[0;33m\]"

# this is too complex, remove from PS1
PS_LINE=`printf -- '- %.0s' {1..200}`

function parse_git_branch {

    PS_BRANCH=''
    PS_FILL=${PS_LINE:0:$COLUMNS}
    if [ -d .svn ]; then
        PS_BRANCH="(svn r$(svn info|awk '/Revision/{print $2}'))"
    elif [ -f _FOSSIL_ -o -f .fslckout ]; then
        PS_BRANCH="(fossil $(fossil status|awk '/tags/{print $2}')) "
    elif [ -d .git ]; then
        ref=$(git symbolic-ref HEAD 2> /dev/null)
        PS_BRANCH="(git ${ref#refs/heads/}) "
    fi

    # also merge previous PROMPT_COMMAND ...

        #ping: to retain each cmd in history
        #http://northernmost.org/blog/flush-bash_history-after-each-command/
        #export PROMPT_COMMAND='history -a'

        #ping: for window title change request feature
        #for secureCRT
        #PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/~}\007"'
        #PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}\007"'

        #for tmux
        #PROMPT_COMMAND='echo -ne "\033k${HOSTNAME%%.*}\033\\"'

        #mix (doesn't working yet)
        #PROMPT_COMMAND='echo -ne "\033]0;\033k${USER}@${HOSTNAME%%.*}\033\\"\007"'

    # as: (after merging into this func:)

        history -a
        #secureCRT
        echo -ne "\033]0;${USER}@${HOSTNAME%%.*}\007"
        #tmux
        #echo -ne "\033k${HOSTNAME%%.*}\033\\"

}

# man bash: "If set, the value is executed as a command prior to issuing each
# primary prompt."
PROMPT_COMMAND=parse_git_branch
PS_INFO="$GREEN\u@\h$RESET:$BLUE\w"
PS_GIT="$YELLOW\$PS_BRANCH"
#PS_TIME="\[\033[\$((COLUMNS-10))G\] $RED[\t]"
#PS_TIME="\[\033 $RED[\t]"
PS_TIME="$RED[\D{%F %T}]"
#export PS1="\${PS_FILL}\[\033[0G\]${PS_INFO} ${PS_GIT}${PS_TIME}\n${RESET}\$ "
#put time in the beginning
#export PS1="\[\033[0G\]${PS_INFO} ${PS_GIT}${PS_TIME}\n${RESET}\$ "
#put time in the end
export PS1="\[\033[0G\]${PS_TIME}${PS_INFO} ${PS_GIT}\n${RESET}\$ "
#===================================

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions. {{{1
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# ping's addition: {{{1
#for e-serials show version
#alias showversion='cat > dummy.txt ; ShowVersion dummy.txt ; rm dummy.txt'
#alias rm='rm -i'
#alias rm='~/bin/trashit'
#alias q='exit'

#IBus has been started! If you can not use IBus, please add below lines in $HOME/.bashrc, and relogin your desktop.
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus

#xmodmap .xmodmaprc

#change default editor(for crontab -e,e.g) to vim
export EDITOR=vim

HISTSIZE=100000
HISTFILESIZE=100000
export HISTTIMEFORMAT="%d/%m/%y %T "

function say { mplayer -really-quiet "http://translate.google.com/translate_tts?tl=en&q=$1"; }

PERL_MB_OPT="--install_base \"/home/ping/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/ping/perl5"; export PERL_MM_OPT;

# path {{{2

PATH=/user/sbin:/user/bin:/usr/local/sbin:/usr/local/bin:~/bin/:/bin:/sbin:$PATH
PATH=~/bin/crtc/:$PATH
if [[ $platform == 'cygwin' ]]; then
    #PATH=/usr/games:/usr/local/games:~/bin/crtc:~/bin/logtool:~/.cabal/bin/:$PATH
    #PATH=~/bin/flowtap/:~/bin/contrail-introspect-cli/:~/bin/pypuller/:~/bin/ranger/:$PATH
    PATH=~/prog-files/draw.io/:$PATH
fi

export PATH


#(2014-11-02) 
#include all subfolders recursively, but exclude hidden folders
#http://stackoverflow.com/questions/657108/bash-recursively-adding-subdirectories-to-the-path
#PATH=${PATH}:$(find ~/bin -type d | sed '/\/\\./d' | tr '\n' ':' | sed 's/:$//')

# vimpager script {{{2
#export PAGER=~/bin/vimpager
#alias less=$PAGER
#alias zless=$PAGER

# ranger-cd {{{2
#man ranger, This is a bash function (for ~/.bashrc) to change the directory to
#the last visited one after ranger quits.  You can always type "cd -" to go back
#to the original one.
#tested but not working...
function ranger-cd {
  tempfile='/tmp/chosendir'
  /usr/bin/ranger --choosedir="$tempfile" "${@:-$(pwd)}"
  test -f "$tempfile" &&
  if [ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]; then
    cd -- "$(cat "$tempfile")"
  fi
  rm -f -- "$tempfile"
}

# This binds Ctrl-O to ranger-cd:
bind '"\C-o":"ranger-cd\C-m"'

# alias {{{2
#http://jetpackweb.com/blog/2009/09/23/pbcopy-in-ubuntu-command-line-clipboard/
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

#alias pbcopy='xsel --clipboard --input'
#alias pbpaste='xsel --clipboard --output'

#(2017-10-01) 
alias bb='pypuller -r "alcoholix-re0.ultralab.juniper.net" -r "getafix-re0.ultralab.juniper.net" -c "file show pr1309063" -L'

#alias sudo='sudo '
#alias kubectl=microk8s.kubectl
#alias docker='/usr/bin/docker -H unix:///var/snap/microk8s/149/docker.sock'

#this is to make tmux config more generic
if [[ $platform == 'linux' ]]; then
    alias putclip='xclip -selection clipboard'
fi

if [[ $platform == 'wsl' ]]; then
    alias wstart="cmdtool wstart"
    alias launchchrome="\"/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe\""
    alias cmd="\"/mnt/c/Program Files (x86)/clink/0.4.9/clink.bat\""
fi


# zsh {{{2
#If use_tmux=1, add these codes to .bashrc/.zshrc:
[[ -z "$TMUX" && -n "$USE_TMUX" ]] && {
    [[ -n "$ATTACH_ONLY" ]] && {
        tmux a 2>/dev/null || {
            cd && exec tmux
        }
        exit
    }

    tmux new-window -c "$PWD" 2>/dev/null && exec tmux a
    exec tmux
}

# fzf {{{2
#(Sun, Feb 18, 2018  2:31:53 AM) ping: disable $(__fzf_history__)
bind '\C-r:reverse-search-history'
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# gcloud {{{2
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/cygdrive/c/Users/pings/Downloads/google-cloud-sdk/path.bash.inc' ]; then . '/cygdrive/c/Users/pings/Downloads/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/cygdrive/c/Users/pings/Downloads/google-cloud-sdk/completion.bash.inc' ]; then . '/cygdrive/c/Users/pings/Downloads/google-cloud-sdk/completion.bash.inc'; fi

# drawio for cygwin {{{2
#https://j2r2b.github.io/2019/08/06/drawio-cli.html
if [[ $platform == 'cygwin' ]]; then
    alias drawio='/cygdrive/c/Program\ Files/draw.io/draw.io.exe'
    alias sudo='cygstart --action=runas'
    #(2020-05-11) for x11 forwarding. 
    #seems not supported for wsl due to lack of /tmp/.X11-unix/X0, so no need for it
    #see https://unix.stackexchange.com/questions/57138/why-does-my-x11-forwarding-attempt-fail-with-connect-tmp-x11-unix-x0-no-such
    # https://unix.stackexchange.com/questions/12755/how-to-forward-x-over-ssh-to-run-graphics-applications-remotely
    #(2020-05-23) but, needed for putclip, xclip, etc, when vim work with tmux...
    export DISPLAY=:0.0
else
    #does not work for batch mode
    alias drawio='/mnt/c/Program\ Files/draw.io/draw.io.exe'
    export DISPLAY=:0.0
fi

# leetcode {{{2
###-begin-leetcode-completions-###
#
# yargs command completion script
#
# Installation: /usr/local/bin/leetcode completion >> ~/.bashrc
#    or /usr/local/bin/leetcode completion >> ~/.bash_profile on OSX.
#
_yargs_completions()
{
    local cur_word args type_list

    cur_word="${COMP_WORDS[COMP_CWORD]}"
    args=("${COMP_WORDS[@]}")

    # ask yargs to generate completions.
    type_list=$(/usr/local/bin/leetcode --get-yargs-completions "${args[@]}")

    COMPREPLY=( $(compgen -W "${type_list}" -- ${cur_word}) )

    # if no match was found, fall back to filename completion
    if [ ${#COMPREPLY[@]} -eq 0 ]; then
      COMPREPLY=( $(compgen -f -- "${cur_word}" ) )
    fi

    return 0
}
complete -F _yargs_completions leetcode

# start ssh-agent automatically {{{2
#(2020-03-05) 
#SSHAGENT=/usr/bin/ssh-agent
#SSHAGENTARGS="-s"
#if [ -z "$SSH_AUTH_SOCK" -a -x "$SSHAGENT" ]; then
#    eval `$SSHAGENT $SSHAGENTARGS` >/dev/null 2>&1
#    trap "kill $SSH_AGENT_PID" 0
#fi
##https://askubuntu.com/questions/389921/how-to-avoid-typing-ssh-add-everytime
#### START-Keychain ###
## Let  re-use ssh-agent and/or gpg-agent between logins
#/usr/bin/keychain $HOME/.ssh/csd_rsa_key
#source $HOME/.keychain/$HOSTNAME-sh
#### End-Keychain ###

# nvm {{{2
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# docker {{{2
# (2020-10-04) 
docker() {
    if [[ $1 == "exec" ]]; then
        command docker exec -e COLUMNS="`tput cols`" -e LINES="`tput lines`" ${@:2}
    else
        echo "will execute docker $@"
        command docker "$@"
    fi
}


# others {{{2

#source $(pip show powerline-status | awk '/Location:/{print $2 "/powerline/bindings/bash/powerline.sh"}')

#disable ctrl-s, seems no use but only occasionally some trouble
stty -ixon

