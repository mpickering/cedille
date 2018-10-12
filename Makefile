IAL=~/ial

AGDA=agda --malonzodir dist
#AGDA=/home/astump/agda-2.5.1.2/.cabal-sandbox/bin/agda

SRCDIR=src

AUTOGEN = \
	cedille.agda \
	cedille-types.agda \
	cedille-main.agda \
        options.agda \
	options-types.agda \
	options-main.agda \
        cws.agda \
	cws-types.agda \
	cws-main.agda \
	templates.agda

AGDASRC = \
	to-string.agda \
	constants.agda \
	spans.agda \
	conversion.agda \
	syntax-util.agda \
	ctxt-types.agda \
	rename.agda \
	classify.agda \
	subst.agda \
	is-free.agda \
	lift.agda \
	rewriting.agda \
	ctxt.agda \
	main.agda \
	toplevel-state.agda \
	process-cmd.agda \
	general-util.agda \
	interactive-cmds.agda \
	untyped-spans.agda \
	rkt.agda \
	meta-vars.agda \
	cedille-options.agda \
	elaboration.agda \
	elaboration-helpers.agda \
	monad-instances.agda

CEDILLE_ELISP = \
		cedille-mode.el \
		cedille-mode/cedille-mode-context.el \
		cedille-mode/cedille-mode-errors.el \
                cedille-mode/cedille-mode-faces.el \
		cedille-mode/cedille-mode-highlight.el \
                cedille-mode/cedille-mode-info.el \
		cedille-mode/cedille-mode-library.el \
		cedille-mode/cedille-mode-summary.el \
		cedille-mode/cedille-mode-normalize.el \
		cedille-mode/cedille-mode-scratch.el \
		cedille-mode/cedille-mode-beta-reduce.el

SE_MODE = \
	se-mode/se.el \
	se-mode/se-helpers.el \
	se-mode/se-highlight.el \
	se-mode/se-inf.el \
	se-mode/se-macros.el \
	se-mode/se-mode.el \
	se-mode/se-navi.el \
	se-mode/se-pin.el \
	se-mode/se-markup.el

ELISP=$(SE_MODE) $(CEDILLE_ELISP)

TEMPLATESDIR = $(SRCDIR)/templates
TEMPLATES = $(TEMPLATESDIR)/Mendler.ced $(TEMPLATESDIR)/MendlerSimple.ced

FILES = $(AUTOGEN) $(AGDASRC)

