! SPDX-License-Identifier: AGPL-3.0-or-later
! Form.Runtime - FQL Parser and Executor
!
! FQL (FormDB Query Language) implementation using PEG parsing.

USING: accessors arrays assocs combinators combinators.short-circuit
continuations io json kernel math math.parser peg peg.ebnf
sequences splitting strings unicode ;

IN: fql

! ============================================================
! AST Node Types
! ============================================================

TUPLE: fql-insert collection document provenance ;
TUPLE: fql-select fields collection where-clause edge-clause limit-clause with-provenance? ;
TUPLE: fql-update collection assignments where-clause provenance ;
TUPLE: fql-delete collection where-clause provenance ;
TUPLE: fql-create collection fields schema ;
TUPLE: fql-drop collection provenance ;
TUPLE: fql-explain inner-stmt ;
TUPLE: fql-introspect target arg ;

TUPLE: edge-clause type direction depth where ;
TUPLE: where-clause expression ;
TUPLE: limit-clause limit offset ;

TUPLE: comparison field op value ;
TUPLE: binary-expr left op right ;

! ============================================================
! Tokenizer
! ============================================================

: skip-whitespace ( str -- str' )
    [ " \t\n\r" member? not ] find drop "" or ;

: keyword? ( str -- ? )
    >upper {
        "SELECT" "FROM" "WHERE" "INSERT" "INTO" "UPDATE"
        "DELETE" "SET" "CREATE" "DROP" "COLLECTION"
        "WITH" "PROVENANCE" "LIMIT" "OFFSET"
        "TRAVERSE" "OUTBOUND" "INBOUND" "ANY" "DEPTH"
        "EXPLAIN" "INTROSPECT" "SCHEMA" "CONSTRAINTS"
        "JOURNAL" "SINCE" "COLLECTIONS"
        "AND" "OR" "NOT" "NULL" "TRUE" "FALSE"
        "STRING" "INTEGER" "FLOAT" "BOOLEAN" "TIMESTAMP"
        "JSON" "PROMPT_SCORE" "UNIQUE" "CHECK" "REFERENCES"
        "LIKE" "IN" "CONTAINS"
    } member? ;

: split-tokens ( str -- tokens )
    ! Simple tokenizer - splits on whitespace and punctuation
    " \t\n\r" split harvest
    [ "," = not ] filter ;

! ============================================================
! Parser Combinators (Simplified)
! ============================================================

ERROR: fql-parse-error message position ;

: expect-token ( tokens expected -- tokens' )
    swap unclip-slice
    pick >upper = [ drop ] [
        "Expected '" "'" surround fql-parse-error
    ] if ;

: peek-token ( tokens -- token/f )
    [ first ] [ drop f ] if-empty ;

: consume-token ( tokens -- tokens' token )
    unclip-slice swap ;

: try-consume ( tokens expected -- tokens' matched? )
    over peek-token dup [
        >upper = [
            swap unclip-slice drop t
        ] [
            drop f
        ] if
    ] [
        2drop f
    ] if ;

! ============================================================
! Parse Primitives
! ============================================================

: parse-identifier ( tokens -- tokens' identifier )
    consume-token
    dup keyword? [ "Unexpected keyword" fql-parse-error ] when ;

: parse-json-value ( tokens -- tokens' value )
    ! Simplified: just consume until end of JSON
    consume-token
    dup "{" = [
        drop
        ! Parse JSON object
        H{ } clone
        [ over peek-token "}" = not ] [
            swap consume-token drop  ! key
            swap consume-token drop  ! :
            swap consume-token       ! value
            ! Would need full JSON parsing here
            2drop
        ] while
        swap consume-token drop  ! }
        swap
    ] [
        ! It's a simple value
        swap
    ] if ;

: parse-string-literal ( tokens -- tokens' string )
    consume-token
    ! Remove quotes if present
    dup first CHAR: " = [
        1 tail* dup length 1 - head*
    ] when ;

! ============================================================
! Parse Statements
! ============================================================

: parse-collection-name ( tokens -- tokens' name )
    parse-identifier ;

: parse-field-list ( tokens -- tokens' fields )
    [ over peek-token "FROM" = not ] [
        consume-token
        over peek-token "," = [ swap consume-token drop swap ] when
    ] produce nip ;

: parse-where-clause ( tokens -- tokens' where/f )
    "WHERE" try-consume [
        ! Parse expression
        parse-identifier              ! field
        swap consume-token swap       ! operator
        swap consume-token swap       ! value
        comparison boa
        where-clause boa
    ] [
        f
    ] if ;

: parse-edge-clause ( tokens -- tokens' edge/f )
    "TRAVERSE" try-consume [
        parse-identifier           ! edge type
        swap consume-token swap    ! direction
        >upper
        "DEPTH" try-consume [
            swap consume-token string>number swap
        ] [ 1 swap ] if
        f  ! where clause placeholder
        edge-clause boa
    ] [
        f
    ] if ;

: parse-limit-clause ( tokens -- tokens' limit/f )
    "LIMIT" try-consume [
        consume-token string>number
        "OFFSET" try-consume [
            swap consume-token string>number swap
        ] [ 0 swap ] if
        limit-clause boa
    ] [
        f
    ] if ;

: parse-provenance-clause ( tokens -- tokens' prov/f )
    "WITH" try-consume [
        "PROVENANCE" expect-token
        ! Parse JSON object
        consume-token drop  ! {
        H{ } clone          ! placeholder
        [ over peek-token "}" = not ] [
            swap consume-token drop  ! skip tokens until }
        ] while
        swap consume-token drop  ! }
        swap
    ] [
        f
    ] if ;

! ============================================================
! Statement Parsers
! ============================================================

: parse-insert ( tokens -- tokens' ast )
    "INTO" expect-token
    parse-collection-name
    ! Parse document body (simplified - just consume JSON)
    swap consume-token drop  ! {
    H{ } clone
    [ over peek-token "}" = not ] [
        swap consume-token drop
    ] while
    swap consume-token drop  ! }
    swap
    ! Parse provenance
    parse-provenance-clause
    fql-insert boa ;

: parse-select ( tokens -- tokens' ast )
    ! Parse field list
    over peek-token "*" = [
        consume-token drop
        { "*" }
    ] [
        parse-field-list
    ] if
    ! FROM collection
    swap "FROM" expect-token
    parse-collection-name
    ! Optional clauses
    parse-where-clause
    swap parse-edge-clause swap
    swap parse-limit-clause swap
    ! WITH PROVENANCE?
    "WITH" try-consume [
        "PROVENANCE" try-consume
    ] [ f ] if
    fql-select boa ;

: parse-update ( tokens -- tokens' ast )
    parse-collection-name
    "SET" expect-token
    ! Parse assignments (simplified)
    { } clone
    [ over peek-token "WHERE" = not ] [
        swap parse-identifier      ! field
        swap consume-token drop    ! =
        swap consume-token         ! value
        2array suffix
        over peek-token "," = [ swap consume-token drop swap ] when
    ] while
    swap parse-where-clause swap
    swap parse-provenance-clause swap
    fql-update boa ;

: parse-delete ( tokens -- tokens' ast )
    "FROM" expect-token
    parse-collection-name
    parse-where-clause
    swap parse-provenance-clause swap
    fql-delete boa ;

: parse-create ( tokens -- tokens' ast )
    "COLLECTION" expect-token
    parse-collection-name
    ! Parse optional field definitions
    over peek-token "(" = [
        consume-token drop  ! (
        { } clone
        [ over peek-token ")" = not ] [
            swap parse-identifier  ! field name
            swap consume-token     ! type
            2array suffix
            over peek-token "," = [ swap consume-token drop swap ] when
        ] while
        swap consume-token drop  ! )
        swap
    ] [
        { } clone swap
    ] if
    ! Parse optional schema
    "WITH" try-consume [
        "SCHEMA" expect-token
        H{ } clone  ! placeholder for JSON
    ] [
        f
    ] if
    fql-create boa ;

: parse-drop ( tokens -- tokens' ast )
    "COLLECTION" expect-token
    parse-collection-name
    parse-provenance-clause
    fql-drop boa ;

: parse-introspect-target ( tokens -- tokens' target arg )
    consume-token >upper
    dup "JOURNAL" = [
        "SINCE" try-consume [
            swap consume-token string>number swap
        ] [
            0 swap
        ] if
    ] [
        dup "SCHEMA" = over "CONSTRAINTS" = or [
            over peek-token dup keyword? not and [
                swap parse-identifier swap
            ] [
                f swap
            ] if
        ] [
            f swap
        ] if
    ] if ;

: parse-introspect ( tokens -- tokens' ast )
    parse-introspect-target
    fql-introspect boa ;

DEFER: parse-statement

: parse-explain ( tokens -- tokens' ast )
    parse-statement
    fql-explain boa ;

: parse-statement ( tokens -- tokens' ast )
    consume-token >upper {
        { "INSERT" [ parse-insert ] }
        { "SELECT" [ parse-select ] }
        { "UPDATE" [ parse-update ] }
        { "DELETE" [ parse-delete ] }
        { "CREATE" [ parse-create ] }
        { "DROP" [ parse-drop ] }
        { "EXPLAIN" [ parse-explain ] }
        { "INTROSPECT" [ parse-introspect ] }
        [ "Unknown statement type" fql-parse-error ]
    } case ;

! ============================================================
! Main Parser Entry Point
! ============================================================

: parse-fql ( str -- ast )
    ! Remove trailing semicolon if present
    dup ";" tail? [ but-last ] when
    ! Remove comments
    "\n" split
    [
        "--" split1 drop ! Remove line comments
        "" or
    ] map
    " " join
    ! Tokenize
    split-tokens
    ! Parse
    parse-statement
    ! Should have consumed all tokens
    nip ;

! ============================================================
! Query Execution (Stubs)
! ============================================================

GENERIC: execute-fql ( ast -- result )

M: fql-insert execute-fql
    [
        H{
            { "status" "ok" }
            { "document_id" "doc_generated" }
        }
    ] [ collection>> ] bi
    "collection" pick set-at ;

M: fql-select execute-fql
    [
        H{
            { "status" "ok" }
            { "rows" { } }
            { "count" 0 }
        }
    ] [ collection>> ] bi
    "collection" pick set-at ;

M: fql-update execute-fql
    H{
        { "status" "ok" }
        { "modified_count" 0 }
    } ;

M: fql-delete execute-fql
    H{
        { "status" "ok" }
        { "deleted_count" 0 }
    } ;

M: fql-create execute-fql
    [
        H{
            { "status" "ok" }
            { "schema_version" 1 }
        }
    ] [ collection>> ] bi
    "collection" pick set-at ;

M: fql-drop execute-fql
    H{
        { "status" "ok" }
    } ;

M: fql-explain execute-fql
    inner-stmt>> execute-fql
    [
        H{
            { "status" "ok" }
            { "plan" H{
                { "type" "SCAN" }
                { "estimated_rows" 0 }
            } }
        }
    ] dip
    "result" pick set-at ;

M: fql-introspect execute-fql
    target>> {
        { "SCHEMA" [
            H{
                { "status" "ok" }
                { "fields" { } }
            }
        ] }
        { "CONSTRAINTS" [
            H{
                { "status" "ok" }
                { "constraints" { } }
            }
        ] }
        { "COLLECTIONS" [
            H{
                { "status" "ok" }
                { "collections" { } }
            }
        ] }
        { "JOURNAL" [
            H{
                { "status" "ok" }
                { "entries" { } }
            }
        ] }
        [ drop H{ { "status" "error" } { "message" "Unknown introspect target" } } ]
    } case ;

! ============================================================
! Public API
! ============================================================

: run-fql ( str -- result )
    parse-fql execute-fql ;

: explain-fql ( str -- plan )
    "EXPLAIN " prepend
    run-fql ;
