#!/bin/bash

# (https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
#   - `-e`: Exit immediately if any pipeline returns nonzero status.
#   - `-o pipefail`: Return value of pipeline is value of last command to exit
#     with nonzero status, or zero if all commands succeeded.
#   - `-x`: Print trace of many of commands below; useful for debugging.
set -e -x -o pipefail

# Many executables in [viral-ngs](https://github.com/broadinstitute/viral-ngs)
# depend on executables in this miniconda/bin/, so we add it to PATH env var
# here.
#
# PRECONDITION: miniconda/bin/ must somehow be downloaded and unpackaged into
# execution env.
export PATH="$PATH:$HOME/miniconda/bin/"

function main() {

  dx cat "$resources" | tar zx -C /

  # log detailed sys utilization
  dstat -cmdn 60 &

  # Fetch and uncompress database
  mkdir "./$database_prefix"
  db_decompressor="zcat"
  if [[ "$database_name" == *.lz4 ]]; then
    db_decompressor="lz4 -d"
  fi
  dx cat "$database" | $db_decompressor | tar -C "./$database_prefix" -xvf -
  # if the tarball had a top-level directory component, move the contents up.
  if [ $(find "./$database_prefix" -type f | cut -d / -f 2,3 | sort | uniq | wc -l) -eq "1" ]; then
    mv ./${database_prefix}/$(find "./$database_prefix" -type f | cut -d / -f 3 | uniq)/* ./${database_prefix}
    find "./$database_prefix" -type f
  fi
  du -sh "./$database_prefix"

  # Fetch and uncompress Krona db.
  mkdir "./$krona_taxonomy_db_prefix"
  db_decompressor="zcat"
  if [[ "$krona_taxonomy_db_name" == *.lz4 ]]; then
    db_decompressor="lz4 -d"
  fi
  dx cat "$krona_taxonomy_db" | $db_decompressor | tar -C "./$krona_taxonomy_db_prefix" -xvf -
  # if the tarball had a top-level directory component, move the contents up.
  if [ $(find "./$krona_taxonomy_db_prefix" -type f | cut -d / -f 2,3 | sort | uniq | wc -l) -eq "1" ]; then
    mv ./${krona_taxonomy_db_prefix}/$(find "./$krona_taxonomy_db_prefix" -type f | cut -d / -f 3 | uniq)/* ./${krona_taxonomy_db_prefix}
    find "./$krona_taxonomy_db_prefix" -type f
  fi
  du -sh "./$krona_taxonomy_db_prefix"


  mkdir -p ~/input/

  for i in "${!mappings[@]}"; do
    dx cat "${mappings[$i]}" > ~/input/"${mappings_prefix[$i]}".bam
    mkdir -p ~/out/outputs/"${mappings_prefix[$i]}"/
    viral-ngs/metagenomics.py kraken ~/input/"${mappings_prefix[$i]}".bam "./$database_prefix" --outReads ~/out/outputs/"${mappings_prefix[$i]}"/"${mappings_prefix[$i]}".kraken-classified.txt.gz --outReport ~/out/outputs/"${mappings_prefix[$i]}"/"${mappings_prefix[$i]}".kraken-report.txt --numThreads `nproc`

    # viral-ngs/metagenomics.py krona ~/out/outputs/"${mappings_prefix[$i]}".kraken-classified.txt.gz "./$krona_taxonomy_db_prefix" ~/out/html/"${mappings_prefix[$i]}".report.html --noRank
  done

  dx-upload-all-outputs --parallel
}
