#!/bin/zsh
# -*- coding: utf-8; mode: sh; indent-tabs-mode: nil; tab-width: 2; sh-basic-offset: 2; sh-indentation: 2; fill-column: 75; -*-

[ $# -ge 2 ] || {
  echo "Illegal number of arguments."
  exit 1
}

command -v xargs >/dev/null 2>&1 || {
  echo >&2 "xargs is required. Aborting."
  exit 2
}

fswatch -o ${=*[1,-2]} | xargs -n1 -I{} ${=*[-1,-1]}
