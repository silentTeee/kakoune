# Detection, using GNAT file structure
hook global BufCreate .*\.(adb|ads)$ %{
    set-option buffer filetype ada
}

hook global WinSetOption filetype=(ada) %[
    require-module ada
    hook window InsertChar \n -group ada-indent ada-indent-on-new-line
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window ada-.+ }
    set-option window static_words %opt{static_words}
]

hook -group ada-highlight global WinSetOption filetype=(ada) %[
    add-highlighter window/ada ref ada
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/ada }
]

provide-module ada %§

add-highlighter shared/ada regions
add-highlighter shared/ada/code default-region group

# NOTE: see http://ada-auth.org/standards/rm12_w_tc1/html/RM-P.html for syntax
# summary
evaluate-commands %sh{

    # Numbers literals (https://www.adaic.org/resources/add_content/standards/05rm/html/RM-2-4-1.html)
    numeral='\d+(?:_\d+)*'
    exponent="[eE][+-]?${numeral}"
    decimal_literal="${numeral}(?:\.${numeral})?(?:${exponent})?"

    base="${numeral}"
    based_numeral='[0-9a-fA-F]+(?:_[0-9a-fA-F]+)*'
    based_literal="${base}#${based_numeral}(?:\.${based_numeral})?#(?:${exponent})?"

    # Character literals
    char_literal="'.'"

    # Declarations

    # This might seem like a lot of effort to highlight routines correctly but 
    # it is worth it
    id='[_a-zA-Z]\w{,126}' # identifier for variables
    enum_literal="(?:${id})|(?:${char_literal})"
    enum_type_def="\(\s*${enum_literal}(?:\s*,\s*${enum_literal})*\s*\)"
    signed_int_type_def="range\s+"
    int_type_def="(?:${signed_int_type_def})|(?:${mod_type_def})"
    type_def="(?:${enum_type_def})"
    type_def="${type_def}|(?:${int_type_def})"
    type_def="${type_def}|(?:${real_type_def})"
    type_def="${type_def}|(?:${array_type_def})"
    type_def="${type_def}|(?:${record_type_def})"
    type_def="${type_def}|(?:${access_type_def})"
    type_def="${type_def}|(?:${derived_type_def})"
    type_def="${type_def}|(?:${iface_type_def})"

    
    full_type_declaration="type (${id})\s+(${known_discriminant_part})?\s+is\s+(${type_def})\s+(${aspect_def})?;"
    
    

    # This might seem like a lot of effort to highlight routines correctly but 
    # it is worth it

    id='([_a-zA-Z][\w]{,126})\s*' # identifier for variables etc.
    id2="(?:$id\.)?$id(?:<.*?>)?" # (module|type).id
    id4="(?:$id\.)?(?:$id\.)?(?:$id\.)?$id" # type.type.type.id
    type=":\s*(?:(array\s+of\s+)?$id2)" # 1:attribute 2:keyword 3:module 4:type

    cat <<EOF
        # routine without parameters
        add-highlighter shared/ada/code/simple_routine regex \
            "\b(?i)(function|procedure)\s+$id4(?:$type)?" \
            2:type 3:type 4:type 5:function 6:attribute 7:keyword 8:module 9:type

        # routine with parameters
        add-highlighter shared/ada/routine region \
            "\b(?i)(function|procedure)(\s+$id4)?\s*(<.*?>)?\s*\("  "\).*?;" regions

        add-highlighter shared/ada/routine/parameters  region -recurse \( \( \) regions
EOF

    # Used to highlight "var1, var2, var3, var4 : type" declarations
    param="$id\s*:\s*(?:(in|out|access|constant)\s+)\s*(?:$id4);"

    for r in routine; do
        cat <<EOF
            add-highlighter shared/ada/$r/parameters/default default-region group
            add-highlighter shared/ada/$r/parameters/default/ regex \
                "(?i)(?:$param\s*)*" \
                3:variable 4:variable 5:variable 6:variable 7:variable 8:attribute 9:keyword 10:module 11:type
            add-highlighter shared/ada/$r/default default-region group
EOF
    done

    cat <<EOF
        add-highlighter shared/ada/routine/default/ regex \
            "\b(?i)(function|procedure)(?:\s+$id4)?" \
            1:keyword 2:type 3:type 4:type 5:function
        add-highlighter shared/ada/routine/default/return_type regex \
            "(?i)$type" 1:attribute 2:keyword 3:module 4:type
        add-highlighter shared/ada/routine/default/ regex \
            "(?i)(of\s+object|is\s+nested)" 1:keyword
EOF


    for r in ada ada/routine ada/routine/parameters; do
        cat <<EOF
            # Example string: "The title is ""To Kill A Mockingbird"""
            add-highlighter shared/$r/string region \
                -recurse %{(?<!")("")+(?!")} %{"} %{"(?!")|\$} group
            add-highlighter shared/$r/string/ fill string
            add-highlighter shared/$r/string/escape regex '""' 0:+b

            # comments
            add-highlighter shared/$r/comment_oneline region -- $ fill comment
EOF
    done


    # Reserved Words (http://www.ada-auth.org/standards/12rm/html/RM-2-9.html)
    reserved='abort abs accept access all and array at begin body case constant
              declare delay delta digits do else elsif end entry exception exit
              for function generic goto if in is loop mod new not of or others 
              out package pragma procedure raise range rem requeue return reverse
              select separate some subtype task terminate then type until use
              when while with xor'

    modifiers='abstract aliased interface limited overriding private protected
               record renames synchronized tagged'

    # Common Types (http://www.ada-auth.org/standards/12rm/html/RM-A-1.html)
    types='Boolean Character Constraint_Error Duration Float Integer Natural
           Positive Program_Error Storage_Error String Tasking_Error 
           Wide_Character Wide_Wide_Character Wide_String Wide_Wide_String'

    # Common Constants
    constants='False True null'

    # Add the language's grammar to the static completion list
    echo declare-option str-list static_words $reserved $modifiers $types \
        $constants

    # Replace spaces with a pipe
    join() { eval set -- $1; IFS='|'; echo "$*"; }

    cat <<EOF
        add-highlighter shared/ada/code/modifiers regex \
            (?i)(?<!\.)\b($(join "$modifiers"))\b(?!\()|message\s+(?!:) 0:attribute
        add-highlighter shared/ada/code/index regex \
            '\b(?i)(index)\s+\w+\s*;' 1:attribute
EOF



    for r in code routine/parameters/default routine/default; do
        cat <<EOF
            add-highlighter shared/ada/$r/ regex '[.:=<>^*/+-]' 0:operator
            add-highlighter shared/ada/$r/constants regex \
                \b(?i)($(join "$constants"))\b 0:value


            add-highlighter shared/ada/$r/decimal regex [^\w](${decimal_literal})[^\w] 1:value
            add-highlighter shared/ada/$r/hex regex [^\w](${based_literal})[^\w] 1:value
EOF
    done
}

define-command -hidden ada-indent-on-new-line %{
    evaluate-commands -no-hooks -draft -itersel %{
        # preserve previous line indent
        try %{ execute-keys -draft <semicolon> K <a-&> }
        # cleanup trailing whitespaces from previous line
        try %{ execute-keys -draft k <a-x> s \h+$ <ret> d }
        # indent after certain keywords
        try %{ execute-keys -draft k<a-x><a-k>(?i)(begin|declare|do|else|exception|generic|loop|record|then|type)\h*$<ret>j<a-gt> }
    }
}
§

# Other syntax highlighters for reference:
# https://github.com/pygments/pygments/blob/master/pygments/lexers/pascal.py
# https://github.com/codemirror/CodeMirror/blob/master/mode/pascal/pascal.js
# https://github.com/vim/vim/blob/master/runtime/syntax/pascal.vim
# https://github.com/highlightjs/highlight.js/blob/master/src/languages/delphi.js
