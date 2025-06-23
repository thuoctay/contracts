gp MESSAGE:
    git add .
    git commit -m "{{MESSAGE}}"
    git push origin HEAD

gc MESSAGE:
    git commit -am "{{MESSAGE}}"
    git push origin HEAD

sync:
    git pull --rebase

st:
    git status

lg:
    git log --oneline --graph --decorate --all

reset-hard:
    git fetch origin
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
