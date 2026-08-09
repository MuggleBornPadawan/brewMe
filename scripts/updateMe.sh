brew update
brew upgrade
npm update
npm outdated
pip list --outdated | awk 'NR>1 {print $1}' | xargs -n1 pip install -U
# pip-review --interactive
