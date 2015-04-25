#===================================================================#
# Appearance                                                        #
#===================================================================#
  export green=$(tput setaf 2)
  export blue=$(tput setaf 4)
  export bold=$(tput bold)
  export reset=$(tput sgr0)
  export PS1='\n\[$green$bold\]\h\[$reset\]:\[$blue$bold\]\w\[$reset\]\$ '
#-------------------------------------------------------------------#
  export HISTSIZE=10000                       #
  eval `dircolors`                            #
  export GREP_OPTIONS="--color=auto"          #
#===================================================================#

#===================================================================#
# RelateIQ                                                          #
#===================================================================#
  export PROJECTS_ROOT=$HOME/projects
  export RIQ=$PROJECTS_ROOT/riq 
  source $PROJECTS_ROOT/devenv/bin/dev_bash_profile.sh
  export DEVENV=$PROJECTS_ROOT/devenv 
  export PATH=$PATH:$DEVENV/bin
  export PATH=/usr/local/opt/coreutils/libexec/gnubin:$PATH
#  export JAVA_HOME="$(/usr/libexec/java_home)"
  export DOCKER_HOST='tcp://localhost:4444'
#-------------------------------------------------------------------#
  api() {
    prd_key="54f7af17e4b00bbdf718b799";
    prd_secret="UBH5VtAUcu2lJaemEqLcftc7g7i";

    if [ $# -eq 1 ] ; then
        args="$1"
    elif [ $# -eq 2 ] ; then
        args="$1 -X $2"
    elif [ $# -eq 3 ] ; then
        args="$1 -X $2 -d '$3'"
    fi
            
    curl -H "Accept: application/json" -H 'Content-Type: application/json' -u "$prd_key":"$prd_secret" https://api.relateiq.com/v2/$args | jq .
  }
#-------------------------------------------------------------------#
  api_lcl() {
    lcl_key="54dc1b96ce246a4960f8892e";
    lcl_secret="SG8u7zcTuZrknnsdmkuYh1PAkEa";

    if [ $# -eq 1 ] ; then
        args="$1"
    elif [ $# -eq 2 ] ; then
        args="$1 -X $2"
    elif [ $# -eq 3 ] ; then
        args="$1 -X $2 -d $3"
    fi

    curl -H "Accept: application/json" -H 'Content-Type: application/json' -u "$lcl_key":"$lcl_secret" http://0.0.0.0:8080/v2/$args  | jq .
  }
#-------------------------------------------------------------------#
  api_stg() {
    stg_key="54f8acd358f28e54c4095dff";
    stg_secret="hO1n7D4iBQ7fU6rtLtf7yO49AzE";

    if [ $# -eq 1 ] ; then
        args="$1"
    elif [ $# -eq 2 ] ; then
        args="$1 -X $2"
    elif [ $# -eq 3 ] ; then
        args="$1 -X $2 -d $3"
    fi

    curl -H "Accept: application/json" -H 'Content-Type: application/json' -u "$stg_key":"$stg_secret" https://api-staging.relateiq.com/v2/$args  | jq .
  }
#-------------------------------------------------------------------#
# Creates a new auto-merge branch and attempts to rebase off the previous auto-merge branch
ambr() {
  # first sync up with staging
  echo ">>> Syncing origin/staging..."
  current_branch=`git symbolic-ref --short HEAD`
  if [ ! $current_branch = 'staging' ]; then
    git co staging
  fi
  git pull --rebase

  # generate a new automerge branch in the format: 'am-{username}-{date}-{time}'
  branchName="am-"
  branchName+=`whoami`
  branchName+=`date "+-%Y%m%d-%H%M%S"`
  git checkout -b $branchName

  # attempt to rebase off the last automerge branch
  if [ -e ~/.last_automerge_branch ]; then
    lastAutoMerge=`cat ~/.last_automerge_branch`
    echo ">>> Trying to rebase off the previous automerge branch ($lastAutoMerge)..."
    git rebase $lastAutoMerge
    git branch -d $lastAutoMerge
  fi

  echo $branchName > ~/.last_automerge_branch
  echo ">>> Auto-Merge branch '$branchName' created"
}

# Pushes the current auto-merge branch and creates a new one
amp() {
  echo ">>> Syncing auto-merge branch to origin/staging"
  git pull --rebase origin staging
  git push --set-upstream origin `git symbolic-ref --short HEAD`
  echo '### Branch Pushed ######################################################'
  ambr
}


  #export EDITOR=subl                                                #
  export DISPLAY=${USER}pc.pc.factset.com:0                         #
  alias cd='pushd'                                                  #
  alias ..='cd ..'                                                  #
  alias ...='popd'                                                  #
  alias kill='kill -9'                                              #
  alias ls='ls --color -ah --group-directories-first'  
  alias logout='cls && logout'                                      #
  alias profile='subl ~/.bash_profile; source ~/.bash_profile'     #              #
  alias cls='clear; ls'                                             #
  alias tail='clear; tail'                                          #
#===================================================================#
  alias dev_package_all=' source $RIQ/scripts/dev_package_all.sh'
  alias dev_tunnel='$RIQ/scripts/dev_tunnel.sh'
  alias tunnel='dev_tunnel off; dev_tunnel on'
  alias stg='tunnel'
  alias lcl='dev_tunnel off'
  alias web='pushd .; dpafw; { sleep 15; open http://127.0.0.1:9000/app.html; } & gulpr server; popd; cls'
  alias dev_update='devenv up; devenv backup; devenv stop; devenv update; devenv update; devenv vagrant halt; devenv up; devenv start; cls'
  alias dev_all='dev_update'
  alias boom='dev_update; web'
  alias cli_prod='ssh -t henry@usw2b-grunt-nimbus1-prod.amz.relateiq.com "/mnt/apps/riqcli/bin/riqcli"; cls'
  alias cli_stg='ssh -t henry@usw2b-grunt-nimbus1-staging.amz.relateiq.com "/mnt/apps/riqcli/bin/riqcli"; cls'
  alias cli_lcl='cd $RIQ; mvn clean package -am -pl LucidCLI -DskipTests; tar zcvf riqcli.tgz LucidCLI/target/appassembler/; scp riqcli.tgz henry@usw2b-riqcli1-support.amz.relateiq.com:~/riqcli.tgz; ssh -t henry@usw2b-riqcli1-support.amz.relateiq.com "rm -r LucidCLI/; tar -zxvf riqcli.tgz; chmod 744 LucidCLI/target/appassembler/bin/riqcli; sudo APP_ENVIRONMENT=prod /home/henry/LucidCLI/target/appassembler/bin/riqcli"; rm $RIQ/riqcli.tgz; cls'
  alias jumpwest='ssh usw2c-jump1-ops'

  alias py='python'
  alias apidocs='pushd $RIQ/LucidRestApi/src/main/resources/docs; ruby compile.rb; open http://localhost:8000/; python -m SimpleHTTPServer; popd; cls'
  alias integrations='cd ~/projects/integrations/'

  alias gmail='open http://gmail.com'

  export CHRONOS='http://usw2c-mesos-master1-prod.amz.relateiq.com:8010/'
  export MESOS='http://usw2c-mesos-master1-prod.amz.relateiq.com:5050/'
  alias chronos='open $CHRONOS'
  alias mesos='open $MESOS'
  alias mesos1='ssh usw2b-mesos-drone1-prod.amz.relateiq.com'
  alias mesos2='ssh usw2b-mesos-drone2-prod.amz.relateiq.com'
  alias mesos3='ssh usw2b-mesos-drone3-prod.amz.relateiq.com'
  alias mesosstg="ssh usw2b-mesos-drone1-staging.amz.relateiq.com"
  alias mongos='mongo --host usw2a-mongo1-staging.amz.relateiq.com'

cls
export PATH=/usr/local/bin:$PATH
