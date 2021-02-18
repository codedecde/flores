SRC=en
SRC_TOK=raw
TGT_TOK=indic
PREFIX=ccaligned

for i in "$@"
do
case $i in
    -l=*|--lang=*)
    TGT="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--datadir=*)
    DATA_ROOT="${i#*=}"
    shift      # past argument level
    ;;
    -st=*|--srctok=*)
    SRC_TOK="${i#*=}"
    shift
    ;;
    -tt=*|--tgttok=*)
    TGT_TOK="${i#*=}"
    shift
    ;;
    -p=*|--prefix=*)
    PREFIX="${i#*=}"
    shift
    ;;
    *)      # unknown argument
    ;;
esac
done
DATA=$DATA_ROOT/data
CODE_DIR=$(dirname "$0")
SCRIPTS=$CODE_DIR/scripts

LANG_DATA=$DATA/all-clean-$TGT

if [ ! -e ${LANG_DATA}/${PREFIX}.train.$SRC ]; then
    echo "${LANG_DATA}/${PREFIX}.train.${SRC} not found"
    echo "Run prepare-ccaligned first .."
    exit -1
fi

pre_tokenize() {
    local TOK=$1
    local IN_FILE=$2
    local OUT_FILE=$3
    local LANG=$4
    echo "Tokenizing ${IN_FILE} with ${TOK}"
    case $TOK in 
        raw)
            local TOKENIZER="cat"
            $TOKENIZER $IN_FILE > $OUT_FILE
            ;;
        indic)
            bash $SCRIPTS/download_indic.sh
            local TOKENIZER="bash $SCRIPTS/indic_norm_tok.sh $LANG"
            $TOKENIZER $IN_FILE > $OUT_FILE
            ;;
        moses)
            local MOSES=$CODE_DIR/mosesdecoder
            if [ ! -e $MOSES ]; then
                echo 'Cloning Moses github repository (for tokenization scripts)...'
                git clone https://github.com/moses-smt/mosesdecoder.git
            fi
            local TOKENIZER=$MOSES/scripts/tokenizer/tokenizer.perl
            local CLEAN=$MOSES/scripts/training/clean-corpus-n.perl
            local NORM_PUNC=$MOSES/scripts/tokenizer/normalize-punctuation.perl
            local REM_NON_PRINT_CHAR=$MOSES/scripts/tokenizer/remove-non-printing-char.perl
            local NUM_THREADS=16
            cat $IN_FILE | \
                perl $NORM_PUNC $LANG | \
                perl $REM_NON_PRINT_CHAR | \
                perl $TOKENIZER -threads $NUM_THREADS -a -l $LANG > $OUT_FILE
            ;;
        jieba)
            cat $IN_FILE | python -m jieba -d ' ' > $OUT_FILE
            ;;
        *)
            echo "${TOK} not supported"
            exit -1
            ;;
    esac
}

PRETOKENIZED_DATA_DIR=${LANG_DATA}/pre-tokenized/${PREFIX}-${SRC_TOK}-${TGT_TOK}
mkdir -p $PRETOKENIZED_DATA_DIR

for SPLIT in "train" "valid"; do \
    if [ ! -e ${PRETOKENIZED_DATA_DIR}/${SPLIT}.$SRC ]; then
        pre_tokenize $SRC_TOK ${LANG_DATA}/${PREFIX}.$SPLIT.$SRC ${PRETOKENIZED_DATA_DIR}/${SPLIT}.$SRC $SRC
        pre_tokenize $TGT_TOK ${LANG_DATA}/${PREFIX}.$SPLIT.$TGT ${PRETOKENIZED_DATA_DIR}/${SPLIT}.$TGT $TGT
    fi
done

