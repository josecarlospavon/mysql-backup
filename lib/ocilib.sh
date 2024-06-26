#PATH=/opt/instit_dump/data_pump_pdb_dir
#BUCKETURL="https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/_rulzMBK9GtXPryVIrimwo2ufDOhrsF01HORPEmQzFctQoiuEhGSSslnVSHWIEW9/n/zrbdyot5qknt/b/pe2atp1_bucket/o/"

#for file in "${PATH}"/*; do
#  if [ -f "$file" ]; then
#    echo "Uploading $file to Object Store Bucket"
#    /usr/bin/curl -T "$file" ${BUCKETURL}
#  fi
#done

function upload_file {
    if [ -z "$1" ]; then
        printError "Error: No file specified."
        return 1
    fi
    
    /usr/bin/curl -T "${1}" "${BUCKETURL}"
}
