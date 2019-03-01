#!/bin/bash
. ./setup-env.sh

function run-all() { mpirun --hosts ${all_h},${all_c} -ppn 1 /bin/bash -c "$1 $2 $3 $4 $5 $6"; }
function run-cln() { mpirun --hosts ${all_c} -ppn 1 /bin/bash -c "$1 $2 $3 $4 $5 $6"; }
function run-srv() { mpirun --hosts ${all_h} -ppn 1 /bin/bash -c "$1 $2 $3 $4 $5 $6"; }
export -f run-all
export -f run-cln
export -f run-srv

function count() {
    IFS=","
    __NC=$(echo $1 | wc -w)
    unset IFS;
    echo $__NC
}

function getval() {
    __str=$1
    ((__n = ${#__str} - 1))
    __val=${__str:0:$__n}
    __sfx=${__str:$__n:1}
    case $__sfx in
    'k' | 'K') ((__val = __val*1024)) ;;
    'm' | 'M') ((__val = __val*1024*1024)) ;;
    'g' | 'G') ((__val = __val*1024*1024*1024)) ;;
    '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9') ((__val=__str)) ;;
    esac
    echo $__val
}

function make_list() {
    a=(`echo "$1" | tr ',' ' '`)
    if ((${#a[*]} == 0 || $2 <= 0)); then
        echo ""
        return;
    fi
    list=""
    for ((i = 0; i < $2 && i < ${#a[*]}; i++)); do
        list="$list${a[$i]},"
    done
    list=${list:0:((${#list}-1))}
    echo $list
}

OPTS=`getopt -o I:i:S:C:R:b:s:nw:r:W:c:vq -l iter-srv:,iter-cln:,servers:,clients:,ranks:,block:,segment:,n2n,writes:,reads:,warmup:,cycles:,verbose,sequential -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
#echo "$OPTS"
eval set -- "$OPTS"

nodes=($(squeue -u $USER -o %P:%N -h | cut -d':' -f 2))
parts=($(squeue -u $USER -o %P:%N -h | cut -d':' -f 1))
all_h=""
all_c=""
for ((i = 0; i < ${#parts[*]}; i++)) do
    nlist=${nodes[$i]}
    if [[ "$nlist" =~ "[" ]]; then
        #some sort of range, list or combination of the two
        base=${nlist%%[*}
        #split into ranges separated by space
        spec=`echo ${nlist##$base} | tr -d [] | tr , ' '`
        nodes=""
        for range in $spec; do
            #process range
            beg=${range%-*}
            len=${#beg}
            ((rbeg = beg))
            ((rend = ${range#*-}))
            if ((rend > rbeg)); then
                #range
                for ((j = rbeg; j <= rend; j++)); do
                    node=`printf "%s%0*d-ib," $base $len $j`
                    nodes="$nodes$node"
                done
            else
                #just one node
                nodes="$nodes$base$range-ib,"
            fi
        done
    else
        #single node
        nodes="$nlist-ib,"
    fi
    nodes=${nodes:0:((${#nodes}-1))}
    if [[ "${parts[$i]}" == *"ionode"* ]]; then
        all_h="$all_h$nodes,"
    else
        all_c="$all_c$nodes,"
    fi
done
all_h=${all_h:0:((${#all_h}-1))}
all_c=${all_c:0:((${#all_c}-1))}
export all_h
export all_c
echo "Allocated Servers: $all_h"
echo "Allocated Clients: $all_c"
export MPI_LOG=${PWD}/mpi.log
export TEST_LOG=${PWD}/test.log
export SRV_LOG=${PWD}/server.log

oSERVERS="$all_h"
oCLIENTS="$all_c"
oRANKS="1,2,4,8,16"
oBLOCK="1G"
oSEGMENT="1"
oWRITES="4K,64K,128K,1M"
oREADS=""
oWARMUP="0"

oVERBOSE=0
oN2N=0
oSEQ=0

cycles=1

declare -a SrvIter
declare -a ClnIter

while true; do
  case "$1" in
  -v | --verbose )   oVERBOSE=1; shift ;;
  -n | --n2n)        oN2N=1; shift ;;
  -q | --sequential) oSEQ=1; shift ;;
  -S | --servers)    oSERVERS="$2"; shift; shift ;;
  -C | --clients)    oCLIENTS="$2"; shift; shift ;;
  -R | --ranks )     oRANKS="$2"; shift; shift ;;
  -b | --block)      oBLOCK="$2"; shift; shift ;;
  -s | --segment)    oSEGMENT="$2"; shift; shift ;;
  -w | --writes)     oWRITES="$2"; shift; shift ;;
  -W | --warmup)     oWARMUP="$2"; shift; shift ;;
  -r | --reads)      oREADS="$2"; shift; shift ;;
  -c | --cycles)     cycles="$2"; shift; shift ;;
  -i | --iter-cln)   ClnIter=(`echo "$2" | tr ',' ' '`); shift; shift ;;
  -I | --iter-srv)   SrvIter=(`echo "$2" | tr ',' ' '`); shift; shift ;;
  -- ) shift; break ;;
  * ) break ;;
  esac
done

if [ -z "$oREADS" ]; then oREADS=$oWRITES; fi

export hh="${oSERVERS}"
export cc="${oCLIENTS}"
ns=$(count $hh)
nc=$(count $cc)
IFS=","

((i = 0))
((max_ranks = 0))
for r in $oRANKS; do RANK[$i]=$r; if ((RANK[i] > max_ranks)); then ((max_ranks = RANK[i])); fi; ((i++)); done

((i = 0))
((max_tx = 0))
for w in $oWRITES; do TXSZ[$i]=$(getval $w); if ((TXSZ[i] > max_tx)); then ((max_tx = TXSZ[i])); fi; ((i++)); done

((i = 0))
for r in $oREADS; do RDSZ[$i]=$(getval $r); ((i++)); done

blksz=$(getval $oBLOCK)
wup=$(getval $oWARMUP)
seg=$(getval $oSEGMENT)

if ((!${#SrvIter[*]})); then SrvIter[0]=$ns; fi
if ((!${#ClnIter[*]})); then ClnIter[0]=$nc; fi

unset IFS

if ((oSEQ)); then seq="-S 1"; else seq=""; fi
((err=0))
for ((si = 0; si < ${#SrvIter[*]}; si++)); do
    export Servers=`make_list "$hh" ${SrvIter[$si]}`
    ns=`count $Servers`

    for ((ci = 0; ci < ${#ClnIter[*]}; ci++)); do
        export Clients=`make_list "$cc" ${ClnIter[$ci]}`
        echo "=== $Clients -> $Servers ===" >> $TEST_LOG
        nc=`count $Clients`

        for ((i = 0; i < ${#RANK[*]}; i++)); do
            for ((j = 0; j < ${#TXSZ[*]}; j++)); do
                dsc="[$nc*${RANK[$i]}]->$ns Block=$blksz Segments=$seg"
                dsc="$dsc Writes=${TXSZ[$j]}"
                if [ -z "${RDSZ[$j]}" ]; then 
                    reads="-w"
                    dsc="$dsc <no reads>"
                else
                    if ((RDSZ[$j] < 0)); then
                        reads="-w"
                        dsc="$dsc <no reads>"
                    else
                        reads="-r ${RDSZ[$j]}"
                        dsc="$dsc Reads=${RDSZ[$j]}"
                    fi
                fi
                if [ -z "$seq" ]; then 
                    dsc="$dsc RANDOM"
                else
                    dsc="$dsc SEQ"
                fi
                if ((oN2N)); then 
                    ptrn="-p 1"
                    dsc="$dsc N-to-N"
                else
                    ptrn="-p 0"
                    dsc="$dsc N-to-1"
                fi
                if ((wup == 0)); then 
                    wu="" 
                    dsc="$dsc <no warmup>"
                else 
                    wu="-W $wup"
                    dsc="$dsc WARMUP=$wup"
                fi
                for ((k = 0; k < cycles; k++)); do
                    ((mem = (nc*RANK[i]*seg*blksz + nc*RANK[i]*wup)/ns))
                    ((mem = (mem/1024/1024/1024 + 1)*1024*1024*1024))
                    export BLK="-b $blksz"
                    export SEG="-s $seg"
                    export WSZ="-t ${TXSZ[$j]}"
                    export RSZ="$reads"
                    export WUP="$wu"
                    export PTR="$ptrn"
                    export SEQ="$seq"
                    export DSC="$dsc"
                    export Ranks="${RANK[$i]}"
                    export AllNodes="$Servers,$Clients"
                    export MEM=$mem
                    export DSC="$dsc"
                    source ./test-env
                    ((kk = k + 1))
                    echo "Starting cycle $kk of: $DSC"
                    if ./test_cycle.sh; then
                        echo "Finished OK"
                    else
                        ((err++))
                        echo "Finished with ERRORS"
                    fi
                done
            done
        done
        echo "===" >> $TEST_LOG
    done
done
echo "Error count: $err"
