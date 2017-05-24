module main where

import parse
import run
open import lib
open import cedille-types

-- for parser for Cedille source files
import cedille
module parsem = parse cedille.gratr2-nt ptr
open parsem.pnoderiv cedille.rrs cedille.cedille-rtn
module pr = run ptr
open pr.noderiv {- from run.agda -}

-- for parser for options files
import options
import options-types
module parsem2 = parse options.gratr2-nt options-types.ptr
module options-parse = parsem2.pnoderiv options.rrs options.options-rtn
module pr2 = run options-types.ptr
module options-run = pr2.noderiv

-- for parser for Cedille comments & whitespace
import cws
import cws-types
module parsem3 = parse cws.gratr2-nt cws-types.ptr
module cws-parse = parsem3.pnoderiv cws.rrs cws.cws-rtn
module pr3 = run cws.ptr
module cws-run = pr3.noderiv

--open import cedille-find
open import classify
open import ctxt
open import constants
open import conversion
open import general-util
open import process-cmd 
open import spans
open import syntax-util
open import to-string
open import toplevel-state

opts : Set
opts = options-types.opts

dot-cedille-directory : string → string 
dot-cedille-directory dir = combineFileNames dir ".cedille"

cede-filename : (ced-path : string) → string
cede-filename ced-path = 
  let dir = takeDirectory ced-path in
  let unit-name = base-filename (takeFileName ced-path) in
    combineFileNames (dot-cedille-directory dir) (unit-name ^ ".cede")

-- .cede files are just a dump of the spans, prefixed by 'e' if there is an error
write-cede-file : (ced-path : string) → (ie : include-elt) → IO ⊤
write-cede-file ced-path ie = 
--  putStrLn ("write-cede-file " ^ ced-path ^ " : " ^ contents) >>
  let dir = takeDirectory ced-path in
    createDirectoryIfMissing ff (dot-cedille-directory dir) >>
    writeFile (cede-filename ced-path) 
      ((if (include-elt.err ie) then "e" else "") ^ 
        (include-elt-spans-to-string ie))

-- we assume the cede file is known to exist at this point
read-cede-file : (ced-path : string) → IO (𝔹 × string)
read-cede-file ced-path = 
  get-file-contents (cede-filename ced-path) >>= λ c → finish c
  where finish : maybe string → IO (𝔹 × string)
        finish nothing = return (tt , global-error-string ("Could not read the file " ^ cede-filename ced-path ^ "."))
        finish (just ss) with string-to-𝕃char ss
        finish (just ss)  | ('e' :: ss') = forceFileRead ss >> return (tt , 𝕃char-to-string ss')
        finish (just ss) | _ = forceFileRead ss >> return (ff , ss)
  
add-cedille-extension : string → string
add-cedille-extension x = x ^ "." ^ cedille-extension 

find-imported-file : (dirs : 𝕃 string) → (unit-name : string) → IO string
find-imported-file [] unit-name = return (add-cedille-extension unit-name) -- assume the current directory if the unit is not found 
find-imported-file (dir :: dirs) unit-name =
  let e = combineFileNames dir (add-cedille-extension unit-name) in
    
    doesFileExist e >>= λ b → 
    if b then
      return e
    else
      find-imported-file dirs unit-name

-- return a list of pairs (i,p) where i is the import string in the file, and p is the full path for that imported file
find-imported-files : (dirs : 𝕃 string) → (imports : 𝕃 string) → IO (𝕃 (string × string))
find-imported-files dirs (u :: us) =
  find-imported-file dirs u >>= λ p →
  find-imported-files dirs us >>= λ ps →
    return ((u , p) :: ps)
find-imported-files dirs [] = return []

ced-file-up-to-date : (ced-path : string) → IO 𝔹
ced-file-up-to-date ced-path =
  let e = cede-filename ced-path in
    doesFileExist e >>= λ b → 
    if b then
      fileIsOlder ced-path e
    else
      return ff

