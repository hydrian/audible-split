#!/bin/bash
APP_NAME="$(basename $0)"

DEFAULT_GAP="1.5"
DEFAULT_OUTPUT_DIR="${HOME}/Music"

function display_help  {
  echo "SYNTAX: ${APP_NAME} OPTIONS FILE/DIR"
  echo '  --artist-tag <STRING>       Author name'
  echo '  --album-tag  <STRING>       Book name'
  echo '  --cover-file <STRING>       Location of image file for the cover art (optional)'
  echo '  --output-dir <FILE>         Location of base directory for outputted files (default: ~/Music)'
  echo "  --pretend                   Does not generated final output files"
  echo "  --silence-gap <FLOAT>       Number of seconds of silence that sections will split on"
  echo "  --track-title-tag <STRING>  Alternate name for the title for each track (default: --album-tag value)"
  echo "  --year-tag <INTEGER>        Release year"
  return 0
}

while [[ $# -gt 0 ]] ; do 
  KEY="$1"
  case "${KEY}" in
    --pretend)
      PRETEND=true
    ;;
    --silence-gap)
      GAP="${2}"
      shift
    ;;
    --artist-tag)
      TAG_ARTIST="${2}"
      shift 
    ;;
    --year-tag)
      TAG_YEAR="${2}"
      shift
    ;;
    --album-tag)
      TAG_ALBUM_TITLE="${2}"
      shift 
    ;;
    --track-title-tag)
      TAG_TRACK_TITLE="${2}"
      shift
    ;;
    --output-dir)
      OUTPUT_DIR="${2}"
      shift
    ;;
    --cover-file)
      COVER_FILE="${2}"
      shift
    ;;
    --)
      FILES="$1"
      break
    ;;
    *)
      FILES="$1"
      break
    ;;
 
  esac
  shift
done



GAP="${GAP:-$DEFAULT_GAP}"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"

if [ -d "${FILES}" ] ; then
  TMP_MP3_FILE=$(mktemp --suffix='audible-split')
  TMP_MP3WRAP_FILE="${TMP_MP3_FILE}_MP3WRAP.mp3"
  mp3wrap "${TMP_MP3_FILE}" "${FILES}"/*.mp3
  if [ $? -ne 0 ] ; then
    echo 'Failed to merge mp3 files to single file' 1>&2
    test -f "${TMP_MP3_FILE}" && rm "${TMP_MP3_FILE}"
    exit 2
  fi
  test -f "${TMP_MP3_FILE}" && rm "${TMP_MP3_FILE}"
  FILES="${TMP_MP3WRAP_FILE}"
elif [ -f "${FILES}" ] ; then
  WRAP_OPT=''
else 
  echo "Failed to filed valid file or directory ${FILES}" 1>&2
  exit 2
fi

if [ -z "${TAG_TRACK_TITLE}" ] ; then
  TAG_TRACK_TITLE="${TAG_ALBUM_TITLE}"
fi

TAG_OPT="r%[@N=1,@a=${TAG_ARTIST},@b=${TAG_ALBUM_TITLE},@g=Speech"

if [ ! -z "${TAG_YEAR}" ] ; then
  TAG_OPT+=",y=${TAG_YEAR}"
fi

if [ -z "${TAG_TRACK_TITLE}" ] ; then
  TAG_TRACK_TITLE="${TAG_ALBUM_TITLE}"
fi

TAG_OPT+=",@t=${TAG_TRACK_TITLE}]"

if $PRETEND ; thennaiteve
  PRETEND_OPT=' -P'
fi

mp3splt ${PRETEND_OPT} -d "${OUTPUT_DIR}" -T 12 -s -p "min=${GAP}" -g "${TAG_OPT}" -m "${TAG_ALBUM_TITLE}.m3u" -o '@a/@b/@N-@t' ${FILES}
if [ $? -ne 0 ] ; then
  echo "Failed to split mp3 files." 1>&2
  exit 2
fi

if [ -f "${TMP_MP3WRAP_FILE}" ] ; then
  rm "${TMP_MP3WRAP_FILE}"
fi

if $PRETEND ; then
  exit 0
fi

EYED3_TAG_OPTS=''

if [ ! -z "${TAG_YEAR}" ] ; then
  EYED3_TAG_OPTS+=" --year=${TAG_YEAR}"
fi

if [ -f "${COVER_FILE}" ] ; then
  COVER_FILE_SHORTNAME=$(basename "${COVER_FILE}")
  COVER_FILE_EXT="${COVER_FILE_SHORTNAME##*.}"
  LOCAL_COVER_FILE="cover.${COVER_FILE_EXT}"
  pushd "${OUTPUT_DIR}/${TAG_ARTIST}/${TAG_ALBUM_TITLE}/"
  cp "${COVER_FILE}" "${LOCAL_COVER_FILE}"
  EYED3_TAG_OPTS+=" --add-image ${LOCAL_COVER_FILE}:FRONT_COVER:''"
fi

if [ ! -z "${EYED3_TAG_OPTS}" ] ; then
  eyeD3 ${EYED3_TAG_OPTS} *.mp3
  if [ $? -ne 0 ] ; then
    echo "Failed to insert cover art" 1>&2
    exit 2
  fi
fi

exit $?