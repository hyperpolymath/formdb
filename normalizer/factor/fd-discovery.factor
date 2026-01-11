! SPDX-License-Identifier: AGPL-3.0-or-later
! Form.Normalizer - Functional Dependency Discovery
!
! Implements the DFD (Depth-First Discovery) algorithm for
! automatic functional dependency detection.

USING: accessors arrays assocs combinators combinators.short-circuit
continuations hash-sets io kernel math math.combinatorics
math.statistics random sequences sets sorting vectors ;

IN: fd-discovery

! ============================================================
! Core Types
! ============================================================

TUPLE: functional-dependency
    determinant     ! Set of attribute names
    dependent       ! Set of attribute names
    confidence      ! 0.0 to 1.0
    discovered-at   ! Journal sequence number
    sample-size ;   ! Number of records sampled

TUPLE: fd-discovery-config
    sample-size           ! Max records to sample
    confidence-threshold  ! Minimum confidence to report
    algorithm             ! dfd | tane | fdhits
    max-lhs-size ;        ! Maximum left-hand side cardinality

TUPLE: fd-discovery-result
    collection        ! Collection name
    dependencies      ! List of functional-dependency
    approximate-fds   ! FDs with confidence < 1.0
    discovery-time    ! Milliseconds
    sample-info ;     ! Sample metadata

! ============================================================
! Default Configuration
! ============================================================

: default-fd-config ( -- config )
    fd-discovery-config new
        10000 >>sample-size
        0.95 >>confidence-threshold
        "dfd" >>algorithm
        5 >>max-lhs-size ;

! ============================================================
! Partition Computation (Core of FD Discovery)
! ============================================================

! A partition groups row indices by their values on a set of attributes
TUPLE: partition
    attributes   ! Which attributes define this partition
    classes ;    ! List of equivalence classes (each a list of row indices)

: compute-partition ( data attributes -- partition )
    ! Group rows by their values on the given attributes
    partition new
        swap >>attributes
        [ ] >>classes ;  ! Placeholder - actual implementation would group rows

