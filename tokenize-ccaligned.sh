TOK=bpe
SRC=en
VOCAB_SIZE=16000
TRAIN_MINLEN=1
TRAIN_MAXLEN=250
SRC_PRETOK=raw
TGT_PRETOK=indic

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
    -spt=*|--src_pretok=*)
    SRC_PRETOK="${i#*=}"
    shift
    ;;
    -tptt=*|--tgt_pretok=*)
    TGT_PRETOK="${i#*=}"
    shift
    ;;
    -tok=*)
    TOK="${i#*=}"
    shift
    ;;
    -sz=*|vocab_size=*)
    VOCAB_SIZE="${i#*=}"
    shift
    ;;
    *)      # unknown argument
    ;;
esac
done
DATA=$DATA_ROOT/data
CODE_DIR=$(dirname "$0")
SCRIPTS=$CODE_DIR/scripts
PREFIX=ccaligned

LANG_DATA=$DATA/all-clean-$TGT
PRETOK_DIR=${LANG_DATA}/pre-tokenized/${PREFIX}-${SRC_PRETOK}-${TGT_PRETOK}

if [ ! -d $PRETOK_DIR ]; then
    echo "Did not find ${PRETOK_DIR}. Run pretokenizer first !"
    exit -1
fi

DATABIN=$DATA_ROOT/data-bin/${PREFIX}.tokenization-${SRC_PRETOK}-${TGT_PRETOK}_${TGT}_${SRC}_${TOK}${VOCAB_SIZE}
mkdir -p $DATABIN

SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

if [ ! -e $DATABIN/sentencepiece.$TOK.model ]; then
  echo "training sentencepiece"
  python $SPM_TRAIN \
    --input=$PRETOK_DIR/train.$SRC,$PRETOK_DIR/train.$TGT \
    --model_prefix=$DATABIN/sentencepiece.$TOK \
    --vocab_size=$VOCAB_SIZE \
    --character_coverage=1.0 \
    --model_type=$TOK
fi

# echo "encoding with trained sentencepiece"
if [ ! -e $PRETOK_DIR/train.$TOK.$SRC ]; then
    python $SPM_ENCODE \
      --model $DATABIN/sentencepiece.$TOK.model \
      --output_format=piece \
      --inputs $PRETOK_DIR/train.$SRC $PRETOK_DIR/train.$TGT \
      --outputs $PRETOK_DIR/train.$TOK.$SRC $PRETOK_DIR/train.$TOK.$TGT \
      --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN
fi

if [ ! -e $PRETOK_DIR/valid.$TOK.$SRC ]; then
    python $SPM_ENCODE \
        --model $DATABIN/sentencepiece.$TOK.model \
        --output_format=piece \
        --inputs $PRETOK_DIR/valid.$SRC $PRETOK_DIR/valid.$TGT \
        --outputs $PRETOK_DIR/valid.$TOK.$SRC $PRETOK_DIR/valid.$TOK.$TGT
fi

if [ -e ${LANG_DATA}/test.$SRC ]; then
    python $SPM_ENCODE \
    --model $DATABIN/sentencepiece.$TOK.model \
    --output_format=piece \
    --inputs $LANG_DATA/test.$SRC $LANG_DATA/test.$TGT \
    --outputs $PRETOK_DIR/test.$TOK.$SRC $PRETOK_DIR/test.$TOK.$TGT
fi

PREPROCESS_DATA_PREFIX="--trainpref ${PRETOK_DIR}/train.bpe --validpref ${PRETOK_DIR}/valid.bpe"

if [ -e ${PRETOK_DIR}/test.$TOK.$SRC ]; then
    PREPROCESS_DATA_PREFIX+=" --testpref ${PRETOK_DIR}/test.${TOK}"
fi

echo "Creating binaries"
fairseq-preprocess \
  --source-lang $SRC --target-lang $TGT \
  ${PREPROCESS_DATA_PREFIX} \
  --destdir $DATABIN \
  --joined-dictionary \
  --workers 8