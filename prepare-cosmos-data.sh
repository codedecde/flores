#!/bin/bash
SRC=ne
TGT=en

BPESIZE=5000
TRAIN_MINLEN=1
TRAIN_MAXLEN=250

CODE_ROOT=$(dirname "$0")
SCRIPTS=$CODE_ROOT/scripts

# DATA_ROOT=$(dirname "$0")
DATA_ROOT="/data/bapatra/flores"

DATA=${DATA_ROOT}/data
COSMOS_PREFIX=cosmos-raw
# COSMOS_PREFIX=cosmos-raw
TMP=${DATA}/${COSMOS_PREFIX}_${SRC}_${TGT}_bpe${BPESIZE}
DATABIN=${DATA_ROOT}/data-bin/${COSMOS_PREFIX}_${SRC}_${TGT}_bpe${BPESIZE}

mkdir -p $TMP $DATABIN


echo "prepraring training data"
COSMOS_ROOT=${DATA}/${COSMOS_PREFIX}-${SRC}
COSMOS_FILE=${COSMOS_ROOT}/${TGT}_${SRC}.tsv
echo $COSMOS_FILE
if [ ! -e $COSMOS_FILE ]; then
    echo "Download tsv from cosmos"
    exit -1
fi

awk 'BEGIN {FS="\t"; OFS="\t"} NR>1 {print gensub(/"?(.+)"?/, "\\1", 1, $3)}' $COSMOS_FILE > $TMP/raw.$TGT
awk 'BEGIN {FS="\t"; OFS="\t"} NR>1 {print gensub(/"?(.+)"?/, "\\1", 1, $4)}' $COSMOS_FILE > $TMP/raw.$SRC

echo "setting up tokenizers"

echo "pre-processing train data..."
SRC_TOKENIZER="bash $SCRIPTS/indic_norm_tok.sh $SRC"
TGT_TOKENIZER="cat"  # learn target-side BPE over untokenized (raw) text
SPM_TRAIN=$SCRIPTS/spm_train.py
SPM_ENCODE=$SCRIPTS/spm_encode.py

bash $SCRIPTS/download_indic.sh
$SRC_TOKENIZER $TMP/raw.$SRC > $TMP/train.$SRC
$TGT_TOKENIZER $TMP/raw.$TGT > $TMP/train.$TGT

echo "pre-processing dev/test data..."
VALID_SET="wikipedia_en_ne_si_test_sets/wikipedia.dev.ne-en"
TEST_SET="wikipedia_en_ne_si_test_sets/wikipedia.devtest.ne-en"
if [ ! -d $DATA/${VALID_SET} ]; then
    pushd $DATA/
    tar -vxf wikipedia_en_ne_si_test_sets.tgz
    popd
fi

$SRC_TOKENIZER $DATA/${VALID_SET}.$SRC > $TMP/valid.$SRC
$TGT_TOKENIZER $DATA/${VALID_SET}.$TGT > $TMP/valid.$TGT
$SRC_TOKENIZER $DATA/${TEST_SET}.$SRC > $TMP/test.$SRC
$TGT_TOKENIZER $DATA/${TEST_SET}.$TGT > $TMP/test.$TGT

echo "remove overlap if any..."
OVERLAP_REMOVE_SCRIPT=$SCRIPTS/remove_overlap.py
python $OVERLAP_REMOVE_SCRIPT \
    --train_file=$TMP/train.$SRC
    --test_file=$TMP/test.$SRC

python $OVERLAP_REMOVE_SCRIPT \
    --train_file=$TMP/train.$TGT
    --test_file=$TMP/test.$TGT

# learn BPE with sentencepiece
python $SPM_TRAIN \
  --input=$TMP/train.$SRC,$TMP/train.$TGT \
  --model_prefix=$DATABIN/sentencepiece.bpe \
  --vocab_size=$BPESIZE \
  --character_coverage=1.0 \
  --model_type=bpe

# encode train/valid/test
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

# binarize data
fairseq-preprocess \
  --source-lang $SRC --target-lang $TGT \
  --trainpref $TMP/train.bpe --validpref $TMP/valid.bpe --testpref $TMP/test.bpe \
  --destdir $DATABIN \
  --joined-dictionary \
  --workers 4
