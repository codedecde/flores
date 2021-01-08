#!/bin/bash
# Adapted from https://github.com/facebookresearch/MIXER/blob/master/prepareData.sh

URLS=(
    "http://statmt.org/wmt13/training-parallel-europarl-v7.tgz"
    "http://statmt.org/wmt13/training-parallel-commoncrawl.tgz"
    "http://statmt.org/wmt13/training-parallel-un.tgz"
    "http://statmt.org/wmt14/training-parallel-nc-v9.tgz"
    "http://statmt.org/wmt10/training-giga-fren.tar"
    "http://statmt.org/wmt14/test-full.tgz"
)
FILES=(
    "training-parallel-europarl-v7.tgz"
    "training-parallel-commoncrawl.tgz"
    "training-parallel-un.tgz"
    "training-parallel-nc-v9.tgz"
    "training-giga-fren.tar"
    "test-full.tgz"
)

echo "Downloading data ...."

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

download_wmt_data() {
    CORPORA=$1
    URL=$2
    download_data $CORPORA $URL
    if [ ${CORPORA: -4} == ".tgz" ]; then
        tar zxvf $CORPORA
    elif [ ${CORPORA: -4} == ".tar" ]; then
        tar xvf $CORPORA
    fi   
}


DATA_ROOT=/data/bapatra/flores
DATA=$DATA_ROOT/data
FR_ROOT=$DATA/all-clean-fr
SRC=fr
TGT=en
LANG=$TGT-$SRC

mkdir -p $FR_ROOT
pushd $FR_ROOT

for ((i=0;i<${#URLS[@]};++i)); do
    file=${FILES[i]}
    url=${URLS[i]}
    download_wmt_data $file $url
done

gunzip giga-fren.release2.fixed.*.gz
popd
