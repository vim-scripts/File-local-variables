" localvariables.vim -- Set/let per-file-variables à la Emacs
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     08-Dec-2003.
" @Last Change: 14-Mär-2004.
" @Revision: 2.0.26

if &cp || exists("s:loaded_localvariables")
    finish
endif
let s:loaded_localvariables = 1

fun! <SID>ConditionalLet(var,value)
    if !exists(a:var)
        exe "let ".a:var." = ".a:value
    endif
endfun

call <SID>ConditionalLet("g:localVariablesRange",                 "30")
call <SID>ConditionalLet("g:localVariablesBegText",               "'Local Variables:'")
call <SID>ConditionalLet("g:localVariablesEndText",               "'End:'")
call <SID>ConditionalLet("g:localVariablesDownCaseHyphenedNames", "1")

let s:localVariablesAllowExec=1

fun! <SID>LocalVariablesAskUser(prompt, default)
    if has("gui_running")
        let val = inputdialog(a:prompt, a:default)
    else
        call inputsave()
        let val = input(a:prompt, a:default)
        call inputrestore()
    endif
    return val
endfun

if s:localVariablesAllowExec >= 1
    fun! <SID>LocalVariablesAllowSpecial(class, value)
        let force = (a:value =~? 'localVariables\|system')
        if s:localVariablesAllowExec > 0
            if !force && s:localVariablesAllowExec == 3
                return 1
            else
                let default = s:localVariablesAllowExec == 2 ? "y" : "n"
                let options = s:localVariablesAllowExec == 2 ? "(Y/n)" : "(y/N)"
                return <SID>LocalVariablesAskUser("LocalVariables: Allow ". a:class ." '".a:value."'? ".
                            \ options, default) ==? "y"
            endif
        else
            return 0
        endif
    endfun
    fun! <SID>LocalVariablesExecute(cmd)
        exec a:cmd
    endfun
    fun! LocalVariablesAppendEvent(event, value)
        if !exists("b:LocalVariables". a:event)
            let pre = ""
        else
            let pre = b:LocalVariables{a:event} ."|"
        endif
        exe "let b:LocalVariables". a:event .' = "'. escape(pre, '"') . escape(a:value, '"') .'"'
    endfun
else
    fun! <SID>LocalVariablesAllowSpecial(class, value)
        return 0
    endfun
    fun! <SID>LocalVariablesExecute(cmd)
        echomsg "LocalVariables: Disabled: ".a:cmd
    endfun
    fun! LocalVariablesAppendEvent(event, value)
        echomsg "LocalVariables: Disabled Event Handling: ".a:event."=".a:value
    endfun
endif

