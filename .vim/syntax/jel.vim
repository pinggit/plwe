" Vim syntax file
" Language:     erx config file and log file
" Last Change:  2012-07-16

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

if !exists("MyAsciidocDebug")
    let MyAsciidocDebug = 0
endif

"(2013-05-17) add max file size detection
let s:largefilesize = 2000000
let s:fsize = getfsize(expand('%%:p')) "get current file size
if MyAsciidocDebug | echom "filesize is" s:fsize | endif
if (s:fsize >= s:largefilesize)
    echom "file too large (current size:" . s:fsize . " Bytes > maxsize for ft check " . s:largefilesize . " Bytes!) , won't set ft"

    if input("are you sure you want to set ft (might take long time) ? (y/n):",'y') == 'y'

    else
        finish
    endif
endif

setlocal iskeyword+=-

syn match ciscoComment	"^\s*!.*$"
hi def link ciscoComment Comment

syn match ciscoIpAddr /\<\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\.\(25[0-5]\|2[0-4][0-9]\|[01]\?[0-9][0-9]\?\)\>/
hi def link ciscoIpAddr	Number

syn match ciscoIfName /\<\(Loopback\|Tunnel\|Dialer\)[0-9][0-9]*\>/
syn match ciscoIfName +\<\(Ethernet\|FastEthernet\|GigabitEthernet\)[0-9][0-9]*/[0-9][0-9]*\(/[0-9][0-9]*\)\?\(\.[0-9][0-9]*\)\?\>+
syn match ciscoIfName +\<ATM[0-9][0-9]*\(/[0-9][0-9]*\)*\(\.[0-9][0-9]*\)\?\>+
hi def link ciscoIfName	Identifier

syn match ciscoWord contained +[a-zA-Z0-9-_]*+
hi def link ciscoWord String


syn region ciscoUsernames start=+^username\s+ skip=+^username\s+ end=+^\S+me=s-1 fold
syn region ciscoIpHosts start=+^ip host\s+ skip=+^ip host\s+ end=+^\S+me=s-1 fold


syn region ciscoInterfaces start=+^interface\s+ skip=+^\(!\n\)\?interface\s+ end=+^\S+me=s-1 fold contains=ciscoInterfaceRegion
syn region ciscoInterfaceRegion contained start=+^interface\s+ end=+^\S+me=s-1 fold contains=ciscoIpAddr,ciscoIfName,ciscoComment

syn region ciscoRouters start=+^router\s+ skip=+^\(!\n\)\?router\s+ end=+^\S+me=s-1 fold contains=ciscoRouterRegion
syn region ciscoRouterRegion start=+^router\s+ end=+^\S+me=s-1 contained fold contains=ciscoIpAddr,ciscoIfName,ciscoComment


syn region ciscoIpRoutes start=+^ip route\s+ end=+^\(ip route\)\@!+me=s-1 fold contains=ciscoIpRoute
syn match ciscoIpRoute +^ip route.*$+ contained skipwhite contains=ciscoIpAddr,ciscoNumber,ciscoIfName


syn region ciscoIpAccessLists start=+^ip access-list\s+ skip=+^\(!\n\)\?ip access-list\s+ end=+^\S+me=s-1 fold contains=ciscoIpAccessList
syn region ciscoIpAccessList contained start=+^ip access-list\s+ end=+^\S+me=s-1 fold contains=ciscoIpAccessListNamed,ciscoIpAddr,ciscoIfName,ciscoComment,ciscoAclKeywords,ciscoAclOperator
syn match ciscoIpAccessListNamed +^ip access-list \(standard\|extended\) + contained nextgroup=ciscoWord skipwhite
syn keyword ciscoAclKeywords contained skipwhite host any
syn keyword ciscoAclOperator contained skipwhite eq ne
hi def link ciscoAclKeywords Keyword
hi def link ciscoAclOperator Special

syn region ciscoAccessLists start=+^access-list\s+ skip=+^access-list\s+ end=+^\S+me=s-1 fold contains=ciscoAccessList
syn region ciscoAccessList start=+^access-list \z(\d\+\)\ + skip=+^access-list \z1 + end=+^\S+me=s-1 contained fold contains=ciscoIpAddr,ciscoIfName


syn region ciscoRouteMaps start=+^route-map\s+ skip=+^\(!\n\)\?route-map\s+ end=+^\S+me=s-1 fold contains=ciscoRouteMap
syn region ciscoRouteMap contained start=+^route-map\s+ end=+^\S+me=s-1 fold contains=ciscoIpAddr,ciscoIfName,ciscoComment


syn region ciscoCryptoIsakmp start=+^crypto isakmp\s+ end=+^\S+me=s-1 fold

syn region ciscoCryptoIsakmpKeys start=+^crypto isakmp key\s+ skip=+^crypto isakmp key\s+ end=+^\S+me=s-1 fold

