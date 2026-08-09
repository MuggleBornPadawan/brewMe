clear
cd
neofetch
# espeak -v en-gb -s 175 -p 50 "roger that"
echo -e "\nDate: $(date) \nOS: $(uname -s) \nKernel: $(uname -r)"
#brew install
brew update
brew upgrade
brew install lm-sensors sqlite3 mpg123 dnsutils make bats jq cron postfix mailutils pass gnupg nmap htop pv tldr tree ncdu parallel tmux rsync bat fd-find git rig espeak nodejs npm openjdk-17-jdk python3 python3-pip mit-scheme racket clojure emacs magit sbcl clisp r-base build-essential firefox-esr fortune cowsay neofetch trash-cli
brew autoremove 
# brew clean
# alias rm='trash-put'
# trash-list
echo -e "\nuse trash-empty or trash-restore as you see fit"
rm .bash_history
# pass ls
# fetch chennai weather
curl wttr.in/Chennai | head -n 7
# Fetch Pondicherry weather
curl wttr.in/Pondicherry | head -n 7
# ping -w 12 google.com > tmp.txt
# cat tmp.txt | grep "rtt"
# fortune -a | cowsay
# ollama run gemma3:1b-it-qat "speak gibberish"
echo "start gemma3:1b"
# ollama run gemma3:1b "write 7 gibberish words in a single sentence; skip commentary; skip asking questions; skip notes"
# ollama stop gemma3:1b
echo "stop gemma"
# echo "start deepseek-r1:1.5b"
# ollama run deepseek-r1:1.5b "ok"
# ollama stop deepseek-r1:1.5b
echo "stop deepseek"

echo "chk openai oss and deepseek r1"

echo "tmux new -s alpha"
echo "sudo shutdown -h now"
# final words 
sleep 2
cd
# espeak -v en-gb -s 175 -p 50 "penguin out"
# cp regular_update.sh GitHub/MuggleBornPadawan/700_linux/bckp/brew_regular_update.sh