paths-to-𝕃string : options-types.paths → 𝕃 string
paths-to-𝕃string options-types.PathsNil = []
paths-to-𝕃string (options-types.PathsCons p ps) = p :: paths-to-𝕃string ps

opts-get-include-path : opts → 𝕃 string
opts-get-include-path options-types.OptsNil = []
opts-get-include-path (options-types.OptsCons (options-types.Lib ps) oo) = (paths-to-𝕃string ps) ++ opts-get-include-path oo
opts-get-include-path (options-types.OptsCons options-types.NoCedeFiles oo) = opts-get-include-path oo
--opts-get-include-path (options-types.OptsCons _ oo) = opts-get-include-path oo

{- see if "no-cede-files" is turned on in the options file -}
opts-get-no-cede-files : opts → 𝔹
opts-get-no-cede-files options-types.OptsNil = ff
opts-get-no-cede-files (options-types.OptsCons options-types.NoCedeFiles oo) = tt
opts-get-no-cede-files (options-types.OptsCons (options-types.Lib _) oo) = opts-get-no-cede-files oo

{- reparse the given file, and update its include-elt in the toplevel-state appropriately -}
reparse : toplevel-state →(filename : string) → IO toplevel-state
reparse st filename = 
--   putStrLn ("reparsing " ^ filename) >>
   doesFileExist filename >>= λ b → 
     (if b then
         (readFiniteFile filename >>= processText)
      else return (error-include-elt ("The file " ^ filename ^ " could not be opened for reading."))) >>= λ ie →
        return (set-include-elt st filename ie)
  where processText : string → IO include-elt
        processText x with string-to-𝕃char x
        processText x | s with runRtn s
        processText x | s | inj₁ cs =
           return (error-include-elt ("Parse error in file " ^ filename ^ " at position " ^ (ℕ-to-string (length s ∸ length cs)) ^ "."))
        processText x | s | inj₂ r with rewriteRun r
        processText x | s | inj₂ r | ParseTree (parsed-start t) :: [] with cws-parse.runRtn s
        processText x | s | inj₂ r | ParseTree (parsed-start t) :: [] | inj₁ cs =
          return (error-include-elt ("This shouldn't happen in " ^ filename ^ " at position "
                                    ^ (ℕ-to-string (length s ∸ length cs)) ^ "."))
        processText x | s | inj₂ r | ParseTree (parsed-start t) :: [] | inj₂ r2 with cws-parse.rewriteRun r2
        processText x | s | inj₂ r | ParseTree (parsed-start t) :: [] | inj₂ r2 | cws-run.ParseTree (cws-types.parsed-start t2) :: [] =
          find-imported-files (toplevel-state.include-path st) (get-imports t) >>= λ deps → 
          return (new-include-elt filename deps t t2)
        processText x | s | inj₂ r | ParseTree (parsed-start t) :: [] | inj₂ r2 | _ =
          return (error-include-elt ("Parse error in file " ^ filename ^ "."))
        processText x | s | inj₂ r | _ =
          return (error-include-elt ("Parse error in file " ^ filename ^ "."))

add-spans-if-up-to-date : (up-to-date : 𝔹) → (use-cede-files : 𝔹) → (filename : string) → include-elt → IO include-elt
add-spans-if-up-to-date up-to-date use-cede-files filename ie = 
  if up-to-date && use-cede-files then
    (read-cede-file filename >>= finish)
  else
    return ie
  where finish : 𝔹 × string → IO include-elt
        finish (err , ss) = return (set-do-type-check-include-elt (set-spans-string-include-elt ie err ss) ff)

{- make sure that the current ast and dependencies are stored in the
   toplevel-state, updating the state as needed. -}
ensure-ast-deps : toplevel-state → (filename : string) → IO toplevel-state
ensure-ast-deps s filename with get-include-elt-if s filename
ensure-ast-deps s filename | nothing =
  let ucf = (toplevel-state.use-cede-files s) in
    reparse s filename >>= λ s → 
    ced-file-up-to-date filename >>= λ up-to-date → 
    add-spans-if-up-to-date up-to-date ucf filename (get-include-elt s filename) >>= λ ie →
    return (set-include-elt s filename ie)
