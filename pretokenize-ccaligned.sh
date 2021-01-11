SRC=en
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
    *)      # unknown argument
    ;;
esac
done
DATA=$DATA_ROOT/data
CODE_DIR=$(dirname "$0")
SCRIPTS=$CODE_DIR/scripts
PREFIX=ccaligned

REMOVE_FILE_PATHS=()

SRC_TOK=raw
TGT_TOK=indic

LANG_DATA=$DATA/all-clean-$TGT

bash $SCRIPTS/download_indic.sh

case $SRC_TOK in
    raw)
        SRC_TOKENIZER="cat"
        ;;
    *)
        echo "${SRC_TOK} not supported"
        exit -1
        ;;
esac
case $TGT_TOK in
    raw)
        TGT_TOKENIZER="cat"
        ;;
    indic)
        TGT_TOKENIZER="bash $SCRIPTS/indic_norm_tok.sh $TGT"
        ;;
    *)
        echo "${TGT_TOK} not supported"
        exit -1
        ;;
esac

TOKENIZED_DATA_DIR=${LANG_DATA}/pre-tokenized/{PREFIX}-${SRC_TOK}-${TGT_TOK}
mkdir -p $LANG_DATA

for SPLIT in "train" "valid"; do \
    if [ ! -e ${TOKENIZED_DATA_DIR}/${SPLIT}.$SRC ]; then
        echo "Tokenizing ${SPLIT} data"
        echo "Using ${SRC_TOKENIZER}"
        $SRC_TOKENIZER ${LANG_DATA}/cc-aligned.$SPLIT.$SRC > ${TOKENIZED_DATA_DIR}/${SPLIT}.$SRC
        echo "Using ${TGT_TOKENIZER}"
        $TGT_TOKENIZER ${LANG_DATA}/cc-aligned.$SPLIT.$TGT > ${TOKENIZED_DATA_DIR}/${SPLIT}.$TGT
    fi
done