syn region ciscoCryptoIpsecTses start=+^crypto ipsec transform-set\s+ skip=+^crypto ipsec transform-set\s+ end=+^\S+me=s-1 fold contains=ciscoCryptoIpsecTs
syn match ciscoCryptoIpsecTs contained +^crypto ipsec transform-set + nextgroup=ciscoWord skipwhite

syn region ciscoCryptoMaps start=+^crypto map\s+ skip=+^crypto map\s+ end=+^\S+me=s-1 fold contains=ciscoCryptoMap
syn region ciscoCryptoMap start=+^crypto map \z(\S\+\)\ + skip=+^crypto map \z1 + end=+^\S+me=s-1 contained fold contains=ciscoCryptoMapEntry
syn region ciscoCryptoMapEntry contained start=+^crypto map\s+ end=+^\S+me=s-1 fold contains=ciscoCryptoMapName,ciscoIpAddr
syn match ciscoCryptoMapName contained +^crypto map + nextgroup=ciscoWord skipwhite


"ping: fold more Junos-e specific configs
"syn region ciscoComment start=/^!/ end=/^!.*\n^[^!]/ fold
syn region ciscoComment start=/^!/ skip=/^!/ end=/^\S/me=s-1 fold
syn region ciscoBoot start=+^\(boot\|no boot\)\s+ skip=+^\(boot\|no boot\)\s+ end=+^\S+me=s-1 fold
syn region ciscoAaa start=+^\(aaa\)\s+ skip=+^\(aaa\)\s+ end=+^\S+me=s-1 fold
syn region ciscoController start=+^\(controller\)\s+ skip=+^\(controller\)\s+ end=+^\S+me=s-1 fold
syn region ciscoSupicious start=+^\(suspicious\|dos-protection\)+ skip=+^\(suspicious\|dos-protection\)+ end=+^\S+me=s-1 fold
syn region ciscoLine start=+^\(line\|privilege\)\s+ skip=+^\(line\|privilege\)\s+ end=+^\S+me=s-1 fold
syn region ciscoProfile start=/^\(\S\{-}profile\)\s/ skip=/^\(\S\{-}profile\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIpRateLimitProfile start=/^\(ip rate-limit-profile\)\s/ skip=/^\(ip rate-limit-profile\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIpVrf start=/^\(ip vrf\)\s/ skip=/^\(ip vrf\)\s/ end=/^\S/me=s-1 fold
syn region ciscoSnmp start=/^\(snmp-server\)\s/ skip=/^\(snmp-server\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIplocalpool start=/^\(ip local pool\)\s/ skip=/^\(ip local pool\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIpPrefix start=/^\(ip prefix-list\)\s/ skip=/^\(ip prefix-list\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIpClassifier start=/^\(ip classifier-list\)\s/ skip=/^\(ip classifier-list\)\s/ end=/^\S/me=s-1 fold
syn region ciscoIpPolicy start=/^\(ip policy-list\)\s/ skip=/^\(ip policy-list\)\s/ end=/^\S/me=s-1 fold
syn region ciscoRtr start=/^\(rtr\)\s/ skip=/^\(rtr\)\s/ end=/^\S/me=s-1 fold
syn region ciscoBgp start=/^\(router bgp\)\s/ skip=/^\(router bgp\)\s/ end=/^\S/me=s-1 fold
syn region ciscoSnmp start=/^\(snmp-server\)/ skip=/^\(snmp-server\)/ end=/^\S/me=s-1 fold
syn region ciscoLog start=/^\(log\)\s/ skip=/^\(log\)\s/ end=/^\S/me=s-1 fold
syn region ciscoLog start=/^\(mpls match\)\s/ skip=/^\(mpls match\)\s/ end=/^\S/me=s-1 fold
syn region ciscoComm start=/^\(ip community-list\)\s/ skip=/^\(ip community-list\)\s/ end=/^\S/me=s-1 fold
syn region ciscoNtp start=/^\(ntp\)\s/ skip=/^\(ntp\)\s/ end=/^\S/me=s-1 fold
"syn region ciscoController start=/^\(controller \w\+ \d\{1,2}\/\d\{1,2}\)\n/ skip=/^\(controller \w\+ \d\{1,2}\/\d\{1,2}\)\n!/ end=/^\S/me=s-1 fold

"ping: fold log files
"
"following are obsolete fold, suppressed by the last 2 fold
"syn region ciscoShow start=/^\(\S\{-}#show\)\s/ end=/^\(\S\{-}#show\)\s/me=s-1 fold
"syn region ciscoSh start=/^\(\S\{-}#sh\)\s/ end=/^\(\S\{-}#sh\)\s/me=s-1 fold
"syn region ciscoTech start=/^\(\S\{-}#tech-support\)\s/ end=/^\(\S\{-}#tech-support\)\s/me=s-1 fold
"this can fold any commands, but need an addi prompt line for each cmd
"syn region ciscoCheckLog start=/^\(\S\{-}#\S\+\)\s/ end=/^\S\{-}#\s$/me=s fold
"
"this seems so far the best
"more about the fancy '/me=s-1':
"    /ms,/me:  
"    m: match: matched strings per the regex
"    s: start; e: end; 'anchor' of charactor in the matched string
"    me=s-12 : match end is the CH from 'the matched string' counting 12 CH backward
"    in this example, the 'end' regex matches 'CLR2.SLC-UT#'(12 CHs)
"    so me=s-12 make the 'match end' to be the prev line -- end of the prev CLI output
"syn region ciscoCheckLog start=/^\(\S\{-}#\S\+\)\s/ end=/^\(\S\{-}#\|^->\)/me=s-1 fold
"syn region erxShell start=/^\(->\s\S\+\)/ end=/^->/me=s-1 fold
"syn region erxShowTac start=/^\(\*-\*-\*-\*-\*-\)/ end=/^\(\*-\*-\*-\*-\*-\)/me=s-1 fold
"
"combile all above 3
"match start:
"   non-blank in b.o.l
"   need to contain one of:
"    	'#'	    :cisco,juniper,most vendor
"    	'->'	    :junos-e vxworks shell
"    	'*-*-*-*-*-':junos-e show-tech
"
"   for '#':
"	at least 2CH before '#',e.g.: R1#blabla
"	leading spaces are ok in CMD: R1# blabla
"	no space preceding # 	: R1 #blabla (not ok)
"
"   for '->':
"	'slot NN->cmd', N can be 1 or 2 digits (LM shell)
"	'->cmd', cmd can be 1 (like 'd') or more CHs (LM serial shell)
"	'-> cmd', optionally w/ a preceding space (SRP shell)
"
"match end:
"   '#' line same as start, optionally CMD following
"   'slot NN->' optionally CMD following
"   '->' at start of the line, optionally followed by some CMDs
"
"   everything between the match-start and one line before (me=s-1) the match-end will be fold
"   	so if other texts are following a cmd output,
"   	add one more prompt line to end the fold before the texts
"   for '#':
"   	it can be : 'R1#' , 
"   	or just a heading '#' (unless some cmd also print a line starting with #)
"   for '->':
"   	it can be just a heading ->
"
"   etc.
"
"Note: this will be conflicting with cisco config foldings
"comment these out in that case
"v1:syn region erxLog 
"	    \start=/^\(\S\S\+.\{0,45}\S#\s*\S\+\|slot \d\d\=->\S\+\|->.\+\|\*-\*-\*-\*-\*-\)/ 
"	    \end=/^\(\S\+.\{0,45}\S#\|^#$\|->\|slot \d\d\=->\|\*-\*-\*-\*-\*-\)/me=s-1 fold

"add exec mode prompt: > , and junos shell %
"v2:syn region erxLog 
"	    \start=/^\(\S\S\+.\{0,45}\S[#>%]\s*\S\+\|slot \d\d\=->\S\+\|->.\+\|\*-\*-\*-\*-\*-\)/ 
"	    \end=/^\(\S\+.\{0,45}\S[#>%]\|^[#>%]$\|->\|slot \d\d\=->\|\*-\*-\*-\*-\*-\)/me=s-1 fold

"v3:
"strict the prompt string, to exclude this:
"disk0:/outgoing <DIR>                                 0               12/24/2007 20:27:10      
"                 heap   cpu
"slot    type     (%)    (%)
"to achieve that, just change .(any CH) to [^xyz] (anything but not x,y,z)
"
"shorten the prompt lenth to 40
"syn region erxLog 
"	    \start=/^\(\S\S\+[^ <(]\{0,37}\S[#>%]\s*\S\+\|slot \d\d\=->\S\+\|->.\+\|\*-\*-\*-\*-\*-\)/ 
"	    \end=/^\(\S\+[^ <(]\{0,37}\S[#>%]\|^[#>%]$\|->\|slot \d\d\=->\|\*-\*-\*-\*-\*-\)/me=s-1 fold
"
"set foldmethod=syntax
"
"let b:current_syntax = "erxlog"

"v3a:
"change ^[#>%]$ to ^[#>%]$\s*\S\+  
"this is to prevent extra return caused prompt line from appearing after fold
"syn region erxLog 
"	    \start=/^\(\S\S\+[^ <(]\{0,37}\S[#>%$]\s*\S\+\|slot \d\d\=->\S\+\|->.\+\|\*-\*-\*-\*-\*-\)/ 
"	    \end=/^\(\S\+[^ <(]\{0,37}\S[#>%$]\s*\S\+\|^[#>%]$\|->\|slot \d\d\=->\|\*-\*-\*-\*-\*-\)/me=s-1 fold

"v3b:
syn region erxLog 
	    \start=/^\(\S\S\+[^ <(]\{0,37}\S[#>%$]\s*\w\+\|slot \d\d\=->\S\+\|->.\+\|\*-\*-\*-\*-\*-\)/ 
	    \end=/^\(\S\+[^ <(]\{0,37}\S[#>%$]\s*\w\+\|^[#>%]$\|->\|slot \d\d\=->\|\*-\*-\*-\*-\*-\)/me=s-1 fold

set foldmethod=syntax

let b:current_syntax = "erxlog"
" vim: set ts=4