ensure-ast-deps s filename | just ie =
  let ucf = (toplevel-state.use-cede-files s) in
    ced-file-up-to-date filename >>= λ up-to-date → 
      if up-to-date then 
        (add-spans-if-up-to-date up-to-date (toplevel-state.use-cede-files s) filename (get-include-elt s filename) >>= λ ie →
         return (set-include-elt s filename ie))
      else reparse s filename
     
{- helper function for update-asts, which keeps track of the files we have seen so
   we avoid importing the same file twice, and also avoid following cycles in the import
   graph. -}
{-# TERMINATING #-}
update-astsh : stringset {- seen already -} → toplevel-state → (filename : string) → 
               IO (stringset {- seen already -} × toplevel-state)
update-astsh seen s filename = 
--  putStrLn ("update-astsh [filename = " ^ filename ^ "]") >>
  if stringset-contains seen filename then return (seen , s)
  else (ensure-ast-deps s filename >>= cont (stringset-insert seen filename))
  where cont : stringset → toplevel-state → IO (stringset × toplevel-state)
        cont seen s with get-include-elt s filename
        cont seen s | ie with include-elt.deps ie 
        cont seen s | ie | ds = 
          proc seen s ds 
          where proc : stringset → toplevel-state → 𝕃 string → IO (stringset × toplevel-state)
                proc seen s [] = 
                  if (list-any (get-do-type-check s) ds) 
                  then return (seen , set-include-elt s filename (set-do-type-check-include-elt ie tt)) 
                  else return (seen , s)
                proc seen s (d :: ds) = update-astsh seen s d >>= λ p → 
                                        proc (fst p) (snd p) ds

{- this function updates the ast associated with the given filename in the toplevel state.
   So if we do not have an up-to-date .cede file (i.e., there is no such file at all,
   or it is older than the given file), reparse the file.  We do this recursively for all
   dependencies (i.e., imports) of the file. -}
update-asts : toplevel-state → (filename : string) → IO toplevel-state
update-asts s filename = update-astsh empty-stringset s filename >>= λ p → 
  return (snd p)

{- this function checks the given file (if necessary), updates .cede files (again, if necessary), and replies on stdout if appropriate -}
checkFile : toplevel-state → (filename : string) → (should-print-spans : 𝔹) → IO toplevel-state
checkFile s filename should-print-spans = 
--  putStrLn ("checkFile " ^ filename) >>
  update-asts s filename >>= λ s → 
  finish (process-file s filename)
 
  where reply : toplevel-state → IO ⊤
        reply s with get-include-elt-if s filename
        reply s | nothing = 
           putStrLn (global-error-string 
                     ("Internal error looking up information for file " ^ filename ^ "."))
        reply s | just ie =
           if should-print-spans then
             putStrLn (include-elt-spans-to-string ie)
           else return triv
        finish : toplevel-state → IO toplevel-state
        finish s with s
        finish s | mk-toplevel-state use-cede ip mod is Γ = 
          writeo mod >>
          reply s >>
          return (mk-toplevel-state use-cede ip [] is Γ)
          where writeo : 𝕃 string → IO ⊤
                writeo [] = return triv
                writeo (f :: us) =
                 let ie = get-include-elt s f in
                   (if use-cede then (write-cede-file f ie) else (return triv)) >>
                   writeo us

-- this is the function that handles requests (from the frontend) on standard input
{-# TERMINATING #-}
readCommandsFromFrontend : toplevel-state → IO ⊤
readCommandsFromFrontend s =
    getLine >>= λ input → 
    let input-list : 𝕃 string 
        input-list = (string-split input delimiter) 
            in (handleCommands input-list s) >>= λ s →
        readCommandsFromFrontend s
        where
            delimiter : char
            delimiter = '§'
            errorCommand : toplevel-state → IO toplevel-state
            errorCommand s = putStrLn (global-error-string "Invalid command sequence.") >>= λ x → return s
            debugCommand : toplevel-state → IO toplevel-state
            debugCommand s = putStrLn (escape-string (toplevel-state-to-string s)) >>= λ x → return s
            checkCommand : 𝕃 string → toplevel-state → IO toplevel-state
            checkCommand (input :: []) s = canonicalizePath input >>= λ input-filename →
                        checkFile (set-include-path s (takeDirectory input-filename :: toplevel-state.include-path s))
                        input-filename tt {- should-print-spans -}
            checkCommand _ s = errorCommand s
  {-          findCommand : 𝕃 string → toplevel-state → IO toplevel-state
            findCommand (symbol :: []) s = putStrLn (find-symbols-to-JSON symbol (toplevel-state-lookup-occurrences symbol s)) >>= λ x → return s
            findCommand _ s = errorCommand s -}
            handleCommands : 𝕃 string → toplevel-state → IO toplevel-state
            handleCommands ("debug" :: []) s = debugCommand s
--            handleCommands ("find" :: xs) s = findCommand xs s
            handleCommands ("check" :: xs) s = checkCommand xs s
            handleCommands _ s = errorCommand s


-- function to process command-line arguments
processArgs : opts → 𝕃 string → IO ⊤ 

-- this is the case for when we are called with a single command-line argument, the name of the file to process
processArgs oo (input-filename :: []) =
  canonicalizePath input-filename >>= λ input-filename → 
  checkFile (new-toplevel-state (takeDirectory input-filename :: opts-get-include-path oo) (~ (opts-get-no-cede-files oo)))
    input-filename ff {- should-print-spans -} >>= finish input-filename
  where finish : string → toplevel-state → IO ⊤
        finish input-filename s = 
          let ie = get-include-elt s input-filename in
          if include-elt.err ie then (putStrLn (include-elt-spans-to-string ie)) else return triv

-- this is the case where we will go into a loop reading commands from stdin, from the fronted
processArgs oo [] = readCommandsFromFrontend (new-toplevel-state (opts-get-include-path oo) (~ (opts-get-no-cede-files oo)))

-- all other cases are errors
processArgs oo xs = putStrLn ("Run with the name of one file to process, or run with no command-line arguments and enter the\n"
                         ^ "names of files one at a time followed by newlines (this is for the emacs mode).")

-- helper function to try to parse the options file
processOptions : string → string → (string ⊎ options-types.opts)
processOptions filename s with string-to-𝕃char s
...                       | i with options-parse.runRtn i
...                           | inj₁ cs =
                                     inj₁ ("Parse error in file " ^ filename ^ " at position " ^ (ℕ-to-string (length i ∸ length cs)) ^ ".")
...                           | inj₂ r with options-parse.rewriteRun r
...                                    | options-run.ParseTree (options-types.parsed-start (options-types.File oo)) :: [] = inj₂ oo
...                                    | _ =  inj₁ ("Parse error in file " ^ filename ^ ". ")

-- read the ~/.cedille/options file
readOptions : IO (string ⊎ options-types.opts)
readOptions =
  getHomeDirectory >>= λ homedir →
    let homecedir = dot-cedille-directory homedir in
    let optsfile = combineFileNames homecedir options-file-name in
      createDirectoryIfMissing ff homecedir >>
      doesFileExist optsfile >>= λ b → 
       if b then
         (readFiniteFile optsfile >>= λ f → return (processOptions optsfile f))
       else
         (return (inj₂ options-types.OptsNil))

-- main entrypoint for the backend
main : IO ⊤
main = initializeStdoutToUTF8 >> setStdoutNewlineMode >> readOptions >>= next
  where next : string ⊎ options-types.opts → IO ⊤
        next (inj₁ s) = putStrLn (global-error-string s)
        next (inj₂ oo) = getArgs >>= processArgs oo

