# Install Homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Brew
brew install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
brew install zsh-syntax-highlighting
brew install zsh-history-substring-search
brew install z

# Brew Casks
brew cask install google-chrome
brew cask install dashlane
brew cask install authy
brew cask install iterm2
brew cask install sublime-text
brew cask install slack

# Brew
brew cask install homebrew/cask-versions/java11
brew install sbt
brew install scala

# Fonts
brew tap homebrew/cask-fonts
brew cask install font-powerline

# Clear Dock
LoggedInUser=$3
LoggedInUserHome="/Users/$3"

brew install dockutil
dockutil --remove all
dockutil --add '/Applications/Google Chrome.app'
dockutil --add '/Applications/Sublime Text.app'
dockutil --add '/Applications/iTerm.app'
dockutil --add '/Applications/Slack.app'
dockutil --add '/Applications/Dashlane.app'
dockutil --add '/Applications/Authy Desktop.app'