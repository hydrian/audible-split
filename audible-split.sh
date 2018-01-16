#!/bin/bash
APP_NAME="$(basename $0)"
################
### DEFAULTS ###
################
DEFAULT_GAP="2.5"
DEFAULT_OUTPUT_DIR="${HOME}/Music"
DEFAULT_PRETEND=false

#################
### Arguments ###
#################

function display_help  {
  echo "SYNTAX: ${APP_NAME} OPTIONS FILE/DIR"
  echo '  --artist-tag <STRING>       Author name'
  echo '  --album-tag  <STRING>       Book name'
  echo '  --cover-file <STRING>       Location of image file for the cover art (optional)'
  echo '  --help                      Displays this help message'
  echo "  --output-dir <FILE>         Location of base directory for outputted files (default: ${DEFAULT_OUTPUT_DIR} )"
  echo '  --pretend                   Does not generated final output files'
  echo "  --silence-gap <FLOAT>       Number of seconds of silence that sections will split on (default: ${DEFAULT_GAP} seconds)"
  echo '  --track-title-tag <STRING>  Alternate name for the title for each track (default: --album-tag value)'
  echo '  --year-tag <INTEGER>        Release year (optional)'
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
    --help)
      display_help
      exit 0
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

#########################
### Applying Defaults ###
#########################

GAP="${GAP:-$DEFAULT_GAP}"
OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
PRETEND=${PRETEND:-$DEFAULT_PRETEND}

###########################
### Required Paramaters ###
###########################
if [ -z "${TAG_ARTIST}" ] ; then
	echo "--artist-tag is a required option" 1>&2
	display_help 1>&2
	exit 2
fi

if [ -z "${TAG_ALBUM}" ] ; then
	echo "--album-tag is a required option" 1>&2
	display_help 1>&2
	exit 2
fi

#########################
### Merging MP3 files ###
#########################

### Processing single file or directory
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

#######################
### Setting up tags ###
#######################

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

if $PRETEND ; then
  PRETEND_OPT=' -P'
fi

###########################
### Spliting on silence ###
###########################
mp3splt ${PRETEND_OPTd} -d "${OUTPUT_DIR}" -T 12 -s -p "min=${GAP}" -g "${TAG_OPT}" -m "${TAG_ALBUM_TITLE}.m3u" -o '@a/@b/@N-@t' ${FILES}
if [ $? -ne 0 ] ; then
  echo "Failed to split mp3 files." 1>&2
  exit 2
fi

if [ -f "${TMP_MP3WRAP_FILE}" ] ; then
  rm "${TMP_MP3WRAP_FILE}"
fi

$PRETEND && exit 0

###########################
### Applying extra tags ###
###########################

EYED3_TAG_OPTS=''

### Release year
if [ ! -z "${TAG_YEAR}" ] ; then
  EYED3_TAG_OPTS+=" --year=${TAG_YEAR}"
fi

### Cover Art
if [ -f "${COVER_FILE}" ] ; then
  COVER_FILE_SHORTNAME=$(basename "${COVER_FILE}")
  COVER_FILE_EXT="${COVER_FILE_SHORTNAME##*.}"
  LOCAL_COVER_FILE="cover.${COVER_FILE_EXT}"
  pushd "${OUTPUT_DIR}/${TAG_ARTIST}/${TAG_ALBUM_TITLE}/"
  
  cp "${COVER_FILE}" "${LOCAL_COVER_FILE}"
  EYED3_TAG_OPTS+=" --add-image ${LOCAL_COVER_FILE}:FRONT_COVER:''"
fi

### Executing tag command

if [ ! -z "${EYED3_TAG_OPTS}" ] ; then
  eyeD3 ${EYED3_TAG_OPTS} *.mp3
  if [ $? -ne 0 ] ; then
    echo "Failed to apply eye3D tags" 1>&2
    exit 2
  fi
fi

exit $?
