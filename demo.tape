# VHS Demo for you-should-use
# https://github.com/vangie/you-should-use

Output assets/demo.gif
Output assets/demo.webm

Set Shell "zsh"
Set FontSize 18
Set Width 900
Set Height 550
Set Padding 20
Set Theme { "name": "Catppuccin", "black": "#1a1b2e", "red": "#ed8796", "green": "#a6da95", "yellow": "#eed49f", "blue": "#8aadf4", "magenta": "#c6a0f6", "cyan": "#8bd5ca", "white": "#cad3f5", "brightBlack": "#5b6078", "brightRed": "#ed8796", "brightGreen": "#a6da95", "brightYellow": "#eed49f", "brightBlue": "#8aadf4", "brightMagenta": "#c6a0f6", "brightCyan": "#8bd5ca", "brightWhite": "#cad3f5", "background": "#1a1b2e", "foreground": "#cad3f5", "selection": "#3a3b5e", "cursor": "#f4dbd6" }
Set TypingSpeed 60ms
Set CursorBlink false

# Setup: source the plugin and create demo aliases
Hide
Type "source ./you-should-use.plugin.zsh"
Enter
Type "alias gc='git commit'"
Enter
Type "alias gp='git push'"
Enter
Type "alias gcb='git checkout -b'"
Enter
Type "alias ll='ls -la'"
Enter
Type "alias k='kubectl'"
Enter
Type "alias tf='terraform'"
Enter
Type "export YSU_INSTALL_HINT=true"
Enter
Type "clear"
Enter
Show

Sleep 500ms

# Scene 1: Alias Reminder
Type "# You type a command... but forgot your alias"
Enter
Sleep 1s
Type "git commit -m 'fix: update config'"
Sleep 500ms
Enter
Sleep 2s

Type "git push origin main"
Sleep 500ms
Enter
Sleep 2s

# Scene 2: Modern Command Suggestions
Type "# It also suggests modern alternatives"
Enter
Sleep 1s
Type "cat README.md"
Sleep 500ms
Enter
Sleep 2s

Type "ls -la"
Sleep 500ms
Enter
Sleep 2s

# Scene 3: Alias Discovery
Type "# Discover all your aliases"
Enter
Sleep 1s
Type "ysu aliases | head -8"
Sleep 500ms
Enter
Sleep 2.5s

# Scene 4: Doctor
Type "# Health check"
Enter
Sleep 1s
Type "ysu doctor"
Sleep 500ms
Enter
Sleep 3s

Sleep 1s
