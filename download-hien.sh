#!/bin/bash
# Downloads the data and creates data/all-clean.tgz within the current directory

set -e
set -o pipefail

SRC=en
HI_TGT=hi

DATA_ROOT=/data/bapatra/flores

DATA=$DATA_ROOT/data
HI_ROOT=$DATA/all-clean-${HI_TGT}

mkdir -p $DATA_ROOT $HI_ROOT

REMOVE_FILE_PATHS=()

# Download data
download_data() {
  CORPORA=$1
  URL=$2

  if [ -f $CORPORA ]; then
    echo "$CORPORA already exists, skipping download"
  else
    echo "Downloading $URL"
    wget $URL -O $CORPORA --no-check-certificate || rm -f $CORPORA
    if [ -f $CORPORA ]; then
      echo "$URL successfully downloaded."
    else
      echo "$URL not successfully downloaded."
      rm -f $CORPORA
      exit -1
    fi
  fi
}

download_data $DATA/en-hi.dev-test.tgz "http://www.cfilt.iitb.ac.in/iitb_parallel/iitb_corpus_download/dev_test.tgz"
tar xvzf $DATA/en-hi.dev-test.tgz
cp dev_test/* $HI_ROOT/
REMOVE_FILE_PATHS+=( dev_test $DATA/en-hi.dev-test.tgz )

download_data $DATA/en-hi.tgz "http://www.cfilt.iitb.ac.in/iitb_parallel/iitb_corpus_download/parallel.tgz"
#download_data $DATA/en-hi.tgz "https://www.cse.iitb.ac.in/~anoopk/share/iitb_en_hi_parallel/iitb_corpus_download/parallel.tgz"
tar xvzf $DATA/en-hi.tgz
cp parallel/* $HI_ROOT/
REMOVE_FILE_PATHS+=( parallel $DATA/en-hi.tgz )

# Remove the temporary files
for ((i=0;i<${#REMOVE_FILE_PATHS[@]};++i)); do
  rm -rf ${REMOVE_FILE_PATHS[i]}
done