###############################################################################
# Location                                                                    #
###############################################################################

# Set to Lower Left
defaults write com.apple.dock pinning end

# Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true

# Remove Hide Delay
defaults write com.apple.Dock autohide-delay -float 0.0001

# Remove the animation when hiding/showing the Dock
defaults write com.apple.dock autohide-time-modifier -float 0.3


###############################################################################
# Styling                                                                     #
###############################################################################

# Suck Effect
defaults write com.apple.dock mineffect suck

# Enable highlight hover effect for the grid view of a stack (Dock)
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# Enable spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Make Hidden Apps Translucent
defaults write com.apple.Dock showhidden -bool true

# Show indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Minimize windows into their application’s icon 
defaults write com.apple.dock minimize-to-application -int 1

# Activate Mouse Over Gradient for Stacks
defaults write com.apple.dock mouse-over-hilte-stack -boolean YES

###############################################################################
# Performance                                                                 #
###############################################################################

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

###############################################################################
# Content                                                                     #
###############################################################################

# Enable Spring-loaded Dock items (allowing you to drag a file over the folder/icon)
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Recent Items Stack
defaults write com.apple.dock persistent-others -array-add '{ "tile-data" = { "list-type" = 1; }; "tile-type" = "recents-tile"; }'

# Don’t group windows by application in Mission Control
# (i.e. use the old Exposé behavior instead)
defaults write com.apple.dock expose-group-by-app -bool false

# Don’t show Dashboard as a Space
defaults write com.apple.dock dashboard-in-overlay -bool true

# Reset Launchpad
find ~/Library/Application\ Support/Dock -name "*.db" -maxdepth 1 -delete

killall Dock