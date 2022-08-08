export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

alias py2='/usr/bin/python'
alias pip2='/usr/local/bin/pip'

alias py37="/usr/local/opt/python@3.7/libexec/bin/python"
alias pip37="/usr/local/opt/python@3.7/libexec/bin/pip"

alias py='python'
alias pir="pip install -r requirements.txt"


function py_use_2() {
	alias python='py2'
	alias pip='pip2'
}

function py_use_37() {
	alias python='py37'
	alias pip='pip37'
}

function py_use_310() {
	pyenv global 3.10.4
}

py_use_310