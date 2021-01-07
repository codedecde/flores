#!/bin/bash
SRC=hi
TGT=en

BPESIZE=5000
TRAIN_MINLEN=1
TRAIN_MAXLEN=250

CODE_ROOT=$(dirname "$0")
SCRIPTS=$CODE_ROOT/scripts

DATA_ROOT=$(dirname "$0")

DATA=$DATA_ROOT/data
HI_ROOT=$DATA/all-clean-$SRC

mkdir -p $DATA_ROOT $HI_ROOT

TRAIN_PREFIX="IITB.en-hi"
DEV_PREFIX="dev"
TEST_PREFIX="test"

TMP=${DATA}/iitb_$SRC_$TGT_bpe${BPESIZE}
DATABIN=${DATA_ROOT}/data-bin/iitb_$SRC_$TGT_bpe${BPESIZE}

mkdir -p $TMP $DATABIN

echo "tokenizing training data"
bash $SCRIPTS/download_indic.sh

SRC_TOKENIZER="bash $SCRIPTS/indic_norm_tok.sh $SRC"
TGT_TOKENIZER="cat"  # learn target-side BPE over untokenized (raw) text

$SRC_TOKENIZER ${HI_ROOT}/${TRAIN_PREFIX}.$SRC > ${TMP}/train.$SRC
$TGT_TOKENIZER ${HI_ROOT}/${TRAIN_PREFIX}.$TGT > ${TMP}/train.$TGT

echo "tokenizing validation data"
$SRC_TOKENIZER ${HI_ROOT}/${DEV_PREFIX}.$SRC > ${TMP}/valid.$SRC
$TGT_TOKENIZER ${HI_ROOT}/${DEV_PREFIX}.$TGT > ${TMP}/valid.$TGT

echo "tokenizing test data"
$SRC_TOKENIZER ${HI_ROOT}/${TEST_PREFIX}.$SRC > ${TMP}/test.$SRC
$TGT_TOKENIZER ${HI_ROOT}/${TEST_PREFIX}.$TGT > ${TMP}/test.$TGT

echo "training sentencepiece"
SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

python $SPM_TRAIN \
  --input=$TMP/train.$SRC,$TMP/train.$TGT \
  --model_prefix=$DATABIN/sentencepiece.bpe \
  --vocab_size=$BPESIZE \
  --character_coverage=1.0 \
  --model_type=bpe

echo "encoding with trained sentencepiece"
python $SPM_ENCODE \
  --model $DATABIN/sentencepiece.bpe.model \
  --output_format=piece \
  --inputs $TMP/train.$SRC $TMP/train.$TGT \
  --outputs $TMP/train.bpe.$SRC $TMP/train.bpe.$TGT \
  --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN

for SPLIT in "valid" "test"; do \
  python $SPM_ENCODE \
    --model $DATABIN/sentencepiece.bpe.model \
    --output_format=piece \
    --inputs $TMP/$SPLIT.$SRC $TMP/$SPLIT.$TGT \
    --outputs $TMP/$SPLIT.bpe.$SRC $TMP/$SPLIT.bpe.$TGT
done

echo "Creating binaries"
fairseq-preprocess \
  --source-lang $SRC --target-lang $TGT \
  --trainpref $TMP/train.bpe --validpref $TMP/valid.bpe --testpref $TMP/test.bpe \
  --destdir $DATABIN \
  --joined-dictionary \
  --workers 4
