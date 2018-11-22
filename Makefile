
.PHONY: default elm

default:
	# do nothing

elm:
	elm make elm/Main.elm --output public/assets/elm.js
