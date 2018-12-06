
.PHONY: default elm test

default:
	# do nothing

elm:
	elm make elm/Main.elm --output public/assets/elm.js

test:
	elm make elm/UI.elm --output public/assets/ui.js