SRC = $(FILES:%=$(SRCDIR)//%)
OBJ = $(SRC:%.agda=%.agdai)

LIB = --library-file=libraries --library=ial --library=cedille 

all: cedille # elisp

libraries: 
	./create-libraries.sh

./src/CedilleParser.hs: parser/src/CedilleParser.y ./src/CedilleLexer.hs
	cd parser; make cedille-parser

./src/CedilleLexer.hs: parser/src/CedilleLexer.x
	cd parser; make cedille-lexer

./src/CedilleCommentsLexer.hs: parser/src/CedilleCommentsLexer.x
	cd parser; make cedille-comments-lexer

./src/CedilleOptionsParser.hs: parser/src/CedilleOptionsParser.y 
	cd parser; make cedille-options-parser

./src/CedilleOptionsLexer.hs: parser/src/CedilleOptionsLexer.x
	cd parser; make cedille-options-lexer

./src/templates.agda: $(TEMPLATES) $(TEMPLATESDIR)/TemplatesCompiler
	$(TEMPLATESDIR)/TemplatesCompiler

CEDILLE_DEPS = $(SRC) Makefile libraries ./src/templates.agda ./src/CedilleParser.hs ./src/CedilleLexer.hs ./src/CedilleCommentsLexer.hs ./src/CedilleOptionsLexer.hs ./src/CedilleOptionsParser.hs
CEDILLE_BUILD_CMD = $(AGDA) $(LIB) --compile-dir=$(OUTDIR) --ghc-flag=-rtsopts -c $(SRCDIR)/main.agda
cedille:	$(CEDILLE_DEPS)
		$(CEDILLE_BUILD_CMD)
		mv $(SRCDIR)/main $@

cedille-static: 	$(CEDILLE_DEPS)
		$(CEDILLE_BUILD_CMD) --ghc-flag=-optl-static --ghc-flag=-optl-pthread 
		mv $(SRCDIR)/main $@

cedille-old:	$(SRC) Makefile libraries
		$(AGDA) $(LIB) --ghc-flag=-rtsopts -c $(SRCDIR)/main-old.agda 
		mv $(SRCDIR)/main-old cedille

# compilation of elisp not working
#
#elisp: $(SE_MODE:%.el=%.elc) $(ELISP:%.el=%.elc)
#
#%.elc: %.el
#	emacs --batch -L se-mode -L cedille-mode -f batch-byte-compile $<

cedille-prof:	$(SRC) Makefile
		$(AGDA) $(LIB) --ghc-flag=-rtsopts --ghc-flag=-prof --ghc-flag=-fprof-auto -c $(SRCDIR)/main.agda 
		mv $(SRCDIR)/main cedille-prof

cedille-main: $(SRCDIR)/cedille-main.agda
	$(AGDA) $(LIB) --ghc-flag=-rtsopts -c $(SRCDIR)/cedille-main.agda 

options-main: $(SRCDIR)/options-main.agda
	$(AGDA) $(LIB) -c $(SRCDIR)/options-main.agda 

cws-main: $(SRCDIR)/cws-main.agda
	$(AGDA) $(LIB) -c $(SRCDIR)/cws-main.agda 

cedille-templates-compiler: $(TEMPLATESDIR)/TemplatesCompiler.hs
	cd $(TEMPLATESDIR); ghc --make -i../ TemplatesCompiler.hs

cedille-deb-pkg: cedille-static
	rm -rf cedille-deb-pkg
	mkdir -p ./cedille-deb-pkg/usr/bin/
	mkdir -p ./cedille-deb-pkg/usr/share/emacs/site-lisp/cedille-mode/
	mkdir -p ./cedille-deb-pkg/DEBIAN/
	cp -R ./cedille-mode/ ./se-mode/ ./docs/info/cedille-info-main.info ./cedille-deb-pkg/usr/share/emacs/site-lisp/cedille-mode/
	cp ./cedille-mode.el ./cedille-deb-pkg/usr/share/emacs/site-lisp/
	cp ./cedille-static ./cedille-deb-pkg/usr/bin/cedille
	cp ./packages/cedille-deb-control ./cedille-deb-pkg/DEBIAN/control
	cp ./packages/copyright ./cedille-deb-pkg/DEBIAN/copyright
	dpkg-deb --build cedille-deb-pkg

cedille-win-pkg: cedille-static
	rm -rf cedille-win-pkg
	mkdir -p ./cedille-win-pkg/src/
	cp -R ./cedille-mode/ ./se-mode/ ./docs/info/cedille-info-main.info ./cedille-mode.el ./packages/copyright ./cedille-win-pkg/src/
	cp ./cedille-static ./cedille-win-pkg/src/cedille.exe
	cp ./packages/cedille-win-install.bat ./cedille-win-pkg/

cedille-mac-pkg: cedille
	rm -rf cedille-mac-pkg
	mkdir -p ./cedille-mac-pkg/Cedille.app/Contents/MacOS/bin/docs/info/
	mkdir -p ./cedille-mac-pkg/Cedille.app/Contents/Resources/
	cp -r cedille ./cedille-mode/ ./se-mode/ ./cedille-mode.el ./cedille-mac-pkg/Cedille.app/Contents/MacOS/bin/
	cp ./docs/info/cedille-info-main.info ./cedille-mac-pkg/Cedille.app/Contents/MacOS/bin/docs/info/
	cp ./packages/mac/cedille.icns ./cedille-mac-pkg/Cedille.app/Contents/Resources/
	cp ./packages/mac/cedille.icns ./cedille-mac-pkg/
	cp ./packages/mac/Info.plist ./cedille-mac-pkg/Cedille.app/Contents/
	cp ./packages/mac/Cedille ./cedille-mac-pkg/Cedille.app/Contents/MacOS/
	cp ./appdmg.json ./cedille-mac-pkg/
	cd ./cedille-mac-pkg && appdmg appdmg.json Cedille.dmg

clean:
	rm -f cedille $(SRCDIR)/main $(OBJ); cd parser; make clean
	rm -rf cedille-deb-pkg

#lines:
#	wc -l $(AGDASRC:%=$(SRCDIR)//%) $(GRAMMARS:%=$(SRCDIR)//%) $(CEDILLE_ELISP)

lines:
	wc -l $(AGDASRC:%=$(SRCDIR)//%) $(CEDILLE_ELISP)

elisp-lines:
	wc -l $(CEDILLE_ELISP)

agda-lines:
	wc -l $(AGDASRC:%=$(SRCDIR)//%)

