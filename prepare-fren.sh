SRC=en
TGT=fr

CODE_ROOT=$(dirname "$0")
DATA_ROOT=$CODE_ROOT
DATA=$DATA_ROOT/data
FR_DATA=$DATA/all-clean-fr

MOSES=$CODE_ROOT/mosesdecoder

if [ ! -e $MOSES ]; then
    echo 'Cloning Moses github repository (for tokenization scripts)...'
    git clone https://github.com/moses-smt/mosesdecoder.git
fi

TOKENIZER=$MOSES/scripts/tokenizer/tokenizer.perl
CLEAN=$MOSES/scripts/training/clean-corpus-n.perl
NORM_PUNC=$MOSES/scripts/tokenizer/normalize-punctuation.perl
REM_NON_PRINT_CHAR=$MOSES/scripts/tokenizer/remove-non-printing-char.perl

BPESIZE=40000

CORPORA=(
    "training/europarl-v7.fr-en"
    "commoncrawl.fr-en"
    "un/undoc.2000.fr-en"
    "training/news-commentary-v9.fr-en"
    "giga-fren.release2.fixed"
)

PREFIX=wmt14
TMP=${DATA}/$PREFIX_$SRC_$TGT_bpe${BPESIZE}
DATABIN=${DATA_ROOT}/data-bin/$PREFIX_$SRC_$TGT_bpe${BPESIZE}

mkdir -p $TMP $DATABIN

echo 'Tokenizing training data...'
for lang in $SRC $TGT; do
    for file in "${CORPORA[@]}"; do
        cat $FR_DATA/$file.$lang | \
            perl $NORM_PUNC $lang | \
            perl $REM_NON_PRINT_CHAR | \
            perl $TOKENIZER -threads 8 -a -l $lang >> $TMP/train-val.$lang
    done
done

echo 'Tokenizing testing data...'
for lang in $SRC $TGT; do
    if [ "$lang" == "$SRC" ]; then
        t="src"
    else
        t="ref"
    fi
    grep '<seg id' $FR_DATA/test-full/newstest2014-fren-$t.$lang.sgm | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -a -l $l > $TMP/test.$lang
    echo ""
done

echo "Splitting train and valid..."
for lang in $SRC $TGT; do
    awk '{if (NR%1333 == 0)  print $0; }' $TMP/train-val.$lang > $TMP/valid.$lang
    awk '{if (NR%1333 != 0)  print $0; }' $TMP/train-val.$lang > $TMP/train.$lang
done

echo "Training sentencepiece"
SCRIPTS=$CODE_ROOT/scripts
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