: refine-partition ( partition attr -- partition' )
    ! Refine partition by adding another attribute
    drop ;  ! Placeholder

: is-unique-partition? ( partition -- ? )
    ! True if every equivalence class has exactly 1 element
    classes>> [ length 1 = ] all? ;

! ============================================================
! DFD Algorithm (Simplified)
! ============================================================

! DFD uses depth-first lattice traversal to find minimal FDs

TUPLE: dfd-state
    attributes     ! All attribute names
    discovered     ! Set of discovered FDs
    visited        ! Set of visited attribute sets
    current-lhs ;  ! Current left-hand side being explored

: init-dfd-state ( attributes -- state )
    dfd-state new
        swap >>attributes
        V{ } clone >>discovered
        HS{ } clone >>visited
        { } >>current-lhs ;

: attribute-subsets ( attrs n -- subsets )
    ! Generate all n-element subsets of attributes
    <combinations> [ >array ] map ;

: check-fd ( data lhs rhs -- confidence )
    ! Check if LHS -> RHS holds in data
    ! Returns confidence (1.0 = exact, < 1.0 = approximate)
    3drop 1.0 ;  ! Placeholder - actual impl checks partition refinement

: discover-fds-for-rhs ( data state rhs -- fds )
    ! Find all minimal FDs with RHS as dependent
    2drop { } ;  ! Placeholder

: run-dfd ( data config -- result )
    ! Main DFD algorithm entry point
    drop
    ! Extract attribute names from data
    dup first keys sort >array
    init-dfd-state

    ! For each attribute as potential RHS
    dup attributes>> [
        [ ] dip  ! data state rhs
        over [ discover-fds-for-rhs ] dip swap
        discovered>> swap suffix!
        drop
    ] with with each

    ! Build result
    fd-discovery-result new
        "unknown" >>collection
        swap discovered>> >>dependencies
        { } >>approximate-fds
        0 >>discovery-time ;

! ============================================================
! Normal Form Detection
! ============================================================

TUPLE: normal-form-analysis
    collection
    current-form      ! 1NF, 2NF, 3NF, BCNF, etc.
    violations        ! List of violations
    candidate-keys ;  ! Inferred candidate keys

: is-superkey? ( attrs keys -- ? )
    ! Check if attrs is a superkey (contains a candidate key)
    [ subset? ] with any? ;

: check-bcnf-violation ( fd keys -- violation/f )
    ! BCNF violation: determinant is not a superkey
    [ determinant>> ] dip is-superkey? not
    [ dup ] [ f ] if ;

: check-3nf-violation ( fd keys prime-attrs -- violation/f )
    ! 3NF violation: determinant not superkey AND dependent not prime
    [ [ determinant>> ] dip is-superkey? not ]
    [ [ dependent>> ] dip subset? not ] 2bi
    and [ swap ] [ 2drop f ] if ;

: analyze-normal-form ( fds keys -- analysis )
    ! Determine highest normal form satisfied
    normal-form-analysis new
        "unknown" >>collection
        { } >>violations
        swap >>candidate-keys
        ! Placeholder: would analyze each FD against normal form rules
        "1NF" >>current-form ;

! ============================================================
! FQL Integration: DISCOVER DEPENDENCIES
! ============================================================

TUPLE: discover-stmt
    collection
    sample-size
    confidence
    algorithm ;

: parse-discover ( tokens -- tokens' ast )
    ! Parse: DISCOVER DEPENDENCIES FROM collection ...
    discover-stmt new
        10000 >>sample-size
        0.95 >>confidence
        "dfd" >>algorithm
    ! Would parse tokens to fill in values
    swap ;

: execute-discover ( stmt -- result )
    ! Execute DISCOVER DEPENDENCIES
    [ collection>> ] [ sample-size>> ] [ confidence>> ] [ algorithm>> ] quad

    ! Build config
    fd-discovery-config new
        swap >>algorithm
        swap >>confidence-threshold
        swap >>sample-size
        5 >>max-lhs-size

    ! Would fetch data from collection via Form.Bridge
    ! For now, return placeholder
    drop
    fd-discovery-result new
        swap >>collection
        { } >>dependencies
        { } >>approximate-fds
        0 >>discovery-time ;

! ============================================================
! Narrative Generation
! ============================================================

: fd>narrative ( fd -- string )
    ! Convert FD to human-readable narrative
    [ determinant>> ", " join ]
    [ dependent>> ", " join ]
    [ confidence>> ]
    tri
    [ "{" prepend "} uniquely determines {" append swap append "}" append ]
    dip
    [ " [confidence: " swap number>string append "]" append ] when* ;

: result>narrative ( result -- string )
    ! Generate full narrative for discovery result
    [
        "FUNCTIONAL DEPENDENCY DISCOVERY\n"
        "Collection: " append
        over collection>> append "\n" append
        "\nDiscovered Dependencies:\n" append
        swap dependencies>> [ fd>narrative "  " prepend "\n" append append ] each
    ] "" make ;

! ============================================================
! Normalization Proposals
! ============================================================

TUPLE: normalization-proposal
    source-schema
    target-schemas
    transformation
    inverse
    equivalence-proof
    narrative ;

: propose-3nf-decomposition ( schema fds -- proposal/f )
    ! Generate 3NF decomposition proposal if violations exist
    ! Returns f if already in 3NF
    2drop f ;  ! Placeholder

: propose-bcnf-decomposition ( schema fds -- proposal/f )
    ! Generate BCNF decomposition proposal if violations exist
    ! Returns f if already in BCNF
    2drop f ;  ! Placeholder

! ============================================================
! Public API
! ============================================================

: discover-dependencies ( collection-name config -- result )
    ! Main entry point for FD discovery
    ! Would call Form.Bridge to fetch data, then run algorithm
    2drop
    fd-discovery-result new
        "placeholder" >>collection
        { } >>dependencies
        { } >>approximate-fds
        0 >>discovery-time ;

: check-normal-form ( collection-name target-nf -- analysis )
    ! Check if collection satisfies target normal form
    2drop
    normal-form-analysis new
        "placeholder" >>collection
        "1NF" >>current-form
        { } >>violations
        { } >>candidate-keys ;

: generate-normalization-proposal ( collection-name target-nf -- proposal/f )
    ! Generate proposal to reach target normal form
    2drop f ;
