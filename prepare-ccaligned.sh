SRC=en
PROCESS=None
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
    -p=*|--process=*)
    PROCESS="${i#*=}"
    shift
    ;;
    *)      # unknown argument
    ;;
esac
done
DATA=$DATA_ROOT/data
CODE_DIR=$(dirname "$0")
SCRIPTS=$CODE_DIR/scripts

REMOVE_FILE_PATHS=()

CC_ALIGNED_ROOT=$DATA/ccaligned
CC_ALIGNED_FILE=$CC_ALIGNED_ROOT/${SRC}_${TGT}.tsv

if [ ! -e $CC_ALIGNED_FILE ]; then
    echo "Download cc aligned data at ${CC_ALIGNED_FILE}"
    exit -1
fi

MAX_NUM_EXAMPLES=$(wc -l $CC_ALIGNED_FILE | awk '{print $1}')
echo "Total Examples: ${MAX_NUM_EXAMPLES}"
NUM_VALIDATION_EXAMPLES=$(( $MAX_NUM_EXAMPLES / 10 ))
NUM_TRAIN_EXAMPLES=$(( $MAX_NUM_EXAMPLES - $NUM_VALIDATION_EXAMPLES ))
echo "Training Examples: ${NUM_TRAIN_EXAMPLES}, Validation Example: ${NUM_VALIDATION_EXAMPLES}" 

PREFIX=cc-aligned
LANG_DATA=$DATA/all-clean-$TGT
mkdir -p $LANG_DATA

data_clean() {
    local FILE=$1
    case $PROCESS in 
        None)
            ;;
        Moses|moses)
            local MOSES=$CODE_DIR/mosesdecoder
            if [ ! -e $MOSES ]; then
                echo 'Cloning Moses github repository (for tokenization scripts)...'
                git clone https://github.com/moses-smt/mosesdecoder.git
            fi
            TMPFILE=$FILE.tmp
            mv $FILE $TMPFILE
            local REM_NON_PRINT_CHAR=$MOSES/scripts/tokenizer/remove-non-printing-char.perl
            echo "Cleaning out non printing characters ...."
            cat $TMPFILE | perl $REM_NON_PRINT_CHAR > $FILE
            rm $TMPFILE
            ;;
        *)
            echo "Preprocess ${PROCESS} not recognized"
            exit -1
            ;;
    esac
}

if [ ! -e $LANG_DATA/${PREFIX}.train.$SRC ]; then
    # First create a temporary file for shuffled data
    echo "Shuffling dataset"
    SHUFFLED_FILE=$CC_ALIGNED_ROOT/shuf.${SRC}_${TGT}.tsv
    cat $CC_ALIGNED_FILE | ./$SCRIPTS/shuf.py --seed 42  > $SHUFFLED_FILE

    echo "Spitting train and validation"
    SHUFFLED_TRAIN=$CC_ALIGNED_ROOT/shuf.train.tsv
    SHUFFLED_VALID=$CC_ALIGNED_ROOT/shuf.valid.tsv
    head -n $NUM_TRAIN_EXAMPLES $SHUFFLED_FILE > $SHUFFLED_TRAIN
    tail -n $NUM_VALIDATION_EXAMPLES $SHUFFLED_FILE > $SHUFFLED_VALID
    echo "Creating training data ..."
    cut -f1 $SHUFFLED_TRAIN > $LANG_DATA/${PREFIX}.train.$SRC
    data_clean ${LANG_DATA}/${PREFIX}.train.$SRC
    cut -f3 $SHUFFLED_TRAIN > $LANG_DATA/${PREFIX}.train.$TGT
    data_clean ${LANG_DATA}/${PREFIX}.train.$TGT

    echo "Creating validation data..."
    cut -f1 $SHUFFLED_VALID > $LANG_DATA/${PREFIX}.valid.$SRC
    data_clean ${LANG_DATA}/${PREFIX}.valid.$SRC
    cut -f3 $SHUFFLED_VALID > $LANG_DATA/${PREFIX}.valid.$TGT
    data_clean ${LANG_DATA}/${PREFIX}.valid.$TGT
    REMOVE_FILE_PATHS+=( $SHUFFLED_FILE $SHUFFLED_TRAIN $SHUFFLED_VALID )

fi
exit -1
# Remove the temporary files
for ((i=0;i<${#REMOVE_FILE_PATHS[@]};++i)); do
  rm -rf ${REMOVE_FILE_PATHS[i]}
done

# # Now tokenize, create BPEs and binarize data
# BPESIZE=32000
# PREFIX=ccaligned
# TMP=${DATA}/${PREFIX}_${TGT}_${SRC}_bpe${BPESIZE}
# DATABIN=${DATA_ROOT}/data-bin/${PREFIX}_${TGT}_${SRC}_bpe${BPESIZE}


# mkdir -p $TMP $DATABIN

# echo "tokenizing training data"
# bash $SCRIPTS/download_indic.sh

# TGT_TOKENIZER="bash $SCRIPTS/indic_norm_tok.sh $TGT"
# SRC_TOKENIZER="cat"  # learn source-side BPE over untokenized (raw) text
# if [ ! -e ${TMP}/train.$SRC ]; then
#     $SRC_TOKENIZER ${LANG_DATA}/cc-aligned.train.$SRC > ${TMP}/train.$SRC
#     $TGT_TOKENIZER ${LANG_DATA}/cc-aligned.train.$TGT > ${TMP}/train.$TGT
# fi

# if [ ! -e ${TMP}/valid.$SRC ]; then
#     echo "tokenizing validation data"
#     $SRC_TOKENIZER ${LANG_DATA}/cc-aligned.valid.$SRC > ${TMP}/valid.$SRC
#     $TGT_TOKENIZER ${LANG_DATA}/cc-aligned.valid.$TGT > ${TMP}/valid.$TGT
# fi

# echo "training sentencepiece"
# SPM_TRAIN=$SCRIPTS/spm_train.py
# SPM_ENCODE=$SCRIPTS/spm_encode.py

# python $SPM_TRAIN \
#   --input=$TMP/train.$SRC,$TMP/train.$TGT \
#   --model_prefix=$DATABIN/sentencepiece.bpe \
#   --vocab_size=$BPESIZE \
#   --character_coverage=1.0 \
#   --model_type=bpe

# echo "encoding with trained sentencepiece"
# python $SPM_ENCODE \
#   --model $DATABIN/sentencepiece.bpe.model \
#   --output_format=piece \
#   --inputs $TMP/train.$SRC $TMP/train.$TGT \
#   --outputs $TMP/train.bpe.$SRC $TMP/train.bpe.$TGT \
#   --min-len $TRAIN_MINLEN --max-len $TRAIN_MAXLEN

# python $SPM_ENCODE \
#     --model $DATABIN/sentencepiece.bpe.model \
#     --output_format=piece \
#     --inputs $TMP/valid.$SRC $TMP/valid.$TGT \
#     --outputs $TMP/valid.bpe.$SRC $TMP/valid.bpe.$TGT

# echo "Creating binaries"
# fairseq-preprocess \
#   --source-lang $SRC --target-lang $TGT \
#   --trainpref $TMP/train.bpe --validpref $TMP/valid.bpe \
#   --destdir $DATABIN \
#   --joined-dictionary \
#   --workers 4