fun! <SID>LocalVariablesSet(line, prefix, suffix)
    let l:scope     = ""
    let l:prefixEnd = strlen(a:prefix)
    let l:scopeEnd  = matchend(a:line, "^.:", l:prefixEnd)
    if l:scopeEnd >= 0
        let l:scope = strpart(a:line, l:prefixEnd, 2)
    else
        let l:scopeEnd = l:prefixEnd
    endif
    
    let l:varEnd = matchend(a:line, '.\{-}:', l:scopeEnd)
    if l:varEnd >= 0
        let l:var = strpart(a:line, l:scopeEnd, l:varEnd-l:scopeEnd-1)
        if l:var =~ "-"
            if g:localVariablesDownCaseHyphenedNames
                let l:var = tolower(l:var)
            endif
            let l:var = substitute(l:var, "-\\(.\\)", "\\U\\1", "g")
        endif
    else
        throw "Local Variables: No variable name found in: ".a:line
    endif
    if l:scope == ""
        if exists("g:localVariableX".l:var)
            let l:var = g:localVariableX{l:var}
        elseif exists("*LocalVariableX".l:var)
            let l:scope = "X"
        else
            let l:scope = "b:"
        endif
    endif
    
    let l:valLen = strlen(a:line) - l:varEnd - strlen(a:suffix)
    if l:valLen > 0
        let l:value = substitute(strpart(a:line, l:varEnd, l:valLen), '^\s\+', "", "")
    else
        throw "Local Variables: No value given for ".l:var
    endif
    
    if l:scope == "::"
        if l:var =~ "^\\cexec\\(u\\(t\\(e\\)\\?\\)\\?\\)\\?$"
            if <SID>LocalVariablesAllowSpecial("execute", l:value)
                call <SID>LocalVariablesExecute(l:value)
            else
                echomsg "Local Variables: Disabled: ".l:value
            endif
        elseif l:var =~? '^On.\+'
            let event = matchstr(l:var, '\c^On\zs.\+')
            if <SID>LocalVariablesAllowSpecial(event, l:value)
                call LocalVariablesAppendEvent(event, l:value)
            else
                echomsg "Local Variables: Disabled: ".l:value
            endif
        else
            throw "Local Variables: Unknown special name: ".l:var
        endif
    elseif l:scope ==# "X"
        call LocalVariableX{l:var}(l:value)
    elseif l:var =~# "localVariablesAllowExec"
        throw "Local Variables: Can't set: ".l:var
    else
        if l:scope ==# "&:"
            exe 'setlocal '.l:var.'='.l:value
        else
            if !(l:value =~ "^\\([\"']\\)[^\"]*\\1$")
                let l:value = '"'.escape(l:value, '"\').'"'
            endif
            exe 'let '.l:scope.l:var.' = '.l:value
        endif
    endif
endfun

fun! <SID>LocalVariablesSearch(repos)
    if a:repos
        let l:currline  = line(".")
        let l:currcol  = col(".")
    endif
    let l:startline = line("$") - g:localVariablesRange
    call cursor(l:startline, 1)
    let l:rv = search("\\V\\C\\^\\(\\.\\*\\)". g:localVariablesBegText ."\\(\\.\\*\\)\\n\\(\\_^\\1\\.\\+:\\.\\+\\2\\n\\)\\*\\_^\\1". g:localVariablesEndText ."\\2\\$", "W")
    if a:repos
        call cursor(l:currline, l:currcol)
    endif
    return l:rv
endfun 

fun! LocalVariablesReCheck()
    let l:currline = line(".")
    let l:currcol  = col(".")
    let l:pos = <SID>LocalVariablesSearch(0)
    if l:pos
        let l:line = getline(l:pos)
        let l:locVarBegPos = match(l:line, "\\V\\C".g:localVariablesBegText)
        if l:locVarBegPos >= 0
            let l:prefix = strpart(l:line, 0, l:locVarBegPos)
            let l:suffix = strpart(l:line, l:locVarBegPos + strlen(g:localVariablesBegText))
        else
            throw "Local Variables: Parsing error (please report)"
        endif
        let l:endPos = search("\\V\\C\\^"
                    \ . substitute(l:prefix, "\\", "\\\\\\\\", "g")
                    \ . g:localVariablesEndText
                    \ . substitute(l:suffix, "\\", "\\\\\\\\", "g")
                    \ . "\\$", "W") - 1
        while l:pos < l:endPos
            let l:pos = l:pos + 1
            call <SID>LocalVariablesSet(getline(l:pos), l:prefix, l:suffix)
        endwh
    endif
    let b:localVariablesChecked = 1
    call cursor(l:currline, l:currcol)
endfun

fun! LocalVariablesCheck()
    if !exists("b:localVariablesChecked")
        call LocalVariablesReCheck()
    endif
endfun

fun! LocalVariablesRunEventHook(event)
    if exists("b:LocalVariables". a:event)
        exe b:LocalVariables{a:event}
    endif
endfun

fun! LocalVariablesRegisterHook(event, bang)
    if exists("b:LocalVariablesRegisteredHooks")
        if (b:LocalVariablesRegisteredHooks =~? "|". a:event ."|")
            if !(a:bang == "!")
                throw "Local Variables: Already registered for ". a:event
            else
                return
            endif
        else
            let b:LocalVariablesRegisteredHooks = b:LocalVariablesRegisteredHooks . a:event ."|"
        endif
    else
        let b:LocalVariablesRegisteredHooks = "|". a:event ."|"
    endif
    exe "au ". a:event ." * call LocalVariablesRunEventHook('". a:event ."')"
endfun

command! LocalVariablesReCheck call LocalVariablesReCheck()
" command! -nargs=1 LocalVariablesRunEventHook call LocalVariablesRunEventHook(<q-args>)
command! -nargs=1 -bang LocalVariablesRegisterHook call LocalVariablesRegisterHook(<q-args>, <q-bang>)

